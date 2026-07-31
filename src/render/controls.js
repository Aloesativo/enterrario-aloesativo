/**
 * Controles de cámara. Ya no rotan el diorama: le hablan al director de
 * cámara (camera.js), que es quien decide el encuadre.
 *
 * Dos modos conviven, igual que antes, pero ahora ambos mueven la CÁMARA:
 *
 *  - Encausado (teclado): A/D avanzan un paso de azimut, W/S suben y bajan
 *    un escalón de elevación. Cada combinación de ambos índices cae en una
 *    celda de la grilla; las celdas curadas en planos.json traen encuadre,
 *    inclinación, proyección y objetivo propios. Por eso el cambio de
 *    perspectiva se siente narrativo y no como un giro mecánico: no estás
 *    recorriendo un rango continuo, estás saltando entre planos.
 *
 *  - Libre (touch/mouse/gamepad): órbita continua para dispositivos sin
 *    teclado. Arrastrar = azimut + elevación, 2 dedos = inclinación de
 *    cámara (ángulo holandés), gamepad = lo mismo con stick y gatillos.
 *
 * Las flechas NO están aquí: son del personaje (ver personaje.js).
 */
export function crearControlesCamara({ canvas, director, alCambiarPlano }) {
  const SENSIBILIDAD_ARRASTRE = 0.006;
  const SENSIBILIDAD_TORSION = 1.0;
  const SENSIBILIDAD_GAMEPAD = 0.03;
  const FRICCION = 0.9;
  const UMBRAL_REPOSO = 0.00005;

  const punteros = new Map();
  let anguloTorsionPrevio = null;
  const velocidad = { azimut: 0, elevacion: 0, roll: 0 };

  function vibrar(patron) {
    if (typeof navigator !== 'undefined' && navigator.vibrate) navigator.vibrate(patron);
  }

  function anunciar(resultado) {
    if (resultado && alCambiarPlano) alCambiarPlano(resultado);
    // Un plano curado vibra distinto que una celda genérica: el cuerpo
    // avisa que llegaste a un encuadre "con nombre".
    vibrar(resultado?.plano ? [12, 30, 12] : 10);
  }

  // --- Pointer (mouse + touch) — órbita libre ---
  function alPointerDown(evento) {
    canvas.setPointerCapture(evento.pointerId);
    punteros.set(evento.pointerId, { x: evento.clientX, y: evento.clientY });
    velocidad.azimut = 0;
    velocidad.elevacion = 0;
    velocidad.roll = 0;
    if (punteros.size === 1) vibrar(10);
  }

  function alPointerMove(evento) {
    const previo = punteros.get(evento.pointerId);
    if (!previo) return;
    const actual = { x: evento.clientX, y: evento.clientY };

    if (punteros.size === 1) {
      const deltaAzimut = -(actual.x - previo.x) * SENSIBILIDAD_ARRASTRE;
      const deltaElevacion = (actual.y - previo.y) * SENSIBILIDAD_ARRASTRE;
      director.orbitarLibre(deltaAzimut, deltaElevacion);
      velocidad.azimut = deltaAzimut;
      velocidad.elevacion = deltaElevacion;
    } else if (punteros.size === 2) {
      punteros.set(evento.pointerId, actual);
      const [p1, p2] = [...punteros.values()];
      const anguloActual = Math.atan2(p2.y - p1.y, p2.x - p1.x);
      if (anguloTorsionPrevio !== null) {
        let delta = anguloActual - anguloTorsionPrevio;
        if (delta > Math.PI) delta -= Math.PI * 2;
        if (delta < -Math.PI) delta += Math.PI * 2;
        const roll = delta * SENSIBILIDAD_TORSION;
        director.inclinarLibre(roll);
        velocidad.roll = roll;
      }
      anguloTorsionPrevio = anguloActual;
      return;
    }
    punteros.set(evento.pointerId, actual);
  }

  function alPointerUp(evento) {
    punteros.delete(evento.pointerId);
    if (punteros.size < 2) anguloTorsionPrevio = null;
  }

  function alDobleClick() {
    anunciar(director.volverAlPlanoBase());
  }

  canvas.style.touchAction = 'none';
  canvas.addEventListener('pointerdown', alPointerDown);
  canvas.addEventListener('pointermove', alPointerMove);
  canvas.addEventListener('pointerup', alPointerUp);
  canvas.addEventListener('pointercancel', alPointerUp);
  canvas.addEventListener('dblclick', alDobleClick);

  // --- Teclado — pasos por la grilla de planos ---
  function alTeclaPresionada(evento) {
    switch (evento.key) {
      case 'a':
      case 'A':
        anunciar(director.paso({ azimut: -1 }));
        break;
      case 'd':
      case 'D':
        anunciar(director.paso({ azimut: 1 }));
        break;
      case 'w':
      case 'W':
        anunciar(director.paso({ elevacion: 1 }));
        break;
      case 's':
      case 'S':
        anunciar(director.paso({ elevacion: -1 }));
        break;
      case 'r':
      case 'R':
        anunciar(director.volverAlPlanoBase());
        break;
      default:
        return;
    }
    velocidad.azimut = 0;
    velocidad.elevacion = 0;
    velocidad.roll = 0;
  }
  window.addEventListener('keydown', alTeclaPresionada);

  // --- Gamepad (Xbox / genérico Android) ---
  const BOTON_RESET = 0; // A / Cross
  const BOTON_PASO_IZQ = 4; // LB
  const BOTON_PASO_DER = 5; // RB
  const estadoBotones = { reset: false, pasoIzq: false, pasoDer: false };

  function leerGamepad() {
    if (typeof navigator === 'undefined' || !navigator.getGamepads) return;
    const [gamepad] = navigator.getGamepads();
    if (!gamepad) return;

    const zonaMuerta = 0.15;
    const limpiar = (valor) => (Math.abs(valor) < zonaMuerta ? 0 : valor);

    const deltaAzimut = -limpiar(gamepad.axes[0] ?? 0) * SENSIBILIDAD_GAMEPAD;
    const deltaElevacion = limpiar(gamepad.axes[1] ?? 0) * SENSIBILIDAD_GAMEPAD;
    if (deltaAzimut !== 0 || deltaElevacion !== 0) {
      director.orbitarLibre(deltaAzimut, deltaElevacion);
      velocidad.azimut = deltaAzimut;
      velocidad.elevacion = deltaElevacion;
    }

    const lt = gamepad.buttons[6]?.value ?? 0;
    const rt = gamepad.buttons[7]?.value ?? 0;
    const roll = (rt - lt) * SENSIBILIDAD_GAMEPAD;
    if (roll !== 0) {
      director.inclinarLibre(roll);
      velocidad.roll = roll;
    }

    // Los bumpers dan acceso a los pasos por planos también en gamepad:
    // sin ellos, un control sin teclado se quedaría solo con órbita libre y
    // nunca alcanzaría los encuadres curados.
    pulsacion(gamepad, BOTON_PASO_IZQ, 'pasoIzq', () => anunciar(director.paso({ azimut: -1 })));
    pulsacion(gamepad, BOTON_PASO_DER, 'pasoDer', () => anunciar(director.paso({ azimut: 1 })));
    pulsacion(gamepad, BOTON_RESET, 'reset', () => {
      anunciar(director.volverAlPlanoBase());
      const actuador = gamepad.vibrationActuator ?? gamepad.hapticActuators?.[0];
      if (actuador?.playEffect) {
        actuador.playEffect('dual-rumble', {
          duration: 120,
          strongMagnitude: 0.5,
          weakMagnitude: 0.3,
        });
      } else if (actuador?.pulse) {
        actuador.pulse(0.4, 120);
      }
    });
  }

  function pulsacion(gamepad, indice, clave, accion) {
    const presionado = gamepad.buttons[indice]?.pressed ?? false;
    if (presionado && !estadoBotones[clave]) accion();
    estadoBotones[clave] = presionado;
  }

  function actualizar() {
    leerGamepad();

    if (punteros.size === 0) {
      const enMovimiento =
        Math.abs(velocidad.azimut) > UMBRAL_REPOSO ||
        Math.abs(velocidad.elevacion) > UMBRAL_REPOSO ||
        Math.abs(velocidad.roll) > UMBRAL_REPOSO;
      if (enMovimiento) {
        director.orbitarLibre(velocidad.azimut, velocidad.elevacion);
        if (velocidad.roll !== 0) director.inclinarLibre(velocidad.roll);
        velocidad.azimut *= FRICCION;
        velocidad.elevacion *= FRICCION;
        velocidad.roll *= FRICCION;
      }
    }
  }

  function destruir() {
    canvas.removeEventListener('pointerdown', alPointerDown);
    canvas.removeEventListener('pointermove', alPointerMove);
    canvas.removeEventListener('pointerup', alPointerUp);
    canvas.removeEventListener('pointercancel', alPointerUp);
    canvas.removeEventListener('dblclick', alDobleClick);
    window.removeEventListener('keydown', alTeclaPresionada);
  }

  return { actualizar, destruir };
}
