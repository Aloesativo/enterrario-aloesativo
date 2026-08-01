import * as THREE from 'three';

const GRADOS = Math.PI / 180;

/**
 * Director de cámara con DOS REGÍMENES, que es la idea entera:
 *
 *  1. MECÁNICO — isométrica fija. Nunca se mueve, nunca se inclina, nunca
 *     opina. Encuadra el nivel entero y se queda quieto.
 *
 *  2. REVELACIÓN — al descubrir algo, la cámara se suelta: va a una
 *     esquina, sube, se inclina, abre la perspectiva. Y vuelve.
 *
 * Por qué el régimen mecánico es aburrido A PROPÓSITO: el significado de
 * un movimiento de cámara no está en el movimiento, está en la ruptura de
 * una regla que el jugador llevaba rato obedeciendo. Si la cámara siempre
 * se expresa, una toma cinematográfica no dice nada. Aburrirla durante el
 * juego es lo que le da poder a la toma del hallazgo.
 *
 * Además hay una razón mecánica dura: el acertijo consiste en leer
 * ALINEACIONES en pantalla. Si la cámara se moviera sola, las alineaciones
 * cambiarían sin que el jugador lo pidiera, y el acertijo sería ilegible.
 * La rigidez no es estética, es la condición para que se pueda jugar.
 *
 * La regla de oro de la toma de revelación: **devuelve al jugador
 * exactamente al encuadre del que lo sacó**. Es un paréntesis, nunca una
 * transición. Como el encuadre mecánico está completamente determinado
 * (siempre el mismo azimut, la misma elevación, el mismo objetivo),
 * volver exacto es trivial — otra ventaja de haberlo hecho rígido.
 */
export function crearDirectorCamara({ theme, planos, escena, objetivoMecanico, radioNivel }) {
  const base = planos.mecanica;

  // El encuadre se deriva del tamaño real del nivel en vez de ser un número
  // fijo. Con un número fijo, mover una isla deja media escena fuera de
  // cuadro sin que nada avise — y aquí lo que queda fuera de cuadro puede
  // ser justo la isla que hay que alinear.
  const encuadreMecanico = radioNivel * 2 * (base.margen ?? 1.2);

  const camera = new THREE.PerspectiveCamera(base.fov, 1, 0.1, 1000);

  const estado = {
    azimut: base.azimut * GRADOS,
    elevacion: base.elevacion * GRADOS,
    encuadre: encuadreMecanico,
    fov: base.fov,
    roll: 0,
  };

  const objetivo = new THREE.Vector3().fromArray(objetivoMecanico);
  const objetivoActual = objetivo.clone();

  let aspecto = 1;
  let regimen = 'mecanica';

  const transicion = { activa: false, inicio: 0, duracion: 0, desde: null, hasta: null,
    objetivoDesde: new THREE.Vector3(), objetivoHasta: new THREE.Vector3() };

  /** El encuadre mecánico, que es siempre el mismo. La referencia a la que
   *  se vuelve después de cada revelación. */
  function poseMecanica() {
    return {
      azimut: base.azimut * GRADOS,
      elevacion: base.elevacion * GRADOS,
      encuadre: encuadreMecanico,
      fov: base.fov,
      roll: 0,
      objetivo: objetivo.clone(),
    };
  }

  /**
   * En pantallas verticales el ancho es el lado corto, así que hay que
   * encuadrar más alto para que el nivel entre a lo ancho. Sin esto el
   * mismo encuadre se ve bien en apaisado y recortado en retrato — y en
   * este artefacto recortar es fatal, porque lo que se recorta puede ser
   * justo la isla que hay que alinear.
   */
  function encuadreEfectivo() {
    return aspecto < 1 ? estado.encuadre / aspecto : estado.encuadre;
  }

  function distanciaActual() {
    return encuadreEfectivo() / (2 * Math.tan((estado.fov * GRADOS) / 2));
  }

  function iniciarTransicion(hasta, duracion) {
    transicion.desde = { ...estado };
    transicion.objetivoDesde.copy(objetivoActual);
    transicion.hasta = {
      azimut: hasta.azimut,
      elevacion: hasta.elevacion,
      encuadre: hasta.encuadre,
      fov: hasta.fov,
      roll: hasta.roll,
    };
    transicion.objetivoHasta.copy(hasta.objetivo);
    transicion.activa = true;
    transicion.inicio = performance.now();
    transicion.duracion = duracion;
  }

  /**
   * Entra en régimen de revelación con un plano curado, encuadrando un
   * punto concreto del mundo (la celda del hallazgo).
   */
  function revelar({ plano, punto, duracion = 1400 }) {
    const encuadrePlano = planos.planosRevelacion[plano] ?? planos.planosRevelacion.vertigo;
    regimen = 'revelacion';
    iniciarTransicion(
      {
        azimut: encuadrePlano.azimut * GRADOS,
        elevacion: encuadrePlano.elevacion * GRADOS,
        encuadre: encuadrePlano.encuadre,
        fov: encuadrePlano.fov,
        roll: encuadrePlano.roll * GRADOS,
        objetivo: new THREE.Vector3().fromArray(punto),
      },
      duracion
    );
    return encuadrePlano;
  }

  /** Cierra el paréntesis: vuelve al encuadre mecánico exacto. */
  function volverAMecanica(duracion = 1100) {
    regimen = 'mecanica';
    iniciarTransicion(poseMecanica(), duracion);
  }

  function ajustarAspecto(ancho, alto) {
    aspecto = ancho / alto;
    camera.aspect = aspecto;
  }

  function actualizar() {
    if (transicion.activa) {
      const t = Math.min((performance.now() - transicion.inicio) / transicion.duracion, 1);
      // Ease in-out: la toma de revelación tiene que arrancar y frenar
      // suave. Un ease-out puro arranca de golpe y se siente como un corte,
      // no como una cámara.
      const s = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;

      for (const clave of ['azimut', 'elevacion', 'encuadre', 'fov', 'roll']) {
        estado[clave] =
          transicion.desde[clave] + (transicion.hasta[clave] - transicion.desde[clave]) * s;
      }
      objetivoActual.lerpVectors(transicion.objetivoDesde, transicion.objetivoHasta, s);

      if (t >= 1) transicion.activa = false;
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

    // La niebla se recalcula a partir de la distancia real. Con la cámara
    // cambiando de encuadre entre regímenes, unos valores fijos que
    // funcionan en la isométrica dejan el nivel invisible en la toma de
    // revelación (el bug de niebla documentado en CLAUDE.md, ahora con la
    // distancia variando sola).
    if (escena.fog) {
      escena.fog.near = distancia * theme.niebla.factorCerca;
      escena.fog.far = distancia * theme.niebla.factorLejos;
    }
  }

  return {
    camera,
    actualizar,
    ajustarAspecto,
    revelar,
    volverAMecanica,
    get regimen() { return regimen; },
    get enTransicion() { return transicion.activa; },
  };
}
