import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';

/**
 * Iluminación basada en imagen (IBL). Es el cambio que más separa un
 * greybox de algo que parece "iluminado" de verdad.
 *
 * Por qué importa: una AmbientLight suma un color plano a todas las caras
 * por igual, así que un cubo iluminado solo con ambiental se ve como una
 * silueta sin volumen. Un entorno, en cambio, aporta luz DISTINTA según
 * hacia dónde mira cada cara, y además da reflejos coherentes en los
 * materiales metálicos/rugosos. Es la diferencia entre "tiene luz" y
 * "está en un lugar".
 *
 * Por qué RoomEnvironment y no un archivo .hdr: RoomEnvironment genera el
 * entorno proceduralmente (una habitación con luces de estudio), así que no
 * hay ningún binario que commitear ni licencia que revisar. Suficiente para
 * validar composición. Cuando RR elija un ambiente real, se pone el .hdr en
 * `public/` y se cambia `theme.entorno.tipo` a "hdri" — sin tocar este
 * archivo salvo para el loader.
 *
 * OJO con la capa de identidad: la ELECCIÓN de ambiente es identidad
 * visual y vive en theme/. Aquí solo está el mecanismo que la ejecuta.
 */
export function instalarEntorno({ renderer, scene, theme }) {
  const config = theme.entorno ?? {};

  // Tone mapping: sin esto, cualquier valor de luz por encima de 1.0 se
  // recorta a blanco puro y la imagen se ve "quemada" y plana. ACES
  // comprime el rango alto con una curva de cine, que es de dónde viene la
  // sensación de foto y no de render de motor.
  renderer.toneMapping = THREE[config.toneMapping ?? 'ACESFilmicToneMapping']
    ?? THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = config.exposicion ?? 1;
  renderer.outputColorSpace = THREE.SRGBColorSpace;

  const pmrem = new THREE.PMREMGenerator(renderer);
  pmrem.compileEquirectangularShader();

  const sala = new RoomEnvironment();
  const objetivo = pmrem.fromScene(sala, config.desenfoque ?? 0.04);
  scene.environment = objetivo.texture;
  scene.environmentIntensity = config.intensidad ?? 1;

  sala.dispose();
  pmrem.dispose();

  return {
    /** Libera la textura de entorno. Hoy nadie la llama; existe para cuando
     *  se pueda cambiar de ambiente en caliente (un ambiente por escena del
     *  guion, por ejemplo). */
    liberar() {
      objetivo.dispose();
      scene.environment = null;
    },
  };
}
