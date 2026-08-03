/**
 * Entrada. Dos verbos, y solo dos:
 *
 *   MOVER el personaje  → flechas / arrastre corto / d-pad / stick
 *   ROTAR el escenario  → A y D / toque en el borde / bumpers
 *
 * Que sean solo dos es deliberado. En la versión anterior convivían el
 * movimiento del personaje, el viaje entre zonas, la órbita libre, la
 * inclinación a dos dedos y los pasos por una grilla de planos — cinco
 * verbos peleando por los mismos dedos, y el resultado fue que ninguno se
 * entendía. Aquí no hay órbita libre a propósito: la cámara del juego no
 * se toca, ni siquiera un poco.
 */
export function crearControles({ canvas, theme, alMover, alRotar, alGesto }) {
  // Los nombres 'arriba'/'abajo' de mundo/proyeccion.js describen el signo
  // en el espacio de pantalla (A,B), no lo que el ojo ve. Esta grilla en
  // diamante solo tiene CUATRO pasos posibles, y los cuatro son diagonales
  // en pantalla (NE/SE/SO/NO) — no hay un paso "puro arriba". La pregunta
  // no es "¿invertido sí o no?", es CUÁL de las dos asignaciones de 45°
  // (horaria o antihoraria) es la intuitiva.
  //
  // La primera corrección (commit anterior) usó la horaria: Arriba→NE,
  // Derecha→SE, Abajo→SO, Izquierda→NO. Se sentía "rotada" — cada tecla
  // hacía lo que la vecina anterior debía hacer. La antihoraria es la que
  // usan los isométricos clásicos: Arriba→NO, Derecha→NE, Abajo→SE,
  // Izquierda→SO. Verificado por captura tras el cambio: Arriba (NO) y
  // Derecha (NE) comparten la mitad superior de la pantalla, como se
  // espera de dos teclas "hacia arriba".
  const DIRECCIONES = {
    ArrowUp: 'abajoIzquierda',
    ArrowDown: 'arribaDerecha',
    ArrowLeft: 'arribaIzquierda',
    ArrowRight: 'abajoDerecha',
  };

  // Se leen de theme.controles en cada gesto (no se cachean en constantes)
  // para que el panel de configuración (?config=1) pueda tunearlos en vivo
  // sin recargar. 26px / 0.16 son los valores por defecto si el theme no
  // trae la sección.
  const umbralArrastre = () => theme?.controles?.umbralArrastre ?? 26;
  const bandaBorde = () => theme?.controles?.bandaBorde ?? 0.16;

  let origen = null;

  function alPointerDown(evento) {
    canvas.setPointerCapture(evento.pointerId);
    origen = { x: evento.clientX, y: evento.clientY };
    alGesto?.();
  }

  /**
   * Al soltar se decide qué fue el gesto. Se resuelve al SOLTAR y no
   * durante el arrastre para que no haya ambigüedad: mientras el dedo está
   * abajo no pasa nada, así que ningún gesto se dispara a medias.
   */
  function alPointerUp(evento) {
    if (!origen) return;
    const dx = evento.clientX - origen.x;
    const dy = evento.clientY - origen.y;
    const recorrido = Math.hypot(dx, dy);
    origen = null;

    if (recorrido < umbralArrastre()) {
      // Toque: los bordes laterales rotan el escenario.
      const ancho = canvas.clientWidth || window.innerWidth;
      const banda = bandaBorde();
      if (evento.clientX < ancho * banda) alRotar(-1);
      else if (evento.clientX > ancho * (1 - banda)) alRotar(1);
      return;
    }

    // Arrastre: las cuatro diagonales de la retícula isométrica.
    // Se compara |dx| con |dy| para elegir el eje dominante y luego el
    // signo — así cualquier arrastre cae siempre en una de las cuatro, sin
    // zonas muertas donde el gesto no haga nada.
    if (Math.abs(dx) > Math.abs(dy)) {
      alMover(dx > 0 ? 'abajoDerecha' : 'arribaIzquierda');
    } else {
      alMover(dy > 0 ? 'arribaDerecha' : 'abajoIzquierda');
    }
  }

  function alPointerCancel() {
    origen = null;
  }

  canvas.style.touchAction = 'none';
  canvas.addEventListener('pointerdown', alPointerDown);
  canvas.addEventListener('pointerup', alPointerUp);
  canvas.addEventListener('pointercancel', alPointerCancel);

  function alTecla(evento) {
    const direccion = DIRECCIONES[evento.key];
    if (direccion) {
      evento.preventDefault();
      alGesto?.();
      alMover(direccion);
      return;
    }
    switch (evento.key) {
      case 'a': case 'A': alGesto?.(); alRotar(-1); break;
      case 'd': case 'D': alGesto?.(); alRotar(1); break;
      default: return;
    }
  }
  window.addEventListener('keydown', alTecla);

  // --- Gamepad ---
  const BOTON_ROTAR_IZQ = 4; // LB
  const BOTON_ROTAR_DER = 5; // RB
  const estado = { izq: false, der: false, eje: false };

  function leerGamepad() {
    if (typeof navigator === 'undefined' || !navigator.getGamepads) return;
    const [gamepad] = navigator.getGamepads();
    if (!gamepad) return;

    const x = gamepad.axes[0] ?? 0;
    const y = gamepad.axes[1] ?? 0;
    const fuera = Math.hypot(x, y) > 0.55;

    // El stick da UN paso por empujón, no un chorro continuo: el juego se
    // piensa celda a celda y un movimiento continuo lo volvería resbaladizo.
    if (fuera && !estado.eje) {
      if (Math.abs(x) > Math.abs(y)) alMover(x > 0 ? 'abajoDerecha' : 'arribaIzquierda');
      else alMover(y > 0 ? 'arribaDerecha' : 'abajoIzquierda');
    }
    estado.eje = fuera;

    pulsacion(gamepad, BOTON_ROTAR_IZQ, 'izq', () => alRotar(-1));
    pulsacion(gamepad, BOTON_ROTAR_DER, 'der', () => alRotar(1));
  }

  function pulsacion(gamepad, indice, clave, accion) {
    const presionado = gamepad.buttons[indice]?.pressed ?? false;
    if (presionado && !estado[clave]) { alGesto?.(); accion(); }
    estado[clave] = presionado;
  }

  return {
    actualizar: leerGamepad,
    destruir() {
      canvas.removeEventListener('pointerdown', alPointerDown);
      canvas.removeEventListener('pointerup', alPointerUp);
      canvas.removeEventListener('pointercancel', alPointerCancel);
      window.removeEventListener('keydown', alTecla);
    },
  };
}
