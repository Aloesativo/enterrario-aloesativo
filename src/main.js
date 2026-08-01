import * as THREE from 'three';
import { generarDiorama } from './generator/grid.js';
import { crearEscena } from './render/scene.js';
import { construirDiorama } from './render/tiles.js';
import { construirMapa, crearMarcadorZona } from './render/mapa.js';
import { instalarEntorno } from './render/entorno.js';
import { crearPostproceso } from './render/postproceso.js';
import { cargarModelo } from './render/modelo.js';
import { crearDirectorCamara } from './render/camera.js';
import { crearControlesCamara } from './render/controls.js';
import { construirPersonaje, encontrarCeldaInicial, crearControladorPersonaje } from './render/personaje.js';
import { stringASemilla } from './generator/seed.js';
import { cargarGuion, validarGuion, MOTIVO } from './story/index.js';
import { crearReloj } from './story/reloj.js';
import guionBurdeo from './story/burdeo.json';
import theme from './theme/default.json';
import planos from './theme/planos.json';

const parametros = new URLSearchParams(window.location.search);
const semillaTexto = parametros.get('semilla') ?? 'enterrario';
const semilla = /^\d+$/.test(semillaTexto) ? Number(semillaTexto) : stringASemilla(semillaTexto);
const tamano = Number(parametros.get('tamano') ?? 12);

const themeActivo =
  parametros.get('postproceso') === 'off'
    ? { ...theme, postproceso: { ...theme.postproceso, activo: false } }
    : theme;

// El guion se valida al arrancar. Es una copia a mano del lore del repo
// hermano, así que el riesgo real es la errata silenciosa; mejor gritarla
// en consola que descubrirla como una zona muda.
const problemas = validarGuion(guionBurdeo);
if (problemas.length) console.warn('[enterrario] guion incoherente:', problemas);

const guion = cargarGuion(guionBurdeo);
const reloj = crearReloj({
  duracionSegundos: guionBurdeo.bucle.duracionSegundos,
  escala: Number(parametros.get('velocidad') ?? 1),
});

const canvas = document.createElement('canvas');
document.body.prepend(canvas);

const { scene, renderer, alRedimensionar } = crearEscena({ canvas, theme: themeActivo });
instalarEntorno({ renderer, scene, theme: themeActivo });

const diorama = generarDiorama({ semilla, tamano });

const rig = new THREE.Group();
scene.add(rig);

// La ciudad conserva el terreno procedural que ya existía: el mapa nuevo
// no sustituye lo anterior, lo enmarca. El resto de las zonas son
// plataformas greybox hasta que existan sus modelos.
const mapa = construirMapa({
  guion,
  mapaTheme: planos.mapa,
  theme: themeActivo,
  terrenos: { ciudad: construirDiorama({ diorama, theme: themeActivo }) },
});
rig.add(mapa.grupo);

const marcador = crearMarcadorZona({ theme: themeActivo });
rig.add(marcador);

const personaje = construirPersonaje({ theme: themeActivo });
mapa.nodoDeZona('ciudad')?.add(personaje);

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

// --- Recorrido por zonas -------------------------------------------------
// El verbo primario que pide el lore. El orden es el del guion, para que
// avanzar y retroceder sea predecible.
const zonasNavegables = guion.zonas.filter((z) => planos.mapa.zonas[z.id]);
let indiceZona = Math.max(
  0,
  zonasNavegables.findIndex((z) => z.id === planos.mapa.zonaInicial)
);

function zonaActual() {
  return zonasNavegables[indiceZona];
}

function irAZona(indice, duracion) {
  const total = zonasNavegables.length;
  indiceZona = ((indice % total) + total) % total;
  const zona = zonaActual();
  const encuadre = planos.mapa.zonas[zona.id];

  director.irAZona({ ...encuadre, nombre: zona.titulo }, duracion);

  const nodo = mapa.nodoDeZona(zona.id);
  if (nodo) {
    marcador.position.copy(nodo.position);
    marcador.scale.setScalar(Math.max(1, (encuadre.tamano ?? 6) * 0.62));
    marcador.visible = true;
  }
  return { zona };
}

// --- HUD -----------------------------------------------------------------
// Mientras no haya audio, el HUD ES la demostración de la mecánica: hace
// legible la regla del lore —qué suena depende de dónde y de cuándo— sin
// necesidad de un solo archivo de sonido.
const hud = document.getElementById('hud');

const TEXTO_MOTIVO = {
  [MOTIVO.SUENA]: '♪',
  [MOTIVO.FUERA_DE_VENTANA]: '— silencio: aquí hay canción, pero no es su momento',
  [MOTIVO.SIN_VENTANA]: '— sin ventana asignada todavía (falta en el lore)',
  [MOTIVO.ZONA_SIN_CANCIONES]: '— zona sin canción asignada',
  [MOTIVO.BUCLE_SIN_DEFINIR]: '— bucle sin definir',
};

function pintarHud() {
  const zona = zonaActual();
  const resultado = guion.queSuena({ zonaId: zona.id, segundos: reloj.segundos });

  const reloj_ = reloj.duracion
    ? `${reloj.segundos.toFixed(0).padStart(3)}s / ${reloj.duracion}s${reloj.corriendo ? '' : ' ⏸'}`
    : 'sin bucle';

  const sonando = resultado.tematicas.length
    ? resultado.tematicas.map((c) => `♪ ${c.titulo}`).join(' · ')
    : TEXTO_MOTIVO[resultado.motivo] ?? '';

  const instrumental = resultado.instrumentales.length
    ? `<br>∞ ${resultado.instrumentales.map((t) => t.titulo).join(' · ')}`
    : '';

  hud.innerHTML =
    `▸ ${zona.titulo} <span style="opacity:.6">(${zona.escala})</span> · ${reloj_}<br>` +
    `${sonando}${instrumental}<br>` +
    `<span style="opacity:.6">← → zonas · A/D/W/S orbitan · ↑↓ mueven al personaje · ` +
    `espacio pausa el reloj · R vuelve al inicio</span>`;
}

const controlesCamara = crearControlesCamara({
  canvas,
  director,
  alCambiarPlano: pintarHud,
  alZona: (delta) => { irAZona(indiceZona + delta); pintarHud(); },
  alReiniciar: () => { irAZona(0, 900); pintarHud(); },
  alPausarReloj: () => { reloj.alternarPausa(); pintarHud(); },
});

const controlesPersonaje = crearControladorPersonaje({
  mesh: personaje,
  diorama,
  celdaInicial: encontrarCeldaInicial(diorama),
  director,
});

irAZona(indiceZona, 0);
pintarHud();

async function montarModeloOpcional() {
  const archivo = parametros.get('modelo') ?? themeActivo.modelo?.archivo;
  if (!archivo) return;

  const modelo = await cargarModelo({
    url: `${import.meta.env.BASE_URL}${archivo}`,
    theme: themeActivo,
  });
  if (modelo) mapa.nodoDeZona(zonaActual().id)?.add(modelo);
}

function animar() {
  requestAnimationFrame(animar);

  reloj.avanzar();
  controlesCamara.actualizar();
  controlesPersonaje.actualizar();
  director.actualizar();

  if (postproceso) postproceso.render();
  else renderer.render(scene, director.camera);
}

animar();
pintarHud();
setInterval(pintarHud, 250); // el reloj corre solo; el HUD lo refleja
montarModeloOpcional();

/**
 * Ventanilla de inspección desde la consola del navegador. Existe porque
 * verificar el bucle temporal "en vivo" obliga a esperar minutos para ver
 * qué pasa en cada ventana, y porque no hay flujo de desarrollo local: la
 * consola del móvil o del navegador es la única herramienta disponible.
 *
 *   enterrario.situar(90)   → salta al segundo 90 del bucle
 *   enterrario.zona('luna') → viaja a una zona por id
 *   enterrario.queSuena()   → qué sonaría aquí y ahora, y por qué
 */
window.enterrario = {
  guion,
  reloj,
  situar(segundos) { reloj.situar(segundos); pintarHud(); return reloj.segundos; },
  zona(id) {
    const indice = zonasNavegables.findIndex((z) => z.id === id);
    if (indice < 0) return `zona desconocida: ${id}`;
    irAZona(indice);
    pintarHud();
    return zonaActual().titulo;
  },
  queSuena() {
    return guion.queSuena({ zonaId: zonaActual().id, segundos: reloj.segundos });
  },
};
