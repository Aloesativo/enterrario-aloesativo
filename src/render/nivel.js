import * as THREE from 'three';

/**
 * Tamaño de celda y de escalón de altura.
 *
 * TIENEN QUE SER IGUALES. No es una elección estética: la matemática de
 * `mundo/proyeccion.js` asume que subir un escalón desplaza en pantalla lo
 * mismo que avanzar una celda en x y otra en z. Si se separan, las
 * alineaciones que el código calcula dejan de coincidir con lo que el
 * jugador ve, y los puentes aparecen donde no se ven y no aparecen donde
 * sí. Es el fallo más difícil de diagnosticar de todo el artefacto.
 */
export const TAM = 2;
export const ALTO = 2;

/** Posición en el mundo del centro de la cara superior de una celda. */
export function posicionDeCelda({ x, y, z }) {
  return new THREE.Vector3(x * TAM, y * ALTO, z * TAM);
}

/**
 * Construye las islas. Losas delgadas en vez de cubos a propósito: un cubo
 * alto tapa lo que hay detrás, y aquí ver lo que hay detrás ES el juego.
 */
export function construirNivel({ nivel, theme }) {
  const grupo = new THREE.Group();
  const conSombras = theme.sombras?.activas !== false;
  const grosor = TAM * 0.3;

  const geometria = new THREE.BoxGeometry(TAM * 0.94, grosor, TAM * 0.94);

  const materiales = new Map();
  const materialDe = (nombreColor) => {
    if (!materiales.has(nombreColor)) {
      materiales.set(
        nombreColor,
        new THREE.MeshStandardMaterial({
          color: theme.paleta.nombresDeColor?.[nombreColor] ?? theme.paleta.zonaSinColor,
          roughness: 0.85,
        })
      );
    }
    return materiales.get(nombreColor);
  };

  for (const bloque of nivel.bloques) {
    const malla = new THREE.Mesh(geometria, materialDe(bloque.color));
    const p = posicionDeCelda(bloque);
    malla.position.set(p.x, p.y - grosor / 2, p.z);
    malla.castShadow = conSombras;
    malla.receiveShadow = conSombras;
    grupo.add(malla);
  }

  return grupo;
}

/**
 * Marca la celda de una revelación antes de descubrirla: algo tiene que
 * decirle al jugador "ahí hay algo" para que ir hasta allá sea una
 * decisión y no un accidente. Sin esto, el hallazgo se encuentra por
 * tropiezo, y tropezar no es descubrir.
 */
export function crearBaliza({ theme }) {
  const geometria = new THREE.OctahedronGeometry(TAM * 0.22);
  const material = new THREE.MeshStandardMaterial({
    color: theme.paleta.baliza,
    emissive: theme.paleta.baliza,
    emissiveIntensity: 0.6,
    roughness: 0.4,
  });
  const malla = new THREE.Mesh(geometria, material);
  malla.castShadow = theme.sombras?.activas !== false;
  return malla;
}
