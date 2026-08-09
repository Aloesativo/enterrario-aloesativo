extends Node3D
## ETAPA 1 del plan (ver DISENO_GODOT.md §10): un personaje que camina por
## celdas sobre una grilla plana. Sin relieve, sin rotación, sin arte.
##
## Lo único que hay que juzgar acá es CÓMO SE SIENTE EL PASO. Todo lo
## demás (el estereograma, la rotación, el zoom, el tilt-shift) llega en
## etapas siguientes y a propósito no está.

const LADO_GRILLA := 9

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
## La grilla de 9×9 proyectada ocupa ~6.5 de alto y ~11.3 de ancho; con 12
## entra entera y con margen en cualquier ventana apaisada.
const TAMANO_CAMARA := 12.0

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

func _ready() -> void:
	_construir_piso()
	_construir_personaje()
	_colocar_camara()
	print("[mundo] etapa 1 lista — grilla %dx%d, personaje en %s" % [
		LADO_GRILLA, LADO_GRILLA, _personaje.celda,
	])
	print("[mundo] un paso por empujón: mantener apretado NO camina solo (a propósito, ver README)")

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

func _colocar_camara() -> void:
	var centro := _centro_del_mundo()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = TAMANO_CAMARA
	_camara.position = centro + Vector3.ONE * DISTANCIA_CAMARA
	_camara.look_at(centro, Vector3.UP)
	_camara.current = true

func _centro_del_mundo() -> Vector3:
	var medio := (LADO_GRILLA - 1) * Personaje.TAM * 0.5
	return Vector3(medio, 0.0, medio)

func _process(_delta: float) -> void:
	# is_action_just_pressed da UN disparo por empujón, tanto de tecla como
	# de stick: el stick tiene que volver a la zona muerta antes de poder
	# empujar de nuevo. Es literal lo que pide DISENO_GODOT.md §3.
	for accion in DIRECCIONES:
		if Input.is_action_just_pressed(accion):
			_personaje.empujar(DIRECCIONES[accion] as Vector2i)
