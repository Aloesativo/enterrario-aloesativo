extends Node3D
## LA FRONTERA — la pieza nueva, y la única con riesgo estructural real.
##
## Ver PREPRODUCCION.md §2. Este script hace dos cosas y nada más:
##
##   1. decide qué registro está activo (habitar o acertijo), y
##   2. es EL DUEÑO DE LA CÁMARA.
##
## Los dos registros solo CALCULAN dónde debería estar la cámara
## (`transform_camara()`); moverla es trabajo de acá. Esa inversión es lo que
## hace posible el punto entero del rediseño:
##
## ══════════════════════════════════════════════════════════════════════════
## EL MUNDO SE APLANA ANTE TUS OJOS, EN UNA SOLA TOMA CONTINUA.
## ══════════════════════════════════════════════════════════════════════════
##
## Cómo funciona, porque no es obvio y es el hallazgo que hizo esto barato:
##
## Una cámara en perspectiva con FOV muy chico es VISUALMENTE
## indistinguible de una ortográfica. Así que la transición no interpola entre
## dos proyecciones (Godot no lo permite): **vuela hacia atrás mientras cierra
## el FOV**, que es un dolly zoom / efecto vértigo, y cuando el FOV llegó al
## valor en que las dos proyecciones coinciden, cambia de proyección en un
## frame donde el cambio no se ve.
##
## El FOV exacto en que coinciden sale de igualar lo que abarcan a la distancia
## del objetivo:
##
##     ortográfica:  alto_visible = size
##     perspectiva:  alto_visible = 2 · distancia · tan(fov/2)
##     ⇒  fov = 2 · atan( size / (2 · distancia) )
##
## No es teoría: `src/render/camera.js` ya renderiza el estereograma con una
## PerspectiveCamera de FOV bajo mientras la matemática es ortográfica, y el
## truco funciona igual — verificado por captura. El jugador LEE la alineación,
## no la mide con un calibre. Esa tolerancia es el espacio donde vive esta
## transición. Y el dolly zoom ya estaba en la biblioteca de planos del repo
## (`src/theme/planos.json`), esperando: se porta, no se reinventa
## (DISENO_GODOT.md §12).

enum Registro { HABITAR, ENTRANDO, ACERTIJO, SALIENDO }

## Cuánto dura la toma. Larga a propósito: es la revelación de que el espacio
## era otra cosa, y en dos tiradas no se lee. Pero no tanto como el zoom-cuerda
## (etapa E), que sí tiene que sentirse como trabajo.
const DURACION_ENTRADA := 1.6
const DURACION_SALIDA := 1.2

const FOV_HABITAR := 62.0

## En qué punto de la toma (0..1) arranca el FUNDIDO CRUZADO: el mundo habitado
## se disuelve mientras el personaje aparece dentro del santuario.
##
## ⚠️ La primera versión no fundía: apagaba el mundo habitado de golpe cerca del
## final, dando por hecho que a esa altura ya había quedado fuera de cuadro.
## **Se comprobó con números y era falso.** Con la cámara isométrica a 35.264°
## la isla de 40×40 cae DENTRO del encuadre de los tres santuarios, y elevar las
## zonas no lo arregla (empuja fuera los puntos de abajo pero mete los de
## arriba). El apagón se habría visto como un parpadeo.
##
## Un fundido no depende del encuadre, así que es correcto por construcción y
## no por suerte geométrica. Y además el cruce dice algo: tu cuerpo se disuelve
## en el mundo y reaparece dentro del santuario.
##
## Si el fundido se siente apurado, bajar este número (0.40); si tapa demasiado
## pronto el vuelo, subirlo (0.70).
const INICIO_FUNDIDO := 0.55

@onready var _camara: Camera3D = $Camara
@onready var _habitar: Habitar = $Habitar
@onready var _acertijo: Acertijo = $Acertijo

var _estado := Registro.HABITAR
var _t := 0.0

var _zona := ""
var _salida := Vector3.ZERO

var _fov_final := FOV_HABITAR
var _size_final := 20.0

var _desde := Transform3D()
var _hasta := Transform3D()

func _ready() -> void:
	# La cámara se coloca DESPUÉS de que los registros actualizaron su estado en
	# el mismo frame. Sin esto, la cámara va siempre un frame por detrás del
	# personaje: no se nota como lag, se nota como un temblor al caminar.
	process_priority = 10

	_preparar_ambiente()

	_camara.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camara.fov = FOV_HABITAR
	_camara.near = 0.1
	_camara.far = 600.0
	_camara.current = true

	_habitar.umbral_cruzado.connect(_entrar)
	_acertijo.salir_pedido.connect(_salir)

	_habitar.activar(true)
	_habitar.desvanecer(1.0)
	_acertijo.activar(false)
	_acertijo.mostrar(false)
	_camara.global_transform = _habitar.transform_camara()

	print("[frontera] registro HABITAR — cruzá un arco para entrar a un santuario")

## Iluminación y cielo. Placeholder neutro: la identidad visual la define RR
## (CLAUDE.md). Lo único que se decide acá es que haya luz ambiente, porque sin
## ella las caras en sombra quedan negras y no se lee la forma — y en este
## juego la forma ES la información con la que se juega.
##
## ⚠️ SIN NIEBLA, y a propósito. La lección más cara del track de Three.js fue
## que una niebla mal calibrada pinta todo invisible aunque geometría, luces y
## cámara estén bien (CLAUDE.md, "Lección del bug de niebla"). Y acá sería
## peor: la cámara cambia de distancia de forma brutal durante la toma —de ~6.5
## a ~69 unidades—, así que cualquier distancia de niebla fija estaría mal en
## alguno de los dos extremos. Si algún día se quiere niebla, tiene que
## derivarse de la distancia real por frame, como terminó haciendo camera.js.
##
## Tampoco hay glow/bloom: `src/theme/default.json` dejó anotado que un color
## por encima de ~#d0d0d0 supera el umbral y se quema hasta volverse ilegible.
func _preparar_ambiente() -> void:
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color(0.36, 0.40, 0.46)
	material.sky_horizon_color = Color(0.56, 0.58, 0.60)
	material.ground_horizon_color = Color(0.44, 0.44, 0.45)
	material.ground_bottom_color = Color(0.24, 0.24, 0.26)

	var cielo := Sky.new()
	cielo.sky_material = material

	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_SKY
	ambiente.sky = cielo
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	ambiente.ambient_light_sky_contribution = 1.0
	ambiente.ambient_light_energy = 1.0
	ambiente.fog_enabled = false
	ambiente.glow_enabled = false

	var nodo := WorldEnvironment.new()
	nodo.name = "Ambiente"
	nodo.environment = ambiente
	add_child(nodo)

## El FOV con el que una perspectiva a esta distancia abarca lo mismo que una
## ortográfica de este `size`. La derivación está en la cabecera.
func _fov_equivalente(size: float, distancia: float) -> float:
	return rad_to_deg(2.0 * atan(size / (2.0 * distancia)))

# ------------------------------------------------------------------- entrar

func _entrar(zona: String, salida: Vector3) -> void:
	if _estado != Registro.HABITAR:
		return
	if not _acertijo.tiene_zona(zona):
		push_warning("[frontera] el arco apunta a la zona '%s', que no existe en acertijo.gd" % zona)
		return

	_zona = zona
	_salida = salida

	# El personaje del acertijo se planta en la celda `partida` de la zona —la
	# verificada— ANTES de volar, así el destino de la cámara ya es el
	# definitivo (PREPRODUCCION.md §2, regla 1).
	_acertijo.entrar_zona(zona)

	_size_final = _acertijo.tamano_camara()
	_fov_final = _fov_equivalente(_size_final, _acertijo.distancia_camara())

	_desde = _camara.global_transform
	_hasta = _acertijo.transform_camara()

	# Nadie juega durante la toma. Es una toma, no una transición jugable: si el
	# personaje pudiera moverse mientras la alineación todavía se está formando,
	# se movería usando información que aún no es cierta.
	_habitar.activar(false)
	_acertijo.activar(false)
	# El personaje del santuario ya existe y está colocado, pero entra en el
	# fundido: se muestra transparente del todo y va apareciendo.
	_acertijo.mostrar(true)
	_acertijo.opacidad_personaje(0.0)

	_t = 0.0
	_estado = Registro.ENTRANDO

	print("[frontera] HABITAR -> ACERTIJO '%s' · el mundo se aplana (fov %.1f° -> %.1f°, size %.1f)" % [
		zona, FOV_HABITAR, _fov_final, _size_final,
	])

# -------------------------------------------------------------------- salir

func _salir() -> void:
	if _estado != Registro.ACERTIJO:
		return

	# Se vuelve a perspectiva EN EL MISMO FOV equivalente al que tenía la
	# ortográfica. Ese es el frame indoloro: las dos proyecciones abarcan lo
	# mismo, así que el cambio no se ve. Recalculado y no reutilizado del
	# entrar, porque viajando entre zonas el `size` pudo cambiar.
	_fov_final = _fov_equivalente(_acertijo.tamano_camara(), _acertijo.distancia_camara())
	_camara.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camara.fov = _fov_final

	# El personaje vuelve al punto que declaró el arco, a un paso y FUERA del
	# área del umbral — si volviera al centro del arco, entraría de rebote en el
	# mismo frame. Y la cámara vuelve a su orientación de reposo: SIEMPRE la
	# misma (PREPRODUCCION.md §2, regla 4).
	_habitar.devolver_a(_salida)

	_desde = _camara.global_transform
	_hasta = _habitar.transform_camara()

	_acertijo.activar(false)
	_habitar.activar(false)
	# Espejo de la entrada: el mundo habitado vuelve a estar visible pero
	# totalmente transparente, y se materializa durante la toma.
	_habitar.visible = true
	_habitar.desvanecer(0.0)

	_t = 0.0
	_estado = Registro.SALIENDO

	print("[frontera] ACERTIJO '%s' -> HABITAR · el mundo recupera el volumen" % _zona)

# ------------------------------------------------------------------ la toma

func _process(delta: float) -> void:
	match _estado:
		Registro.HABITAR:
			_camara.global_transform = _habitar.transform_camara()
		Registro.ACERTIJO:
			_camara.global_transform = _acertijo.transform_camara()
			_camara.size = _acertijo.tamano_camara()
		Registro.ENTRANDO:
			_animar_entrada(delta)
		Registro.SALIENDO:
			_animar_salida(delta)

## Interpola la cámara entre dos encuadres. La posición con lerp y la
## orientación con slerp de cuaterniones: interpolar los ángulos de Euler
## sueltos puede tomar el camino largo o pasar por una postura torcida a mitad
## de camino, y acá el camino de la cámara ES el contenido de la toma.
func _colocar_camara(s: float) -> void:
	var q := Quaternion(_desde.basis).slerp(Quaternion(_hasta.basis), s)
	_camara.global_transform = Transform3D(Basis(q), _desde.origin.lerp(_hasta.origin, s))

## Suave al salir y al llegar. Sin esto la toma arranca y frena de golpe, y una
## cámara que arranca de golpe se lee como un tirón, no como un gesto.
func _suavizar(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

## Avance del fundido, 0..1.
##
## ⚠️ Los dos sentidos NO son el mismo tramo, y confundirlos arruina la toma.
## El fundido tiene que ocurrir siempre CON LA CÁMARA LEJOS, que es donde el
## cambio se lee como una disolución y no como que el mundo aparece de golpe
## en la cara del jugador:
##
##   entrando (se vuela de cerca a lejos) → el fundido va AL FINAL
##   saliendo (se vuela de lejos a cerca) → el fundido va AL PRINCIPIO
func _avance_fundido_entrando(t: float) -> float:
	return clampf((t - INICIO_FUNDIDO) / (1.0 - INICIO_FUNDIDO), 0.0, 1.0)

func _avance_fundido_saliendo(t: float) -> float:
	return clampf(t / (1.0 - INICIO_FUNDIDO), 0.0, 1.0)

func _animar_entrada(delta: float) -> void:
	_t += delta / DURACION_ENTRADA
	var t := clampf(_t, 0.0, 1.0)
	var s := _suavizar(t)

	_colocar_camara(s)
	_camara.fov = lerpf(FOV_HABITAR, _fov_final, s)

	var f := _avance_fundido_entrando(t)
	_habitar.desvanecer(1.0 - f)
	_acertijo.opacidad_personaje(f)

	if t < 1.0:
		return

	# Llegada exacta: el encuadre tiene que quedar EXACTAMENTE en la isométrica.
	# Una fracción de grado bastaría para que las losas dejaran de verse
	# alineadas aunque la matemática diga que lo están (INFORME.md §6).
	_camara.global_transform = _hasta
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = _size_final
	# Se apaga con el nodo YA invisible por el fundido, así que no hay parpadeo.
	# Y se le devuelve la opacidad plena para que la próxima vez que se muestre
	# esté opaco (y sus materiales vuelvan al modo sin transparencia).
	_habitar.visible = false
	_habitar.desvanecer(1.0)
	_acertijo.mostrar(true)
	_acertijo.opacidad_personaje(1.0)
	_acertijo.activar(true)
	_estado = Registro.ACERTIJO

	print("[frontera] registro ACERTIJO '%s' — mover: flechas/stick · rotar: A/D o LB/RB · salir: pisá la esfera verde, Escape o B" % _zona)

func _animar_salida(delta: float) -> void:
	_t += delta / DURACION_SALIDA
	var t := clampf(_t, 0.0, 1.0)
	var s := _suavizar(t)

	_colocar_camara(s)
	_camara.fov = lerpf(_fov_final, FOV_HABITAR, s)

	# Espejo exacto de la entrada: el mundo habitado se materializa y el
	# personaje del santuario se disuelve, al mismo tiempo.
	var f := _avance_fundido_saliendo(t)
	_habitar.desvanecer(f)
	_acertijo.opacidad_personaje(1.0 - f)

	if t < 1.0:
		return

	_habitar.desvanecer(1.0)
	_acertijo.opacidad_personaje(1.0)
	_acertijo.mostrar(false)
	_camara.global_transform = _hasta
	_camara.fov = FOV_HABITAR
	_habitar.activar(true)
	_estado = Registro.HABITAR

	print("[frontera] registro HABITAR — mover: flechas/stick izq · cámara: stick der, Q/E o botón derecho del mouse")
