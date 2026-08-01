/**
 * El reloj del bucle temporal. Datos puros: no sabe de Three.js ni de
 * render, solo cuenta.
 *
 * El lore es explícito en que las ventanas temporales NO son el centro del
 * diseño — "sirven solo para separar los elementos y darles un orden". Por
 * eso esto es deliberadamente mínimo: un contador que da la vuelta y una
 * fase normalizada. Nada de líneas de tiempo, keyframes ni eventos.
 * Sobre-construir el sistema de tiempo sería ir en contra del guion.
 */
export function crearReloj({ duracionSegundos, escala = 1 }) {
  let segundos = 0;
  let corriendo = true;
  let ultimoMs = null;

  function avanzar(ahoraMs = performance.now()) {
    if (ultimoMs === null) ultimoMs = ahoraMs;
    const delta = (ahoraMs - ultimoMs) / 1000;
    ultimoMs = ahoraMs;

    if (!corriendo || !duracionSegundos) return segundos;

    segundos = (segundos + delta * escala) % duracionSegundos;
    return segundos;
  }

  return {
    get segundos() { return segundos; },
    get duracion() { return duracionSegundos; },
    /** Posición dentro del bucle, de 0 a 1. Útil para dibujar el estado. */
    get fase() { return duracionSegundos ? segundos / duracionSegundos : 0; },
    get corriendo() { return corriendo; },
    avanzar,
    /** Saltar a un momento concreto — para inspeccionar el bucle a mano. */
    situar(nuevosSegundos) {
      if (!duracionSegundos) return;
      const d = duracionSegundos;
      segundos = ((nuevosSegundos % d) + d) % d;
    },
    alternarPausa() {
      corriendo = !corriendo;
      return corriendo;
    },
  };
}
