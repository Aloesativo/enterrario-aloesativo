class_name Acertijo
extends Node3D
## REGISTRO ACERTIJO — el estereograma. Isométrica rígida, celdas discretas.
##
## Esto es lo que antes era `mundo.gd`, o sea TODO el juego. Ya no: ahora es
## UN registro de dos (PREPRODUCCION.md §1). Lo de adentro no cambió — está
## verificado por RR y por `herramientas/verificar_nivel.py` — pero cambió
## quién manda:
##
##   - antes  → era la escena raíz, dueña de la cámara, y arrancaba sola.
##   - ahora  → `frontera.gd` le dice cuándo se activa y a qué zona se entra,
##              y este script solo CALCULA dónde debería estar la cámara.
##
## Por qué la cámara dejó de ser suya: la transición desde el registro habitar
## tiene que ser UNA TOMA CONTINUA en la que el mundo se aplana ante tus ojos.
## Con una cámara por registro eso sería un corte, y un corte no revela nada.
##
## LO QUE NO SE TOCA, NI UN POCO (DISENO_GODOT.md §2, §3, §4):
##   - celdas discretas, sin move_and_slide(), sin gravedad, sin velocidad
##     continua. El movimiento continuo del otro registro NO entra acá.
##   - cámara ortográfica isométrica verdadera, RÍGIDA. Sin órbita libre.
##   - rotaciones de 90° exactos, con enteros, sin senos ni cosenos.
##   - los DOS contadores de rotación.
##
## Estructura de nodos que arma:
##   Acertijo (este script)
##     Zona_ciudad (pivote) ... gira sobre su propio centro
##       Islas / Balizas
##     Zona_playa (pivote)
##     Zona_luna (pivote)
##     (el Personaje se re-parenta a la zona activa)

## Distancia de la cámara al punto que mira, por eje. La posición es
## `objetivo + ONE * esto`, que da azimut 45° y elevación atan(1/√2) ≈ 35.264°
## — la isométrica verdadera, la única en la que la matemática de A y B vale.
const DISTANCIA_CAMARA := 40.0

## Distancia real cámara↔objetivo. La necesita `frontera.gd` para calcular el
## FOV con el que la perspectiva se vuelve indistinguible de la ortográfica.
const DISTANCIA_REAL := DISTANCIA_CAMARA * 1.7320508 # * √3

const DURACION_GIRO := 0.38

## El viaje entre zonas del acertijo. RR lo pidió como "saltos de cámara":
## corto, no un paseo. Es OTRO mecanismo que la frontera con el registro
## habitar, y no se pisan.
const DURACION_VIAJE := 0.55

## Flechas/D-pad/stick a las cuatro diagonales de la pantalla.
## Asignación antihoraria (DISENO_GODOT.md §4), verificada por RR.
const DIRECCIONES := {
	"ui_up": "NO",
	"ui_right": "NE",
	"ui_down": "SE",
	"ui_left": "SO",
}

signal salir_pedido

var _zonas := {}      # id -> datos (la definición de abajo)
var _vivas := {}      # id -> {pivote, nav, giro}
var _zona_activa := ""

var _personaje: Personaje

# --- giro de la zona activa (los DOS contadores, ver más abajo) ---
var _rotando := false
var _t_giro := 0.0
var _angulo_desde := 0.0
var _angulo_hasta := 0.0

# --- viaje entre zonas del acertijo ---
var _viajando := false
var _t_viaje := 0.0
var _cam_desde := Vector3.ZERO
var _cam_hasta := Vector3.ZERO
var _size_desde := 20.0
var _size_hasta := 20.0

# --- estado de cámara que este registro PIDE (no la mueve él) ---
var _cam_pos := Vector3.ZERO
var _cam_size := 20.0

var _cola_direccion := ""
var _aviso_oculto_dado := false
var _activo := false

## Salir pisando la celda de partida. Se habilita recién cuando el personaje
## se fue de ella: si no, entrar al santuario te expulsaría en el mismo paso,
## porque se entra parado justo ahí.
var _puede_salir_por_partida := false

## Los materiales del cuerpo del personaje, para el fundido de la toma.
var _materiales_personaje: Array = []

## Lo que el mundo recuerda entre visitas. Hoy los hallazgos y la rotación de
## cada zona (guardada en _vivas). Es el gancho para "el mundo recuerda lo que
## dejaste" (DISENO_GODOT.md §6) cuando exista el guardado — que sigue sin
## diseñar (PREPRODUCCION.md §8).
var _descubiertos := {}

## Las zonas de Burdeo.
##
## ⚠️ QUÉ SE PUEDE TOCAR Y QUÉ NO — la distinción importa y no era obvia:
##
##   `origen`  → SEGURO de mover. Solo coloca la zona en el espacio del mundo.
##               La matemática del acertijo trabaja en coordenadas de CELDA
##               relativas a `centro`, así que trasladar la zona no cambia
##               ninguna alineación.
##   `areas`, `centro`, `partida`, `acertijo`, `rotacion_inicial`
##             → NO se tocan a ojo. Mover una isla UNA celda puede dejar el
##               acertijo sin solución o quitarle la gracia, en silencio.
##               Verificar con `herramientas/verificar_nivel.py`.
##
## Los `origen` de acá están puestos ALTO a propósito: cada zona flota sobre la
## isla habitable, visible desde abajo como un monumento, con su arco al pie
## (ver habitar.gd → _definir_arcos). Así el santuario se ve desde afuera antes
## de entrar, que es requisito de diseño (PREPRODUCCION.md §2) — un umbral que
## no se ve venir no es una invitación.
##
## ⚠️ Lo que elevarlas NO consigue, aunque lo parezca: sacar la isla habitable
## del encuadre isométrico. Se comprobó con números y es falso — la isla de
## 40×40 cae dentro del cuadro de los tres santuarios, y subirlas más no ayuda
## porque empuja fuera los puntos de abajo pero mete los de arriba (playa
## tendría que estar a y=50). Por eso la frontera DISUELVE el mundo habitado en
## vez de apagarlo: ver cuerpo.gd → recolectar_materiales().
func _definir_zonas() -> Dictionary:
	return {
		"ciudad": {
			"titulo": "Burdeo — la ciudad",
			# "Concreto, guetos verticales" + "Burdeo BB: las dos torres, los
			# dos pilares de la ciudad" (src/story/burdeo.json).
			"areas": [
				{"x0": 0, "x1": 5, "z0": 0, "z1": 5, "y": 0},
				{"x0": 9, "x1": 14, "z0": 9, "z1": 14, "y": 7},
			],
			"centro": Vector2i(7, 7),
			"partida": Vector3i(0, 0, 0),
			"rotacion_inicial": 2,
			"acertijo": Vector3i(14, 7, 14),
			"origen": Vector3(-21, 20, -21), # pivote en (-14, 20, -14)
			"tamano_camara": 20.0,
			"salidas": {
				Vector3i(14, 7, 14): "luna", # arriba de las torres: el premio
				Vector3i(5, 0, 5): "playa",  # a ras de suelo: el vecino fácil
			},
		},
		"playa": {
			"titulo": "Playa / costas",
			# "Conectada a Burdeo dentro del mismo mapa". Sin acertijo a
			# propósito: un lugar donde estar. "Cada lugar al que se llega debe
			# ser contemplativo" (IDEAS_DISENO.md).
			"areas": [
				{"x0": 0, "x1": 8, "z0": 0, "z1": 5, "y": 0},
			],
			"centro": Vector2i(4, 2),
			"partida": Vector3i(0, 0, 0),
			"rotacion_inicial": 0,
			"acertijo": null,
			"origen": Vector3(-4, 16, 14), # pivote en (0, 16, 16)
			"tamano_camara": 16.0,
			"salidas": {
				Vector3i(8, 0, 5): "ciudad",
			},
		},
		"luna": {
			"titulo": "La luna de Burdeo",
			# "El satélite de la ciudad". Más chica y más alta.
			"areas": [
				{"x0": 0, "x1": 3, "z0": 0, "z1": 3, "y": 0},
				{"x0": 7, "x1": 10, "z0": 7, "z1": 10, "y": 5},
			],
			"centro": Vector2i(5, 5),
			"partida": Vector3i(0, 0, 0),
			"rotacion_inicial": 2,
			"acertijo": Vector3i(10, 5, 10),
			"origen": Vector3(9, 26, -19), # pivote en (14, 26, -14)
			"tamano_camara": 15.0,
			"salidas": {
				Vector3i(0, 0, 3): "ciudad",
			},
		},
	}

func _ready() -> void:
	_zonas = _definir_zonas()
	for id in _zonas:
		_construir_zona(id as String)
	_crear_personaje()
	# Arranca apagado: manda frontera.gd. Antes este registro entraba solo a la
	# ciudad porque era el juego entero.
	_personaje.visible = false
	print("[acertijo] %d santuarios listos: %s" % [_zonas.size(), _zonas.keys()])

## ¿Existe esta zona? Lo pregunta frontera.gd antes de volar hacia ella, para
## que un arco mal escrito dé un error claro en vez de un crash a mitad de la
## transición.
func tiene_zona(id: String) -> bool:
	return _zonas.has(id)

# ------------------------------------------------------------- construcción

func _construir_zona(id: String) -> void:
	var datos: Dictionary = _zonas[id]
	var bloques := _bloques_de(datos)

	var pivote := Node3D.new()
	pivote.name = "Zona_" + id.replace("-", "_")
	# El pivote se planta en el centro de giro de SU zona: rotarlo hace girar
	# esa zona sobre su propio centro, el mismo que usa la matemática.
	var centro: Vector2i = datos["centro"]
	pivote.position = (datos["origen"] as Vector3) + Vector3(
		centro.x * Personaje.TAM, 0.0, centro.y * Personaje.TAM
	)
	add_child(pivote)

	var nav := Navegacion.new(bloques, centro)
	var giro: int = datos["rotacion_inicial"]
	pivote.rotation.y = _angulo_de(giro)

	_construir_islas(pivote, bloques, centro)
	_construir_marcas(pivote, datos, centro)

	_vivas[id] = {"pivote": pivote, "nav": nav, "giro": giro}

	print("[zona:%s] %s — %d celdas" % [id, datos["titulo"], bloques.size()])
	var acertijo = datos["acertijo"]
	if acertijo != null:
		nav.validar(datos["partida"] as Vector3i, acertijo as Vector3i, giro)

func _bloques_de(datos: Dictionary) -> Array:
	var bloques: Array = []
	for area in datos["areas"]:
		var y := int(area["y"])
		for x in range(int(area["x0"]), int(area["x1"]) + 1):
			for z in range(int(area["z0"]), int(area["z1"]) + 1):
				bloques.append(Vector3i(x, y, z))
	return bloques

func _construir_islas(pivote: Node3D, bloques: Array, centro: Vector2i) -> void:
	# Losas delgadas: dejan ver la altura, que es la información con la que se
	# juega. El damero no es decoración — sin contraste entre celdas vecinas no
	# se pueden contar celdas, y contar celdas es como se lee la alineación
	# (DISENO_GODOT.md §6 ter).
	var malla := BoxMesh.new()
	malla.size = Vector3(Personaje.TAM * 0.94, 0.25, Personaje.TAM * 0.94)

	var claro := StandardMaterial3D.new()
	claro.albedo_color = Color(0.66, 0.66, 0.66)
	var oscuro := StandardMaterial3D.new()
	oscuro.albedo_color = Color(0.54, 0.54, 0.54)

	for b in bloques:
		var c: Vector3i = b
		var losa := MeshInstance3D.new()
		losa.mesh = malla
		losa.material_override = oscuro if (c.x + c.z) % 2 == 0 else claro
		losa.position = Personaje.posicion_local(c, centro) - Vector3(0, 0.125, 0)
		pivote.add_child(losa)

func _construir_marcas(pivote: Node3D, datos: Dictionary, centro: Vector2i) -> void:
	# Colores placeholder reutilizados del theme que ya existía en
	# src/theme/default.json — la identidad visual la define RR.
	var acertijo = datos["acertijo"]
	if acertijo != null:
		pivote.add_child(_marca(acertijo as Vector3i, centro, Color(0.878, 0.753, 0.376), 0.30))
	for celda in datos["salidas"]:
		pivote.add_child(_marca(celda as Vector3i, centro, Color(0.5, 0.78, 0.85), 0.22))
	# La celda de partida marcada como la puerta de vuelta al mundo habitado.
	# Que se VEA es importante: el prototipo anterior tuvo un bug en el que
	# entrar a una zona era un viaje solo de ida y el jugador quedaba pegado
	# (CLAUDE.md, "Bug del mapa-zoom sin vuelta atrás"). Una salida invisible
	# es lo mismo que no tener salida.
	pivote.add_child(_marca(datos["partida"] as Vector3i, centro, Color(0.72, 0.84, 0.72), 0.20))

func _marca(celda: Vector3i, centro: Vector2i, color: Color, radio: float) -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	var forma := SphereMesh.new()
	forma.radius = radio
	forma.height = radio * 2.0
	malla.mesh = forma
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.5
	malla.material_override = material
	malla.position = Personaje.posicion_local(celda, centro) + Vector3(0, 0.9, 0)
	return malla

func _crear_personaje() -> void:
	_personaje = Personaje.new()
	_personaje.name = "Personaje"
	_personaje.paso_terminado.connect(_al_terminar_paso)
	# El cuerpo va en su propio nodo para que el bamboleo, la inclinación y el
	# giro del andar no toquen la posición lógica (ver personaje.gd). Es el
	# MISMO cuerpo que usa el registro habitar: un solo ser, dos registros.
	_personaje.montar_cuerpo(Cuerpo.crear())
	_materiales_personaje = Cuerpo.recolectar_materiales(_personaje)

# --------------------------------------------------- lo que pide frontera.gd

## Entrar a una zona sin viaje de cámara: la cámara la trae la frontera, con su
## propia toma. Se entra siempre en la celda `partida`, que es la verificada.
func entrar_zona(id: String) -> void:
	_entrar_a(id, false)
	_puede_salir_por_partida = false

## Si este registro responde al input. Separado de `mostrar()` a propósito: la
## toma de la frontera necesita que el personaje ya se VEA un instante antes de
## que se pueda jugar, y mezclarlos daba un frame en el que el jugador podía
## mover a alguien invisible.
func activar(si: bool) -> void:
	_activo = si

func mostrar(si: bool) -> void:
	if _personaje != null:
		_personaje.visible = si

## Opacidad del personaje, 0..1. Durante la toma de la frontera el personaje se
## funde hacia dentro mientras el mundo habitado se funde hacia fuera: es un
## fundido CRUZADO, no dos cortes. Sin esto el personaje aparecía de golpe al
## final de la toma.
func opacidad_personaje(opacidad: float) -> void:
	Cuerpo.aplicar_opacidad(_materiales_personaje, opacidad)

## Distancia real cámara↔objetivo. La usa frontera.gd para calcular el FOV con
## el que la perspectiva se vuelve indistinguible de esta ortográfica.
func distancia_camara() -> float:
	return DISTANCIA_REAL

## Dónde debería estar la cámara. No la mueve: la calcula.
##
## La BASE es constante siempre — se mira siempre desde la misma dirección, así
## que "la cámara no gira nunca" queda garantizado por construcción y no por
## disciplina. Lo único que cambia entre zonas es el origen.
func transform_camara() -> Transform3D:
	var t := Transform3D()
	t.origin = _cam_pos
	return t.looking_at(_cam_pos - Vector3.ONE * DISTANCIA_CAMARA, Vector3.UP)

func tamano_camara() -> float:
	return _cam_size

# ------------------------------------------------------------ cambio de zona

func _entrar_a(id: String, con_viaje: bool) -> void:
	var datos: Dictionary = _zonas[id]
	var viva: Dictionary = _vivas[id]
	var pivote: Node3D = viva["pivote"]

	# El personaje se re-parenta a la zona nueva. Es UN solo personaje que
	# viaja, no uno por zona.
	if _personaje.get_parent() != null:
		_personaje.get_parent().remove_child(_personaje)
	pivote.add_child(_personaje)
	_personaje.configurar(datos["partida"] as Vector3i, datos["centro"] as Vector2i)

	_zona_activa = id
	_rotando = false
	_cola_direccion = ""
	_aviso_oculto_dado = false

	var destino := _ancla_de(id)
	_size_hasta = datos["tamano_camara"]
	if con_viaje:
		_cam_desde = _cam_pos
		_cam_hasta = destino
		_size_desde = _cam_size
		_t_viaje = 0.0
		_viajando = true
		_puede_salir_por_partida = false
	else:
		_cam_pos = destino
		_cam_size = _size_hasta

	print("[acertijo] entrás a '%s' (%s)" % [id, datos["titulo"]])

## El punto que mira la cámara: el centro de giro de la zona a media altura.
## Ese punto no se mueve al rotar, así que la zona queda estable en pantalla en
## las cuatro rotaciones.
func _objetivo_de(id: String) -> Vector3:
	var datos: Dictionary = _zonas[id]
	var pivote: Node3D = (_vivas[id] as Dictionary)["pivote"]
	var alto_max := 0
	for area in datos["areas"]:
		alto_max = maxi(alto_max, int(area["y"]))
	return pivote.position + Vector3(0, alto_max * Personaje.ALTO * 0.5, 0)

func _ancla_de(id: String) -> Vector3:
	return _objetivo_de(id) + Vector3.ONE * DISTANCIA_CAMARA

func _animar_viaje(delta: float) -> void:
	if not _viajando:
		return
	_t_viaje += delta / DURACION_VIAJE
	var t := clampf(_t_viaje, 0.0, 1.0)
	var s := t * t * (3.0 - 2.0 * t) # suave al salir y al llegar
	_cam_pos = _cam_desde.lerp(_cam_hasta, s)
	_cam_size = lerpf(_size_desde, _size_hasta, s)
	if t >= 1.0:
		_viajando = false
		_cam_pos = _cam_hasta
		_cam_size = _size_hasta

# ------------------------------------------------------------------- giro

## LOS DOS CONTADORES. No es redundancia: es la corrección de un bug real y
## caro (INFORME.md §6).
##
## El giro guardado por zona nunca da la vuelta (…, -1, 0, 1, 2, 3, 4, …) y
## sirve para ANIMAR: como siempre cambia de a uno, el ángulo destino está
## siempre a 90° del actual y la animación no puede tomar el camino largo.
## `_rotacion()` es ese valor módulo 4, y es el que usa la MATEMÁTICA.
##
## Con un solo contador módulo 4, pasar de la rotación 3 a la 0 hacía girar el
## mundo 270° hacia atrás. Dio 815% de desviación medida en pantalla.
func _angulo_de(giro: int) -> float:
	# La rotación r de la matemática — (dx,dz) -> (-dz,dx) para r=1 — equivale
	# a girar -90° alrededor de +Y en Godot.
	return -PI * 0.5 * giro

func _giro_actual() -> int:
	return int((_vivas[_zona_activa] as Dictionary)["giro"])

func _rotacion() -> int:
	return posmod(_giro_actual(), Proyeccion.ROTACIONES)

func _rotar(sentido: int) -> void:
	if _rotando or _viajando or _personaje.animando:
		return
	var viva: Dictionary = _vivas[_zona_activa]
	viva["giro"] = int(viva["giro"]) + sentido

	var pivote: Node3D = viva["pivote"]
	_angulo_desde = pivote.rotation.y
	_angulo_hasta = _angulo_de(int(viva["giro"]))
	_t_giro = 0.0
	_rotando = true
	_aviso_oculto_dado = false
	print("[acertijo] '%s' rota -> %d" % [_zona_activa, _rotacion()])

func _animar_giro(delta: float) -> void:
	if not _rotando:
		return
	var pivote: Node3D = (_vivas[_zona_activa] as Dictionary)["pivote"]
	_t_giro += delta / DURACION_GIRO
	var t := clampf(_t_giro, 0.0, 1.0)
	var s := 1.0 - pow(1.0 - t, 3.0)
	pivote.rotation.y = lerpf(_angulo_desde, _angulo_hasta, s)
	if t >= 1.0:
		_rotando = false
		# Ángulo exacto: una fracción de grado bastaría para que las losas
		# dejaran de verse alineadas aunque la matemática diga que lo están.
		pivote.rotation.y = _angulo_hasta

# ------------------------------------------------------------------ pasos

func _intentar_paso(direccion: String, encadenado := false) -> void:
	if _personaje.animando:
		_cola_direccion = direccion
		return

	var nav: Navegacion = (_vivas[_zona_activa] as Dictionary)["nav"]
	var paso := nav.intentar_paso(_personaje.celda, direccion, _rotacion())
	if not paso["permitido"]:
		if paso["motivo"] == "oculto" and not _aviso_oculto_dado:
			_aviso_oculto_dado = true
			print("[acertijo] estás tapado: desde acá no se puede cruzar el puente (sí caminar). Rotá para volver a verte.")
		return

	var destino: Vector3i = paso["celda"]
	if paso["puente"]:
		print("[acertijo] ¡PUENTE IMPOSIBLE! %s -> %s (salto real de %d celdas)" % [
			_personaje.celda, destino, paso["distancia"],
		])
	_personaje.ir_a(destino, paso["puente"], encadenado)

func _al_terminar_paso() -> void:
	var datos: Dictionary = _zonas[_zona_activa]

	var acertijo = datos["acertijo"]
	if acertijo != null and _personaje.celda == (acertijo as Vector3i):
		var clave := "%s/%s" % [_zona_activa, _personaje.celda]
		if not _descubiertos.has(clave):
			_descubiertos[clave] = true
			print("[acertijo] ***** HALLAZGO en '%s' *****" % _zona_activa)

	# Volver al mundo habitado pisando la celda de partida. Es la salida
	# diegética; `ui_cancel` es la de emergencia. Dos disparadores a propósito:
	# quedar encerrado ya pasó una vez en este proyecto.
	var partida: Vector3i = datos["partida"]
	if _personaje.celda != partida:
		_puede_salir_por_partida = true
	elif _puede_salir_por_partida:
		_cola_direccion = ""
		print("[acertijo] pisás la salida: volvés al mundo habitado")
		salir_pedido.emit()
		return

	var salidas: Dictionary = datos["salidas"]
	if salidas.has(_personaje.celda):
		_cola_direccion = ""
		_entrar_a(salidas[_personaje.celda] as String, true)
		return

	if _rotando or _viajando:
		return

	if _cola_direccion != "":
		var direccion := _cola_direccion
		_cola_direccion = ""
		_intentar_paso(direccion, true)
		return

	# Mantener apretado camina. Sin esto hay que volver a apretar por cada
	# celda, y eso es la mitad de por qué el movimiento se sentía de ajedrez:
	# cada paso era una jugada aparte, con su arranque y su frenada.
	var sostenida := _direccion_sostenida()
	if sostenida != "":
		_intentar_paso(sostenida, true)

func _direccion_sostenida() -> String:
	for accion in DIRECCIONES:
		if Input.is_action_pressed(accion):
			return DIRECCIONES[accion] as String
	return ""

# ---------------------------------------------------------------- entrada

func _unhandled_input(evento: InputEvent) -> void:
	if not _activo:
		return
	# Se lee acá y no con acciones de InputMap para no tener que escribir a mano
	# el mapeo en project.godot, que es fácil de romper.
	if evento is InputEventKey:
		var tecla := evento as InputEventKey
		if tecla.pressed and not tecla.echo:
			if tecla.keycode == KEY_A:
				_rotar(-1)
			elif tecla.keycode == KEY_D:
				_rotar(1)
			elif tecla.keycode == KEY_ESCAPE:
				salir_pedido.emit()
	elif evento is InputEventJoypadButton:
		var boton := evento as InputEventJoypadButton
		if boton.pressed:
			if boton.button_index == JOY_BUTTON_LEFT_SHOULDER:
				_rotar(-1)
			elif boton.button_index == JOY_BUTTON_RIGHT_SHOULDER:
				_rotar(1)
			elif boton.button_index == JOY_BUTTON_B:
				salir_pedido.emit()

func _process(delta: float) -> void:
	# El giro y el viaje se animan aunque el registro esté apagado: si no,
	# apagarlo a mitad de una rotación dejaría el pivote en un ángulo que no es
	# múltiplo de 90°, y ahí TODAS las alineaciones quedan mal sin que nada
	# avise. Es el modo de fallar más caro que tiene este código.
	_animar_giro(delta)
	_animar_viaje(delta)

	if not _activo:
		return

	# Mientras el mundo gira o la cámara viaja no se camina: si se pudiera, el
	# jugador se movería usando una alineación que todavía no terminó de
	# formarse.
	if _rotando or _viajando:
		return

	for accion in DIRECCIONES:
		if Input.is_action_just_pressed(accion):
			_intentar_paso(DIRECCIONES[accion] as String)
