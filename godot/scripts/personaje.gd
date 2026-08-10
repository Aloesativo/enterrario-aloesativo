class_name Personaje
extends Node3D
## El personaje. Se mueve por CELDAS DISCRETAS, un paso por empujón.
##
## LA REGLA MÁS IMPORTANTE DE TODO EL PROYECTO (ver DISENO_GODOT.md §3):
## esto NO es un CharacterBody3D, NO usa move_and_slide(), NO tiene
## velocidad continua ni gravedad simulada. El estado lógico del personaje
## es una celda entera (Vector3i), nunca una posición flotante.
##
## Por qué es obligatorio y no una preferencia de estilo: la regla del
## juego ("puedes pisar lo que se ve pegado a ti") compara posiciones en
## pantalla buscando igualdad EXACTA. Con posiciones continuas esa igualdad
## no ocurre nunca y el core del juego no puede existir.
##
## Lo que SÍ es continuo es la animación: el paso se ve suave, con su arco
## y su tiempo. Lo discreto es el estado, no el dibujo.

## Tamaño de celda en x/z, y altura de un escalón.
##
## ⚠️ TIENEN QUE SER IGUALES. La matemática de proyeccion.gd asume que subir
## un escalón desplaza en pantalla exactamente lo mismo que avanzar una
## celda en x o z (por eso B = x + z - 2y con un 2 y no otro número).
## Separarlos rompe TODAS las alineaciones sin que nada avise (INFORME §6).
const TAM := 1.0
const ALTO := 1.0

## Sensación del paso normal.
##
## OJO (DISENO_GODOT.md §6): el peso va en la TEXTURA del paso (arco,
## aterrizaje, sonido), NO en hacerlo lento. Un paso lento vuelve tedioso
## probar rotaciones, que es el core del juego.
const DURACION_PASO := 0.16
const ALTURA_ARCO := 0.12

## El paso del PUENTE IMPOSIBLE dura más y sube mucho más alto.
##
## Es la única pista que da el sistema de que acaba de pasar algo que no era
## obvio. Sin ella, cruzar un abismo de 22 celdas se siente igual que
## caminar al lado, y el hallazgo pierde todo su peso.
const DURACION_PUENTE := 0.42
const ALTURA_ARCO_PUENTE := 2.2

signal paso_terminado

var celda := Vector3i.ZERO
var animando := false

var _centro := Vector2i.ZERO
var _t := 0.0
var _duracion := DURACION_PASO
var _arco := ALTURA_ARCO
var _desde := Vector3.ZERO
var _hasta := Vector3.ZERO

## Posición dentro del pivote que rota. Es la posición SIN rotar: el giro
## del mundo lo aplica el nodo padre, no esta cuenta.
static func posicion_local(c: Vector3i, centro: Vector2i) -> Vector3:
	return Vector3(
		(c.x - centro.x) * TAM,
		c.y * ALTO,
		(c.z - centro.y) * TAM
	)

func configurar(celda_inicial: Vector3i, centro: Vector2i) -> void:
	_centro = centro
	celda = celda_inicial
	position = posicion_local(celda, _centro)

## Mover a una celda concreta. Quién decide si el paso es legal es
## navegacion.gd — acá solo se anima.
func ir_a(destino: Vector3i, es_puente: bool) -> void:
	if animando:
		return

	_desde = posicion_local(celda, _centro)
	_hasta = posicion_local(destino, _centro)
	celda = destino

	_duracion = DURACION_PUENTE if es_puente else DURACION_PASO
	_arco = ALTURA_ARCO_PUENTE if es_puente else ALTURA_ARCO
	_t = 0.0
	animando = true

func _process(delta: float) -> void:
	if not animando:
		return

	_t += delta / _duracion
	var t := clampf(_t, 0.0, 1.0)
	# Ease-out cúbico: sale rápido y aterriza suave. El aterrizaje es la
	# parte que se siente como "peso".
	var s := 1.0 - pow(1.0 - t, 3.0)

	position = _desde.lerp(_hasta, s)
	position.y += sin(s * PI) * _arco

	if t < 1.0:
		return

	# Fin del paso: se fija la posición exacta para que no quede deriva
	# acumulada por coma flotante — el estado lógico es la celda, y la
	# posición dibujada tiene que volver a coincidir con ella exactamente.
	animando = false
	position = _hasta
	paso_terminado.emit()
