extends Node3D
## Esqueleto genérico de zona jugable: cámara isométrica siguiendo al
## personaje. Lo reusan Ciudad, Playa, Bosque, Luna y OtroPlaneta — todas
## son el mismo placeholder (piso gris + cápsula gris), ver godot/README.md.

const OFFSET := Vector3(0, 10, 10)

@onready var _personaje: CharacterBody3D = $Personaje
@onready var _camara: Camera3D = $Camara3D

func _ready() -> void:
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = 8.0
	_camara.current = true

func _process(_delta: float) -> void:
	_camara.position = _personaje.position + OFFSET
	_camara.look_at(_personaje.position, Vector3.UP)
