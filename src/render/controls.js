import * as THREE from 'three';

/**
 * Controles del ESCENARIO (el rig que contiene el diorama + el personaje).
 * Dos modos conviven:
 *
 *  - Libre (touch/mouse/gamepad): arrastrar = yaw+pitch, 2 dedos = roll,
 *    stick de gamepad = yaw/pitch, gatillos = roll. Rotación continua en
 *    los 3 ejes, relativa a los ejes de la cámara (arcball) para que el
 *    gesto siempre coincida con lo que se ve en pantalla.
 *
 *  - Encausado (teclado, WASD): NO es arrastre libre. Cada tecla dispara
 *    un giro cinematográfico a una etapa fija (múltiplos de 90° en el eje
 *    Y del mundo), animado con easing. Los giros se pueden encadenar en
 *    combinación mientras el anterior todavía está animando (p.ej. A, A
 *    seguidas dan un giro de 180° en dos pasos suaves) — esa es la
 *    "narrativa" pedida: cambios de perspectiva por etapas, no un rango
 *    libre de 360° paso por paso. Las flechas quedan libres para mover al
 *    personaje (ver personaje.js).
 *
 * Ambos modos rotan el mismo `objetivo.quaternion`, así que si el usuario
 * empieza a arrastrar se cancela cualquier animación de etapa en curso
 * (y viceversa) para que no compitan.
 */
export function crearControlesEscenario({ camera, canvas, objetivo }) {
  const SENSIBILIDAD_ARRASTRE = 0.006;
  const SENSIBILIDAD_TORSION = 1.0;
  const SENSIBILIDAD_GAMEPAD = 2.2;
  const FRICCION = 0.9; // decae la velocidad del arrastre libre, no la corta
  const UMBRAL_REPOSO = 0.0005;

  const ETAPA = Math.PI / 2; // 90°: unidad mínima de giro cinematográfico
  const DURACION_ETAPA = 420; // ms, giro de 90°
  const DURACION_MEDIA_VUELTA = 600; // ms, giro de 180°
  const DURACION_RESET = 450;
  const EJE_Y_MUNDO = new THREE.Vector3(0, 1, 0);

  const velocidad = new THREE.Vector3(0, 0, 0); // (yaw, pitch, roll) rad/frame — solo modo libre
  const punteros = new Map(); // pointerId -> {x, y}
  let anguloTorsionPrevio = null;
  const quaternionIdentidad = new THREE.Quaternion();

  // --- Animación de giro por etapas (keyboard) ---
  let animandoEtapa = false;
  let inicioEtapa = 0;
  let duracionEtapa = 0;
  const origenEtapa = new THREE.Quaternion();
  const destinoEtapa = new THREE.Quaternion();

  const ejeCamara = {
    right: new THREE.Vector3(),
    up: new THREE.Vector3(),
    forward: new THREE.Vector3(),
  };

  function actualizarEjesCamara() {
    camera.matrixWorld.extractBasis(ejeCamara.right, ejeCamara.up, ejeCamara.forward);
    ejeCamara.forward.negate(); // "forward" real es -Z de la matriz de la cámara
  }

  function aplicarRotacionLibre(yaw, pitch, roll) {
    actualizarEjesCamara();
    const q = new THREE.Quaternion();
    if (yaw !== 0) q.multiply(new THREE.Quaternion().setFromAxisAngle(ejeCamara.up, -yaw));
    if (pitch !== 0) q.multiply(new THREE.Quaternion().setFromAxisAngle(ejeCamara.right, -pitch));
    if (roll !== 0) q.multiply(new THREE.Quaternion().setFromAxisAngle(ejeCamara.forward, roll));
    objetivo.quaternion.premultiply(q);
  }

  function vibrar(patron) {
    if (typeof navigator !== 'undefined' && navigator.vibrate) {
      navigator.vibrate(patron);
    }
  }

  function animarEtapaHacia(quaternionDestino, duracion) {
    origenEtapa.copy(objetivo.quaternion);
    destinoEtapa.copy(quaternionDestino);
    inicioEtapa = performance.now();
    duracionEtapa = duracion;
    animandoEtapa = true;
  }

  function girarEtapaRelativa(anguloDelta, duracion) {
    const deltaQ = new THREE.Quaternion().setFromAxisAngle(EJE_Y_MUNDO, anguloDelta);
    const destino = objetivo.quaternion.clone().premultiply(deltaQ);
    animarEtapaHacia(destino, duracion);
    vibrar(12);
  }

  function resetearVista() {
    animarEtapaHacia(quaternionIdentidad, DURACION_RESET);
    vibrar([15, 40, 15]);
  }

  // --- Pointer (mouse + touch unificados) — modo libre ---
  function alPointerDown(evento) {
    canvas.setPointerCapture(evento.pointerId);
    punteros.set(evento.pointerId, { x: evento.clientX, y: evento.clientY });
    velocidad.set(0, 0, 0);
    animandoEtapa = false;
    if (punteros.size === 1) vibrar(10);
  }

  function alPointerMove(evento) {
    const previo = punteros.get(evento.pointerId);
    if (!previo) return;
    const actual = { x: evento.clientX, y: evento.clientY };

    if (punteros.size === 1) {
      const dx = actual.x - previo.x;
      const dy = actual.y - previo.y;
      const yaw = dx * SENSIBILIDAD_ARRASTRE;
      const pitch = dy * SENSIBILIDAD_ARRASTRE;
      aplicarRotacionLibre(yaw, pitch, 0);
      velocidad.x = yaw;
      velocidad.y = pitch;
    } else if (punteros.size === 2) {
      punteros.set(evento.pointerId, actual);
      const [p1, p2] = [...punteros.values()];
      const anguloActual = Math.atan2(p2.y - p1.y, p2.x - p1.x);
      if (anguloTorsionPrevio !== null) {
        let delta = anguloActual - anguloTorsionPrevio;
        if (delta > Math.PI) delta -= Math.PI * 2;
        if (delta < -Math.PI) delta += Math.PI * 2;
        const roll = delta * SENSIBILIDAD_TORSION;
        aplicarRotacionLibre(0, 0, roll);
        velocidad.z = roll;
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
    resetearVista();
  }

  canvas.style.touchAction = 'none';
  canvas.addEventListener('pointerdown', alPointerDown);
  canvas.addEventListener('pointermove', alPointerMove);
  canvas.addEventListener('pointerup', alPointerUp);
  canvas.addEventListener('pointercancel', alPointerUp);
  canvas.addEventListener('dblclick', alDobleClick);

  // --- Teclado — modo encausado (WASD), las flechas son del personaje ---
  function alTeclaPresionada(evento) {
    switch (evento.key) {
      case 'a':
      case 'A':
        girarEtapaRelativa(-ETAPA, DURACION_ETAPA);
        break;
      case 'd':
      case 'D':
        girarEtapaRelativa(ETAPA, DURACION_ETAPA);
        break;
      case 'w':
      case 'W':
        girarEtapaRelativa(Math.PI, DURACION_MEDIA_VUELTA);
        break;
      case 's':
      case 'S':
        resetearVista();
        break;
      default:
        return;
    }
    velocidad.set(0, 0, 0);
  }
  window.addEventListener('keydown', alTeclaPresionada);

  // --- Gamepad (Xbox / genérico Android) — modo libre ---
  const BOTON_RESET = 0; // A / Cross
  let botonResetPrevio = false;

  function leerGamepad() {
    if (typeof navigator === 'undefined' || !navigator.getGamepads) return;
    const [gamepad] = navigator.getGamepads();
    if (!gamepad) return;

    const zonaMuerta = 0.15;
    const aplicarZonaMuerta = (valor) => (Math.abs(valor) < zonaMuerta ? 0 : valor);

    const yaw = aplicarZonaMuerta(gamepad.axes[0] ?? 0) * SENSIBILIDAD_GAMEPAD * 0.02;
    const pitch = aplicarZonaMuerta(gamepad.axes[1] ?? 0) * SENSIBILIDAD_GAMEPAD * 0.02;
    const lt = gamepad.buttons[6]?.value ?? 0;
    const rt = gamepad.buttons[7]?.value ?? 0;
    const roll = (rt - lt) * SENSIBILIDAD_GAMEPAD * 0.02;

    if (yaw !== 0 || pitch !== 0 || roll !== 0) {
      animandoEtapa = false;
      aplicarRotacionLibre(yaw, pitch, roll);
      velocidad.set(yaw, pitch, roll);
    }

    const botonReset = gamepad.buttons[BOTON_RESET]?.pressed ?? false;
    if (botonReset && !botonResetPrevio) {
      resetearVista();
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
    }
    botonResetPrevio = botonReset;
  }

  function actualizar() {
    leerGamepad();

    if (animandoEtapa) {
      const t = Math.min((performance.now() - inicioEtapa) / duracionEtapa, 1);
      const suavizado = 1 - Math.pow(1 - t, 3); // ease-out cúbico
      objetivo.quaternion.slerpQuaternions(origenEtapa, destinoEtapa, suavizado);
      if (t >= 1) animandoEtapa = false;
      return;
    }

    if (punteros.size === 0 && velocidad.lengthSq() > UMBRAL_REPOSO) {
      aplicarRotacionLibre(velocidad.x, velocidad.y, velocidad.z);
      velocidad.multiplyScalar(FRICCION);
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

  return { actualizar, destruir, resetearVista };
}
