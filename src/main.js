import * as THREE from 'three';
import { generarDiorama } from './generator/grid.js';
import { crearEscena } from './render/scene.js';
import { construirDiorama } from './render/tiles.js';
import { crearDirectorCamara } from './render/camera.js';
import { crearControlesCamara } from './render/controls.js';
import { construirPersonaje, encontrarCeldaInicial, crearControladorPersonaje } from './render/personaje.js';
import { stringASemilla } from './generator/seed.js';
import theme from './theme/default.json';
import planos from './theme/planos.json';

const parametros = new URLSearchParams(window.location.search);
const semillaTexto = parametros.get('semilla') ?? 'enterrario';
const semilla = /^\d+$/.test(semillaTexto) ? Number(semillaTexto) : stringASemilla(semillaTexto);
const tamano = Number(parametros.get('tamano') ?? 12);

const canvas = document.createElement('canvas');
document.body.prepend(canvas);

const { scene, renderer, alRedimensionar } = crearEscena({ canvas, theme });

const diorama = generarDiorama({ semilla, tamano });
const grupoDiorama = construirDiorama({ diorama, theme });

// El rig contiene el diorama y el personaje. En el esquema anterior era lo
// que rotaba con cada cambio de vista; ahora se queda quieto casi siempre
// —la que se mueve es la cámara— y solo gira cuando un plano declara un
// "volteo", que es la parte híbrida: el momento en que el terrario mismo se
// da vuelta en vez de que la cámara lo rodee.
const rig = new THREE.Group();
rig.add(grupoDiorama);
scene.add(rig);

const personaje = construirPersonaje({ theme });
rig.add(personaje);

const director = crearDirectorCamara({ theme, planos, escena: scene });
director.vincularPersonaje(personaje);
director.vincularRig(rig);
alRedimensionar((ancho, alto) => director.ajustarAspecto(ancho, alto));

const hud = document.getElementById('hud');

function describirPlano(resultado) {
  const plano = resultado?.plano;
  const cabecera = `semilla: ${semillaTexto} · tamaño: ${tamano}`;
  const ayuda =
    'A/D giran · W/S suben y bajan · flechas mueven al personaje · ' +
    'arrastra u orbita con el stick · R vuelve al plano base';
  const linea = plano
    ? `▸ ${plano.nombre} — ${plano.cuenta}`
    : '▸ encuadre libre (entre planos)';
  hud.innerHTML = `${cabecera}<br>${linea}<br>${ayuda}`;
}

const controlesCamara = crearControlesCamara({
  canvas,
  director,
  alCambiarPlano: describirPlano,
});
const controlesPersonaje = crearControladorPersonaje({
  mesh: personaje,
  diorama,
  celdaInicial: encontrarCeldaInicial(diorama),
  director,
});

describirPlano({ plano: director.planoActual });

function animar() {
  requestAnimationFrame(animar);
  controlesCamara.actualizar();
  controlesPersonaje.actualizar();
  director.actualizar();
  renderer.render(scene, director.camera);
}
animar();
