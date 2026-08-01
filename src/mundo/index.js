import { crearNavegacion } from './navegacion.js';

/**
 * Carga el nivel: expande las áreas a celdas y arma la navegación.
 * Datos puros — no sabe de Three.js.
 */
export function cargarNivel(datos) {
  const bloques = [];
  for (const area of datos.areas) {
    for (let x = area.x0; x <= area.x1; x++) {
      for (let z = area.z0; z <= area.z1; z++) {
        bloques.push({ x, y: area.y, z, area: area.id, color: area.color });
      }
    }
  }

  const nivel = { ...datos, bloques };
  const navegacion = crearNavegacion(nivel);

  const revelacionEn = (celda) =>
    datos.revelaciones.find(
      (r) => r.celda.x === celda.x && r.celda.y === celda.y && r.celda.z === celda.z
    ) ?? null;

  return { ...nivel, navegacion, revelacionEn };
}

/**
 * Comprueba que el nivel sigue siendo jugable: que exista al menos una
 * rotación desde la que se llega a cada revelación, y que NO se llegue
 * desde la rotación inicial.
 *
 * Existe porque la alineación isométrica es exacta y frágil: mover una
 * isla una sola celda puede abrir el puente en todas las rotaciones (y el
 * nivel deja de ser un acertijo) o cerrarlo en todas (y deja de tener
 * solución). Las dos fallas son silenciosas si no se comprueban.
 */
export function validarNivel(nivel) {
  const problemas = [];
  const clave = (c) => `${c.x},${c.y},${c.z}`;

  for (const revelacion of nivel.revelaciones) {
    const rotacionesQueLlegan = [];
    for (let r = 0; r < 4; r++) {
      const alcanzables = nivel.navegacion.alcanzables(nivel.partida, r);
      if (alcanzables.has(clave(revelacion.celda))) rotacionesQueLlegan.push(r);
    }

    if (rotacionesQueLlegan.length === 0) {
      problemas.push(`la revelación "${revelacion.id}" es inalcanzable desde cualquier rotación`);
    }
    if (rotacionesQueLlegan.includes(nivel.rotacionInicial)) {
      problemas.push(
        `la revelación "${revelacion.id}" se alcanza sin rotar: no hay acertijo`
      );
    }
    if (rotacionesQueLlegan.length === 4) {
      problemas.push(`la revelación "${revelacion.id}" se alcanza desde todas las rotaciones`);
    }
  }

  return problemas;
}
