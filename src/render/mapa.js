import * as THREE from 'three';

/**
 * Traduce el guion (`story/`) a geometría: una zona del mapa = un lugar
 * físico al que la cámara puede viajar.
 *
 * Reparto de responsabilidades, para no romper la regla de las tres capas:
 *   - `story/burdeo.json`  dice QUÉ zonas existen y qué suena en cada una.
 *   - `theme/planos.json`  dice DÓNDE está cada una y cómo se encuadra.
 *   - este módulo           junta ambas y hace mallas. No decide nada.
 *
 * Los volúmenes son greybox deliberado: cajas de proporción distinta según
 * la escala declarada. No son propuestas de diseño — son marcadores para
 * poder validar que el RECORRIDO funciona antes de modelar nada. Cuando
 * exista el .glb autorado, esto se reemplaza zona por zona.
 */
export function construirMapa({ guion, mapaTheme, theme, terrenos = {} }) {
  const grupo = new THREE.Group();
  const porZona = new Map();

  const colorDe = (nombreColor) =>
    theme.paleta.nombresDeColor?.[nombreColor] ?? theme.paleta.zonaSinColor;

  for (const zona of guion.zonas) {
    const encuadre = mapaTheme.zonas[zona.id];
    if (!encuadre) continue;

    const nodo = new THREE.Group();
    const [x, y, z] = encuadre.objetivo;
    nodo.position.set(x, y, z);

    // Una zona puede traer su propio terreno ya construido (hoy: la ciudad
    // usa el diorama procedural que ya existía). Si no, se le da una
    // plataforma greybox del tamaño de su escala.
    const terreno = terrenos[zona.id];
    if (terreno) {
      nodo.add(terreno);
    } else {
      nodo.add(crearPlataforma(encuadre.tamano, colorDe(zona.color), theme));
    }

    grupo.add(nodo);
    porZona.set(zona.id, nodo);
  }

  return {
    grupo,
    nodoDeZona: (id) => porZona.get(id) ?? null,
    /** Posición mundial de una zona, para que la cámara sepa a dónde ir. */
    posicionDeZona(id) {
      const nodo = porZona.get(id);
      return nodo ? nodo.position.clone() : null;
    },
  };
}

/**
 * Plataforma marcadora. Delgada respecto de su ancho para que se lea como
 * "un lugar" y no como "un bloque": desde la cámara isométrica, un cubo
 * compite con el terreno y una losa se lee como suelo.
 */
function crearPlataforma(tamano, color, theme) {
  const alto = Math.max(0.3, tamano * 0.06);
  const geometria = new THREE.BoxGeometry(tamano, alto, tamano);
  const material = new THREE.MeshStandardMaterial({ color });
  const malla = new THREE.Mesh(geometria, material);

  malla.position.y = -alto / 2;
  const conSombras = theme.sombras?.activas !== false;
  malla.castShadow = conSombras;
  malla.receiveShadow = conSombras;

  return malla;
}

/**
 * Marcador de la zona activa: un anillo que se posa sobre la zona que se
 * está mirando. Existe porque en un mapa de once zonas a escalas muy
 * distintas, sin una señal explícita se pierde la noción de dónde estás —
 * y "dónde estás" es la mitad de la mecánica del lore (la otra mitad es
 * "cuándo").
 */
export function crearMarcadorZona({ theme }) {
  const geometria = new THREE.TorusGeometry(1, 0.06, 8, 48);
  const material = new THREE.MeshBasicMaterial({
    color: theme.paleta.marcadorZona,
    transparent: true,
    opacity: 0.85,
  });
  const anillo = new THREE.Mesh(geometria, material);
  anillo.rotation.x = -Math.PI / 2;
  anillo.visible = false;
  return anillo;
}
