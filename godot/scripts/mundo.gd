extends Node3D
## ETAPAS 1-2 del plan (ver DISENO_GODOT.md §10).
##
## Etapa 1: un personaje que camina por celdas sobre una grilla plana.
## Etapa 2: la cámara isométrica fija, que sigue al personaje SIN GIRAR.
##
## Sin relieve, sin rotación del mundo, sin zoom, sin arte — todo eso son
## etapas 3 en adelante y a propósito no está.

## La grilla es más grande que lo que entra en pantalla, a propósito: si
## cupiera entera, una cámara que sigue al personaje sería indistinguible
## de una fija y la etapa 2 no se podría probar.
const LADO_GRILLA := 21

# El tamaño de celda vive en personaje.gd y se lee de ahí (Personaje.TAM):
# si estuviera escrito en los dos lados, un día alguien cambia uno y el
# piso deja de coincidir con los pasos, sin que nada avise.

## Cámara: ángulo isométrico VERDADERO.
##
## Con la cámara en centro + (k, k, k) mirando al centro, la dirección de
## vista es (-1,-1,-1)/√3, o sea una elevación de asin(1/√3) = 35.264° —
## exactamente el ángulo isométrico real — y un azimut de 45°. No hace
## falta escribir el ángulo a mano: sale solo de que las tres componentes
## sean iguales.
const DISTANCIA_CAMARA := 24.0

## Alto visible en unidades de mundo (Godot mide `size` sobre el alto).
## Con 12 se ve una porción de la grilla, no toda: por eso la cámara tiene
## que seguir al personaje.
const TAMANO_CAMARA := 12.0

## Suavizado del seguimiento. Más alto = más pegada al personaje.
##
## Suavizar es SEGURO para el acertijo, y conviene tenerlo claro: con una
## cámara ortográfica de rotación fija, mover la cámara NO cambia las
## posiciones relativas en pantalla entre dos objetos del mundo. Solo
## rotarla las cambiaría — y la cámara no rota nunca (§4).
const VELOCIDAD_CAMARA := 9.0

## Mapeo de teclas a pasos de celda.
##
## Derivación (no cambiar sin rehacerla): con la cámara de arriba,
##   +X en el mundo se ve hacia el SE de la pantalla
##   -X                                NO
##   +Z                                SO
##   -Z                                NE
##
## DISENO_GODOT.md §4 fija la asignación ANTIHORARIA como la intuitiva
## (la horaria se probó y se sentía "rotada"):
##   Arriba → NO,  Derecha → NE,  Abajo → SE,  Izquierda → SO
##
## Combinando ambas cosas salen los deltas de abajo. `celda.x` es la celda
## en el eje X del mundo y `celda.y` la del eje Z.
##
## Se usan las acciones ui_* que Godot trae de fábrica: cubren flechas del
## teclado, D-pad y stick izquierdo de cualquier control (PS/Xbox) sin que
## RR tenga que configurar nada. Eso es requisito duro (§4: cero UI, todo
## pre-mapeado).
const DIRECCIONES := {
	"ui_up": Vector2i(-1, 0),
	"ui_right": Vector2i(0, -1),
	"ui_down": Vector2i(1, 0),
	"ui_left": Vector2i(0, 1),
}

@onready var _camara: Camera3D = $Camara

var _personaje: Personaje
var _offset_camara := Vector3.ZERO

func _ready() -> void:
	_construir_piso()
	_construir_personaje()
	_colocar_camara()
	print("[mundo] etapas 1-2 listas — grilla %dx%d, personaje en %s" % [
		LADO_GRILLA, LADO_GRILLA, _personaje.celda,
	])
	print("[mundo] cámara isométrica fija: se orienta una vez y ya no gira nunca")

func _construir_piso() -> void:
	# Damero de dos grises para que cada celda se distinga de la vecina y el
	# paso se vea como un salto de casilla, no como un deslizamiento.
	# Grises neutros a propósito: la identidad visual la define RR (§11).
	var claro := StandardMaterial3D.new()
	claro.albedo_color = Color(0.62, 0.62, 0.62)
	var oscuro := StandardMaterial3D.new()
	oscuro.albedo_color = Color(0.52, 0.52, 0.52)

	var malla := BoxMesh.new()
	malla.size = Vector3(Personaje.TAM * 0.94, 0.2, Personaje.TAM * 0.94)

	var piso := Node3D.new()
	piso.name = "Piso"
	add_child(piso)

	for x in LADO_GRILLA:
		for z in LADO_GRILLA:
			var celda := MeshInstance3D.new()
			celda.mesh = malla
			celda.material_override = oscuro if (x + z) % 2 == 0 else claro
			# La cara de arriba de la losa queda en y=0: ese es el suelo
			# sobre el que se para el personaje.
			celda.position = Vector3(x * Personaje.TAM, -0.1, z * Personaje.TAM)
			piso.add_child(celda)

func _construir_personaje() -> void:
	_personaje = Personaje.new()
	_personaje.name = "Personaje"
	add_child(_personaje)

	var malla := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.25
	capsula.height = 0.9
	malla.mesh = capsula
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.80, 0.80, 0.85)
	malla.material_override = material
	# El nodo del personaje está a ras de suelo (y=0); la cápsula se sube
	# su media altura para apoyarse encima en vez de quedar hundida.
	malla.position = Vector3(0, 0.45, 0)
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_personaje.add_child(malla)

	var centro := LADO_GRILLA / 2
	_personaje.configurar(Vector2i(centro, centro), _puede_pisar)

## Etapa 1: lo único que limita el paso son los bordes de la grilla. La
## regla de verdad ("puedes pisar lo que se ve pegado a ti") es la etapa 4.
func _puede_pisar(celda: Vector2i) -> bool:
	return celda.x >= 0 and celda.x < LADO_GRILLA \
		and celda.y >= 0 and celda.y < LADO_GRILLA

## La cámara se ORIENTA UNA SOLA VEZ, acá, y después nunca más: en
## _process solo se le cambia la posición. Así "no gira nunca" queda
## garantizado por construcción y no por acordarse de no hacerlo.
##
## Su rigidez no es pereza: es la condición de que el acertijo se pueda
## leer (§4). Si la cámara se moviera sola, las alineaciones cambiarían sin
## que el jugador lo pidiera.
func _colocar_camara() -> void:
	_offset_camara = Vector3.ONE * DISTANCIA_CAMARA

	var objetivo := _objetivo_camara()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = TAMANO_CAMARA
	_camara.position = objetivo + _offset_camara
	_camara.look_at(objetivo, Vector3.UP)
	_camara.current = true

## A dónde mira la cámara: el personaje, pero SOLO en el plano horizontal.
##
## Importante: se descarta la altura. Durante el paso, personaje.position.y
## sube por el arco del salto; si la cámara siguiera eso, cabecearía en
## cada paso — justo lo que la etapa 2 pide que no pase ("nada la mueve
## por accidente").
func _objetivo_camara() -> Vector3:
	var p := _personaje.position
	return Vector3(p.x, 0.0, p.z)

func _process(delta: float) -> void:
	# is_action_just_pressed da UN disparo por empujón, tanto de tecla como
	# de stick: el stick tiene que volver a la zona muerta antes de poder
	# empujar de nuevo. Es literal lo que pide DISENO_GODOT.md §3.
	for accion in DIRECCIONES:
		if Input.is_action_just_pressed(accion):
			_personaje.empujar(DIRECCIONES[accion] as Vector2i)

	_seguir_con_la_camara(delta)

## Solo traslación, nunca rotación. El suavizado usa exp() para que sea
## independiente de los cuadros por segundo: con un lerp por delta pelado,
## la cámara se sentiría distinta a 60 y a 144 Hz.
func _seguir_con_la_camara(delta: float) -> void:
	var destino := _objetivo_camara() + _offset_camara
	var factor := 1.0 - exp(-VELOCIDAD_CAMARA * delta)
	_camara.position = _camara.position.lerp(destino, factor)
