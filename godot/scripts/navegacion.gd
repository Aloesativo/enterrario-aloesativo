class_name Navegacion
## Las reglas de movimiento. Datos puros: decide a qué celda se puede ir,
## nunca dibuja nada. Puerto de src/mundo/navegacion.js.
##
## La regla es UNA y es la que define el juego:
##
##     PUEDES PISAR LO QUE SE VE PEGADO A TI.
##
## No "lo que está al lado en el mundo" — lo que está al lado EN LA
## PANTALLA. Casi siempre coinciden, y por eso caminar se siente normal.
## Pero cuando no coinciden, cruzás un abismo porque desde ese ángulo el
## abismo no existe. Y al rotar, el puente desaparece.
##
## Es deliberadamente UNA sola regla, sin excepciones: si hubiera casos
## especiales, el jugador no podría construir un modelo mental fiable, y sin
## modelo mental fiable no hay descubrimiento — hay prueba y error.

var _indices: Array = [] # por rotación: Vector2i(pantalla) -> Vector3i(celda)
var _centro: Vector2i
var _bloques: Array = []

func _init(bloques: Array, centro: Vector2i) -> void:
	_centro = centro
	_bloques = bloques
	for r in Proyeccion.ROTACIONES:
		var mapa := {}
		for b in bloques:
			var p := Proyeccion.proyectar(b, r, centro)
			if not mapa.has(p) or b.y > (mapa[p] as Vector3i).y:
				mapa[p] = b
		_indices.append(mapa)

## Qué celda se VE en un punto de la pantalla (o null si no hay ninguna).
##
## Cuando dos celdas caen en el mismo píxel gana la más cercana a la cámara,
## porque solo se puede pisar lo que se ve.
##
## CORRECCIÓN RESPECTO DEL ORIGINAL: navegacion.js comparaba `x + z` SIN
## rotar, y eso solo es válido en la rotación 0 — la rotación cambia x+z.
## Acá se compara la ALTURA, que es equivalente y correcto en las cuatro.
##
## Demostración: dos celdas con el mismo (A,B) cumplen rx+rz = B + 2y, y la
## profundidad hacia la cámara va como rx+rz+y = B + 3y. Con B igual, el
## orden lo decide y. Y como la altura no rota, el criterio no depende de
## la rotación.
func celda_en_pantalla(pantalla: Vector2i, rotacion: int):
	return _indices[rotacion].get(pantalla)

## ¿Se VE esta celda, o está tapada por otra más cerca de la cámara?
func esta_visible(celda: Vector3i, rotacion: int) -> bool:
	var visible = _indices[rotacion].get(Proyeccion.proyectar(celda, rotacion, _centro))
	return visible != null and (visible as Vector3i) == celda

## Intenta dar un paso. Devuelve un diccionario con `permitido`, y si lo es,
## también `celda`, `puente` (si en el mundo real esas celdas NO se tocan y
## solo las une la perspectiva) y `distancia`.
func intentar_paso(desde: Vector3i, direccion: String, rotacion: int) -> Dictionary:
	if not Proyeccion.PASOS.has(direccion):
		return {"permitido": false, "motivo": "direccion-desconocida"}

	# LA OTRA MITAD DE LA REGLA: si no se te ve, no podés actuar.
	#
	# "Puedes pisar lo que se ve pegado a ti" solo tiene sentido si vos
	# también estás a la vista. Al rotar, el personaje puede quedar tapado
	# por la otra isla; si desde ahí pudiera saltar, el salto se vería salir
	# de la nada y aterrizar solo — se siente teletransporte, y rompe el
	# desafío (el jugador ni siquiera puede ver desde dónde saltó).
	#
	# Quedar tapado es inevitable y está bien. Lo que no puede pasar es
	# actuar estando tapado. Se sale rotando.
	if not esta_visible(desde, rotacion):
		return {"permitido": false, "motivo": "oculto"}

	var pantalla := Proyeccion.proyectar(desde, rotacion, _centro)
	var destino := pantalla + (Proyeccion.PASOS[direccion] as Vector2i)
	var celda = _indices[rotacion].get(destino)

	if celda == null:
		return {"permitido": false, "motivo": "vacio"}

	var c := celda as Vector3i
	var distancia: int = absi(c.x - desde.x) + absi(c.y - desde.y) + absi(c.z - desde.z)

	return {
		"permitido": true,
		"celda": c,
		"puente": distancia > 1,
		"distancia": distancia,
	}

## Qué celdas se alcanzan desde una, en una rotación dada. Es lo que permite
## comprobar que un nivel tiene solución sin jugarlo a mano.
func alcanzables(desde: Vector3i, rotacion: int) -> Dictionary:
	var vistas := {desde: true}
	var cola: Array = [desde]
	while not cola.is_empty():
		var actual: Vector3i = cola.pop_back()
		for direccion in Proyeccion.PASOS:
			var paso := intentar_paso(actual, direccion, rotacion)
			if not paso["permitido"]:
				continue
			var c: Vector3i = paso["celda"]
			if not vistas.has(c):
				vistas[c] = true
				cola.append(c)
	return vistas

## Comprueba que el nivel siga siendo un acertijo y avisa por consola si no.
##
## Un nivel se rompe de dos formas, y las dos son MUDAS si nadie las
## comprueba: que el objetivo quede inalcanzable en las cuatro rotaciones
## (no tiene solución), o que se alcance ya desde la rotación inicial (no es
## acertijo). Mover una sola celda basta para cualquiera de las dos.
##
## Corre al arrancar y solo informa: nunca rompe el arranque.
func validar(partida: Vector3i, objetivo: Vector3i, rotacion_inicial: int) -> bool:
	var resuelven: Array = []
	for r in Proyeccion.ROTACIONES:
		if alcanzables(partida, r).has(objetivo):
			resuelven.append(r)

	print("[nivel] rotaciones que alcanzan el objetivo: %s (inicial: %d)" % [resuelven, rotacion_inicial])

	if resuelven.is_empty():
		push_warning("[nivel] SIN SOLUCIÓN: el objetivo es inalcanzable en las 4 rotaciones.")
		return false
	if resuelven.has(rotacion_inicial):
		push_warning("[nivel] NO ES ACERTIJO: el objetivo ya se alcanza en la rotación inicial.")
		return false
	if not _comprobar_sin_trampas():
		return false

	print("[nivel] OK — acertijo válido: hay que rotar para llegar.")
	return true

## Tercera forma de romper un nivel, y la más traicionera: una celda que
## quede TAPADA en las cuatro rotaciones.
##
## Como no se puede actuar estando oculto, el jugador que pise ahí no puede
## ni moverse ni salir rotando: queda trabado para siempre y hay que
## reiniciar. El BFS de arriba no lo detecta nunca, porque nunca rota — solo
## explora dentro de una rotación fija.
func _comprobar_sin_trampas() -> bool:
	var trampas: Array = []
	for b in _bloques:
		var celda: Vector3i = b
		var visible_en_alguna := false
		for r in Proyeccion.ROTACIONES:
			if esta_visible(celda, r):
				visible_en_alguna = true
				break
		if not visible_en_alguna:
			trampas.append(celda)

	if trampas.is_empty():
		return true

	push_warning("[nivel] TRAMPA: %d celdas quedan tapadas en las 4 rotaciones; quien pise ahí no puede salir. %s" % [
		trampas.size(), trampas.slice(0, 5),
	])
	return false
