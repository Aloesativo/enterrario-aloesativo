import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';

/**
 * Carga un diorama autorado (.glb) en vez del generado por procedimiento.
 *
 * Por qué existe: la generación procedural resuelve "necesito contenido
 * infinito y barato". El Enterrario necesita lo contrario — unas pocas
 * escenas concretas que cuenten algo. Un terreno de senos con props al azar
 * no puede narrar. Este módulo es la puerta para que el diorama pase a
 * modelarse en Blender, que además permite HORNEAR LA ILUMINACIÓN: calidad
 * de raytracing incrustada en las texturas, a coste cero en runtime.
 *
 * Es deliberadamente opcional y tolerante a fallos: mientras no exista un
 * .glb, el greybox procedural sigue siendo lo que se ve. Pages nunca se
 * puede romper por un asset que todavía no se ha modelado.
 */

/**
 * @returns {Promise<THREE.Group|null>} null si no hay modelo configurado o
 *   si la carga falla — quien llama debe usar el greybox como respaldo.
 */
export async function cargarModelo({ url, theme }) {
  if (!url) return null;

  const loader = new GLTFLoader();

  try {
    const gltf = await loader.loadAsync(url);
    const modelo = gltf.scene;

    prepararSombras(modelo, theme);
    if (theme.modelo?.ajusteAutomatico !== false) {
      encajarEnEncuadre(modelo, theme.modelo?.tamanoObjetivo ?? 12);
    }

    return modelo;
  } catch (error) {
    // Un .glb comprimido con Draco (casilla que Blender ofrece al exportar)
    // falla aquí, porque el decodificador es un wasm aparte que este loader
    // no trae. Si pasa, reexportar SIN compresión Draco es la salida rápida.
    console.warn(
      `[enterrario] no se pudo cargar el modelo "${url}", se usa el greybox procedural.`,
      error
    );
    return null;
  }
}

/**
 * Las sombras no vienen activadas en un glTF: son una decisión del motor,
 * no del archivo. Sin ellas los objetos flotan visualmente aunque estén
 * perfectamente colocados — es el punto 2 de la lista de identidad visual
 * del INFORME.
 */
function prepararSombras(raiz, theme) {
  if (theme.sombras?.activas === false) return;
  raiz.traverse((objeto) => {
    if (objeto.isMesh) {
      objeto.castShadow = true;
      objeto.receiveShadow = true;
    }
  });
}

/**
 * Normaliza escala y posición del modelo para que quepa en el encuadre que
 * ya está calibrado en planos.json.
 *
 * El motivo es práctico: el shot list está afinado para una grilla de 12x12
 * centrada en el origen. Un .glb exportado de Blender puede venir en
 * cualquier escala y con cualquier origen, así que sin esto habría que
 * recalibrar TODOS los planos con cada reexportación del modelo. Se puede
 * apagar (`theme.modelo.ajusteAutomatico: false`) cuando el modelo ya venga
 * con las medidas correctas de fábrica.
 */
function encajarEnEncuadre(modelo, tamanoObjetivo) {
  const caja = new THREE.Box3().setFromObject(modelo);
  const medidas = caja.getSize(new THREE.Vector3());
  const ladoMayor = Math.max(medidas.x, medidas.z) || 1;

  const escala = tamanoObjetivo / ladoMayor;
  modelo.scale.setScalar(escala);

  // Recalcular tras escalar: la caja anterior ya no vale.
  const cajaEscalada = new THREE.Box3().setFromObject(modelo);
  const centro = cajaEscalada.getCenter(new THREE.Vector3());

  // Centrado en X/Z, apoyado en Y=0. Se apoya en vez de centrarse en
  // vertical porque el director de cámara mira a `alturaCentro` sobre el
  // suelo, y un diorama hundido bajo el origen queda fuera de todos los
  // planos.
  modelo.position.x -= centro.x;
  modelo.position.z -= centro.z;
  modelo.position.y -= cajaEscalada.min.y;
}
