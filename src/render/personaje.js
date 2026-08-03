import * as THREE from 'three';
import { TAM, ALTO, posicionDeCelda } from './nivel.js';

const LADO = TAM * 0.42;

/**
 * El personaje. Es la agencia del jugador: todo lo demás está a su
 * servicio. En la versión anterior había quedado degradado a marcador de
 * presencia mientras el gesto principal viajaba entre zonas — ese fue el
 * error que rompió el artefacto. Aquí vuelve al centro.
 */
export function construirPersonaje({ theme }) {
  const geometria = new THREE.BoxGeometry(LADO, LADO * 1.4, LADO);
  const material = new THREE.MeshStandardMaterial({ color: theme.paleta.personaje });
  const malla = new THREE.Mesh(geometria, material);
  malla.castShadow = theme.sombras?.activas !== false;
  return malla;
}

/**
 * Movimiento por celdas. La animación del paso es corta (160ms por
 * defecto, tuneable en theme.personaje.duracionPaso) porque este juego se
 * piensa con los ojos, no con los dedos: una animación larga castigaría
 * probar alineaciones, que es exactamente lo que queremos que el jugador
 * haga sin miedo.
 *
 * El paso a un "puente imposible" dura más y vibra distinto. Es la única
 * pista que da el sistema de que acaba de pasar algo que no era obvio —
 * sin ella, cruzar un abismo se siente igual que caminar, y el hallazgo
 * pierde su peso.
 *
 * Mientras la animación corre, una tecla nueva NO se descarta: se guarda
 * en `colaDireccion` (un solo paso de cola, el más reciente gana) y se
 * ejecuta apenas termina el paso en curso, en `actualizar()`. Antes se
 * tiraba silenciosamente ("en-movimiento"), que es lo que hacía sentir
 * las flechas como rotas al pulsarlas rápido o mantenerlas apretadas.
 */
export function crearControladorPersonaje({ malla, nivel, theme }) {
  let celda = { ...nivel.partida };
  let rotacion = nivel.rotacionInicial;
  let animacion = null;
  let colaDireccion = null;

  const desde = new THREE.Vector3();
  const hasta = new THREE.Vector3();

  function alturaSobreCelda(c) {
    const p = posicionDeCelda(c);
    p.y += (LADO * 1.4) / 2;
    return p;
  }

  malla.position.copy(alturaSobreCelda(celda));

  function vibrar(patron) {
    if (typeof navigator !== 'undefined' && navigator.vibrate) navigator.vibrate(patron);
  }

  /** @returns {{movido:boolean, puenteImposible?:boolean, celda?:object}} */
  function mover(direccion) {
    if (animacion) {
      colaDireccion = direccion;
      return { movido: false, motivo: 'en-movimiento' };
    }

    const paso = nivel.navegacion.intentarPaso(celda, direccion, rotacion);
    if (!paso.permitido) {
      vibrar(8);
      return { movido: false, motivo: paso.motivo };
    }

    desde.copy(malla.position);
    hasta.copy(alturaSobreCelda(paso.celda));
    celda = paso.celda;

    const duracion = paso.puenteImposible
      ? theme.personaje?.duracionPuente ?? 420
      : theme.personaje?.duracionPaso ?? 160;

    animacion = { inicio: performance.now(), duracion, puente: paso.puenteImposible };

    vibrar(paso.puenteImposible ? [18, 40, 18, 40, 30] : 10);
    return { movido: true, puenteImposible: paso.puenteImposible, celda };
  }

  function fijarRotacion(nueva) {
    rotacion = ((nueva % 4) + 4) % 4;
    return rotacion;
  }

  /**
   * @returns {null|{movido:boolean}} el resultado del paso encolado que
   * acaba de arrancar solo, o null si no había nada que continuar. Quien
   * llama (main.js) tiene que tratarlo igual que el resultado de un
   * mover() directo — HUD y detección de revelación incluidas — porque
   * para el jugador es exactamente lo mismo: pulsó una tecla y algo se
   * movió.
   */
  function actualizar() {
    if (!animacion) return null;
    const t = Math.min((performance.now() - animacion.inicio) / animacion.duracion, 1);
    const s = 1 - Math.pow(1 - t, 3);

    malla.position.lerpVectors(desde, hasta, s);

    // Un arco vertical durante el paso. En un puente imposible el arco es
    // alto: el personaje "salta" a través del vacío que la perspectiva
    // acaba de cerrar, y eso hace visible que ocurrió algo raro.
    const alturaArco = animacion.puente ? ALTO * 0.9 : ALTO * 0.12;
    malla.position.y += Math.sin(s * Math.PI) * alturaArco;

    if (t < 1) return null;
    animacion = null;

    if (!colaDireccion) return null;
    const direccion = colaDireccion;
    colaDireccion = null;
    return mover(direccion);
  }

  return {
    mover,
    actualizar,
    fijarRotacion,
    get celda() { return celda; },
    get rotacion() { return rotacion; },
    get enMovimiento() { return animacion !== null; },
  };
}
