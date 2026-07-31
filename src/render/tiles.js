import * as THREE from 'three';

export const TAMANO_CELDA = 1;
export const ALTO_BLOQUE = 0.5;

/**
 * Construye las mallas del diorama a partir de los datos del generador
 * y la paleta del theme activo. Esta es la ÚNICA función que traduce
 * "datos" a "colores/materiales" — si cambia la identidad visual, se
 * reescribe esta función (o se reemplaza por una que lea otro theme),
 * nunca el generador.
 */
export function construirDiorama({ diorama, theme }) {
  const grupo = new THREE.Group();
  const centrado = -(diorama.tamano * TAMANO_CELDA) / 2;
  const conSombras = theme.sombras?.activas !== false;

  const geometriaBloque = new THREE.BoxGeometry(TAMANO_CELDA, ALTO_BLOQUE, TAMANO_CELDA);
  const geometriaProp = new THREE.BoxGeometry(
    TAMANO_CELDA * 0.4,
    TAMANO_CELDA * 0.8,
    TAMANO_CELDA * 0.4
  );

  const materialAgua = new THREE.MeshStandardMaterial({ color: theme.paleta.agua });
  const materialesSuelo = theme.paleta.sueloPorAltura.map(
    (color) => new THREE.MeshStandardMaterial({ color })
  );
  const materialProp = new THREE.MeshStandardMaterial({ color: theme.paleta.prop });

  for (const celda of diorama.celdas) {
    const material = celda.tipo === 'agua' ? materialAgua : materialesSuelo[celda.altura];
    const bloque = new THREE.Mesh(geometriaBloque, material);
    // El suelo recibe sombra pero no la proyecta: proyectarla desde cada
    // bloque del terreno duplica el coste sin cambiar la imagen, porque los
    // bloques ya se ocultan entre sí por geometría.
    bloque.receiveShadow = conSombras;
    const y = (celda.altura || 0.3) * ALTO_BLOQUE; // el agua queda ligeramente hundida
    bloque.position.set(
      centrado + celda.x * TAMANO_CELDA,
      y,
      centrado + celda.z * TAMANO_CELDA
    );
    grupo.add(bloque);

    if (celda.tieneProp) {
      const prop = new THREE.Mesh(geometriaProp, materialProp);
      prop.castShadow = conSombras;
      prop.receiveShadow = conSombras;
      prop.position.set(bloque.position.x, y + ALTO_BLOQUE / 2 + 0.4, bloque.position.z);
      grupo.add(prop);
    }
  }

  return grupo;
}
