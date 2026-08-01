import { proyectar, sumarPaso, clavePantalla, PASOS_PANTALLA } from './proyeccion.js';

/**
 * Las reglas de movimiento. Datos puros: decide a qué celda se puede ir,
 * nunca dibuja nada.
 *
 * La regla es UNA y es la que define el juego:
 *
 *   **Puedes pisar lo que se ve pegado a ti.**
 *
 * No "lo que está al lado en el mundo" — lo que está al lado EN LA
 * PANTALLA. Casi siempre coinciden, y por eso caminar se siente normal.
 * Pero cuando no coinciden, cruzas un abismo porque desde ese ángulo el
 * abismo no existe. Y al rotar, el puente desaparece.
 *
 * Es deliberadamente una sola regla: si hubiera excepciones ("aquí sí,
 * aquí no"), el jugador no podría construir un modelo mental fiable, y sin
 * modelo mental fiable no hay descubrimiento, hay prueba y error.
 */

export function crearNavegacion(nivel) {
  const centro = nivel.centro;

  // Índice por rotación: para cada rotación, qué celda ocupa cada punto de
  // la pantalla. Se calcula una vez porque el nivel no cambia.
  const indices = [];
  for (let r = 0; r < 4; r++) {
    const mapa = new Map();
    for (const bloque of nivel.bloques) {
      const p = proyectar(bloque, r, centro);
      const clave = clavePantalla(p);
      const previo = mapa.get(clave);

      // Si dos celdas caen en el mismo punto de pantalla, gana la que está
      // MÁS CERCA de la cámara: es la que el jugador ve, y solo se puede
      // pisar lo que se ve. La profundidad en isométrica crece con x+z.
      if (!previo || bloque.x + bloque.z > previo.x + previo.z) {
        mapa.set(clave, bloque);
      }
    }
    indices.push(mapa);
  }

  /** La celda visible en un punto de la pantalla, o null. */
  function celdaEnPantalla(pantalla, rotacion) {
    return indices[rotacion].get(clavePantalla(pantalla)) ?? null;
  }

  /**
   * Intenta dar un paso. Devuelve la celda de destino y si el paso fue un
   * "puente imposible" — o sea, si en el mundo real esas dos celdas no se
   * tocan y solo están unidas por la perspectiva.
   */
  function intentarPaso(desde, direccion, rotacion) {
    const paso = PASOS_PANTALLA[direccion];
    if (!paso) return { permitido: false, motivo: 'direccion-desconocida' };

    const destinoPantalla = sumarPaso(proyectar(desde, rotacion, centro), paso);
    const celda = celdaEnPantalla(destinoPantalla, rotacion);

    if (!celda) return { permitido: false, motivo: 'vacio' };

    // ¿Están de verdad juntas en el mundo, o solo lo parecen?
    const distanciaReal =
      Math.abs(celda.x - desde.x) + Math.abs(celda.y - desde.y) + Math.abs(celda.z - desde.z);

    return {
      permitido: true,
      celda,
      puenteImposible: distanciaReal > 1,
      distanciaReal,
    };
  }

  /**
   * Qué celdas son alcanzables desde una, en una rotación dada. Sirve para
   * verificar que un nivel tiene solución sin jugarlo a mano — la parte
   * que más se rompe al mover un bloque de sitio.
   */
  function alcanzables(desde, rotacion) {
    const vistas = new Set();
    const cola = [desde];
    const clave = (c) => `${c.x},${c.y},${c.z}`;
    vistas.add(clave(desde));

    while (cola.length) {
      const actual = cola.pop();
      for (const direccion of Object.keys(PASOS_PANTALLA)) {
        const paso = intentarPaso(actual, direccion, rotacion);
        if (paso.permitido && !vistas.has(clave(paso.celda))) {
          vistas.add(clave(paso.celda));
          cola.push(paso.celda);
        }
      }
    }
    return vistas;
  }

  return { celdaEnPantalla, intentarPaso, alcanzables, centro };
}
