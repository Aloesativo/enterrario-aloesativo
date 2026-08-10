"""Valida el diorama de Burdeo COMPLETO (todas las zonas a la vez).

Buscar cada isla por separado no alcanza: al juntarlas pueden taparse entre
si o servirse de escalon, y abrirse en rotaciones donde no deberian. Este
script prueba combinaciones y valida el mundo entero.
"""

import itertools

from verificar_nivel import rect, construir_indice, proyectar, esta_visible
from buscar_burdeo import SUELO, CENTRO, PARTIDA, alcanzables, rotaciones_que_conectan


def franja(x0, x1, z0, z1, y):
    """El cometa: una franja larga y fina que 'atraviesa el mapa entero'."""
    return rect(x0, x1, z0, z1, y)


def validar_mundo(zonas, centro=CENTRO, partida=PARTIDA):
    """zonas: dict nombre -> lista de celdas. Devuelve (ok, informe)."""
    bloques = [c for z in zonas.values() for c in z]
    if len(bloques) != len(set(bloques)):
        return False, "  X hay celdas repetidas entre zonas (se pisan)"

    suelo = set(SUELO.keys())
    informe = []
    apertura = {}

    for rot in range(4):
        alc = alcanzables(partida, bloques, rot, centro)
        llega = {n for n, celdas in zonas.items() if any(c in alc for c in celdas)}
        informe.append(f"  rot {rot}: se llega a {sorted(llega)}")
        for n in zonas:
            if n in llega and n not in suelo:
                apertura.setdefault(n, []).append(rot)

    # el suelo tiene que ser caminable en TODAS las rotaciones
    for rot in range(4):
        alc = alcanzables(partida, bloques, rot, centro)
        for n in suelo:
            if not any(c in alc for c in zonas[n]):
                return False, "\n".join(informe + [f"  X el suelo '{n}' no se camina en rot {rot}"])

    imposibles = [n for n in zonas if n not in suelo]
    for n in imposibles:
        rots = apertura.get(n, [])
        if len(rots) != 1:
            return False, "\n".join(informe + [f"  X '{n}' se abre en {rots} (tiene que ser exactamente 1)"])

    usadas = [apertura[n][0] for n in imposibles]
    if len(set(usadas)) != len(usadas):
        return False, "\n".join(informe + [f"  X dos zonas comparten rotacion: {dict(zip(imposibles, usadas))}"])

    inicial = [r for r in range(4) if r not in usadas]
    if not inicial:
        return False, "\n".join(informe + ["  X no queda ninguna rotacion inicial sin premio"])

    informe.append(f"  apertura: {{n: rot}} = { {n: apertura[n][0] for n in imposibles} }")
    informe.append(f"  rotacion inicial posible: {inicial}")
    return True, "\n".join(informe)


if __name__ == "__main__":
    # Candidatas elegidas del barrido, con alturas distintas para que el
    # relieve se lea, y posiciones coherentes con el lore.
    intentos = [
        {
            "luna": rect(4, 7, 12, 15, 5),          # satelite: cerca de la ciudad, alto
            "otro-planeta": rect(-6, -3, -6, -3, 9),  # lejos y mas alto
            "cometa": franja(-6, -3, 10, 17, 7),      # franja larga que cruza
        },
        {
            "luna": rect(5, 8, 13, 16, 6),
            "otro-planeta": rect(-6, -3, -6, -3, 10),
            "cometa": franja(12, 15, -6, 1, 8),
        },
        {
            "luna": rect(4, 7, 13, 16, 4),
            "otro-planeta": rect(-5, -2, -5, -2, 8),
            "cometa": franja(13, 16, 2, 9, 6),
        },
    ]

    for i, imposibles in enumerate(intentos):
        zonas = dict(SUELO)
        zonas.update(imposibles)
        ok, informe = validar_mundo(zonas)
        print(f"=== intento {i} === {'OK' if ok else 'FALLA'}")
        print(informe)
        print()
