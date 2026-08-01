/**
 * La ambigüedad isométrica: el truco entero del artefacto.
 *
 * En una cámara isométrica ortográfica (azimut 45°, elevación 35.264°) la
 * posición en PANTALLA de una celda del mundo depende solo de dos números:
 *
 *     A = x - z          (columna en pantalla)
 *     B = x + z - 2y     (fila en pantalla)
 *
 * De ahí sale la propiedad que hace posible todo: **dos celdas distintas
 * del mundo pueden ocupar el mismo punto de la pantalla**. Concretamente,
 * moverse (+1, +1, +1) en (x, y, z) no cambia ni A ni B — te desplazas en
 * el mundo sin moverte en la imagen.
 *
 * Eso es lo que permite el "puente imposible" de Fez: dos islas separadas
 * por un abismo pueden verse PEGADAS desde cierta rotación, y si se ven
 * pegadas, se puede cruzar. Rotar no es mirar mejor: rotar cambia qué está
 * conectado con qué.
 *
 * Este módulo es matemática pura. No importa `three` ni sabe de mallas:
 * calcula posiciones de pantalla y nada más.
 */

/** Las cuatro rotaciones del escenario. No hay intermedias, a propósito. */
export const ROTACIONES = 4;

/**
 * Rota una celda alrededor del centro del nivel. La altura nunca rota:
 * el escenario gira sobre su eje vertical, como una peana.
 */
export function rotarCelda({ x, y, z }, rotacion, centro) {
  const dx = x - centro.x;
  const dz = z - centro.z;

  // Giros de 90° exactos: sin senos ni cosenos, para que no haya error de
  // coma flotante. Dos celdas que deben alinearse se alinean EXACTO — si
  // se usara trigonometría, la comparación de igualdad fallaría a veces y
  // el puente aparecería de forma intermitente.
  const [rx, rz] = [
    [dx, dz],
    [-dz, dx],
    [-dx, -dz],
    [dz, -dx],
  ][((rotacion % ROTACIONES) + ROTACIONES) % ROTACIONES];

  return { x: rx + centro.x, y, z: rz + centro.z };
}

/**
 * Posición en pantalla de una celda, para una rotación dada.
 * Devuelve enteros, así que la comparación es exacta.
 */
export function proyectar(celda, rotacion, centro) {
  const { x, y, z } = rotarCelda(celda, rotacion, centro);
  return { a: x - z, b: x + z - 2 * y };
}

/**
 * Los cuatro pasos posibles en pantalla, expresados en el espacio (A, B).
 *
 * Son las cuatro diagonales de la retícula isométrica: lo que el jugador
 * percibe como "arriba-derecha", "abajo-izquierda", etc. Cada una
 * corresponde a ±1 en x o en z dentro del marco ya rotado.
 */
export const PASOS_PANTALLA = {
  arribaDerecha: { a: 1, b: 1 },
  abajoIzquierda: { a: -1, b: -1 },
  arribaIzquierda: { a: -1, b: 1 },
  abajoDerecha: { a: 1, b: -1 },
};

export function sumarPaso(pantalla, paso) {
  return { a: pantalla.a + paso.a, b: pantalla.b + paso.b };
}

export function mismaPantalla(p, q) {
  return p.a === q.a && p.b === q.b;
}

export function clavePantalla(p) {
  return `${p.a}|${p.b}`;
}
