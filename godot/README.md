# godot/ — prototipo por etapas

> **Antes de tocar cualquier cosa acá: leer `../DISENO_GODOT.md`.**
> Este prototipo se construye por etapas chicas definidas ahí (§10). Si lo
> que vas a escribir no está en ese documento, no se escribe: se propone,
> se acuerda, se anota, y recién después se construye.

## Estado: ETAPA 2 — la cámara isométrica fija

✅ **Etapa 1 verificada por RR:** el personaje camina por celdas discretas.

Ahora la grilla es de 21×21 —más grande que la pantalla, a propósito— y la
cámara **sigue al personaje sin girar nunca**.

> La grilla creció porque si cupiera entera en pantalla, una cámara que
> sigue sería indistinguible de una fija, y no habría forma de probar esta
> etapa.

### Cómo probarlo

1. Abrir `godot/project.godot` con Godot 4.x (NO la raíz del repo).
2. F5 / Play. Arranca en `escenas/Mundo.tscn`.
3. Mover con flechas del teclado, o D-pad, o stick izquierdo de un control
   (PS o Xbox — funciona de fábrica, sin configurar nada).

### Qué mirar en esta etapa

- **¿La vista se ve plana / 2.5D?** Ese achatamiento es el core del juego
  (§2): el mundo tiene que parecer casi un dibujo plano. Si se ve con
  profundidad "de 3D normal", algo está mal.
- **¿La cámara gira o se inclina alguna vez?** No debería, jamás, por
  ningún motivo. Si la ves girar, es un bug grave — esa rigidez es la
  condición de que el acertijo se pueda leer.
- **¿Cabecea al caminar?** No debería. El personaje sube un arquito en
  cada paso, pero la cámara ignora la altura a propósito.
- **¿El seguimiento se siente bien?** Ajustable con `VELOCIDAD_CAMARA` en
  `scripts/mundo.gd` (hoy `9.0`; más alto = más pegada).

### Sigue valiendo de la etapa 1

- El paso es discreto (de casilla a casilla, nunca deslizándose).
- Un empujón durante la animación no se descarta: queda en cola.
- Los controles andan sin configurar nada.

### ⚠️ Decisión a evaluar: un paso por empujón

**Mantener apretado NO camina solo.** Hay que soltar y volver a empujar
por cada paso — y con el stick, hay que devolverlo a la zona muerta.

Está implementado así porque `DISENO_GODOT.md` §3 lo dice literal (*"el
stick da UN paso por empujón, no un chorro continuo"*), pero puede que en
la mano se sienta tedioso. **Es exactamente el tipo de cosa que esta etapa
existe para detectar.** Si molesta, decilo: cambiarlo a "mantener apretado
camina" es una línea (`is_action_just_pressed` → `is_action_pressed`).

### Números para tocar

Están arriba de todo en `scripts/personaje.gd`, juntos a propósito:

| Constante | Hoy | Qué hace |
|---|---|---|
| `DURACION_PASO` | `0.16` s | cuánto dura el paso |
| `ALTURA_ARCO` | `0.12` | cuánto se levanta a mitad de paso |

> ⚠️ **No hagas el paso lento para darle peso.** `DISENO_GODOT.md` §6: el
> peso va en la textura del paso (arco, aterrizaje, sonido), nunca en la
> duración. Un paso lento vuelve tedioso probar rotaciones, y probar
> rotaciones es el core del juego.

## Qué NO está, a propósito

Rotación del mundo, relieve/alturas, el estereograma, el zoom-cuerda, el
tilt-shift, las zonas del lore, el cometa, sonido, arte. **Todo eso son
etapas 3 a 7** (`DISENO_GODOT.md` §10) y meterlas ahora sería repetir el
error que ya rompió dos prototipos: construir mucho de una vez sin poder
verificar nada.

**La próxima es la etapa 3:** rotar el mundo 90° exactos con A/D y los
bumpers, con dos contadores desde el día uno (uno continuo para animar,
uno módulo 4 para la matemática) — si no, reaparece el bug de girar 270°
por el camino largo que ya costó caro una vez (§2).

## La regla que no se rompe

`scripts/personaje.gd` **no** es un `CharacterBody3D`, **no** usa
`move_and_slide()`, **no** tiene gravedad ni velocidad continua. El estado
del personaje es una celda entera (`Vector2i`).

No es preferencia de estilo: la regla del juego ("puedes pisar lo que se
ve pegado a ti", etapa 4) compara posiciones en pantalla buscando igualdad
**exacta**, y con posiciones continuas esa igualdad no ocurre nunca. Ver
`DISENO_GODOT.md` §3 — es la causa raíz del último prototipo roto.

Lo que sí es continuo es la **animación**. Lo discreto es el estado.

## Si algo falla

El agente **no puede correr Godot** (`DISENO_GODOT.md` §11) — esto se
escribió leyendo, sin ejecutar. Si tira un error:

**copiar el mensaje de la terminal tal cual, sin resumirlo.**

Hay `print()` de diagnóstico al arrancar; corriendo el proyecto desde la
terminal aparecen directo en la consola.

## Archivos

```
project.godot           escena principal: escenas/Mundo.tscn
escenas/Mundo.tscn      raíz + cámara + sol (lo demás se construye por código)
scripts/mundo.gd        arma la grilla, el personaje y la cámara; lee la entrada
scripts/personaje.gd    LA REGLA: movimiento por celdas discretas
```

> **Nota de rendimiento, para más adelante:** hoy cada celda del piso es un
> `MeshInstance3D` aparte (21×21 = 441 nodos). A esta escala no importa,
> pero si la grilla crece mucho, la salida estándar es `MultiMeshInstance3D`
> (el equivalente en Godot del `InstancedMesh` que menciona `INFORME.md`
> §9.4). No hace falta todavía.

## Cómo se garantiza que la cámara no gire

No por disciplina, **por construcción**: la cámara se orienta una sola vez
en `_colocar_camara()` (con un `look_at`) y a partir de ahí el código solo
le cambia la **posición**, nunca la rotación. No hay ninguna línea que
pueda girarla por accidente.

El ángulo es el isométrico **verdadero** (elevación 35.264°, azimut 45°),
y no está escrito a mano: sale solo de poner la cámara en
`objetivo + (k, k, k)` mirando al objetivo — la dirección de vista queda
`(-1,-1,-1)/√3`, o sea `asin(1/√3) = 35.264°`.

**Suavizar el seguimiento es seguro para el acertijo.** Con una cámara
ortográfica de rotación fija, trasladarla no cambia las posiciones
relativas en pantalla entre dos objetos del mundo — solo rotarla las
cambiaría. Por eso el suavizado no puede romper la lectura de las
alineaciones.

> **Corrección de una imprecisión del README anterior:** ahí decía que la
> matemática de proyección (`proyeccion.js`) era lo que definía la etapa 2.
> No es así — según `DISENO_GODOT.md` §10, la etapa 2 es solo la cámara.
> La proyección se necesita para la **etapa 4** (la regla "puedes pisar lo
> que se ve pegado a ti").
