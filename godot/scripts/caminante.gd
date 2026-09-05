class_name Caminante
extends CharacterBody3D
## EL CUERPO DEL REGISTRO HABITAR: movimiento continuo, en tercera persona.
##
## ⚠️ LEER ESTO ANTES DE ASUSTARSE: sí, esto es un CharacterBody3D con
## move_and_slide() y gravedad — exactamente lo que `DISENO_GODOT.md` §3
## prohíbe. **Acá es lo correcto, y ahí sigue estando prohibido.**
##
## La prohibición existe porque la regla del acertijo ("puedes pisar lo que se
## ve pegado a ti") compara posiciones en pantalla buscando igualdad EXACTA, y
## con posiciones continuas esa igualdad no ocurre nunca. Esa comparación vive
## en `navegacion.gd` y solo se usa dentro del registro acertijo.
##
## En el registro habitar no hay ninguna comparación de igualdad exacta que
## romper: es un entorno 3D común y corriente. La regla NO se relajó, se
## localizó (PREPRODUCCION.md §1).
##
## EL MODO DE FALLAR NUEVO, el que hay que vigilar: **filtrar un registro
## dentro del otro.** Si algún día `move_and_slide()` aparece en
## `personaje.gd`, el juego se rompe igual que se rompió antes. Por eso son dos
## scripts que no se importan entre sí y no comparten estado: lo único que
## comparten es el cuerpo que dibujan (`cuerpo.gd`).
##
## Quién le dice hacia dónde ir: `habitar.gd`, en coordenadas de cámara. Este
## script no lee el input de dirección — así el "adelante" siempre es el
## adelante de la cámara y no hay dos sitios decidiendo lo mismo.

const VELOCIDAD := 4.2

## Arranque y frenada. Son distintos a propósito: arrancar cuesta un poco más
## que parar, y eso es la mitad de que caminar tenga peso (DISENO_GODOT.md §6,
## Death Stranding). El peso va en la TEXTURA del paso, nunca en hacerlo
## lento — un personaje lento vuelve tedioso explorar.
const ACELERACION := 14.0
const FRENADA := 18.0

const GRAVEDAD := 24.0

## El andar. Todo cosmético: nada de esto toca la física.
const VELOCIDAD_GIRO := 11.0     # qué tan rápido encara la dirección nueva
const VELOCIDAD_POSTURA := 9.0   # qué tan rápido adopta/suelta la postura
const AMPLITUD_BAMBOLEO := 0.055 # sube y baja al andar (NO es un salto)
const INCLINACION := 0.10        # radianes que se echa hacia delante
const PASOS_POR_UNIDAD := 2.2    # cadencia del bamboleo por unidad recorrida

## Cuando está en false el cuerpo se queda quieto pero la física sigue
## corriendo (así no se hunde ni queda flotando). Lo apaga `frontera.gd`
## durante la transición y mientras se juega el acertijo.
var activo := true

var _cuerpo: Node3D
var _direccion := Vector3.ZERO

var _fase := 0.0
var _postura := 0.0
var _mirando := 0.0
var _mirando_a := 0.0

func _ready() -> void:
	var forma := CollisionShape3D.new()
	forma.name = "Forma"
	var capsula := CapsuleShape3D.new()
	capsula.radius = Cuerpo.RADIO
	capsula.height = Cuerpo.ALTO
	forma.shape = capsula
	forma.position = Vector3(0, Cuerpo.ALTO * 0.5, 0)
	add_child(forma)

	_cuerpo = Cuerpo.crear()
	add_child(_cuerpo)

## Hacia dónde caminar, en coordenadas de MUNDO y ya relativo a la cámara.
## Se espera un vector horizontal de largo 0..1.
func dirigir(direccion: Vector3) -> void:
	_direccion = direccion

## Para reposicionar al volver del acertijo. Corta la velocidad para que no
## salga disparado con la inercia que traía de antes de entrar.
func plantar_en(punto: Vector3) -> void:
	global_position = punto
	velocity = Vector3.ZERO
	_direccion = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if is_on_floor():
		# Un empujoncito hacia abajo, no cero: con velocity.y == 0 el
		# `floor_snap_length` de move_and_slide no engancha y el personaje se
		# despega al bajar una rampa, dando un trote saltarín.
		velocity.y = -0.1
	else:
		velocity.y -= GRAVEDAD * delta

	var objetivo := (_direccion * VELOCIDAD) if activo else Vector3.ZERO
	var plano := Vector3(velocity.x, 0.0, velocity.z)
	var tasa := ACELERACION if objetivo.length_squared() > 0.0001 else FRENADA
	plano = plano.move_toward(objetivo, tasa * delta)
	velocity.x = plano.x
	velocity.z = plano.z

	move_and_slide()

func _process(delta: float) -> void:
	if _cuerpo == null:
		return

	var rapidez := Vector3(velocity.x, 0.0, velocity.z).length()
	var andando := rapidez > 0.15

	if andando:
		# La fase avanza con la DISTANCIA recorrida, no con el reloj: así la
		# cadencia del bamboleo coincide con lo que se ve avanzar. Con el reloj,
		# el personaje bambolea igual de rápido caminando o casi parado, y eso
		# se lee como patinaje.
		_fase = fmod(_fase + rapidez * PASOS_POR_UNIDAD * delta, TAU)
		# En Godot el "frente" de un nodo es -Z: de ahí los signos. Misma
		# convención que personaje.gd, para que el giro se vea igual en los dos
		# registros.
		_mirando_a = atan2(-velocity.x, -velocity.z)

	_postura = lerpf(_postura, 1.0 if andando else 0.0, 1.0 - exp(-VELOCIDAD_POSTURA * delta))

	# absf(sin) da dos apoyos por ciclo: se lee como pisadas, no como flotar.
	_cuerpo.position.y = absf(sin(_fase)) * AMPLITUD_BAMBOLEO * _postura
	_mirando = lerp_angle(_mirando, _mirando_a, 1.0 - exp(-VELOCIDAD_GIRO * delta))
	_cuerpo.rotation.y = _mirando
	_cuerpo.rotation.x = INCLINACION * _postura
