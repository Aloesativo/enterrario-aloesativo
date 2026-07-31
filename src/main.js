import * as THREE from 'three';
import { generarDiorama } from './generator/grid.js';
import { crearEscena } from './render/scene.js';
import { construirDiorama } from './render/tiles.js';
import { instalarEntorno } from './render/entorno.js';
import { crearPostproceso } from './render/postproceso.js';
import { cargarModelo } from './render/modelo.js';
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

// Permite comparar el antes/después de la cadena de postproceso sin editar
// el theme ni recompilar: ?postproceso=off. Es la forma barata de ver qué
// está aportando realmente cada efecto.
const themeActivo =
  parametros.get('postproceso') === 'off'
    ? { ...theme, postproceso: { ...theme.postproceso, activo: false } }
    : theme;

const canvas = document.createElement('canvas');
document.body.prepend(canvas);

const { scene, renderer, alRedimensionar } = crearEscena({ canvas, theme: themeActivo });

// El entorno se instala antes que nada porque además del IBL configura el
// tone mapping del renderer, que afecta a cómo se ve TODO lo demás.
instalarEntorno({ renderer, scene, theme: themeActivo });

// La grilla de datos se genera siempre, incluso cuando el diorama visible
// viene de un .glb: el personaje se mueve por celdas, y esas reglas
// (bordes, agua) viven en los datos, no en las mallas.
const diorama = generarDiorama({ semilla, tamano });

const rig = new THREE.Group();
scene.add(rig);

const personaje = construirPersonaje({ theme: themeActivo });
rig.add(personaje);

const director = crearDirectorCamara({ theme: themeActivo, planos, escena: scene });
director.vincularPersonaje(personaje);
director.vincularRig(rig);

const postproceso = crearPostproceso({
  renderer,
  scene,
  camera: director.camera,
  theme: themeActivo,
});

alRedimensionar((ancho, alto) => {
  director.ajustarAspecto(ancho, alto);
  postproceso?.ajustarTamano(ancho, alto);
});

const hud = document.getElementById('hud');
let origenDelDiorama = 'procedural';

function describirPlano(resultado) {
  const plano = resultado?.plano;
  const cabecera = `semilla: ${semillaTexto} · tamaño: ${tamano} · ${origenDelDiorama}`;
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

/**
 * Decide qué diorama se ve: el modelo autorado si existe, el greybox
 * procedural si no. Es asíncrono, así que el bucle de render ya está
 * corriendo cuando esto resuelve — se ve el greybox y el modelo lo
 * reemplaza al llegar. Preferible a una pantalla en negro esperando.
 */
async function montarDiorama() {
  const archivo = parametros.get('modelo') ?? themeActivo.modelo?.archivo;
  const url = archivo ? `${import.meta.env.BASE_URL}${archivo}` : null;

  const modelo = await cargarModelo({ url, theme: themeActivo });

  if (modelo) {
    rig.add(modelo);
    origenDelDiorama = `modelo: ${archivo}`;
  } else {
    rig.add(construirDiorama({ diorama, theme: themeActivo }));
    origenDelDiorama = 'procedural';
  }
  describirPlano({ plano: director.planoActual });
}

function animar() {
  requestAnimationFrame(animar);
  controlesCamara.actualizar();
  controlesPersonaje.actualizar();
  director.actualizar();

  // Si la cadena de postproceso está apagada (o no se pudo crear), se cae
  // al render directo. Un fallo de postproceso no puede dejar la pantalla
  // en negro: el prototipo tiene que verse siempre.
  if (postproceso) postproceso.render();
  else renderer.render(scene, director.camera);
}

animar();
montarDiorama();
