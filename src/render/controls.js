import * as THREE from 'three';

/**
 * Controles tipo "rubik con gravedad": rotan un grupo (el diorama completo)
 * en los 3 ejes, sin necesidad de que el usuario aprenda un mapeo previo.
 * La cámara isométrica queda fija; lo que gira es el objetivo.
 *
 * Entrada soportada, todas produciendo el mismo efecto (rotar `objetivo`):
 *  - 1 dedo / mouse: arrastrar horizontal = yaw, vertical = pitch.
 *  - 2 dedos: el giro relativo entre ambos = roll (como girar una tapa).
 *  - Teclado: flechas/WASD = yaw/pitch, Q/E = roll, R = reset.
 *  - Gamepad (Xbox/Android): stick izquierdo = yaw/pitch, gatillos LT/RT = roll,
 *    botón A/Cross = reset.
 *
 * Las rotaciones se aplican relativas a los ejes de la cámara (right/up/forward),
 * no a los ejes del objeto: así el gesto siempre coincide con lo que se ve en
 * pantalla sin importar cómo esté orientado el diorama en ese momento
 * (arcball). Al soltar, la velocidad angular decae con fricción en vez de
 * detenerse en seco — es el efecto "gravedad" pedido.
 */
export function crearControlesRubik({ camera, canvas, objetivo }) {
  const SENSIBILIDAD_ARRASTRE = 0.006;
  const SENSIBILIDAD_TORSION = 1.0;
  const SENSIBILIDAD_GAMEPAD = 2.2;
  const FRICCION = 0.90; // por frame a 60fps aprox.: decae la velocidad, no la corta
  const UMBRAL_REPOSO = 0.0005;
  const DURACION_RESET = 350; // ms

  const velocidad = new THREE.Vector3(0, 0, 0); // (yaw, pitch, roll) rad/frame
  const punteros = new Map(); // pointerId -> {x, y}
  let anguloTorsionPrevio = null;
  let reseteando = false;
  let inicioReset = 0;
  let quaternionInicioReset = null;
  const quaternionIdentidad = new THREE.Quaternion();

  const ejeCamara = {
    right: new THREE.Vector3(),
    up: new THREE.Vector3(),
    forward: new THREE.Vector3(),
  };

  function actualizarEjesCamara() {
    camera.matrixWorld.extractBasis(ejeCamara.right, ejeCamara.up, ejeCamara.forward);
    ejeCamara.forward.negate(); // "forward" real es -Z de la matriz de la cámara
  }

  function aplicarRotacion(yaw, pitch, roll) {
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

  function iniciarReset() {
    reseteando = true;
    inicioReset = performance.now();
    quaternionInicioReset = objetivo.quaternion.clone();
    velocidad.set(0, 0, 0);
    vibrar([15, 40, 15]);
  }

  // --- Pointer (mouse + touch unificados) ---
  function alPointerDown(evento) {
    canvas.setPointerCapture(evento.pointerId);
    punteros.set(evento.pointerId, { x: evento.clientX, y: evento.clientY });
    velocidad.set(0, 0, 0);
    reseteando = false;
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
      aplicarRotacion(yaw, pitch, 0);
      velocidad.x = yaw;
      velocidad.y = pitch;
    } else if (punteros.size === 2) {
      punteros.set(evento.pointerId, actual);
      const [p1, p2] = [...punteros.values()];
      const anguloActual = Math.atan2(p2.y - p1.y, p2.x - p1.x);
      if (anguloTorsionPrevio !== null) {
        let delta = anguloActual - anguloTorsionPrevio;
        // normaliza el salto -PI..PI para evitar saltos al cruzar el borde
        if (delta > Math.PI) delta -= Math.PI * 2;
        if (delta < -Math.PI) delta += Math.PI * 2;
        const roll = delta * SENSIBILIDAD_TORSION;
        aplicarRotacion(0, 0, roll);
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
    iniciarReset();
  }

  canvas.style.touchAction = 'none';
  canvas.addEventListener('pointerdown', alPointerDown);
  canvas.addEventListener('pointermove', alPointerMove);
  canvas.addEventListener('pointerup', alPointerUp);
  canvas.addEventListener('pointercancel', alPointerUp);
  canvas.addEventListener('dblclick', alDobleClick);

  // --- Teclado (fallback desktop, sin mapeo previo: flechas + WASD) ---
  const PASO_TECLADO = 0.05;
  function alTeclaPresionada(evento) {
    switch (evento.key) {
      case 'ArrowLeft':
      case 'a':
      case 'A':
        aplicarRotacion(-PASO_TECLADO, 0, 0);
        break;
      case 'ArrowRight':
      case 'd':
      case 'D':
        aplicarRotacion(PASO_TECLADO, 0, 0);
        break;
      case 'ArrowUp':
      case 'w':
      case 'W':
        aplicarRotacion(0, -PASO_TECLADO, 0);
        break;
      case 'ArrowDown':
      case 's':
      case 'S':
        aplicarRotacion(0, PASO_TECLADO, 0);
        break;
      case 'q':
      case 'Q':
        aplicarRotacion(0, 0, -PASO_TECLADO);
        break;
      case 'e':
      case 'E':
        aplicarRotacion(0, 0, PASO_TECLADO);
        break;
      case 'r':
      case 'R':
        iniciarReset();
        break;
      default:
        return;
    }
    velocidad.set(0, 0, 0);
  }
  window.addEventListener('keydown', alTeclaPresionada);

  // --- Gamepad (Xbox / genérico Android) ---
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
      aplicarRotacion(yaw, pitch, roll);
      velocidad.set(yaw, pitch, roll);
      reseteando = false;
    }

    const botonReset = gamepad.buttons[BOTON_RESET]?.pressed ?? false;
    if (botonReset && !botonResetPrevio) {
      iniciarReset();
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

    if (reseteando) {
      const t = Math.min((performance.now() - inicioReset) / DURACION_RESET, 1);
      const suavizado = 1 - Math.pow(1 - t, 3); // ease-out cúbico
      objetivo.quaternion.slerpQuaternions(quaternionInicioReset, quaternionIdentidad, suavizado);
      if (t >= 1) reseteando = false;
      return;
    }

    if (punteros.size === 0 && velocidad.lengthSq() > UMBRAL_REPOSO) {
      aplicarRotacion(velocidad.x, velocidad.y, velocidad.z);
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

  return { actualizar, destruir, reset: iniciarReset };
}
