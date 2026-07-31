import * as THREE from 'three';
import { TAMANO_CELDA, ALTO_BLOQUE } from './tiles.js';

const ALTO_PERSONAJE = TAMANO_CELDA * 0.55;

/**
 * El personaje: por ahora un cubo simple. Vive dentro del mismo `rig` que
 * el diorama, así que se mueve en el espacio local de la grilla — la
 * rotación cinematográfica del escenario (ver controls.js) no interfiere
 * con hacia dónde "cree" el personaje que se está moviendo.
 */
export function construirPersonaje({ theme }) {
  const geometria = new THREE.BoxGeometry(ALTO_PERSONAJE, ALTO_PERSONAJE, ALTO_PERSONAJE);
  const material = new THREE.MeshStandardMaterial({ color: theme.paleta.personaje });
  return new THREE.Mesh(geometria, material);
}

/** Elige una celda de partida cerca del centro que no sea agua. */
export function encontrarCeldaInicial(diorama) {
  const centro = Math.floor(diorama.tamano / 2);
  let mejor = null;
  let mejorDistancia = Infinity;
  for (const celda of diorama.celdas) {
    if (celda.tipo === 'agua') continue;
    const distancia = Math.abs(celda.x - centro) + Math.abs(celda.z - centro);
    if (distancia < mejorDistancia) {
      mejorDistancia = distancia;
      mejor = celda;
    }
  }
  return mejor ?? diorama.celdas[0];
}

/**
 * Mueve al personaje por la grilla del diorama con las flechas: una celda
 * a la vez, con animación corta y bloqueo en bordes/agua (choque = vibra
 * distinto y no avanza — el toque "RPG" de que el mundo tiene reglas).
 */
export function crearControladorPersonaje({ mesh, diorama, celdaInicial }) {
  const DURACION_PASO = 160;
  const centrado = -(diorama.tamano * TAMANO_CELDA) / 2;
  const celdasPorCoordenada = new Map(
    diorama.celdas.map((celda) => [`${celda.x},${celda.z}`, celda])
  );

  let celdaActual = celdaInicial;
  const origenPos = new THREE.Vector3();
  const destinoPos = new THREE.Vector3();
  let inicioMovimiento = 0;
  let moviendo = false;

  function posicionDeCelda(celda) {
    const y = (celda.altura || 0.3) * ALTO_BLOQUE + ALTO_BLOQUE / 2 + ALTO_PERSONAJE / 2;
    return new THREE.Vector3(
      centrado + celda.x * TAMANO_CELDA,
      y,
      centrado + celda.z * TAMANO_CELDA
    );
  }

  mesh.position.copy(posicionDeCelda(celdaActual));

  function vibrar(patron) {
    if (typeof navigator !== 'undefined' && navigator.vibrate) navigator.vibrate(patron);
  }

  function intentarMover(dx, dz) {
    if (moviendo) return;
    const destino = celdasPorCoordenada.get(`${celdaActual.x + dx},${celdaActual.z + dz}`);
    if (!destino || destino.tipo === 'agua') {
      vibrar(8); // choque: fuera de la grilla o contra el agua
      return;
    }
    celdaActual = destino;
    origenPos.copy(mesh.position);
    destinoPos.copy(posicionDeCelda(destino));
    inicioMovimiento = performance.now();
    moviendo = true;
    vibrar(10);
  }

  function alTeclaPresionada(evento) {
    switch (evento.key) {
      case 'ArrowUp':
        intentarMover(0, -1);
        break;
      case 'ArrowDown':
        intentarMover(0, 1);
        break;
      case 'ArrowLeft':
        intentarMover(-1, 0);
        break;
      case 'ArrowRight':
        intentarMover(1, 0);
        break;
      default:
        return;
    }
  }
  window.addEventListener('keydown', alTeclaPresionada);

  function actualizar() {
    if (!moviendo) return;
    const t = Math.min((performance.now() - inicioMovimiento) / DURACION_PASO, 1);
    mesh.position.lerpVectors(origenPos, destinoPos, t);
    if (t >= 1) moviendo = false;
  }

  function destruir() {
    window.removeEventListener('keydown', alTeclaPresionada);
  }

  return { actualizar, destruir };
}
