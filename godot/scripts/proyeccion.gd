class_name Proyeccion
## La ambigüedad isométrica: EL TRUCO ENTERO DEL JUEGO.
##
## Puerto de src/mundo/proyeccion.js. Matemática pura: no sabe de mallas,
## de nodos ni de Godot. Solo calcula posiciones de pantalla.
##
## En cámara isométrica ortográfica verdadera (azimut 45°, elevación
## 35.264°) la posición en PANTALLA de una celda depende solo de dos
## números enteros:
##
##     A = x - z          (columna en pantalla)
##     B = x + z - 2y     (fila en pantalla, crece hacia ABAJO)
##
## De ahí sale todo: moverse (+1,+1,+1) en (x,y,z) no cambia ni A ni B. Te
## desplazás en el mundo sin moverte en la imagen. Dos celdas lejísimos una
## de otra pueden ocupar el MISMO píxel.
##
## Eso permite el "puente imposible": dos islas separadas por un abismo se
## ven PEGADAS desde cierta rotación, y si se ven pegadas, se cruzan. Rotar
## no es mirar mejor — rotar cambia qué está conectado con qué.

const ROTACIONES := 4

## Rota una celda alrededor del centro del nivel. La altura NUNCA rota: el
## escenario gira sobre su eje vertical, como una peana.
##
## Giros de 90° exactos, con enteros y sin senos ni cosenos. Es obligatorio:
## con trigonometría, la comparación de igualdad entre dos puntos de
## pantalla fallaría por error de coma flotante y el puente aparecería y
## desaparecería de forma intermitente (INFORME.md §6).
##
## `centro` es (x, z) del mundo empaquetado en un Vector2i — o sea centro.y
## es una coordenada Z, no una altura.
static func rotar_celda(celda: Vector3i, rotacion: int, centro: Vector2i) -> Vector3i:
	var dx := celda.x - centro.x
	var dz := celda.z - centro.y

	var rx := 0
	var rz := 0
	match ((rotacion % ROTACIONES) + ROTACIONES) % ROTACIONES:
		0:
			rx = dx
			rz = dz
		1:
			rx = -dz
			rz = dx
		2:
			rx = -dx
			rz = -dz
		_:
			rx = dz
			rz = -dx

	return Vector3i(rx + centro.x, celda.y, rz + centro.y)

## Posición en pantalla de una celda. Devuelve ENTEROS, así que comparar
## dos posiciones por igualdad es exacto y no "casi igual".
static func proyectar(celda: Vector3i, rotacion: int, centro: Vector2i) -> Vector2i:
	var r := rotar_celda(celda, rotacion, centro)
	return Vector2i(r.x - r.z, r.x + r.z - 2 * r.y)

## Los cuatro pasos posibles, en el espacio (A, B) de la pantalla.
##
## Están nombrados por LO QUE EL OJO VE, a diferencia del original en JS
## (cuyos nombres describían el signo en (A,B) y por eso confundían: ahí
## "arribaDerecha" era en realidad el sudeste de la pantalla).
##
## Derivación: A crece hacia la derecha; B crece hacia ABAJO.
const PASOS := {
	"NO": Vector2i(-1, -1),
	"NE": Vector2i(1, -1),
	"SE": Vector2i(1, 1),
	"SO": Vector2i(-1, 1),
}
