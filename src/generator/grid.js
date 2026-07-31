import { crearRng } from './seed.js';

// Núcleo procedural: no sabe nada de Three.js, colores ni materiales.
// Genera solo DATOS — una grilla de celdas — para que la capa de render
// y la capa de identidad visual (theme/) se puedan reemplazar sin tocar
// esta lógica. Ver README para la explicación de las tres capas.

/**
 * @typedef {Object} Celda
 * @property {number} x
 * @property {number} z
 * @property {number} altura   - entero 0..N, altura del bloque de "suelo"
 * @property {"suelo"|"agua"} tipo
 * @property {boolean} tieneProp - si hay un elemento vertical encima (prototipo: cubo simple)
 */

export function generarDiorama({ semilla, tamano = 12, densidadProps = 0.08 }) {
  const rng = crearRng(semilla);

  // Fases fijas por semilla, para que el "ruido" sea determinista y no
  // dependa del orden de llamadas a rng() durante el recorrido de la grilla.
  const faseX = rng() * Math.PI * 2;
  const faseZ = rng() * Math.PI * 2;
  const octava2 = rng() * Math.PI * 2;

  const alturaEn = (x, z) => {
    const base =
      Math.sin(x * 0.35 + faseX) * Math.cos(z * 0.35 + faseZ) +
      0.5 * Math.sin((x + z) * 0.2 + octava2);
    // normaliza [-1.5, 1.5] a un entero 0..3
    const norm = (base + 1.5) / 3;
    return Math.max(0, Math.min(3, Math.round(norm * 3)));
  };

  /** @type {Celda[]} */
  const celdas = [];
  for (let x = 0; x < tamano; x++) {
    for (let z = 0; z < tamano; z++) {
      const altura = alturaEn(x, z);
      const tipo = altura === 0 ? 'agua' : 'suelo';
      const tieneProp = tipo === 'suelo' && rng() < densidadProps;
      celdas.push({ x, z, altura, tipo, tieneProp });
    }
  }

  return { semilla, tamano, celdas };
}
