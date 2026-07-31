import * as THREE from 'three';
import { generarDiorama } from './generator/grid.js';
import { crearEscena } from './render/scene.js';
import { construirDiorama } from './render/tiles.js';
import { crearControlesEscenario } from './render/controls.js';
import { construirPersonaje, encontrarCeldaInicial, crearControladorPersonaje } from './render/personaje.js';
import { stringASemilla } from './generator/seed.js';
import theme from './theme/default.json';

const parametros = new URLSearchParams(window.location.search);
const semillaTexto = parametros.get('semilla') ?? 'enterrario';
const semilla = /^\d+$/.test(semillaTexto) ? Number(semillaTexto) : stringASemilla(semillaTexto);
const tamano = Number(parametros.get('tamano') ?? 12);

const canvas = document.createElement('canvas');
document.body.prepend(canvas);

const { scene, camera, renderer } = crearEscena({ canvas, theme });

const diorama = generarDiorama({ semilla, tamano });
const grupoDiorama = construirDiorama({ diorama, theme });

// El diorama y el personaje viven dentro de un "rig" rotable: los
// controles de escenario giran este grupo entero (no la cámara), como un
// terrario tipo rubik. El personaje se mueve en el espacio local del rig,
// así que su movimiento no depende de en qué etapa de giro esté la vista.
const rig = new THREE.Group();
rig.add(grupoDiorama);
scene.add(rig);

const personaje = construirPersonaje({ theme });
rig.add(personaje);

const controlesEscenario = crearControlesEscenario({ camera, canvas, objetivo: rig });
const controlesPersonaje = crearControladorPersonaje({
  mesh: personaje,
  diorama,
  celdaInicial: encontrarCeldaInicial(diorama),
});

document.getElementById('hud').textContent =
  `semilla: ${semillaTexto} (${semilla}) · tamaño: ${tamano} · ?semilla=X para probar otra · ` +
  'WASD gira el escenario por etapas · flechas mueven al personaje · ' +
  'arrastra / 2 dedos / gamepad para rotación libre · doble tap para resetear';

function animar() {
  requestAnimationFrame(animar);
  controlesEscenario.actualizar();
  controlesPersonaje.actualizar();
  renderer.render(scene, camera);
}
animar();
