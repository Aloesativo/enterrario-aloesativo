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

  // Sombras proyectadas. Sin ellas los bloques flotan visualmente aunque
  // estén bien colocados: la sombra es lo que ancla un objeto al suelo.
  // PCFSoft porque el borde duro delata el shadow map y rompe la ilusión
  // de miniatura; el coste extra es despreciable a esta escala.
  const sombras = theme.sombras ?? {};
  if (sombras.activas !== false) {
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  }

  const luzAmbiental = new THREE.AmbientLight(theme.luz.ambiental);
  const luzDireccional = new THREE.DirectionalLight(
    theme.luz.direccional,
    theme.luz.intensidadDireccional
  );

  // La dirección de la luz principal es identidad visual (es la hora del
  // día del diorama), así que sale del theme. Antes estaba fija aquí, que
  // era una decisión de estilo escondida en la capa de traducción.
  const [lx, ly, lz] = theme.luz.posicion ?? [10, 20, 10];
  luzDireccional.position.set(lx, ly, lz);

  if (sombras.activas !== false) {
    luzDireccional.castShadow = true;
    // Resolución moderada a propósito: 2048 se nota en un teléfono y este
    // prototipo tiene que verse bien en el móvil de RR, no en una GPU.
    const resolucion = sombras.resolucion ?? 1024;
    luzDireccional.shadow.mapSize.set(resolucion, resolucion);

    // La cámara de sombra es ortográfica y hay que decirle qué volumen
    // cubre: si es muy chica recorta la sombra, si es muy grande desperdicia
    // resolución y la sombra sale pixelada. `alcance` debe cubrir el
    // diorama entero con algo de margen.
    const alcance = sombras.alcance ?? 14;
    const camaraSombra = luzDireccional.shadow.camera;
    camaraSombra.left = -alcance;
    camaraSombra.right = alcance;
    camaraSombra.top = alcance;
    camaraSombra.bottom = -alcance;
    camaraSombra.near = 0.5;
    camaraSombra.far = 60;
    camaraSombra.updateProjectionMatrix();

    // El bias corrige el "shadow acne" (rayado en las superficies
    // iluminadas). Demasiado bias despega la sombra del objeto.
    luzDireccional.shadow.bias = sombras.bias ?? -0.0006;
    luzDireccional.shadow.normalBias = sombras.biasNormal ?? 0.02;
  }

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

  return { scene, renderer, alRedimensionar, luzAmbiental, luzDireccional };
}
