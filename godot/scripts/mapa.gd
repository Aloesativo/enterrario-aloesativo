extends Node3D
## Mapa/zoom del diorama de Burdeo — esqueleto mínimo (ver godot/README.md).
##
## Datos de zonas: copia mínima y a mano de src/story/burdeo.json ("zonas"),
## solo id + título + una posición de layout provisional para que la
## mecánica se pueda ver funcionando. No es una lectura real del JSON —
## eso queda pendiente, ver godot/README.md.

const ZONAS := [
	{"id": "ciudad", "titulo": "Burdeo (ciudad)", "pos": Vector3(0, 0, 0), "escena": "res://escenas/Ciudad.tscn"},
	{"id": "playa", "titulo": "Playa / costas", "pos": Vector3(-6, 0, 3), "escena": "res://escenas/Playa.tscn"},
	{"id": "bosque", "titulo": "Bosque místico", "pos": Vector3(6, 0, 3), "escena": "res://escenas/Bosque.tscn"},
	{"id": "luna", "titulo": "Luna de Burdeo", "pos": Vector3(-4, 0, -6), "escena": "res://escenas/Luna.tscn"},
	{"id": "otro-planeta", "titulo": "Otro planeta", "pos": Vector3(4, 0, -6), "escena": "res://escenas/OtroPlaneta.tscn"},
]

const ZOOM_MIN := 3.0
const ZOOM_MAX := 20.0
const ZOOM_PASO := 1.0
const ZOOM_UMBRAL_CIUDAD := 4.0 # tamaño de cámara por debajo del cual "entrás" a una zona
const VELOCIDAD_PAN := 8.0

@onready var _camara: Camera3D = $Camara3D

var _zoom := 12.0
var _objetivo := Vector3.ZERO

func _ready() -> void:
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	for zona in ZONAS:
		_crear_marcador(zona)
	_actualizar_camara()

func _crear_marcador(zona: Dictionary) -> void:
	var raiz := Node3D.new()
	raiz.name = "Zona_" + String(zona["id"]).replace("-", "_")
	raiz.position = zona["pos"]
	raiz.set_meta("zona_id", zona["id"])
	add_child(raiz)

	var caja := MeshInstance3D.new()
	var malla := BoxMesh.new()
	malla.size = Vector3(1.5, 1.0, 1.5)
	caja.mesh = malla
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.55, 0.55) # gris neutro — placeholder, la paleta la define RR
	caja.material_override = material
	raiz.add_child(caja)

	var etiqueta := Label3D.new()
	etiqueta.text = zona["titulo"]
	etiqueta.position = Vector3(0, 1.3, 0)
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	raiz.add_child(etiqueta)

func _process(delta: float) -> void:
	var mover := _vector_movimiento()
	_objetivo += Vector3(mover.x, 0, mover.y) * VELOCIDAD_PAN * delta
	_actualizar_camara()

func _vector_movimiento() -> Vector2:
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if v == Vector2.ZERO:
		v.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		v.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	return v

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_acercar()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_alejar()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			_acercar()
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			_alejar()

func _acercar() -> void:
	_zoom = max(ZOOM_MIN, _zoom - ZOOM_PASO)
	if _zoom <= ZOOM_UMBRAL_CIUDAD:
		var escena := _escena_de(_zona_mas_cercana())
		if escena != "":
			get_tree().change_scene_to_file(escena)

func _alejar() -> void:
	_zoom = min(ZOOM_MAX, _zoom + ZOOM_PASO)

func _actualizar_camara() -> void:
	_camara.size = _zoom
	_camara.position = _objetivo + Vector3(0, 12, 12)
	_camara.look_at(_objetivo, Vector3.UP)

func _zona_mas_cercana() -> String:
	var mejor_id := ""
	var mejor_dist := INF
	for hijo in get_children():
		if hijo.has_meta("zona_id"):
			var dist: float = hijo.position.distance_to(_objetivo)
			if dist < mejor_dist:
				mejor_dist = dist
				mejor_id = String(hijo.get_meta("zona_id"))
	return mejor_id

func _escena_de(zona_id: String) -> String:
	for zona in ZONAS:
		if zona["id"] == zona_id:
			return zona.get("escena", "")
	return ""
