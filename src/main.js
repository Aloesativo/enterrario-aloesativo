import { generarDiorama } from './generator/grid.js';
import { crearEscena } from './render/scene.js';
import { construirDiorama } from './render/tiles.js';
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
scene.add(grupoDiorama);

document.getElementById('hud').textContent =
  `semilla: ${semillaTexto} (${semilla}) · tamaño: ${tamano} · ?semilla=X para probar otra`;

function animar() {
  requestAnimationFrame(animar);
  renderer.render(scene, camera);
}
animar();
