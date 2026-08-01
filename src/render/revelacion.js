import * as THREE from 'three';
import { TAM } from './nivel.js';

/**
 * El hallazgo: portada + sonido.
 *
 * Una revelación NO son cuatro sistemas coordinándose (cámara, portada,
 * audio, HUD). Es UN evento compuesto con un solo latido: la cámara se
 * suelta, el punto de vista se resuelve, aparece la portada, entra el
 * sonido. Por eso todo esto vive junto y se dispara desde un solo sitio.
 */

/**
 * Portada placeholder generada en canvas. Cuando existan las portadas
 * reales de RR se cambia por una textura cargada — la geometría, la
 * animación de aparición y el emplazamiento ya son los definitivos.
 */
export function crearPortada({ obra, theme }) {
  const lado = 512;
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = lado;
  const ctx = canvas.getContext('2d');

  const color = theme.paleta.nombresDeColor?.[obra.color] ?? theme.paleta.zonaSinColor;
  ctx.fillStyle = color;
  ctx.fillRect(0, 0, lado, lado);

  ctx.strokeStyle = 'rgba(255,255,255,0.5)';
  ctx.lineWidth = 6;
  ctx.strokeRect(24, 24, lado - 48, lado - 48);

  ctx.fillStyle = 'rgba(255,255,255,0.92)';
  ctx.font = '600 46px system-ui, sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText(obra.titulo, lado / 2, lado / 2 - 8);

  ctx.font = '300 22px system-ui, sans-serif';
  ctx.fillStyle = 'rgba(255,255,255,0.55)';
  ctx.fillText('portada placeholder', lado / 2, lado / 2 + 34);

  const textura = new THREE.CanvasTexture(canvas);
  textura.colorSpace = THREE.SRGBColorSpace;

  const geometria = new THREE.PlaneGeometry(TAM * 2.2, TAM * 2.2);
  const material = new THREE.MeshBasicMaterial({
    map: textura,
    transparent: true,
    opacity: 0,
    // Se dibuja por encima de todo: la portada es el premio, no un objeto
    // del mundo que pueda quedar tapado por una losa.
    depthTest: false,
  });

  const malla = new THREE.Mesh(geometria, material);
  malla.renderOrder = 10;
  malla.visible = false;
  return malla;
}

/**
 * Aparición de la portada: sube un poco y se funde. Se llama cada frame
 * mientras dura. Devuelve true cuando terminó.
 */
export function animarPortada(portada, inicio, duracion = 900) {
  const t = Math.min((performance.now() - inicio) / duracion, 1);
  const s = 1 - Math.pow(1 - t, 3);
  portada.material.opacity = s;
  portada.position.y = portada.userData.baseY + (1 - s) * -0.6;
  return t >= 1;
}

/**
 * Acorde sintetizado. Es un PLACEHOLDER descarado: cuando existan los
 * .opus de RR, este módulo carga y reproduce el archivo de la obra.
 *
 * Existe igual porque sin ningún sonido no se puede evaluar si el latido
 * del hallazgo funciona — y evaluar eso es el objetivo entero de esta
 * primera rebanada. Un hallazgo mudo se siente roto aunque el diseño esté
 * bien.
 *
 * Nota de navegador: el contexto de audio se crea al primer gesto del
 * usuario, no antes. Todos los navegadores bloquean el audio sin
 * interacción previa, así que crearlo al cargar daría un contexto
 * suspendido y silencio en el primer hallazgo.
 */
export function crearSonido() {
  let contexto = null;

  function asegurarContexto() {
    if (!contexto) {
      const AudioCtx = window.AudioContext ?? window.webkitAudioContext;
      if (!AudioCtx) return null;
      contexto = new AudioCtx();
    }
    if (contexto.state === 'suspended') contexto.resume();
    return contexto;
  }

  function sonarHallazgo() {
    const ctx = asegurarContexto();
    if (!ctx) return;

    const ahora = ctx.currentTime;
    const maestro = ctx.createGain();
    maestro.gain.value = 0.0001;
    maestro.connect(ctx.destination);

    // Envolvente larga y suave: el hallazgo es un descanso, no un premio
    // de arcade. Un ataque corto sonaría a "conseguiste una moneda".
    maestro.gain.exponentialRampToValueAtTime(0.16, ahora + 0.7);
    maestro.gain.exponentialRampToValueAtTime(0.0001, ahora + 4.5);

    for (const [i, frecuencia] of [220, 277.18, 329.63, 440].entries()) {
      const osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.value = frecuencia;
      const voz = ctx.createGain();
      voz.gain.value = 0.25 / (i + 1);
      osc.connect(voz).connect(maestro);
      osc.start(ahora + i * 0.09);
      osc.stop(ahora + 5);
    }
  }

  return { sonarHallazgo, despertar: asegurarContexto };
}
