import * as THREE from 'three';

const GRADOS = Math.PI / 180;

/**
 * Director de cámara: es quien decide DÓNDE se para la cámara y CÓMO
 * encuadra. Sustituye a la cámara isométrica fija que vivía en scene.js.
 *
 * Por qué cambia el enfoque respecto de la versión anterior: antes se
 * rotaba el diorama alrededor del eje Y y la cámara no se movía nunca, así
 * que la altura del punto de vista era siempre la misma — cambiaba qué
 * cara quedaba al frente, pero nunca la composición. Eso no es lenguaje de
 * cámara, es girar un objeto sobre un plato. Aquí la cámara orbita de
 * verdad (azimut + elevación) y además cada plano puede cambiar encuadre,
 * inclinación y proyección.
 *
 * Proyección animable: en vez de alternar entre cámara ortográfica y
 * cámara en perspectiva (dos objetos distintos, imposible de interpolar),
 * se usa UNA PerspectiveCamera con el fov como parámetro. Un fov muy bajo
 * a mucha distancia es visualmente indistinguible de una proyección
 * ortográfica —el look isométrico del prototipo— y un fov alto da fuga
 * real. Como es un solo número, se puede animar: pasar de fov bajo a fov
 * alto manteniendo el encuadre es literalmente un dolly zoom.
 *
 * La distancia no se elige a mano, se deriva: para encuadrar una altura
 * `encuadre` con un `fov` dado, la cámara tiene que estar a
 * `encuadre / (2·tan(fov/2))`. Así "cuánto se ve" y "cuánta fuga hay" son
 * parámetros independientes, como en una cámara real (encuadre y focal).
 */
export function crearDirectorCamara({ theme, planos, escena, alturaCentro = 1 }) {
  const { grilla, encuadreGenerico } = planos;

  const camera = new THREE.PerspectiveCamera(encuadreGenerico.fov, 1, 0.1, 1000);

  // Estado continuo de la cámara. Todo esto es lo que se anima.
  const estado = {
    azimut: (360 / grilla.azimutPasos) * grilla.azimutInicial * GRADOS,
    elevacion: grilla.elevaciones[grilla.elevacionInicial] * GRADOS,
    encuadre: encuadreGenerico.encuadre,
    fov: encuadreGenerico.fov,
    roll: encuadreGenerico.roll * GRADOS,
  };

  let azimutIndice = grilla.azimutInicial;
  let elevacionIndice = grilla.elevacionInicial;
  let planoActual = buscarPlano(azimutIndice, elevacionIndice);

  // Objetivo (a qué mira). Se recalcula cada frame porque el personaje se
  // mueve; durante una transición se interpola entre el objetivo anterior
  // y el nuevo, ambos vivos.
  const objetivoActual = new THREE.Vector3(0, alturaCentro, 0);
  const objetivoOrigen = new THREE.Vector3(0, alturaCentro, 0);
  let nombreObjetivoOrigen = encuadreGenerico.objetivo;
  let nombreObjetivoDestino = encuadreGenerico.objetivo;

  // El "volteo" del mundo: la parte híbrida. La mayoría de los planos deja
  // el terrario derecho, pero algunos lo dan vuelta — ahí ya no se mueve la
  // cámara, se mueve el mundo.
  const volteoOrigen = new THREE.Quaternion();
  const volteoDestino = new THREE.Quaternion();

  // Transición entre planos.
  const transicion = { activa: false, inicio: 0, duracion: 0, desde: null, hasta: null };

  let objetoPersonaje = null;
  let rigMundo = null;
  let aspecto = 1;

  function buscarPlano(ai, ei) {
    return (
      planos.planos.find((plano) => plano.celda[0] === ai && plano.celda[1] === ei) ?? null
    );
  }

  /** Fusiona el plano curado de una celda con el encuadre genérico. */
  function encuadreDe(plano) {
    return { ...encuadreGenerico, ...(plano ?? {}) };
  }

  function posicionDelPersonaje(destino) {
    if (!objetoPersonaje) return destino.set(0, alturaCentro, 0);
    return objetoPersonaje.getWorldPosition(destino);
  }

  function resolverObjetivo(nombre, destino) {
    return nombre === 'personaje'
      ? posicionDelPersonaje(destino)
      : destino.set(0, alturaCentro, 0);
  }

  /**
   * La altura visible se corrige por aspecto: en pantallas verticales
   * (móvil en retrato) el ancho es el lado corto, así que hay que encuadrar
   * MÁS alto para que el diorama entre a lo ancho. Sin esto, el mismo plano
   * se ve bien en apaisado y recortado en retrato.
   */
  function encuadreEfectivo() {
    return aspecto < 1 ? estado.encuadre / aspecto : estado.encuadre;
  }

  function distanciaActual() {
    return encuadreEfectivo() / (2 * Math.tan((estado.fov * GRADOS) / 2));
  }

  function irACelda(nuevoAzimutIndice, nuevoElevacionIndice, duracion = 620) {
    const pasos = grilla.azimutPasos;
    azimutIndice = ((nuevoAzimutIndice % pasos) + pasos) % pasos;
    elevacionIndice = Math.max(
      0,
      Math.min(grilla.elevaciones.length - 1, nuevoElevacionIndice)
    );

    planoActual = buscarPlano(azimutIndice, elevacionIndice);
    const encuadre = encuadreDe(planoActual);

    // Azimut por el camino más corto: sin esto, ir de 315° a 45° daría una
    // vuelta larga de 270° en vez del giro de 90° que el usuario espera.
    const azimutDestinoCrudo = (360 / pasos) * azimutIndice * GRADOS;
    let deltaAzimut = azimutDestinoCrudo - estado.azimut;
    while (deltaAzimut > Math.PI) deltaAzimut -= Math.PI * 2;
    while (deltaAzimut < -Math.PI) deltaAzimut += Math.PI * 2;

    transicion.desde = { ...estado };
    transicion.hasta = {
      azimut: estado.azimut + deltaAzimut,
      elevacion: grilla.elevaciones[elevacionIndice] * GRADOS,
      encuadre: encuadre.encuadre,
      fov: encuadre.fov,
      roll: encuadre.roll * GRADOS,
    };

    nombreObjetivoOrigen = nombreObjetivoDestino;
    nombreObjetivoDestino = encuadre.objetivo;
    resolverObjetivo(nombreObjetivoOrigen, objetivoOrigen);

    volteoOrigen.copy(rigMundo ? rigMundo.quaternion : new THREE.Quaternion());
    const [vx, vy, vz] = encuadre.volteo;
    volteoDestino.setFromEuler(new THREE.Euler(vx * GRADOS, vy * GRADOS, vz * GRADOS));

    transicion.activa = true;
    transicion.inicio = performance.now();
    transicion.duracion = duracion;

    return { plano: planoActual, encuadre };
  }

  /** Paso regular: A/D mueven el azimut, W/S la elevación. */
  function paso({ azimut = 0, elevacion = 0 }) {
    return irACelda(azimutIndice + azimut, elevacionIndice + elevacion);
  }

  function volverAlPlanoBase() {
    return irACelda(grilla.azimutInicial, grilla.elevacionInicial, 700);
  }

  /**
   * Órbita libre (arrastre táctil / mouse / stick). Mueve la cámara sin
   * pasar por la grilla de planos: es el modo continuo, para dispositivos
   * sin teclado. Cancela cualquier transición en curso.
   */
  function orbitarLibre(deltaAzimut, deltaElevacion) {
    transicion.activa = false;
    estado.azimut += deltaAzimut;
    estado.elevacion = Math.max(
      2 * GRADOS,
      Math.min(88 * GRADOS, estado.elevacion + deltaElevacion)
    );
  }

  function inclinarLibre(deltaRoll) {
    transicion.activa = false;
    estado.roll += deltaRoll;
  }

  /**
   * Ejes de pantalla expresados en coordenadas de la grilla. Los sirve el
   * director porque solo él sabe hacia dónde mira la cámara: sin esto, tras
   * girar 90° la flecha "arriba" movería al personaje en diagonal respecto
   * de lo que se ve, que es justo la fricción de controles que el prototipo
   * quiere evitar.
   */
  function ejesPantallaEnGrilla() {
    const adelanteMundo = new THREE.Vector3()
      .subVectors(objetivoActual, camera.position)
      .setY(0)
      .normalize();
    const derechaMundo = new THREE.Vector3(-adelanteMundo.z, 0, adelanteMundo.x);

    // Si el mundo está volteado, hay que pasar del espacio del mundo al
    // espacio local de la grilla antes de decidir en qué celda cae el paso.
    if (rigMundo) {
      const inversa = rigMundo.quaternion.clone().invert();
      adelanteMundo.applyQuaternion(inversa).setY(0).normalize();
      derechaMundo.applyQuaternion(inversa).setY(0).normalize();
    }

    return { adelante: ajustarAEje(adelanteMundo), derecha: ajustarAEje(derechaMundo) };
  }

  /** Redondea una dirección continua al eje de grilla más parecido. */
  function ajustarAEje(vector) {
    return Math.abs(vector.x) >= Math.abs(vector.z)
      ? { dx: Math.sign(vector.x) || 1, dz: 0 }
      : { dx: 0, dz: Math.sign(vector.z) || 1 };
  }

  function ajustarAspecto(ancho, alto) {
    aspecto = ancho / alto;
    camera.aspect = aspecto;
  }

  function actualizar() {
    if (transicion.activa) {
      const t = Math.min((performance.now() - transicion.inicio) / transicion.duracion, 1);
      const s = 1 - Math.pow(1 - t, 3); // ease-out cúbico
      for (const clave of ['azimut', 'elevacion', 'encuadre', 'fov', 'roll']) {
        estado[clave] = transicion.desde[clave] + (transicion.hasta[clave] - transicion.desde[clave]) * s;
      }
      if (rigMundo) rigMundo.quaternion.slerpQuaternions(volteoOrigen, volteoDestino, s);

      const destinoVivo = resolverObjetivo(nombreObjetivoDestino, new THREE.Vector3());
      resolverObjetivo(nombreObjetivoOrigen, objetivoOrigen);
      objetivoActual.lerpVectors(objetivoOrigen, destinoVivo, s);

      if (t >= 1) transicion.activa = false;
    } else {
      resolverObjetivo(nombreObjetivoDestino, objetivoActual);
    }

    const distancia = distanciaActual();
    camera.fov = estado.fov;
    camera.near = Math.max(0.1, distancia * 0.05);
    camera.far = distancia * 3;
    camera.updateProjectionMatrix();

    const radioHorizontal = distancia * Math.cos(estado.elevacion);
    camera.position.set(
      objetivoActual.x + radioHorizontal * Math.cos(estado.azimut),
      objetivoActual.y + distancia * Math.sin(estado.elevacion),
      objetivoActual.z + radioHorizontal * Math.sin(estado.azimut)
    );
    camera.lookAt(objetivoActual);
    if (estado.roll !== 0) camera.rotateZ(estado.roll);

    // La niebla se recalcula a partir de la distancia real, no se deja fija.
    // Con la cámara moviéndose entre planos la distancia cambia mucho: unos
    // valores fijos que funcionan de cerca dejan el diorama completamente
    // invisible en un plano lejano (es exactamente el bug de niebla
    // documentado en CLAUDE.md, pero ahora con la distancia variando sola).
    if (escena.fog) {
      escena.fog.near = distancia * theme.niebla.factorCerca;
      escena.fog.far = distancia * theme.niebla.factorLejos;
    }
  }

  return {
    camera,
    actualizar,
    ajustarAspecto,
    paso,
    irACelda,
    volverAlPlanoBase,
    orbitarLibre,
    inclinarLibre,
    ejesPantallaEnGrilla,
    vincularPersonaje: (objeto) => { objetoPersonaje = objeto; },
    vincularRig: (rig) => { rigMundo = rig; },
    get planoActual() { return planoActual; },
  };
}
