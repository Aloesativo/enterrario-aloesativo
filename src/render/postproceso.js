import {
  BloomEffect,
  EffectComposer,
  EffectPass,
  NoiseEffect,
  RenderPass,
  SMAAEffect,
  TiltShiftEffect,
  VignetteEffect,
  BlendFunction,
} from 'postprocessing';

/**
 * Cadena de postproceso. Traduce los valores de `theme.postproceso` a
 * efectos concretos — no decide ninguno por su cuenta.
 *
 * El efecto que importa aquí es el TILT-SHIFT. Es el que hace que una
 * escena 3D se lea como MINIATURA FOTOGRAFIADA en vez de como render
 * genérico: al desenfocar arriba y abajo dejando una franja nítida, el ojo
 * interpreta profundidad de campo corta, y profundidad de campo corta solo
 * ocurre de verdad cuando fotografías algo muy pequeño muy de cerca. Es un
 * truco de percepción, y es la razón de que los dioramas fotografiados se
 * vean como juguetes. Coste bajísimo, impacto altísimo — por eso encabeza
 * la lista de identidad visual del INFORME.
 *
 * Los demás (bloom, viñeta, grano) están para romper la limpieza de
 * "render de motor": una imagen perfectamente nítida y sin grano lee como
 * software, no como objeto fotografiado.
 *
 * Todos los efectos se pueden apagar poniendo su bloque en null dentro del
 * theme, para poder comparar antes/después sin tocar código.
 */
export function crearPostproceso({ renderer, scene, camera, theme }) {
  const config = theme.postproceso ?? {};

  if (config.activo === false) return null;

  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));

  const efectos = [];

  if (config.tiltShift) {
    const t = config.tiltShift;
    efectos.push(
      new TiltShiftEffect({
        offset: t.desplazamiento ?? 0,
        rotation: (t.rotacion ?? 0) * (Math.PI / 180),
        focusArea: t.franjaNitida ?? 0.4,
        feather: t.difuminado ?? 0.3,
        bias: t.sesgo ?? 0.06,
        kernelSize: t.calidad ?? 2,
        resolutionScale: t.escalaResolucion ?? 0.5,
      })
    );
  }

  if (config.bloom) {
    const b = config.bloom;
    efectos.push(
      new BloomEffect({
        intensity: b.intensidad ?? 0.4,
        luminanceThreshold: b.umbral ?? 0.85,
        luminanceSmoothing: b.suavizado ?? 0.2,
        mipmapBlur: true,
      })
    );
  }

  if (config.vineta) {
    const v = config.vineta;
    efectos.push(
      new VignetteEffect({
        offset: v.desplazamiento ?? 0.35,
        darkness: v.oscuridad ?? 0.5,
      })
    );
  }

  if (config.grano) {
    const g = config.grano;
    const ruido = new NoiseEffect({
      blendFunction: BlendFunction.OVERLAY,
      premultiply: true,
    });
    // La opacidad del ruido no es un parámetro del constructor: se ajusta
    // en el modo de mezcla. Es el número que separa "textura de película"
    // de "televisor sin señal", así que vive en el theme.
    ruido.blendMode.opacity.value = g.opacidad ?? 0.12;
    efectos.push(ruido);
  }

  // SMAA va al final y siempre: el composer se salta el antialias nativo
  // del WebGLRenderer (dibuja a una textura intermedia, no al canvas), así
  // que sin esto todos los bordes del diorama quedan dentados. Es corrección
  // técnica, no identidad — por eso no es configurable.
  efectos.push(new SMAAEffect());

  composer.addPass(new EffectPass(camera, ...efectos));

  return {
    render: () => composer.render(),
    ajustarTamano: (ancho, alto) => composer.setSize(ancho, alto),
    liberar: () => composer.dispose(),
  };
}
