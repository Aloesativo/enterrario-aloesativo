"""Verifica el nivel del estereograma ANTES de escribirlo en Godot.

No puedo correr Godot, pero sí puedo correr la matemática. Este script
replica proyeccion.js + navegacion.js y comprueba las dos propiedades que
hacen que un nivel sea un acertijo y no un chiste:

  1. La celda del hallazgo es alcanzable en ALGUNA rotacion.
  2. NO es alcanzable en la rotacion inicial (si no, no hay acertijo).
"""

from collections import deque


def rotar(celda, rot, centro):
    x, y, z = celda
    cx, cz = centro
    dx, dz = x - cx, z - cz
    rot = rot % 4
    if rot == 0:
        rx, rz = dx, dz
    elif rot == 1:
        rx, rz = -dz, dx
    elif rot == 2:
        rx, rz = -dx, -dz
    else:
        rx, rz = dz, -dx
    return (rx + cx, y, rz + cz)


def proyectar(celda, rot, centro):
    x, y, z = rotar(celda, rot, centro)
    return (x - z, x + z - 2 * y)


# Los cuatro pasos en pantalla, nombrados por lo que el OJO ve.
# Derivacion: screen_x propto A, screen_y_abajo propto B.
PASOS = {
    "NO": (-1, -1),
    "NE": (1, -1),
    "SE": (1, 1),
    "SO": (-1, 1),
}


def construir_indice(bloques, rot, centro):
    """Que celda se VE en cada punto de pantalla.

    Entre dos celdas que caen en el mismo pixel gana la mas cercana a la
    camara. Demostracion de que eso equivale a "la de mayor y":
      con A y B fijos, rx+rz = B + 2y, y la profundidad va como
      rx+rz+y = B + 3y. Con B igual, ordena y. Es independiente de la
      rotacion, a diferencia de comparar x+z sin rotar.
    """
    indice = {}
    for b in bloques:
        p = proyectar(b, rot, centro)
        previo = indice.get(p)
        if previo is None or b[1] > previo[1]:
            indice[p] = b
    return indice


def esta_visible(celda, indice, rot, centro):
    """La celda es la que se VE en su propio punto de pantalla, o esta tapada
    por otra que esta mas cerca de la camara."""
    return indice.get(proyectar(celda, rot, centro)) == celda


def intentar_paso(desde, direccion, indice, rot, centro):
    pa, pb = proyectar(desde, rot, centro)
    da, db = PASOS[direccion]
    destino = indice.get((pa + da, pb + db))
    if destino is None:
        return None
    dist = abs(destino[0] - desde[0]) + abs(destino[1] - desde[1]) + abs(destino[2] - desde[2])

    # Estando tapado no se puede romper la ilusion (cruzar un puente), pero
    # SI se puede caminar. Bloquear todo era un softlock; el movimiento
    # tiene que sentirse libre.
    if dist > 1 and not esta_visible(desde, indice, rot, centro):
        return None

    return destino, dist


def alcanzables(desde, bloques, rot, centro):
    indice = construir_indice(bloques, rot, centro)
    vistas = {desde}
    cola = deque([desde])
    puentes = []
    while cola:
        actual = cola.popleft()
        for d in PASOS:
            r = intentar_paso(actual, d, indice, rot, centro)
            if r is None:
                continue
            destino, dist = r
            if destino not in vistas:
                vistas.add(destino)
                cola.append(destino)
                if dist > 1:
                    puentes.append((actual, destino, dist))
    return vistas, puentes


def rect(x0, x1, z0, z1, y):
    return [(x, y, z) for x in range(x0, x1 + 1) for z in range(z0, z1 + 1)]


def evaluar(nombre, areas, centro, partida, objetivo, rot_inicial):
    bloques = [c for a in areas for c in a]
    print(f"\n=== {nombre} ===")
    print(f"bloques={len(bloques)} centro={centro} partida={partida} objetivo={objetivo}")
    ok_rots = []
    for rot in range(4):
        vistas, puentes = alcanzables(partida, bloques, rot, centro)
        llega = objetivo in vistas
        if llega:
            ok_rots.append(rot)
        marca = "SI" if llega else "no"
        print(f"  rot {rot}: alcanza objetivo = {marca:3s} | celdas alcanzables={len(vistas):3d} | puentes={len(puentes)}")
        for a, b, d in puentes[:3]:
            print(f"      puente {a} -> {b} (distancia real {d})")

    print(f"  --> rotaciones que resuelven: {ok_rots}")
    if not ok_rots:
        print("  X FALLA: el objetivo es inalcanzable en las 4 rotaciones.")
        return False
    if rot_inicial in ok_rots:
        print(f"  X FALLA: se alcanza ya en la rotacion inicial ({rot_inicial}) -> no hay acertijo.")
        return False

    # Aviso, no falla: estando tapado igual se puede caminar, asi que no hay
    # softlock. Pero una celda que no se ve en NINGUNA rotacion es un olor
    # de diseno: el jugador puede pararse donde nunca se lo ve.
    indices = [construir_indice(bloques, r, centro) for r in range(4)]
    siempre_tapadas = [
        c for c in bloques
        if not any(esta_visible(c, indices[r], r, centro) for r in range(4))
    ]
    if siempre_tapadas:
        print(f"  aviso: {len(siempre_tapadas)} celdas no se ven en ninguna rotacion: {siempre_tapadas[:5]}")

    tapadas = {r: sum(1 for c in bloques if not esta_visible(c, indices[r], r, centro)) for r in range(4)}
    print(f"  celdas tapadas por rotacion: {tapadas} (tapado esta bien: igual se camina)")
    print(f"  OK: acertijo valido. Inicia en rot {rot_inicial}, se resuelve rotando a {ok_rots}.")
    return True


if __name__ == "__main__":
    # El nivel que está EN USO hoy en godot/scripts/mundo.gd (AREAS,
    # CENTRO, PARTIDA, OBJETIVO, ROTACION_INICIAL). Si tocas esos numeros
    # alla, cambialos aca y corre este script antes de abrir Godot.
    ok = evaluar(
        "nivel en uso (mundo.gd): orilla 6x6 y=0 + mirador 6x6 y=7",
        [rect(0, 5, 0, 5, 0), rect(9, 14, 9, 14, 7)],
        centro=(7, 7),
        partida=(0, 0, 0),
        objetivo=(14, 7, 14),
        rot_inicial=2,
    )

    # De referencia: el nivel original de src/mundo/nivel.json (Three.js).
    evaluar(
        "referencia src/mundo/nivel.json: orilla 4x4 y=0 + mirador 4x4 y=5",
        [rect(0, 3, 0, 3, 0), rect(6, 9, 6, 9, 5)],
        centro=(5, 5),
        partida=(1, 0, 1),
        objetivo=(9, 5, 9),
        rot_inicial=2,
    )

    raise SystemExit(0 if ok else 1)
