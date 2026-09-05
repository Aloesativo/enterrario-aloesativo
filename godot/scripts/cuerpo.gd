class_name Cuerpo
## El cuerpo visual del personaje. UNO solo, compartido por los DOS registros.
##
## Por qué esto es un archivo aparte y no se duplica en cada registro
## (PREPRODUCCION.md §1): el jugador tiene que entender que el que camina por
## la ciudad y el que da pasos por celdas dentro del santuario son EL MISMO
## ser. Si cada registro dibujara su propio cuerpo, la frontera se leería
## como un cambio de personaje en vez de un cambio de cámara — y el cambio de
## cámara es justamente lo que se quiere que se lea.
##
## Es solo el dibujo: no sabe caminar, no sabe de celdas, no sabe de física.
## Quien lo mueve es `personaje.gd` (registro acertijo) o `caminante.gd`
## (registro habitar).
##
## Identidad visual: placeholder gris. La define RR (CLAUDE.md).

## Alto total del cuerpo, en unidades de mundo. Es igual a `Personaje.ALTO`
## (una celda) a propósito: dentro del acertijo el personaje mide exactamente
## un escalón, y eso ayuda a contar celdas de un vistazo.
const ALTO := 1.0

const RADIO := 0.26

## Crea el cuerpo, con los pies en y = 0.
##
## Devuelve un Node3D suelto, sin padre: quien lo pide decide dónde colgarlo.
## Los dos registros lo cuelgan de un nodo intermedio para que el bamboleo, la
## inclinación y el giro del andar NO toquen la posición lógica.
static func crear() -> Node3D:
	var cuerpo := Node3D.new()
	cuerpo.name = "Cuerpo"

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.85, 0.9)

	var tronco := MeshInstance3D.new()
	tronco.name = "Tronco"
	var capsula := CapsuleMesh.new()
	capsula.radius = RADIO
	capsula.height = ALTO
	tronco.mesh = capsula
	tronco.material_override = material
	tronco.position = Vector3(0, ALTO * 0.5, 0)
	cuerpo.add_child(tronco)

	# Un morro al frente. Sin esto la cápsula es simétrica y no se ve hacia
	# dónde mira — y que mire hacia donde va es media gracia de que parezca una
	# criatura y no una ficha.
	var morro := MeshInstance3D.new()
	morro.name = "Morro"
	var caja := BoxMesh.new()
	caja.size = Vector3(0.17, 0.17, 0.24)
	morro.mesh = caja
	morro.material_override = material
	morro.position = Vector3(0, ALTO * 0.62, -RADIO) # -Z es el frente en Godot
	cuerpo.add_child(morro)

	return cuerpo

## ---------------------------------------------------- el fundido de la toma

## Junta los materiales de todas las mallas colgadas de un nodo, para poder
## desvanecerlas juntas.
##
## Por qué existe esto (hallazgo de esta sesión, comprobado con números):
## la primera versión de la frontera apagaba el mundo habitado de golpe al
## final de la toma, asumiendo que a esa altura ya había quedado fuera de
## cuadro. **Es falso.** Con la cámara isométrica a 35.264°, la isla habitable
## de 40×40 cae DENTRO del encuadre de los tres santuarios, y elevarlos no lo
## arregla: subir una zona empuja fuera los puntos de abajo pero mete los de
## arriba (playa necesitaría estar a y=50 para librarse, que es absurdo).
##
## O sea que el apagón se habría visto como un parpadeo. Un fundido no depende
## del encuadre en absoluto, así que es correcto por construcción y no por
## suerte geométrica.
static func recolectar_materiales(nodo: Node, acumulado: Array = []) -> Array:
	for hijo in nodo.get_children():
		if hijo is MeshInstance3D:
			var material = (hijo as MeshInstance3D).material_override
			if material is StandardMaterial3D and not acumulado.has(material):
				acumulado.append(material)
		recolectar_materiales(hijo, acumulado)
	return acumulado

## Opacidad 0..1. A opacidad plena se vuelve al modo opaco: dejar el material
## en modo alfa cuesta orden de dibujado y no escribe profundidad, y no hay
## motivo de pagarlo fuera de la toma.
static func aplicar_opacidad(materiales: Array, opacidad: float) -> void:
	var a := clampf(opacidad, 0.0, 1.0)
	for m in materiales:
		var material := m as StandardMaterial3D
		material.transparency = (
			BaseMaterial3D.TRANSPARENCY_DISABLED if a >= 1.0
			else BaseMaterial3D.TRANSPARENCY_ALPHA
		)
		var color := material.albedo_color
		color.a = a
		material.albedo_color = color
