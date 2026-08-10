# herramientas/ — verificar niveles sin abrir Godot

Scripts de Python que replican la matemática de `scripts/proyeccion.gd` y
`scripts/navegacion.gd`. Existen por una razón concreta:

> El agente **no puede correr Godot** (`../../DISENO_GODOT.md` §11), pero
> **sí puede correr la matemática**. Un nivel de este juego se rompe de
> formas que no se ven mirando el código, así que se comprueba con BFS
> antes de escribirlo.

Un nivel se rompe de dos maneras, y **las dos son mudas**:

1. El objetivo queda **inalcanzable** en las cuatro rotaciones → no tiene
   solución.
2. El objetivo se alcanza **ya en la rotación inicial** → no es acertijo,
   se llega caminando sin entender nada.

Mover una isla **una sola celda** basta para caer en cualquiera de las dos.

## `verificar_nivel.py`

Comprueba el nivel que está en uso hoy en `scripts/mundo.gd`.

```bash
python3 verificar_nivel.py
```

Sale con código 0 si el nivel es un acertijo válido, 1 si no. Imprime, por
rotación: si se alcanza el objetivo, cuántas celdas son alcanzables y qué
puentes imposibles existen con su salto real.

**Si tocás `AREAS`, `CENTRO`, `PARTIDA`, `OBJETIVO` o `ROTACION_INICIAL` en
`mundo.gd`, actualizá los mismos valores acá abajo del `__main__` y corré
esto antes de abrir Godot.**

> El mismo chequeo corre dentro del juego en cada arranque
> (`Navegacion.validar()`, que avisa por consola). Este script es para
> saberlo *antes*, y para poder buscar niveles nuevos.

## `buscar_nivel.py`

Barrido de parámetros: prueba muchas configuraciones de dos islas y lista
las que son acertijos válidos, ordenadas por superficie caminable y por
tamaño del salto.

```bash
python3 buscar_nivel.py
```

Así se encontró el nivel actual (72 celdas, salto de 22). Diseñar un nivel
a mano sin pasarlo por acá es la forma más fácil de terminar con un
acertijo que parece bueno y está roto.
