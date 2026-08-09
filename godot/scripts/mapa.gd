extends Node3D
## El diorama de Burdeo: un único mundo 3D con relieve real (plataformas a
## distinta altura, no un plano) que el personaje recorre caminando, visto
## desde una cámara isométrica fija que lo sigue. Reemplaza el mapa plano +
## "zoom para teletransportarte a otra escena" que había antes — ver
## CLAUDE.md ("Diorama unificado") para el porqué del cambio, y
## godot/README.md para qué falta.
##
## Todavía NO tiene el acertijo de rotación/ambigüedad isométrica de
## src/mundo/proyeccion.js — eso es a propósito el siguiente paso, no este.
## Por eso ciudad/playa/bosque están conectadas a nivel de suelo (caminables
## ya mismo, como dice burdeo.json: "conectada dentro del mismo mapa"), pero
## luna/otro-planeta quedan como islas elevadas visibles y NO alcanzables
## todavía — ese vacío es justo lo que la rotación va a resolver después.

const PERSONAJE_SCRIPT := preload("res://scripts/personaje.gd")

const OFFSET_CAMARA := Vector3(0, 16, 16)
const TAMANO_CAMARA := 20.0

## Copia mínima y a mano de src/story/burdeo.json -> "zonas": solo lo
## necesario para plantar el relieve (id + título + posición/tamaño de la
## plataforma). No es una lectura real del JSON — ver godot/README.md.
const ZONAS := [
	{"id": "ciudad", "titulo": "Burdeo (ciudad)", "pos": Vector3(0, 0, 0), "tamano": Vector3(14, 1, 14)},
	{"id": "playa", "titulo": "Playa / costas", "pos": Vector3(-13, 0, 9), "tamano": Vector3(10, 1, 10)},
	{"id": "bosque", "titulo": "Bosque místico", "pos": Vector3(13, 0, 9), "tamano": Vector3(10, 1, 10)},
	{"id": "luna", "titulo": "Luna de Burdeo", "pos": Vector3(-11, 9, -17), "tamano": Vector3(7, 1, 7)},
	{"id": "otro-planeta", "titulo": "Otro planeta", "pos": Vector3(11, 11, -19), "tamano": Vector3(7, 1, 7)},
]

## "cometa" (burdeo.json): no es una plataforma, es algo que "atraviesa el
## mapa entero en vez de ocupar un lugar" — un elemento del cielo que cruza
## el diorama, sin colisión.
const COMETA_ALTURA := 24.0
const COMETA_RADIO := 42.0
const COMETA_VELOCIDAD := 0.06

var _camara: Camera3D
var _personaje: CharacterBody3D
var _cometa: MeshInstance3D
var _tiempo := 0.0

func _ready() -> void:
	for zona in ZONAS:
		_crear_plataforma(zona)
	_crear_personaje()
	_crear_cometa()
	_crear_camara()
	_actualizar_camara()
	print("[mapa] diorama listo — %d zonas plantadas, personaje en %s" % [ZONAS.size(), _personaje.position])

func _crear_plataforma(zona: Dictionary) -> void:
	var raiz := StaticBody3D.new()
	raiz.name = "Zona_" + String(zona["id"]).replace("-", "_")
	add_child(raiz)

	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = zona["tamano"]
	malla.mesh = caja
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.5, 0.5) # gris neutro — placeholder, la paleta la define RR
	malla.material_override = material
	malla.position = zona["pos"]
	raiz.add_child(malla)

	var colision := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = zona["tamano"]
	colision.shape = forma
	colision.position = zona["pos"]
	raiz.add_child(colision)

	var etiqueta := Label3D.new()
	etiqueta.text = zona["titulo"]
	etiqueta.position = zona["pos"] + Vector3(0, zona["tamano"].y / 2.0 + 1.5, 0)
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	raiz.add_child(etiqueta)

func _crear_personaje() -> void:
	_personaje = CharacterBody3D.new()
	_personaje.name = "Personaje"
	_personaje.set_script(PERSONAJE_SCRIPT)
	_personaje.position = _posicion_de("ciudad") + Vector3(0, 1.5, 0)
	add_child(_personaje)

	var malla := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.5
	capsula.height = 1.8
	malla.mesh = capsula
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.75, 0.75, 0.8)
	malla.material_override = material
	_personaje.add_child(malla)

	var colision := CollisionShape3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = 0.5
	forma.height = 1.8
	colision.shape = forma
	_personaje.add_child(colision)

func _crear_cometa() -> void:
	_cometa = MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 1.2
	esfera.height = 2.4
	_cometa.mesh = esfera
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.85, 0.9)
	material.emission_enabled = true
	material.emission = Color(0.85, 0.85, 0.9)
	_cometa.material_override = material
	add_child(_cometa)

func _crear_camara() -> void:
	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = TAMANO_CAMARA
	_camara.current = true
	add_child(_camara)

func _posicion_de(zona_id: String) -> Vector3:
	for zona in ZONAS:
		if zona["id"] == zona_id:
			return zona["pos"]
	return Vector3.ZERO

func _process(delta: float) -> void:
	_tiempo += delta
	_actualizar_camara()
	_actualizar_cometa()

func _actualizar_camara() -> void:
	if _personaje == null:
		return
	_camara.position = _personaje.position + OFFSET_CAMARA
	_camara.look_at(_personaje.position, Vector3.UP)

func _actualizar_cometa() -> void:
	var angulo := _tiempo * COMETA_VELOCIDAD
	_cometa.position = Vector3(cos(angulo) * COMETA_RADIO, COMETA_ALTURA, sin(angulo) * COMETA_RADIO - 10.0)
