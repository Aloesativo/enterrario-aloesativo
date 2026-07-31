import * as THREE from 'three';

/**
 * Monta escena, luces y renderer. La cámara ya NO se crea aquí: vive en
 * camera.js, porque dejó de ser un objeto fijo (una isométrica quieta) para
 * pasar a ser un director con estado propio, planos y transiciones.
 *
 * Lo que queda aquí es lo que no depende del punto de vista: fondo, niebla
 * y luces. Los valores de niebla se recalculan por frame en camera.js a
 * partir de la distancia real de la cámara — aquí solo se instala con
 * valores iniciales cualesquiera.
 */
export function crearEscena({ canvas, theme }) {
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(theme.fondo);
  scene.fog = new THREE.Fog(theme.niebla.color, 1, 100);

  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

  const luzAmbiental = new THREE.AmbientLight(theme.luz.ambiental);
  const luzDireccional = new THREE.DirectionalLight(
    theme.luz.direccional,
    theme.luz.intensidadDireccional
  );
  luzDireccional.position.set(10, 20, 10);
  scene.add(luzAmbiental, luzDireccional);

  const suscriptores = [];

  function ajustarTamano() {
    const ancho = window.innerWidth;
    const alto = window.innerHeight;
    renderer.setSize(ancho, alto);
    for (const suscriptor of suscriptores) suscriptor(ancho, alto);
  }

  window.addEventListener('resize', ajustarTamano);
  window.addEventListener('orientationchange', ajustarTamano);

  /**
   * Permite que el director de cámara (u otros) reaccionen al tamaño real
   * de la ventana. Se llama de inmediato al suscribirse para que el estado
   * inicial sea correcto tanto en retrato como en apaisado.
   */
  function alRedimensionar(suscriptor) {
    suscriptores.push(suscriptor);
    suscriptor(window.innerWidth, window.innerHeight);
  }

  ajustarTamano();

  return { scene, renderer, alRedimensionar };
}
