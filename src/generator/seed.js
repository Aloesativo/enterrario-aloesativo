// PRNG determinista (mulberry32). Misma semilla => siempre el mismo diorama.
// Se usa en vez de Math.random() en todo el generador para que el prototipo
// sea reproducible: útil para comparar cambios en las reglas de generación
// sin que el ruido de aleatoriedad distinta tape la diferencia real.
export function crearRng(semilla) {
  let a = semilla >>> 0;
  return function rng() {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function stringASemilla(texto) {
  let h = 1779033703 ^ texto.length;
  for (let i = 0; i < texto.length; i++) {
    h = Math.imul(h ^ texto.charCodeAt(i), 3432918353);
    h = (h << 13) | (h >>> 19);
  }
  return h >>> 0;
}
