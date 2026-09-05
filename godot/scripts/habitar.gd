class_name Habitar
extends Node3D
## REGISTRO HABITAR — un entorno 3D común y corriente, en tercera persona.
##
## Ver PREPRODUCCION.md §1. Es el registro que NO existía: RR probó el
## prototipo y dijo que el personaje tiene que verse en tercera persona y
## habitar un entorno 3D normal, y que la isometría pase a funcionar de manera
## cinematográfica. Esto es la mitad "habitar" de esa decisión.
##
## Qué hay acá y qué NO:
##   SÍ  — suelo con relieve y colisión, arquitectura vertical a escala de
##         cuerpo, cámara en tercera persona que el jugador controla,
##         movimiento continuo, los arcos que llevan a los santuarios.
##   NO  — el acertijo (eso es acertijo.gd), rotación del mundo, celdas.
##
## LA CÁMARA NO ES DE ESTE NODO. Este script solo CALCULA dónde debería estar
## (`transform_camara()`); quien la mueve es `frontera.gd`. Es lo que permite
## que la transición al acertijo sea UNA TOMA CONTINUA en vez de un corte
## entre dos cámaras — y esa toma continua es el punto entero del rediseño.
##
## ⚠️ Sobre la escala: que el personaje se lea como un CUERPO y no como una
## ficha depende menos de la proyección que de tres cosas concretas —
## qué fracción del cuadro ocupa, si hay arquitectura vertical a su altura, y
## si la cámara lo acompaña de cerca. La causa #2 del diagnóstico
## (PREPRODUCCION.md §0) fue exactamente esto: con la cámara ortográfica en
## size 20, el personaje ocupaba ~5% del cuadro. Los arcos miden 2.4 de alto
## contra 1.0 del personaje justamente para dar esa referencia.

## ---------------------------------------------------------------- la cámara

## Distancia de la cámara al personaje. Es LO PRIMERO que hay que tocar si no
## se siente tercera persona: más chico = más íntimo y más "habitado", más
## grande = más diorama (que es de lo que veníamos).
const DISTANCIA_CAMARA := 6.5

## A qué altura del cuerpo apunta. Al pecho, no a los pies: apuntar a los pies
## hace que el personaje quede pegado al borde de abajo del cuadro.
const ALTURA_FOCO := 0.85

## Inclinación de la cámara, en radianes sobre la horizontal. Acotada a
## propósito: pasar de ~70° la deja casi cenital y se vuelve el diorama otra
## vez; bajar de ~5° mete el suelo en toda la pantalla.
const PITCH_REPOSO := 0.36
const PITCH_MIN := 0.08
const PITCH_MAX := 1.15

## Orientación de reposo. REGLA DURA (PREPRODUCCION.md §2, regla 4): al volver
## del acertijo la cámara vuelve SIEMPRE a esta orientación, siempre la misma.
## Si el jugador vuelve a un mundo orientado distinto, pierde el modelo mental
## que acababa de construir. Es la misma regla que rige el zoom-out.
const YAW_REPOSO := 0.0

const VELOCIDAD_YAW := 2.6    # radianes/segundo con stick o teclas
const VELOCIDAD_PITCH := 1.6
const SENSIBILIDAD_MOUSE := 0.005
const ZONA_MUERTA := 0.18     # el stick derecho no vuelve a cero exacto

## Suavizado del seguimiento. La cámara persigue al personaje con un retardo
## chico: sin él el encuadre es rígido y el andar se siente sobre rieles.
const SUAVIZADO_FOCO := 12.0

## --------------------------------------------------------------- los arcos

## Los umbrales que llevan a cada santuario.
##
## Cada uno declara la zona del acertijo a la que entra. **La celda de entrada
## NO se declara acá a propósito**: es la `partida` de esa zona, que está
## verificada con `herramientas/verificar_nivel.py`. Declarar otra celda
## invalidaría el acertijo en silencio (PREPRODUCCION.md §2, regla 1).
##
## `posicion` es dónde está el arco; `salida` es dónde reaparece el personaje
## al volver — a un paso del arco y FUERA de su área, para no volver a entrar
## de rebote.
func _definir_arcos() -> Array:
	return [
		{
			"zona": "ciudad",
			"titulo": "Burdeo — la ciudad",
			"posicion": Vector3(-14, 0, -6),
			"salida": Vector3(-14, 0, -3.2),
			"mirando": 0.0,
		},
		{
			"zona": "luna",
			"titulo": "La luna de Burdeo",
			"posicion": Vector3(14, 0, -6),
			"salida": Vector3(14, 0, -3.2),
			"mirando": 0.0,
		},
		{
			"zona": "playa",
			"titulo": "Playa / costas",
			# Arriba de la terraza: hay que subir la rampa para encontrarlo.
			"posicion": Vector3(0, 2, 15),
			"salida": Vector3(0, 2, 12.2),
			"mirando": PI,
		},
	]

signal umbral_cruzado(zona: String, salida: Vector3)

const PUNTO_DE_PARTIDA := Vector3(0, 0.3, 0)

var _caminante: Caminante
var _yaw := YAW_REPOSO
var _pitch := PITCH_REPOSO
var _foco := Vector3.ZERO
var _mirando_con_mouse := false

## Cuando es true no se disparan los umbrales. Se enciende al volver del
## acertijo y se apaga cuando el personaje sale del área — si no, volver del
## acertijo te mete de nuevo adentro en el mismo frame.
var _umbrales_sordos := false

var _activo := true

## Los materiales de todo lo que se dibuja acá, para poder desvanecerlos juntos
## durante la toma de la frontera. Ver Cuerpo.recolectar_materiales().
var _materiales: Array = []

func _ready() -> void:
	_construir_isla()
	_construir_arquitectura()
	_construir_arcos()
	_crear_caminante()
	_foco = _caminante.global_position + Vector3(0, ALTURA_FOCO, 0)
	# Al final, cuando ya existe todo lo que se dibuja — el caminante incluido.
	_materiales = Cuerpo.recolectar_materiales(self)
	print("[habitar] isla construida — mover: flechas/stick izq · cámara: stick der, Q/E, o botón derecho del mouse")

func activar(si: bool) -> void:
	_activo = si
	if _caminante != null:
		_caminante.activo = si

## Opacidad del mundo habitado entero, 0..1. La usa frontera.gd para
## disolverlo durante la toma en vez de apagarlo de golpe — el apagón se veía
## como un parpadeo, porque la isla NO queda fuera de cuadro en la isométrica
## (la cuenta está en cuerpo.gd).
func desvanecer(opacidad: float) -> void:
	Cuerpo.aplicar_opacidad(_materiales, opacidad)

## Devuelve al personaje al mundo habitado, en el punto que declaró el arco.
func devolver_a(punto: Vector3) -> void:
	_umbrales_sordos = true
	_yaw = YAW_REPOSO
	_pitch = PITCH_REPOSO
	_caminante.plantar_en(punto)
	# El foco se reposiciona de golpe, no interpolado: si no, la cámara entra
	# volando desde donde estaba y eso sí sería un corte mal hecho.
	_foco = punto + Vector3(0, ALTURA_FOCO, 0)

## Dónde debería estar la cámara. No la mueve: la calcula. Ver la cabecera.
func transform_camara() -> Transform3D:
	var direccion := Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch)
	)
	var t := Transform3D()
	t.origin = _foco + direccion * DISTANCIA_CAMARA
	return t.looking_at(_foco, Vector3.UP)

# ------------------------------------------------------------- construcción

## Un bloque sólido con colisión. Es el ladrillo de todo lo de acá: el suelo,
## las rampas, los edificios y los muros del borde son todos esto.
func _bloque(pos: Vector3, tam: Vector3, color: Color, rot_x := 0.0, visible_ := true) -> StaticBody3D:
	var cuerpo := StaticBody3D.new()
	cuerpo.position = pos
	cuerpo.rotation.x = rot_x

	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	forma.shape = caja
	cuerpo.add_child(forma)

	if visible_:
		var malla := MeshInstance3D.new()
		var caja_malla := BoxMesh.new()
		caja_malla.size = tam
		malla.mesh = caja_malla
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		malla.material_override = material
		cuerpo.add_child(malla)

	add_child(cuerpo)
	return cuerpo

func _construir_isla() -> void:
	# La placa base. Su cara de arriba queda en y = 0, así que el personaje
	# camina a la altura 0 igual que dentro del acertijo.
	_bloque(Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.50, 0.50, 0.50))

	# Una terraza elevada con su rampa. Existe por una razón de diseño, no de
	# adorno: sin cambio de altura, un entorno en tercera persona se lee como
	# una alfombra. Y la rampa (en vez de un escalón) porque CharacterBody3D no
	# sube escalones por sí solo — un escalón de 2 unidades sería un muro.
	_bloque(Vector3(0, 1.75, 14), Vector3(16, 0.5, 10), Color(0.55, 0.55, 0.55))

	# Rampa de y=0 (en z=4) a y=2 (en z=9.5). Rotar en X con ángulo NEGATIVO
	# sube el extremo +Z: con rotación positiva la rampa baja hacia la terraza y
	# queda un escalón imposible al final.
	var largo := sqrt(5.5 * 5.5 + 2.0 * 2.0)
	_bloque(Vector3(0, 1.0, 6.75), Vector3(5, 0.4, largo), Color(0.58, 0.58, 0.58), -atan(2.0 / 5.5))

	# El borde del mundo. PENDIENTE DE DISEÑO (PREPRODUCCION.md §8): todavía no
	# se decidió qué ve el jugador al llegar al límite. Mientras tanto, muros
	# invisibles — caerse al vacío sin fondo sería un softlock, y eso es peor
	# que un límite provisional que se nota.
	for lado in [Vector3(0, 0, -20.5), Vector3(0, 0, 20.5)]:
		_bloque(lado + Vector3(0, 3, 0), Vector3(41, 6, 1), Color.BLACK, 0.0, false)
	for lado in [Vector3(-20.5, 0, 0), Vector3(20.5, 0, 0)]:
		_bloque(lado + Vector3(0, 3, 0), Vector3(1, 6, 41), Color.BLACK, 0.0, false)

func _construir_arquitectura() -> void:
	# "Concreto, guetos verticales" (src/story/burdeo.json). Torres altas y
	# flacas, en gris placeholder. Su trabajo acá es dar ESCALA: contra un
	# personaje de 1 unidad, una torre de 9 se lee como un edificio, y de
	# repente el personaje se lee como un cuerpo. Es la mitad del arreglo que
	# pidió RR.
	var torres := [
		{"pos": Vector3(-17, 0, 6), "tam": Vector3(4.5, 9, 4.5)},
		{"pos": Vector3(-9, 0, 10), "tam": Vector3(3.5, 6, 3.5)},
		{"pos": Vector3(17, 0, 7), "tam": Vector3(4, 8, 5)},
		{"pos": Vector3(9, 0, 12), "tam": Vector3(3, 5, 3)},
		{"pos": Vector3(-6, 0, -15), "tam": Vector3(5, 7, 4)},
		{"pos": Vector3(6, 0, -16), "tam": Vector3(4, 4.5, 4)},
		{"pos": Vector3(-18, 0, -14), "tam": Vector3(3, 5.5, 6)},
		{"pos": Vector3(18, 0, -13), "tam": Vector3(3, 6.5, 5)},
	]
	var claro := Color(0.62, 0.62, 0.62)
	var oscuro := Color(0.46, 0.46, 0.46)
	var i := 0
	for torre in torres:
		var tam: Vector3 = torre["tam"]
		var pos: Vector3 = torre["pos"]
		# El centro va a media altura para que la base quede apoyada en y = 0.
		_bloque(pos + Vector3(0, tam.y * 0.5, 0), tam, claro if i % 2 == 0 else oscuro)
		i += 1

	# Un par de muros bajos, a la altura de la cintura del personaje. Son la
	# referencia de escala más útil de todas porque se comparan de un vistazo.
	_bloque(Vector3(-4, 0.35, -9), Vector3(9, 0.7, 0.6), Color(0.56, 0.56, 0.56))
	_bloque(Vector3(5, 0.35, -9), Vector3(7, 0.7, 0.6), Color(0.56, 0.56, 0.56))

## El arco de un santuario, y su área de disparo.
##
## Mide 2.4 de alto contra 1.0 del personaje: se lee sin dudar como algo por
## donde pasa un cuerpo. Esa proporción es información de escala, no adorno.
const ALTO_ARCO := 2.4
const ANCHO_ARCO := 2.6

func _construir_arcos() -> void:
	for arco in _definir_arcos():
		var base: Vector3 = arco["posicion"]
		var giro: float = arco["mirando"]
		var color := Color(0.5, 0.78, 0.85) # mismo celeste que marca los portales del acertijo

		var nodo := Node3D.new()
		nodo.name = "Arco_" + (arco["zona"] as String)
		nodo.position = base
		nodo.rotation.y = giro
		add_child(nodo)

		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.6

		# Dos pilares y un dintel. Los pilares llevan colisión (se choca con
		# ellos), el dintel no hace falta: nadie llega a su altura.
		for lado in [-1.0, 1.0]:
			var pilar := StaticBody3D.new()
			pilar.position = Vector3(lado * ANCHO_ARCO * 0.5, ALTO_ARCO * 0.5, 0)
			var forma := CollisionShape3D.new()
			var caja := BoxShape3D.new()
			caja.size = Vector3(0.4, ALTO_ARCO, 0.4)
			forma.shape = caja
			pilar.add_child(forma)
			var malla := MeshInstance3D.new()
			var caja_malla := BoxMesh.new()
			caja_malla.size = caja.size
			malla.mesh = caja_malla
			malla.material_override = material
			pilar.add_child(malla)
			nodo.add_child(pilar)

		var dintel := MeshInstance3D.new()
		var viga := BoxMesh.new()
		viga.size = Vector3(ANCHO_ARCO + 0.4, 0.4, 0.4)
		dintel.mesh = viga
		dintel.material_override = material
		dintel.position = Vector3(0, ALTO_ARCO + 0.2, 0)
		nodo.add_child(dintel)

		# El área de disparo: el hueco del arco. Se cruza caminando, no se
		# "activa" — cero UI, interacción directa con el mundo
		# (DISENO_GODOT.md §4).
		var area := Area3D.new()
		area.name = "Umbral"
		var col := CollisionShape3D.new()
		var volumen := BoxShape3D.new()
		volumen.size = Vector3(ANCHO_ARCO - 0.4, ALTO_ARCO, 1.0)
		col.shape = volumen
		col.position = Vector3(0, ALTO_ARCO * 0.5, 0)
		area.add_child(col)
		nodo.add_child(area)

		var zona: String = arco["zona"]
		var salida: Vector3 = arco["salida"]
		area.body_entered.connect(func(cuerpo: Node3D) -> void:
			_al_entrar_al_umbral(cuerpo, zona, salida)
		)
		area.body_exited.connect(func(cuerpo: Node3D) -> void:
			if cuerpo == _caminante:
				_umbrales_sordos = false
		)

func _crear_caminante() -> void:
	_caminante = Caminante.new()
	_caminante.name = "Caminante"
	_caminante.position = PUNTO_DE_PARTIDA
	add_child(_caminante)

func _al_entrar_al_umbral(cuerpo: Node3D, zona: String, salida: Vector3) -> void:
	if cuerpo != _caminante or not _activo or _umbrales_sordos:
		return
	print("[habitar] cruzás el umbral de '%s'" % zona)
	umbral_cruzado.emit(zona, salida)

# ---------------------------------------------------------------- la cámara

func _unhandled_input(evento: InputEvent) -> void:
	if not _activo:
		return
	# Mirar con el mouse SOLO con el botón derecho apretado. Capturar el cursor
	# de entrada sería intrusivo en un juego contemplativo, y encima molesta
	# para probar desde el editor.
	if evento is InputEventMouseButton:
		var boton := evento as InputEventMouseButton
		if boton.button_index == MOUSE_BUTTON_RIGHT:
			_mirando_con_mouse = boton.pressed
	elif evento is InputEventMouseMotion and _mirando_con_mouse:
		var mov := (evento as InputEventMouseMotion).relative
		_yaw -= mov.x * SENSIBILIDAD_MOUSE
		_pitch = clampf(_pitch + mov.y * SENSIBILIDAD_MOUSE, PITCH_MIN, PITCH_MAX)

func _eje_derecho(eje: JoyAxis) -> float:
	var v := Input.get_joy_axis(0, eje)
	return 0.0 if absf(v) < ZONA_MUERTA else v

func _process(delta: float) -> void:
	if not _activo:
		return

	# Cámara: stick derecho (pre-mapeado de fábrica, sin pantalla de
	# configuración — requisito duro de RR) más Q/E de teclado. A/D NO se usan
	# acá: están reservados para rotar el mundo dentro del acertijo, y que una
	# tecla haga dos cosas distintas según el registro sería justo la confusión
	# que la frontera visible trata de evitar.
	var giro := _eje_derecho(JOY_AXIS_RIGHT_X)
	if Input.is_key_pressed(KEY_Q):
		giro -= 1.0
	if Input.is_key_pressed(KEY_E):
		giro += 1.0
	_yaw -= giro * VELOCIDAD_YAW * delta

	var alto := _eje_derecho(JOY_AXIS_RIGHT_Y)
	_pitch = clampf(_pitch + alto * VELOCIDAD_PITCH * delta, PITCH_MIN, PITCH_MAX)

	# Movimiento, relativo a la cámara: "adelante" es adelante de lo que ves.
	# Con el eje del mundo en vez del de la cámara, girar la cámara invierte los
	# controles y se vuelve injugable.
	var entrada := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	var adelante := -Vector3(sin(_yaw), 0.0, cos(_yaw))
	var derecha := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var direccion := adelante * -entrada.y + derecha * entrada.x
	if direccion.length() > 1.0:
		direccion = direccion.normalized()
	_caminante.dirigir(direccion)

	_seguir_al_personaje(delta)

func _seguir_al_personaje(delta: float) -> void:
	var objetivo := _caminante.global_position + Vector3(0, ALTURA_FOCO, 0)
	# exp() en vez de un lerp con delta crudo: así el suavizado no cambia de
	# carácter según los fps.
	_foco = _foco.lerp(objetivo, 1.0 - exp(-SUAVIZADO_FOCO * delta))
