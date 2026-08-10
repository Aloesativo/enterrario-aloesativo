extends Node3D
## El diorama de Burdeo: ZONAS MODULARES + ilusión de cámara.
##
## Ver DISENO_GODOT.md §5 bis bis. Cada zona del lore es un espacio en sí
## mismo, con su propio acertijo, su propio centro de giro y su propia
## rotación recordada. La sensación de que todas están en el mismo diorama
## se da con el viaje de la cámara entre ellas — es ilusión, y a propósito.
##
## Por qué así y no todo superpuesto en un mismo sistema de coordenadas: se
## probó, y (a) exigía una cámara de 36 unidades con todo diminuto, y (b)
## cada zona tenía que abrirse en una rotación distinta A LA VEZ, así que
## mover una rompía otra. Modular, cada zona se valida sola.
##
## El estereograma sigue viviendo DENTRO de cada zona. Entre zonas hay
## viaje de cámara, que es otro mecanismo y no se pisa con el primero.
##
## Estructura de nodos:
##   Mundo (este script)
##     Camara ................ nunca rota; solo se traslada
##     Sol
##     Zona_ciudad (pivote) ... gira sobre su propio centro
##       Islas / Balizas
##     Zona_playa (pivote)
##     Zona_luna (pivote)
##     (el Personaje se re-parenta a la zona activa)

const DISTANCIA_CAMARA := 40.0
const DURACION_GIRO := 0.38

## El viaje entre zonas. RR lo pidió como "saltos de cámara": corto, no un
## paseo. Tunealo acá si se siente lento o brusco.
const DURACION_VIAJE := 0.55

## Flechas/D-pad/stick a las cuatro diagonales de la pantalla.
## Asignación antihoraria (DISENO_GODOT.md §4), verificada por RR.
const DIRECCIONES := {
	"ui_up": "NO",
	"ui_right": "NE",
	"ui_down": "SE",
	"ui_left": "SO",
}

@onready var _camara: Camera3D = $Camara

var _zonas := {}      # id -> datos (la definición de abajo)
var _vivas := {}      # id -> {pivote, nav, giro, balizas}
var _zona_activa := ""

var _personaje: Personaje

# --- giro de la zona activa (los DOS contadores, ver más abajo) ---
var _rotando := false
var _t_giro := 0.0
var _angulo_desde := 0.0
var _angulo_hasta := 0.0

# --- viaje entre zonas ---
var _viajando := false
var _t_viaje := 0.0
var _cam_desde := Vector3.ZERO
var _cam_hasta := Vector3.ZERO
var _size_desde := 20.0
var _size_hasta := 20.0

var _cola_direccion := ""
var _aviso_oculto_dado := false

## Lo que el mundo recuerda entre visitas. Hoy solo los hallazgos y la
## rotación de cada zona (guardada en _vivas), pero es el gancho para "el
## mundo recuerda lo que dejaste" (DISENO_GODOT.md §6) cuando exista el
## guardado.
var _descubiertos := {}

## Las zonas de Burdeo.
##
## Se define en una función y no en un `const` a propósito: un const en
## GDScript solo admite expresiones constantes, y esto lleva Vector3i como
## claves de diccionario.
##
## ⚠️ Los números de cada zona NO se tocan a ojo. Están verificados con
## godot/herramientas/verificar_nivel.py — mover una isla una celda puede
## dejar el acertijo sin solución o quitarle la gracia. La ventaja de que
## las zonas sean modulares es que cada una se valida SOLA.
func _definir_zonas() -> Dictionary:
	return {
		"ciudad": {
			"titulo": "Burdeo — la ciudad",
			# "Concreto, guetos verticales" + "Burdeo BB: las dos torres,
			# los dos pilares de la ciudad" (src/story/burdeo.json).
			"areas": [
				{"x0": 0, "x1": 5, "z0": 0, "z1": 5, "y": 0},
				{"x0": 9, "x1": 14, "z0": 9, "z1": 14, "y": 7},
			],
			"centro": Vector2i(7, 7),
			"partida": Vector3i(0, 0, 0),
			"rotacion_inicial": 2,
			"acertijo": Vector3i(14, 7, 14),
			"origen": Vector3(0, 0, 0),
			"tamano_camara": 20.0,
			"salidas": {
				Vector3i(14, 7, 14): "luna", # arriba de las torres: el premio
				Vector3i(5, 0, 5): "playa",  # a ras de suelo: el vecino fácil
			},
		},
		"playa": {
			"titulo": "Playa / costas",
			# "Conectada a Burdeo dentro del mismo mapa". Sin acertijo a
			# propósito: un lugar donde estar. "Cada lugar al que se llega
			# debe ser contemplativo" (IDEAS_DISENO.md).
			"areas": [
				{"x0": 0, "x1": 8, "z0": 0, "z1": 5, "y": 0},
			],
			"centro": Vector2i(4, 2),
			"partida": Vector3i(0, 0, 0),
			"rotacion_inicial": 0,
			"acertijo": null,
			"origen": Vector3(46, 0, 0),
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
			"origen": Vector3(0, 0, 46),
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
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_entrar_a("ciudad", false)

	print("[mundo] diorama de Burdeo — %d zonas modulares: %s" % [_zonas.size(), _zonas.keys()])
	print("[mundo] mover: flechas/stick — rotar: A y D, o los bumpers (LB/RB)")

# ------------------------------------------------------------- construcción

func _construir_zona(id: String) -> void:
	var datos: Dictionary = _zonas[id]
	var bloques := _bloques_de(datos)

	var pivote := Node3D.new()
	pivote.name = "Zona_" + id.replace("-", "_")
	# El pivote se planta en el centro de giro de SU zona: rotarlo hace
	# girar esa zona sobre su propio centro, el mismo que usa la matemática.
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
	# Losas delgadas: dejan ver la altura, que es la información con la que
	# se juega. El damero no es decoración — sin contraste entre celdas
	# vecinas no se pueden contar celdas, y contar celdas es como se lee la
	# alineación (DISENO_GODOT.md §6 ter).
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
	# src/theme/default.json — la identidad visual la define RR (§11).
	var acertijo = datos["acertijo"]
	if acertijo != null:
		pivote.add_child(_marca(acertijo as Vector3i, centro, Color(0.878, 0.753, 0.376), 0.30))
	for celda in datos["salidas"]:
		pivote.add_child(_marca(celda as Vector3i, centro, Color(0.5, 0.78, 0.85), 0.22))

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

	# El cuerpo va en su propio nodo para que el bamboleo, la inclinación y
	# el giro del andar no toquen la posición lógica (ver personaje.gd).
	var cuerpo := Node3D.new()
	cuerpo.name = "Cuerpo"

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.85, 0.9)

	var tronco := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.26
	capsula.height = 1.0
	tronco.mesh = capsula
	tronco.material_override = material
	tronco.position = Vector3(0, 0.5, 0)
	cuerpo.add_child(tronco)

	# Un morro al frente. Sin esto la cápsula es simétrica y no se ve hacia
	# dónde mira — y que mire hacia donde va es media gracia de que parezca
	# una criatura y no una ficha.
	var morro := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.17, 0.17, 0.24)
	morro.mesh = caja
	morro.material_override = material
	morro.position = Vector3(0, 0.62, -0.26) # -Z es el frente en Godot
	cuerpo.add_child(morro)

	_personaje.montar_cuerpo(cuerpo)

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
		_cam_desde = _camara.position
		_cam_hasta = destino
		_size_desde = _camara.size
		_t_viaje = 0.0
		_viajando = true
	else:
		_camara.position = destino
		_camara.size = _size_hasta
		# La cámara se orienta UNA sola vez en toda la partida: después solo
		# se traslada. Así "no gira nunca" está garantizado por construcción.
		_camara.look_at(destino - Vector3.ONE * DISTANCIA_CAMARA, Vector3.UP)
		_camara.current = true

	print("[mundo] entrás a '%s' (%s)" % [id, datos["titulo"]])

## Dónde se para la cámara para encuadrar una zona. Es el centro de giro de
## la zona a media altura: ese punto no se mueve al rotar, así que la zona
## queda estable en pantalla en las cuatro rotaciones.
func _ancla_de(id: String) -> Vector3:
	var datos: Dictionary = _zonas[id]
	var pivote: Node3D = (_vivas[id] as Dictionary)["pivote"]
	var alto_max := 0
	for area in datos["areas"]:
		alto_max = maxi(alto_max, int(area["y"]))
	var objetivo := pivote.position + Vector3(0, alto_max * Personaje.ALTO * 0.5, 0)
	return objetivo + Vector3.ONE * DISTANCIA_CAMARA

func _animar_viaje(delta: float) -> void:
	if not _viajando:
		return
	_t_viaje += delta / DURACION_VIAJE
	var t := clampf(_t_viaje, 0.0, 1.0)
	var s := t * t * (3.0 - 2.0 * t) # suave al salir y al llegar
	_camara.position = _cam_desde.lerp(_cam_hasta, s)
	_camara.size = lerpf(_size_desde, _size_hasta, s)
	if t >= 1.0:
		_viajando = false
		_camara.position = _cam_hasta
		_camara.size = _size_hasta

# ------------------------------------------------------------------- giro

## LOS DOS CONTADORES. No es redundancia: es la corrección de un bug real y
## caro (INFORME.md §6).
##
## El giro guardado por zona nunca da la vuelta (…, -1, 0, 1, 2, 3, 4, …) y
## sirve para ANIMAR: como siempre cambia de a uno, el ángulo destino está
## siempre a 90° del actual y la animación no puede tomar el camino largo.
## `_rotacion()` es ese valor módulo 4, y es el que usa la MATEMÁTICA.
##
## Con un solo contador módulo 4, pasar de la rotación 3 a la 0 hacía girar
## el mundo 270° hacia atrás. Dio 815% de desviación medida en pantalla.
func _angulo_de(giro: int) -> float:
	# La rotación r de la matemática — (dx,dz) -> (-dz,dx) para r=1 —
	# equivale a girar -90° alrededor de +Y en Godot.
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
	print("[mundo] '%s' rota -> %d" % [_zona_activa, _rotacion()])

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
			print("[mundo] estás tapado: desde acá no se puede cruzar el puente (sí caminar). Rotá para volver a verte.")
		return

	var destino: Vector3i = paso["celda"]
	if paso["puente"]:
		print("[mundo] ¡PUENTE IMPOSIBLE! %s -> %s (salto real de %d celdas)" % [
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
			print("[mundo] ***** HALLAZGO en '%s' *****" % _zona_activa)

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
	# celda, y eso es la mitad de por qué el movimiento se sentía de
	# ajedrez: cada paso era una jugada aparte, con su arranque y su frenada.
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
	# Se lee acá y no con acciones de InputMap para no tener que escribir a
	# mano el mapeo en project.godot, que es fácil de romper.
	if evento is InputEventKey:
		var tecla := evento as InputEventKey
		if tecla.pressed and not tecla.echo:
			if tecla.keycode == KEY_A:
				_rotar(-1)
			elif tecla.keycode == KEY_D:
				_rotar(1)
	elif evento is InputEventJoypadButton:
		var boton := evento as InputEventJoypadButton
		if boton.pressed:
			if boton.button_index == JOY_BUTTON_LEFT_SHOULDER:
				_rotar(-1)
			elif boton.button_index == JOY_BUTTON_RIGHT_SHOULDER:
				_rotar(1)

func _process(delta: float) -> void:
	_animar_giro(delta)
	_animar_viaje(delta)

	# Mientras el mundo gira o la cámara viaja no se camina: si se pudiera,
	# el jugador se movería usando una alineación que todavía no terminó de
	# formarse.
	if _rotando or _viajando:
		return

	for accion in DIRECCIONES:
		if Input.is_action_just_pressed(accion):
			_intentar_paso(DIRECCIONES[accion] as String)
