class_name Personaje
extends Node3D
## El personaje. Se mueve por CELDAS DISCRETAS, un paso por empujón.
##
## LA REGLA MÁS IMPORTANTE DE TODO EL PROYECTO (ver DISENO_GODOT.md §3):
## esto NO es un CharacterBody3D, NO usa move_and_slide(), NO tiene
## velocidad continua ni gravedad simulada. El estado lógico del personaje
## es una celda entera (Vector2i), nunca una posición flotante.
##
## Por qué es obligatorio y no una preferencia de estilo: la regla del
## juego ("puedes pisar lo que se ve pegado a ti") compara posiciones en
## pantalla buscando igualdad EXACTA. Con posiciones continuas esa igualdad
## no ocurre nunca y el core del juego no puede existir.
##
## Lo que SÍ es continuo es la animación: el paso se ve suave, con su arco
## y su tiempo. Lo discreto es el estado, no el dibujo.

const TAM := 1.0

## Sensación del paso. Estos números son lo que RR tiene que juzgar en la
## etapa 1 — están acá arriba para que sean fáciles de tocar.
##
## OJO (DISENO_GODOT.md §6): el peso del paso va en la TEXTURA (arco,
## aterrizaje, sonido, vibración), NO en hacerlo lento. Un paso lento
## vuelve tedioso probar rotaciones, que es el core del juego.
const DURACION_PASO := 0.16 # segundos
const ALTURA_ARCO := 0.12

var celda := Vector2i.ZERO

var _puede_pisar: Callable
var _animando := false
var _t := 0.0
var _desde := Vector3.ZERO
var _hasta := Vector3.ZERO

## Cola de UN solo paso, el más reciente gana. Sin esto, un empujón que
## llega mientras el paso anterior todavía anima se descarta en silencio —
## y eso es exactamente lo que hacía sentir los controles como rotos al
## pulsarlos rápido (lección ya pagada en src/render/personaje.js).
var _hay_cola := false
var _cola := Vector2i.ZERO

static func posicion_de_celda(c: Vector2i) -> Vector3:
	return Vector3(c.x * TAM, 0.0, c.y * TAM)

func configurar(celda_inicial: Vector2i, puede_pisar: Callable) -> void:
	celda = celda_inicial
	_puede_pisar = puede_pisar
	position = posicion_de_celda(celda)

## Un empujón en una dirección. `delta` es un paso de celda: (±1,0) o (0,±1).
func empujar(delta: Vector2i) -> void:
	if _animando:
		_hay_cola = true
		_cola = delta
		return

	var destino := celda + delta
	if not _puede_pisar.call(destino):
		return

	_desde = posicion_de_celda(celda)
	_hasta = posicion_de_celda(destino)
	celda = destino
	_t = 0.0
	_animando = true

func _process(delta: float) -> void:
	if not _animando:
		return

	_t += delta / DURACION_PASO
	var t := clampf(_t, 0.0, 1.0)
	# Ease-out cúbico: sale rápido y aterriza suave. El aterrizaje es la
	# parte que se siente como "peso".
	var s := 1.0 - pow(1.0 - t, 3.0)

	position = _desde.lerp(_hasta, s)
	position.y += sin(s * PI) * ALTURA_ARCO

	if t < 1.0:
		return

	# Fin del paso: se fija la posición exacta para que no quede deriva
	# acumulada por coma flotante — el estado lógico es la celda, y la
	# posición dibujada tiene que volver a coincidir con ella exactamente.
	_animando = false
	position = _hasta

	if _hay_cola:
		_hay_cola = false
		var siguiente := _cola
		empujar(siguiente)
