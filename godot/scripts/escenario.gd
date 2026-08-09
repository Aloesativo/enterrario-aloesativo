extends Node3D
## Esqueleto genérico de zona jugable: cámara isométrica siguiendo al
## personaje. Lo reusan Ciudad, Playa, Bosque, Luna y OtroPlaneta — todas
## son el mismo placeholder (piso gris + cápsula gris), ver godot/README.md.

const OFFSET := Vector3(0, 10, 10)
const MAPA := "res://escenas/Mapa.tscn"

@onready var _personaje: CharacterBody3D = $Personaje
@onready var _camara: Camera3D = $Camara3D

var _volviendo_al_mapa := false # evita disparar change_scene_to_file dos veces

func _ready() -> void:
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = 8.0
	_camara.current = true
	print("[escenario] '%s' cargó — personaje en %s" % [name, _personaje.position])

func _process(_delta: float) -> void:
	_camara.position = _personaje.position + OFFSET
	_camara.look_at(_personaje.position, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if _volviendo_al_mapa:
		return
	var pide_volver := event.is_action_pressed("ui_cancel") # Escape / botón B o "back" del control
	if not pide_volver and event is InputEventMouseButton and event.pressed:
		pide_volver = event.button_index == MOUSE_BUTTON_WHEEL_DOWN
	if not pide_volver and event is InputEventKey and event.pressed:
		pide_volver = event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT
	if pide_volver:
		_volver_al_mapa()

func _volver_al_mapa() -> void:
	_volviendo_al_mapa = true
	print("[escenario] '%s' — volviendo a %s" % [name, MAPA])
	var error := get_tree().change_scene_to_file(MAPA)
	if error != OK:
		push_error("[escenario] change_scene_to_file('%s') falló con código %d" % [MAPA, error])
		_volviendo_al_mapa = false
