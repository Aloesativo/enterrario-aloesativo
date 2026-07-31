import * as THREE from 'three';

// Ángulo isométrico clásico: 45° en Y, ~35.264° de inclinación
// (arctan(1/√2), el ángulo que hace que un cubo se vea con sus tres caras
// visibles en proporciones iguales).
const INCLINACION = Math.atan(1 / Math.sqrt(2));

export function crearEscena({ canvas, theme }) {
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(theme.fondo);
  scene.fog = new THREE.Fog(theme.niebla.color, theme.niebla.cerca, theme.niebla.lejos);

  const camera = crearCamaraIsometrica();

  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

  const luzAmbiental = new THREE.AmbientLight(theme.luz.ambiental);
  const luzDireccional = new THREE.DirectionalLight(
    theme.luz.direccional,
    theme.luz.intensidadDireccional
  );
  luzDireccional.position.set(10, 20, 10);
  scene.add(luzAmbiental, luzDireccional);

  function ajustarTamano() {
    const ancho = window.innerWidth;
    const alto = window.innerHeight;
    renderer.setSize(ancho, alto);
    const aspecto = ancho / alto;
    const frustumAltura = camera.userData.frustumAltura;
    camera.left = (-frustumAltura * aspecto) / 2;
    camera.right = (frustumAltura * aspecto) / 2;
    camera.top = frustumAltura / 2;
    camera.bottom = -frustumAltura / 2;
    camera.updateProjectionMatrix();
  }
  window.addEventListener('resize', ajustarTamano);
  ajustarTamano();

  return { scene, camera, renderer };
}

function crearCamaraIsometrica(frustumAltura = 20, distancia = 50) {
  const camera = new THREE.OrthographicCamera(-10, 10, 10, -10, 0.1, 200);
  camera.userData.frustumAltura = frustumAltura;

  // Posiciona la cámara sobre la diagonal del cubo unitario y la apunta
  // al origen: eso da la vista isométrica sin tener que rotar la escena.
  const y = distancia * Math.sin(INCLINACION);
  const radioHorizontal = distancia * Math.cos(INCLINACION);
  camera.position.set(
    radioHorizontal * Math.cos(Math.PI / 4),
    y,
    radioHorizontal * Math.sin(Math.PI / 4)
  );
  camera.lookAt(0, 0, 0);
  return camera;
}
