import * as THREE from 'three';
import { cargarNivel, validarNivel } from './mundo/index.js';
import { crearEscena } from './render/scene.js';
import { instalarEntorno } from './render/entorno.js';
import { crearPostproceso } from './render/postproceso.js';
import { construirNivel, crearBaliza, posicionDeCelda, TAM } from './render/nivel.js';
import { construirPersonaje, crearControladorPersonaje } from './render/personaje.js';
import { crearDirectorCamara } from './render/camera.js';
import { crearControles } from './render/controls.js';
import { crearPortada, animarPortada, crearSonido } from './render/revelacion.js';
import datosNivel from './mundo/nivel.json';
import theme from './theme/default.json';
import planos from './theme/planos.json';

const parametros = new URLSearchParams(window.location.search);
const themeActivo =
  parametros.get('postproceso') === 'off'
    ? { ...theme, postproceso: { ...theme.postproceso, activo: false } }
    : theme;

// --- Mundo ---------------------------------------------------------------
const nivel = cargarNivel(datosNivel);

// La alineación isométrica es exacta y frágil: mover una isla una celda
// puede abrir el puente en todas las rotaciones (y deja de ser acertijo) o
// cerrarlo en todas (y deja de tener solución). Las dos fallas son mudas.
const problemas = validarNivel(nivel);
if (problemas.length) console.warn('[enterrario] nivel roto:', problemas);

const canvas = document.createElement('canvas');
document.body.prepend(canvas);

const { scene, renderer, alRedimensionar } = crearEscena({ canvas, theme: themeActivo });
instalarEntorno({ renderer, scene, theme: themeActivo });

// El rig es el escenario que gira. La cámara NO se mueve: lo que rota es
// el mundo, como una peana. Es la diferencia entre mirar desde otro sitio
// y cambiar qué está conectado con qué.
//
// El `pivote` desplaza el nivel para que el eje de giro del rig caiga
// EXACTAMENTE sobre `nivel.centro`, que es el punto sobre el que
// mundo/proyeccion.js rota las celdas. Si los dos centros no coinciden, la
// matemática dice que dos celdas se alinean y la imagen muestra otra cosa
// — el fallo más difícil de diagnosticar posible, porque cada mitad del
// sistema está bien por separado.
const rig = new THREE.Group();
scene.add(rig);

const pivote = new THREE.Group();
pivote.position.set(-nivel.centro.x * TAM, 0, -nivel.centro.z * TAM);
rig.add(pivote);

pivote.add(construirNivel({ nivel, theme: themeActivo }));

const personaje = construirPersonaje({ theme: themeActivo });
pivote.add(personaje);

const controlador = crearControladorPersonaje({
  malla: personaje,
  nivel,
  theme: themeActivo,
});

// Balizas: algo tiene que decir "ahí hay algo" antes de llegar.
const balizas = new Map();
for (const revelacion of nivel.revelaciones) {
  const baliza = crearBaliza({ theme: themeActivo });
  const p = posicionDeCelda(revelacion.celda);
  baliza.position.set(p.x, p.y + TAM * 0.45, p.z);
  pivote.add(baliza);
  balizas.set(revelacion.id, baliza);
}

// --- Cámara --------------------------------------------------------------
/**
 * El encuadre sale del nivel, no de un número escrito a mano. Se usa la
 * ESFERA envolvente y no la caja porque el mundo gira: una caja daría un
 * encuadre distinto en cada rotación y la escena "respiraría" al girar,
 * que es justo el tipo de movimiento de cámara que rompe la lectura de las
 * alineaciones.
 */
function encuadreDelNivel() {
  // Posiciones ya desplazadas por el pivote, o sea tal como quedan en el
  // mundo. El eje de giro pasa por (0, ·, 0), así que medir el radio desde
  // un punto de ese eje lo vuelve invariante a la rotación.
  const puntos = nivel.bloques.map((bloque) =>
    posicionDeCelda(bloque).add(pivote.position)
  );

  const caja = new THREE.Box3();
  for (const punto of puntos) caja.expandByPoint(punto);
  const centro = new THREE.Vector3(0, caja.getCenter(new THREE.Vector3()).y, 0);

  let radio = 0;
  for (const punto of puntos) radio = Math.max(radio, punto.distanceTo(centro));

  return { centro, radio: Math.max(radio, TAM) };
}

const { centro: centroNivel, radio: radioNivel } = encuadreDelNivel();
const director = crearDirectorCamara({
  theme: themeActivo,
  planos,
  escena: scene,
  objetivoMecanico: centroNivel.toArray(),
  radioNivel,
});

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

// --- Revelación ----------------------------------------------------------
const sonido = crearSonido();
const descubiertas = new Set();
let revelacionEnCurso = null;

function lanzarRevelacion(revelacion) {
  descubiertas.add(revelacion.id);

  // `p` es LOCAL al pivote (el nivel gira dentro de él); la portada y la
  // baliza son hijas del pivote, así que colocarlas en local es correcto.
  // La CÁMARA, en cambio, es hija de `scene`, no del pivote — necesita el
  // punto en coordenadas de MUNDO. Pasarle el local directo apuntaba a un
  // punto a ~14 unidades del real, y la niebla (calibrada para la
  // distancia corta de la toma) se comía el objeto entero antes de que se
  // pudiera ver: exactamente el bug de niebla documentado en CLAUDE.md,
  // con una causa nueva.
  const p = posicionDeCelda(revelacion.celda);
  const pMundo = p.clone().applyMatrix4(pivote.matrixWorld);

  const portada = crearPortada({ obra: revelacion.obra, theme: themeActivo });
  portada.position.set(p.x, p.y + TAM * 1.5, p.z);
  portada.userData.baseY = portada.position.y;
  pivote.add(portada);

  balizas.get(revelacion.id)?.removeFromParent();

  const plano = director.revelar({
    plano: revelacion.plano,
    punto: [pMundo.x, pMundo.y + TAM * 0.6, pMundo.z],
  });

  revelacionEnCurso = {
    revelacion,
    portada,
    plano,
    fase: 'entrando',
    inicio: performance.now(),
  };

  pintarHud();
}

/**
 * La revelación es UN evento con fases, no cuatro sistemas sueltos:
 * la cámara viaja → aparece la portada y entra el sonido → se sostiene →
 * la cámara devuelve al jugador exactamente donde estaba.
 */
function actualizarRevelacion() {
  if (!revelacionEnCurso) return;
  const r = revelacionEnCurso;
  const transcurrido = performance.now() - r.inicio;

  if (r.fase === 'entrando' && !director.enTransicion) {
    r.fase = 'mostrando';
    r.inicio = performance.now();
    r.portada.visible = true;
    r.portadaInicio = performance.now();
    sonido.sonarHallazgo();
    pintarHud();
    return;
  }

  if (r.fase === 'mostrando') {
    animarPortada(r.portada, r.portadaInicio);
    r.portada.lookAt(director.camera.position);
    // Se sostiene lo justo para que la canción respire. Demasiado corto y
    // el hallazgo no descansa; demasiado largo y se vuelve peaje.
    if (transcurrido > 3200) {
      r.fase = 'volviendo';
      director.volverAMecanica();
      pintarHud();
    }
    return;
  }

  if (r.fase === 'volviendo') {
    r.portada.lookAt(director.camera.position);
    r.portada.material.opacity = Math.max(0, r.portada.material.opacity - 0.02);
    if (!director.enTransicion) {
      r.portada.removeFromParent();
      revelacionEnCurso = null;
      pintarHud();
    }
  }
}

// --- Entrada -------------------------------------------------------------
/**
 * Dos contadores para la misma rotación, y hacen falta los dos:
 *
 *  - `giroContinuo` NO da la vuelta. Es el que usa la animación, porque un
 *    contador que salta de 3 a 0 haría girar el mundo 270° hacia atrás en
 *    vez de 90° hacia delante. Ese giro largo destruye exactamente lo que
 *    el jugador está construyendo en la cabeza: hacia dónde se movió qué.
 *  - `rotacion` sí da la vuelta (0..3). Es el que usa la matemática de
 *    alineaciones, que solo entiende de cuatro estados.
 */
let giroContinuo = nivel.rotacionInicial;
let rotacion = nivel.rotacionInicial;
let ultimoPaso = null;

const anguloDeGiro = () => -giroContinuo * (Math.PI / 2);

function aplicarRotacion(delta) {
  if (revelacionEnCurso) return; // durante el hallazgo el mundo no se toca
  giroContinuo += delta;
  rotacion = ((giroContinuo % 4) + 4) % 4;
  controlador.fijarRotacion(rotacion);
  pintarHud();
}

function mover(direccion) {
  if (revelacionEnCurso) return;
  const resultado = controlador.mover(direccion);
  if (resultado.movido) {
    ultimoPaso = resultado.puenteImposible ? 'puente' : 'paso';
    const revelacion = nivel.revelacionEn(resultado.celda);
    if (revelacion && !descubiertas.has(revelacion.id)) lanzarRevelacion(revelacion);
  } else {
    ultimoPaso = resultado.motivo === 'vacio' ? 'bloqueado' : null;
  }
  pintarHud();
}

const controles = crearControles({
  canvas,
  alMover: mover,
  alRotar: aplicarRotacion,
  // El contexto de audio solo se puede crear tras un gesto del usuario.
  alGesto: () => sonido.despertar(),
});

// --- HUD -----------------------------------------------------------------
const hud = document.getElementById('hud');

function pintarHud() {
  if (revelacionEnCurso) {
    const o = revelacionEnCurso.revelacion.obra;
    hud.innerHTML =
      `<b>${o.titulo}</b><br>` +
      `<span style="opacity:.7">${o.lore}</span><br>` +
      `<span style="opacity:.45">${revelacionEnCurso.plano.cuenta}</span>`;
    return;
  }

  const pista = {
    puente: '↯ cruzaste por donde no había suelo',
    bloqueado: '· ahí no hay nada — prueba girando',
    paso: '',
  }[ultimoPaso] ?? '';

  hud.innerHTML =
    `▸ rotación ${rotacion + 1}/4 · hallazgos ${descubiertas.size}/${nivel.revelaciones.length}<br>` +
    `<span style="opacity:.75">${pista}</span><br>` +
    `<span style="opacity:.5">flechas o arrastra: mover · A/D o toca los bordes: girar el mundo</span>`;
}

pintarHud();

// --- Bucle ---------------------------------------------------------------
let rotacionSuave = anguloDeGiro();
let mezclaRegimen = 0;

function animar() {
  requestAnimationFrame(animar);

  // El giro del escenario se interpola: un salto instantáneo de 90° rompe
  // la lectura de qué se movió a dónde, y esa lectura es el juego. Usa
  // anguloDeGiro() (giroContinuo, sin dar la vuelta) y NO rotacion — un
  // contador que salta de 3 a 0 giraría el mundo 270° hacia atrás en vez
  // de 90° hacia delante.
  const destino = anguloDeGiro();
  rotacionSuave += (destino - rotacionSuave) * 0.16;
  rig.rotation.y = rotacionSuave;

  for (const baliza of balizas.values()) {
    baliza.rotation.y += 0.02;
    baliza.position.y += Math.sin(performance.now() * 0.003) * 0.004;
  }

  controlador.actualizar();
  actualizarRevelacion();
  director.actualizar();

  // La imagen acompaña al régimen: nítida mientras se juega, miniatura
  // fotografiada mientras se descubre. Se interpola en vez de conmutar
  // para que el cambio forme parte del mismo gesto de la cámara.
  const objetivoMezcla = director.regimen === 'revelacion' ? 1 : 0;
  mezclaRegimen += (objetivoMezcla - mezclaRegimen) * 0.05;
  postproceso?.ajustarRegimen(mezclaRegimen);

  if (postproceso) postproceso.render();
  else renderer.render(scene, director.camera);
}

animar();

/** Ventanilla de inspección desde la consola del navegador. */
window.enterrario = {
  nivel,
  problemas,
  celda: () => controlador.celda,
  rotacion: () => rotacion,
  /** Cuánto le falta al giro para asentarse. Sirve para no medir
   *  alineaciones a mitad de la animación. */
  girando: () => Math.abs(anguloDeGiro() - rotacionSuave) > 0.002,
  alcanzables: (r = rotacion) => nivel.navegacion.alcanzables(controlador.celda, r),
  enMovimiento: () => controlador.enMovimiento,
  debugEscena: () => ({
    fase: revelacionEnCurso?.fase ?? null,
    enTransicion: director.enTransicion,
    regimen: director.regimen,
    portadaVisible: revelacionEnCurso?.portada.visible ?? null,
    portadaOpacity: revelacionEnCurso?.portada.material.opacity ?? null,
    camPos: director.camera.position.toArray().map((v) => +v.toFixed(1)),
  }),
  debugPortada: () => {
    const p = revelacionEnCurso?.portada;
    if (!p) return null;
    const mundo = new THREE.Vector3();
    p.getWorldPosition(mundo);
    const enFrustum = mundo.clone().project(director.camera);
    return {
      posicionLocal: p.position.toArray().map((v) => +v.toFixed(2)),
      posicionMundo: mundo.toArray().map((v) => +v.toFixed(2)),
      ndc: enFrustum.toArray().map((v) => +v.toFixed(2)),
      dentroDeVista: Math.abs(enFrustum.x) <= 1 && Math.abs(enFrustum.y) <= 1 && enFrustum.z >= -1 && enFrustum.z <= 1,
      camNear: director.camera.near,
      camFar: director.camera.far,
      fogNear: scene.fog?.near,
      fogFar: scene.fog?.far,
      distanciaCamara: mundo.distanceTo(director.camera.position),
      materialOpacity: p.material.opacity,
      materialVisible: p.material.visible,
      objetoVisible: p.visible,
    };
  },
  /**
   * Posición REAL en pantalla de una celda. Sirve para comprobar que la
   * alineación que calcula mundo/proyeccion.js es la que el jugador ve de
   * verdad — que no es automático: un bug de interpolación de la rotación
   * hizo que estuvieran de acuerdo en los números pero en desacuerdo en la
   * pantalla, y esto fue lo que lo hizo visible.
   */
  proyectarEnPantalla(celda) {
    const v = posicionDeCelda(celda).applyMatrix4(pivote.matrixWorld);
    v.project(director.camera);
    return { x: (v.x + 1) / 2 * window.innerWidth, y: (1 - v.y) / 2 * window.innerHeight };
  },
  controles,
};
