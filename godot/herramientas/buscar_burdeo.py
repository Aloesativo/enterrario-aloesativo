"""Busca el diorama de Burdeo: UN mundo con las zonas del lore superpuestas.

Estructura buscada (DISENO_GODOT.md §5 + src/story/burdeo.json):

  SUELO (y=0), todo caminable sin rotar, porque el lore lo dice explicito:
    - ciudad ...... "el plano ancla", donde se arranca
    - playa ....... "conectada a Burdeo dentro del mismo mapa"
    - bosque ...... "conectado a la ciudad"

  IMPOSIBLES: elevados y lejos, cada uno alcanzable SOLO en una rotacion
  distinta, para que descubrirlos sea una progresion y no un solo truco:
    - luna ........ "el satelite de la ciudad"
    - otro-planeta  "desde aqui se ve el mismo momento del cometa, pero
                     desde fuera"
    - cometa ...... "atraviesa el mapa entero en vez de ocupar un lugar"

Todas las zonas caminables comparten altura para que caminar entre ellas
sea un paso normal: subir un escalon cuenta como distancia 2 y se marcaria
como "puente imposible", lo que diluiria el efecto de los saltos de verdad.
"""

from verificar_nivel import rect, construir_indice, proyectar, esta_visible, PASOS
from collections import deque

CENTRO = (10, 10)
PARTIDA = (2, 0, 2)

# El suelo de Burdeo: tres zonas pegadas que forman una L.
SUELO = {
    "ciudad": rect(0, 5, 0, 5, 0),
    "playa": rect(0, 5, 6, 10, 0),
    "bosque": rect(6, 10, 0, 5, 0),
}


def alcanzables(desde, bloques, rot, centro):
    indice = construir_indice(bloques, rot, centro)
    vistas = {desde}
    cola = deque([desde])
    while cola:
        actual = cola.popleft()
        pa, pb = proyectar(actual, rot, centro)
        for da, db in PASOS.values():
            destino = indice.get((pa + da, pb + db))
            if destino is None:
                continue
            dist = sum(abs(destino[i] - actual[i]) for i in range(3))
            if dist > 1 and not esta_visible(actual, indice, rot, centro):
                continue
            if destino not in vistas:
                vistas.add(destino)
                cola.append(destino)
    return vistas


def rotaciones_que_conectan(isla, centro=CENTRO):
    """En que rotaciones se llega a esa isla desde la partida, con el suelo."""
    bloques = [c for z in SUELO.values() for c in z] + isla
    ok = []
    for rot in range(4):
        alc = alcanzables(PARTIDA, bloques, rot, centro)
        if any(c in alc for c in isla):
            ok.append(rot)
    return ok


def buscar_candidatas(lado, alturas, rango):
    """Islas que se conectan en EXACTAMENTE una rotacion."""
    encontradas = {0: [], 1: [], 2: [], 3: []}
    for y in alturas:
        for x0 in rango:
            for z0 in rango:
                isla = rect(x0, x0 + lado - 1, z0, z0 + lado - 1, y)
                if any(c in [b for zz in SUELO.values() for b in zz] for c in isla):
                    continue
                rots = rotaciones_que_conectan(isla)
                if len(rots) == 1:
                    encontradas[rots[0]].append((x0, z0, y, lado))
    return encontradas


if __name__ == "__main__":
    print("buscando islas imposibles (esto tarda un poco)...\n")
    cand = buscar_candidatas(lado=4, alturas=range(3, 12), rango=range(-6, 20))
    for rot in range(4):
        print(f"rotacion {rot}: {len(cand[rot])} islas se conectan SOLO ahi")
        for c in cand[rot][:6]:
            print(f"    x0={c[0]:3d} z0={c[1]:3d} y={c[2]:2d} lado={c[3]}")
        print()
