class_name Personaje
extends Node3D
## El personaje. Su ESTADO es una celda discreta; su ANIMACIÓN es la de
## algo que camina.
##
## LA REGLA QUE NO SE ROMPE (DISENO_GODOT.md §3): esto NO es un
## CharacterBody3D, NO usa move_and_slide(), NO tiene velocidad continua ni
## gravedad. El estado lógico es un Vector3i, siempre. La regla del juego
## ("puedes pisar lo que se ve pegado a ti") compara posiciones en pantalla
## buscando igualdad EXACTA, y con posiciones continuas esa igualdad no
## ocurre nunca.
##
## PERO lo discreto es el ESTADO, no el dibujo. El mismo documento lo dice:
## "el paso puede (y debe) verse suave". La primera versión animaba cada
## paso como un saltito con frenada al final, y RR lo describió exacto: se
## movía como una pieza de ajedrez. Un ser que camina:
##
##   - no frena entre paso y paso mientras siga andando (encadena),
##   - no salta en cada celda: bambolea, y el bamboleo CRUZA de una celda a
##     la otra en vez de reiniciarse,
##   - mira hacia donde va,
##   - se echa un poco hacia delante al andar.
##
## El salto del PUENTE IMPOSIBLE es la excepción a propósito: ahí sí hay
## arco alto y frenada, porque tiene que sentirse como algo que no era
## obvio.

## Tamaño de celda en x/z, y altura de un escalón.
##
## ⚠️ TIENEN QUE SER IGUALES. La matemática de proyeccion.gd asume que subir
## un escalón desplaza en pantalla exactamente lo mismo que avanzar una
## celda (por eso B = x + z - 2y lleva un 2). Separarlos rompe TODAS las
## alineaciones sin que nada avise (INFORME §6).
const TAM := 1.0
const ALTO := 1.0

const DURACION_PASO := 0.15
const DURACION_PUENTE := 0.42
const ALTURA_ARCO_PUENTE := 2.2

## El andar. Nada de esto toca el estado lógico: es todo cosmético.
const AMPLITUD_BAMBOLEO := 0.06 # sube y baja al andar (NO es un salto)
const INCLINACION := 0.13       # radianes que se echa hacia delante
const VELOCIDAD_GIRO := 14.0    # qué tan rápido encara la dirección nueva
const VELOCIDAD_POSTURA := 9.0  # qué tan rápido adopta/suelta la postura

signal paso_terminado

var celda := Vector3i.ZERO
var animando := false

var _centro := Vector2i.ZERO
var _cuerpo: Node3D

var _t := 0.0
var _duracion := DURACION_PASO
var _arco := 0.0
var _encadenado := false
var _es_puente := false
var _desde := Vector3.ZERO
var _hasta := Vector3.ZERO

## Fase continua del andar. NO se reinicia en cada celda: por eso el
## bamboleo se lee como una zancada que sigue, y no como un rebote por
## casilla. Avanza PI por paso, así que dos pasos son un ciclo completo —
## un pie y el otro.
var _fase := 0.0
var _bamboleo := 0.0
var _postura := 0.0
var _mirando := 0.0
var _mirando_a := 0.0

## Posición dentro del pivote que rota. Es la posición SIN rotar: el giro
## del mundo lo aplica el nodo padre, no esta cuenta.
static func posicion_local(c: Vector3i, centro: Vector2i) -> Vector3:
	return Vector3(
		(c.x - centro.x) * TAM,
		c.y * ALTO,
		(c.z - centro.y) * TAM
	)

## El cuerpo va en un nodo aparte para que el bamboleo, la inclinación y el
## giro no toquen la posición lógica del personaje.
func montar_cuerpo(nodo: Node3D) -> void:
	_cuerpo = nodo
	add_child(_cuerpo)

func configurar(celda_inicial: Vector3i, centro: Vector2i) -> void:
	_centro = centro
	celda = celda_inicial
	position = posicion_local(celda, _centro)
	animando = false
	_t = 0.0

## Mover a una celda. Quién decide si el paso es legal es navegacion.gd.
## `encadenado` es true cuando el personaje ya venía andando: entonces no
## vuelve a arrancar de cero, que es lo que hacía parecer cada paso una
## jugada de ajedrez.
func ir_a(destino: Vector3i, es_puente: bool, encadenado := false) -> void:
	if animando:
		return

	_desde = posicion_local(celda, _centro)
	_hasta = posicion_local(destino, _centro)

	var delta := destino - celda
	if delta.x != 0 or delta.z != 0:
		# En Godot el "frente" de un nodo es -Z: de ahí los signos.
		_mirando_a = atan2(-float(delta.x), -float(delta.z))

	celda = destino
	_es_puente = es_puente
	_encadenado = encadenado and not es_puente
	_duracion = DURACION_PUENTE if es_puente else DURACION_PASO
	_arco = ALTURA_ARCO_PUENTE if es_puente else 0.0
	_t = 0.0
	animando = true

func _process(delta: float) -> void:
	_animar_postura(delta)

	if not animando:
		return

	_t += delta / _duracion
	var t := clampf(_t, 0.0, 1.0)

	# El puente frena y pesa. El paso encadenado va a velocidad pareja (así
	# no hay una frenada por celda). El paso suelto arranca y para suave.
	var s := t
	if _es_puente:
		s = t * t * (3.0 - 2.0 * t)
	elif not _encadenado:
		s = t * t * (3.0 - 2.0 * t)

	position = _desde.lerp(_hasta, s)
	if _arco > 0.0:
		position.y += sin(s * PI) * _arco

	# La fase del andar avanza con el paso, no con el reloj: si el paso es
	# más largo, la zancada es más larga.
	if not _es_puente:
		# fmod para que no crezca sin límite en una sesión larga.
		_fase = fmod(_fase + PI * (delta / _duracion), TAU)

	if t < 1.0:
		return

	# Fin del paso: se fija la posición exacta para que no quede deriva de
	# coma flotante. El estado lógico es la celda, y el dibujo tiene que
	# volver a coincidir con ella exactamente.
	animando = false
	position = _hasta
	paso_terminado.emit()

func _animar_postura(delta: float) -> void:
	if _cuerpo == null:
		return

	var objetivo := 1.0 if animando and not _es_puente else 0.0
	_postura = lerpf(_postura, objetivo, 1.0 - exp(-VELOCIDAD_POSTURA * delta))

	# absf(sin) da dos apoyos por ciclo: se lee como pisadas, no como un
	# flotar. Se apaga solo cuando el personaje se queda quieto.
	_bamboleo = absf(sin(_fase)) * AMPLITUD_BAMBOLEO * _postura
	_cuerpo.position.y = _bamboleo

	_mirando = lerp_angle(_mirando, _mirando_a, 1.0 - exp(-VELOCIDAD_GIRO * delta))
	_cuerpo.rotation.y = _mirando
	_cuerpo.rotation.x = INCLINACION * _postura
