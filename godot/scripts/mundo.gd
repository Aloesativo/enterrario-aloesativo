extends Node3D
## ETAPAS 3 y 4 del plan (ver DISENO_GODOT.md §10): la rotación en pasos
## exactos y EL ESTEREOGRAMA — la regla "puedes pisar lo que se ve pegado
## a ti".
##
## Esta es la etapa donde el juego existe o no existe. Todo lo anterior era
## andamiaje: una grilla plana que se recorría es un tablero de ajedrez, no
## un mundo. Lo que lo convierte en juego es que haya un lugar imposible de
## alcanzar que, al rotar, se vuelve alcanzable.
##
## Estructura de nodos:
##   Mundo (este script)
##     Camara .......... FUERA del pivote: nunca rota, nunca se mueve
##     Sol
##     Pivote .......... el mundo que gira en pasos de 90°
##       Isla_* ........ las losas del nivel
##       Personaje
##       Baliza ........ marca el objetivo

# ---------------------------------------------------------------- el nivel

## Las dos islas, como rectángulos de celdas. Se declaran así (y no celda a
## celda) para poder mover una isla entera cambiando un número.
##
## ⚠️ ESTOS NÚMEROS NO SE TOCAN A OJO. La alineación isométrica es exacta y
## frágil: mover una isla UNA celda puede abrir el puente en las cuatro
## rotaciones (deja de ser acertijo) o cerrarlo en todas (deja de tener
## solución). Las dos fallas son mudas.
##
## Esta configuración se encontró por barrido de parámetros con BFS y está
## verificada: el objetivo se alcanza SOLO en la rotación 0, el puente salta
## 22 celdas de mundo, y en la rotación 0 hay 16 celdas tapadas por otras
## (eso es el efecto Magic Eye: las islas se funden en pantalla).
## `Navegacion.validar()` lo vuelve a comprobar en cada arranque.
const AREAS := [
	{"id": "orilla", "x0": 0, "x1": 5, "z0": 0, "z1": 5, "y": 0},
	{"id": "mirador", "x0": 9, "x1": 14, "z0": 9, "z1": 14, "y": 7},
]

## Centro de giro del nivel: (x, z) del mundo en un Vector2i.
const CENTRO := Vector2i(7, 7)
const PARTIDA := Vector3i(0, 0, 0)
const OBJETIVO := Vector3i(14, 7, 14)

## Se arranca en una rotación desde la que el objetivo NO se alcanza: si se
## alcanzara, no habría acertijo. Es la 2, la opuesta a la que resuelve.
const ROTACION_INICIAL := 2

# -------------------------------------------------------------- la cámara

const DISTANCIA_CAMARA := 40.0

## La cámara NO sigue al personaje en esta etapa, y es a propósito.
##
## Medido sobre este nivel: en la rotación 2 ocupa 17.15 unidades de alto y
## en la 1 y la 3 ocupa 19.8 de ancho. Con la vista centrada en el
## personaje, una de las dos islas se saldría de cuadro — y el acertijo se
## resuelve COMPARANDO las dos islas. Si no se ven juntas, no hay nada que
## leer. El seguimiento vuelve cuando el mundo sea más grande que la
## pantalla.
const TAMANO_CAMARA := 20.0

## Duración del giro de 90°. Lento se vuelve tedioso (hay que rotar mucho
## para explorar); instantáneo no deja ver QUÉ cambió, que es justamente lo
## que el jugador tiene que aprender a leer.
const DURACION_GIRO := 0.38

# ------------------------------------------------------------- movimiento

## Flechas/D-pad/stick a las cuatro diagonales de la pantalla.
## Asignación antihoraria (DISENO_GODOT.md §4), ya verificada por RR en la
## etapa 1: Arriba→NO, Derecha→NE, Abajo→SE, Izquierda→SO.
const DIRECCIONES := {
	"ui_up": "NO",
	"ui_right": "NE",
	"ui_down": "SE",
	"ui_left": "SO",
}

@onready var _camara: Camera3D = $Camara

var _pivote: Node3D
var _personaje: Personaje
var _baliza: Node3D
var _nav: Navegacion

## LOS DOS CONTADORES. Esto no es redundancia: es la corrección de un bug
## real y caro (INFORME.md §6).
##
## `_giro_continuo` nunca da la vuelta: 0, 1, 2, 3, 4, 5... o -1, -2...
## Sirve para ANIMAR, y como siempre crece o decrece de a uno, el ángulo
## destino está siempre a 90° del actual: la animación nunca puede tomar
## el camino largo.
##
## `rotacion` es el mismo valor módulo 4, y es el que usa la MATEMÁTICA.
##
## Con un solo contador módulo 4, pasar de la rotación 3 a la 0 hacía girar
## el mundo 270° hacia atrás en vez de 90° hacia delante. La medición en
## pantalla dio 815% de desviación y se sospechó de la proyección, que
## estaba bien.
var _giro_continuo := 0

var _rotando := false
var _t_giro := 0.0
var _angulo_desde := 0.0
var _angulo_hasta := 0.0

var _cola_direccion := ""
var _descubierto := false
var _tiempo := 0.0

## La rotación que usa la matemática de alineación. Siempre 0..3.
var rotacion: int:
	get:
		return posmod(_giro_continuo, Proyeccion.ROTACIONES)

func _ready() -> void:
	var bloques := _construir_bloques()
	_nav = Navegacion.new(bloques, CENTRO)

	_pivote = Node3D.new()
	_pivote.name = "Pivote"
	# El pivote se planta EN el centro de giro para que rotarlo gire el
	# nivel sobre ese centro, que es el mismo que usa la matemática.
	_pivote.position = Vector3(CENTRO.x * Personaje.TAM, 0.0, CENTRO.y * Personaje.TAM)
	add_child(_pivote)

	_construir_islas(bloques)
	_construir_personaje()
	_construir_baliza()
	_colocar_camara()

	_giro_continuo = ROTACION_INICIAL
	_pivote.rotation.y = _angulo_de(_giro_continuo)

	print("[mundo] etapas 3-4 — %d celdas, arranca en rotación %d" % [bloques.size(), rotacion])
	_nav.validar(PARTIDA, OBJETIVO, ROTACION_INICIAL)
	print("[mundo] mover: flechas/stick — rotar: A y D, o los bumpers (LB/RB)")

func _construir_bloques() -> Array:
	var bloques: Array = []
	for area in AREAS:
		var y := int(area["y"])
		for x in range(int(area["x0"]), int(area["x1"]) + 1):
			for z in range(int(area["z0"]), int(area["z1"]) + 1):
				bloques.append(Vector3i(x, y, z))
	return bloques

# ------------------------------------------------------------- construcción

func _construir_islas(bloques: Array) -> void:
	# Losas delgadas a propósito: dejan ver la altura de cada isla, que es
	# la información con la que se juega.
	var malla := BoxMesh.new()
	malla.size = Vector3(Personaje.TAM * 0.94, 0.25, Personaje.TAM * 0.94)

	# Dos grises que se alternan en damero. Esto NO es decoración: sin el
	# contraste entre celdas vecinas no se puede contar cuántas celdas hay
	# entre una cosa y otra, y contar celdas es como se lee la alineación.
	# La identidad visual la define RR; acá solo hay legibilidad (§6 ter).
	var claro := StandardMaterial3D.new()
	claro.albedo_color = Color(0.66, 0.66, 0.66)
	var oscuro := StandardMaterial3D.new()
	oscuro.albedo_color = Color(0.54, 0.54, 0.54)

	var islas := Node3D.new()
	islas.name = "Islas"
	_pivote.add_child(islas)

	for celda in bloques:
		var c: Vector3i = celda
		var losa := MeshInstance3D.new()
		losa.mesh = malla
		losa.material_override = oscuro if (c.x + c.z) % 2 == 0 else claro
		# La cara de arriba de la losa queda a la altura de la celda: ahí
		# es donde se apoya el personaje.
		losa.position = Personaje.posicion_local(c, CENTRO) - Vector3(0, 0.125, 0)
		islas.add_child(losa)

func _construir_personaje() -> void:
	_personaje = Personaje.new()
	_personaje.name = "Personaje"
	_pivote.add_child(_personaje)

	var malla := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.28
	capsula.height = 1.0
	malla.mesh = capsula
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.85, 0.9)
	malla.material_override = material
	malla.position = Vector3(0, 0.5, 0)
	_personaje.add_child(malla)

	_personaje.configurar(PARTIDA, CENTRO)
	_personaje.paso_terminado.connect(_al_terminar_paso)

func _construir_baliza() -> void:
	# Marca el objetivo para que haya algo que buscar. El color reutiliza el
	# placeholder de baliza que ya existía en src/theme/default.json — no es
	# una elección de identidad visual del agente, que no le corresponde.
	_baliza = Node3D.new()
	_baliza.name = "Baliza"
	_baliza.position = Personaje.posicion_local(OBJETIVO, CENTRO)
	_pivote.add_child(_baliza)

	var malla := MeshInstance3D.new()
	var forma := SphereMesh.new()
	forma.radius = 0.3
	forma.height = 0.6
	malla.mesh = forma
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.878, 0.753, 0.376)
	material.emission_enabled = true
	material.emission = Color(0.878, 0.753, 0.376)
	material.emission_energy_multiplier = 1.5
	malla.material_override = material
	_baliza.add_child(malla)

func _colocar_camara() -> void:
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = TAMANO_CAMARA
	var objetivo := _centro_visual()
	_camara.position = objetivo + Vector3.ONE * DISTANCIA_CAMARA
	_camara.look_at(objetivo, Vector3.UP)
	_camara.current = true

## El punto que deja el nivel centrado en pantalla en LAS CUATRO
## rotaciones. Es el centro de la caja del nivel: su proyección da
## A=0 y B=7 en todas, o sea siempre el mismo punto de la imagen.
func _centro_visual() -> Vector3:
	var alto_max := 0
	for area in AREAS:
		alto_max = maxi(alto_max, int(area["y"]))
	return Vector3(
		CENTRO.x * Personaje.TAM,
		alto_max * Personaje.ALTO * 0.5,
		CENTRO.y * Personaje.TAM
	)

# ------------------------------------------------------------------ giro

func _angulo_de(giro: int) -> float:
	# Signo negativo: la rotación r de la matemática — (dx,dz) -> (-dz,dx)
	# para r=1 — equivale a girar -90° alrededor de +Y en Godot.
	return -PI * 0.5 * giro

func _rotar(sentido: int) -> void:
	if _rotando or _personaje.animando:
		return
	_giro_continuo += sentido
	_angulo_desde = _pivote.rotation.y
	_angulo_hasta = _angulo_de(_giro_continuo)
	_t_giro = 0.0
	_rotando = true
	print("[mundo] rotación -> %d (giro continuo %d)" % [rotacion, _giro_continuo])

func _animar_giro(delta: float) -> void:
	if not _rotando:
		return
	_t_giro += delta / DURACION_GIRO
	var t := clampf(_t_giro, 0.0, 1.0)
	var s := 1.0 - pow(1.0 - t, 3.0)
	_pivote.rotation.y = lerpf(_angulo_desde, _angulo_hasta, s)
	if t >= 1.0:
		_rotando = false
		# Se fija el ángulo exacto: si quedara una fracción de grado, las
		# losas dejarían de verse alineadas aunque la matemática dijera
		# que lo están.
		_pivote.rotation.y = _angulo_hasta

# ------------------------------------------------------------------ pasos

func _intentar_paso(direccion: String) -> void:
	if _personaje.animando:
		# Cola de un solo paso, el más reciente gana: un empujón que llega
		# durante la animación no se descarta en silencio.
		_cola_direccion = direccion
		return

	var paso := _nav.intentar_paso(_personaje.celda, direccion, rotacion)
	if not paso["permitido"]:
		return

	var destino: Vector3i = paso["celda"]
	var es_puente: bool = paso["puente"]
	if es_puente:
		print("[mundo] ¡PUENTE IMPOSIBLE! %s -> %s (salto real de %d celdas)" % [
			_personaje.celda, destino, paso["distancia"],
		])
	_personaje.ir_a(destino, es_puente)

func _al_terminar_paso() -> void:
	if not _descubierto and _personaje.celda == OBJETIVO:
		_descubrir()

	if _cola_direccion != "":
		var direccion := _cola_direccion
		_cola_direccion = ""
		_intentar_paso(direccion)

func _descubrir() -> void:
	_descubierto = true
	print("[mundo] ***** HALLAZGO: llegaste al mirador *****")
	# La revelación de verdad (la cámara que se suelta, la portada, la
	# canción) es una etapa posterior. Por ahora la baliza se apaga, para
	# que llegar tenga alguna consecuencia visible.
	_baliza.visible = false

# ---------------------------------------------------------------- entrada

func _unhandled_input(evento: InputEvent) -> void:
	# Rotación. Se lee acá y no con acciones de InputMap para no tener que
	# escribir a mano el mapeo en project.godot, que es fácil de romper.
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
	_tiempo += delta
	_animar_giro(delta)

	# Mientras el mundo gira no se camina: si se pudiera, el jugador se
	# movería usando una alineación que todavía no terminó de formarse.
	if not _rotando:
		for accion in DIRECCIONES:
			if Input.is_action_just_pressed(accion):
				_intentar_paso(DIRECCIONES[accion] as String)

	if _baliza != null and not _descubierto:
		_baliza.position.y = Personaje.posicion_local(OBJETIVO, CENTRO).y + 1.0 + sin(_tiempo * 2.0) * 0.15
