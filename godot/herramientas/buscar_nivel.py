"""Barrido de parametros para encontrar un nivel con MAS superficie
caminable que el de nivel.json, que siga siendo un acertijo valido.

Criterio de acertijo (igual que validarNivel):
  - el objetivo se alcanza en exactamente UNA rotacion
  - esa rotacion NO es la inicial
Ademas se prefiere: mucha superficie, y un puente que salte lejos.
"""

from verificar_nivel import rect, alcanzables

RESULTADOS = []

for lado_a in (4, 5, 6):
    for lado_b in (4, 5, 6):
        for sep in range(4, 9):          # separacion entre islas en x y z
            for alto in range(2, 8):      # altura de la isla del hallazgo
                orilla = rect(0, lado_a - 1, 0, lado_a - 1, 0)
                x0 = lado_a - 1 + sep
                hallazgo = rect(x0, x0 + lado_b - 1, x0, x0 + lado_b - 1, alto)
                bloques = orilla + hallazgo

                # centro del nivel = centro geometrico de todo
                todos_x = [c[0] for c in bloques]
                todos_z = [c[2] for c in bloques]
                cx = (min(todos_x) + max(todos_x)) // 2
                cz = (min(todos_z) + max(todos_z)) // 2

                partida = (0, 0, 0)
                objetivo = (x0 + lado_b - 1, alto, x0 + lado_b - 1)

                resuelven = []
                mejor_salto = 0
                for rot in range(4):
                    vistas, puentes = alcanzables(partida, bloques, rot, (cx, cz))
                    if objetivo in vistas:
                        resuelven.append(rot)
                        for _, _, d in puentes:
                            mejor_salto = max(mejor_salto, d)

                if len(resuelven) != 1:
                    continue
                rot_ok = resuelven[0]
                # la rotacion inicial es cualquiera de las otras tres; se
                # elige la "mas lejos" del la solucion para que no se
                # resuelva por accidente al primer toque
                rot_inicial = (rot_ok + 2) % 4

                RESULTADOS.append({
                    "superficie": len(bloques),
                    "salto": mejor_salto,
                    "lado_a": lado_a,
                    "lado_b": lado_b,
                    "sep": sep,
                    "alto": alto,
                    "centro": (cx, cz),
                    "rot_ok": rot_ok,
                    "rot_inicial": rot_inicial,
                    "partida": partida,
                    "objetivo": objetivo,
                    "x0": x0,
                })

RESULTADOS.sort(key=lambda r: (r["superficie"], r["salto"]), reverse=True)

print(f"configuraciones validas encontradas: {len(RESULTADOS)}\n")
for r in RESULTADOS[:10]:
    print(
        f"superficie={r['superficie']:3d} salto={r['salto']:2d} | "
        f"orilla {r['lado_a']}x{r['lado_a']} y=0, hallazgo {r['lado_b']}x{r['lado_b']} y={r['alto']} "
        f"en x,z={r['x0']} | centro={r['centro']} | resuelve rot {r['rot_ok']}, inicia rot {r['rot_inicial']}"
    )
