# godot/ — prototipo por etapas

> **Antes de tocar cualquier cosa acá: leer `../DISENO_GODOT.md`.**
> Este prototipo se construye por etapas chicas definidas ahí (§10). Si lo
> que vas a escribir no está en ese documento, no se escribe: se propone,
> se acuerda, se anota, y recién después se construye.

## Estado: el diorama de Burdeo, en zonas modulares

**Tres zonas del lore**, cada una un espacio en sí mismo con su propio
acertijo, su propio centro de giro y su propia rotación recordada:

| Zona | Qué es | Acertijo |
|---|---|---|
| **ciudad** | Burdeo: las calles y las dos torres (Burdeo BB) | sí — el mirador de las torres |
| **playa** | "conectada a Burdeo dentro del mismo mapa" | no, a propósito: un lugar donde estar |
| **luna** | "el satélite de la ciudad" | sí, más chico y más alto |

Se viaja pisando las **esferas celestes** (portales). Arriba de las torres
de la ciudad —a donde solo se llega resolviendo el acertijo— está el portal
a la luna: el premio de resolverlo. A ras de suelo hay otro a la playa.

### La ilusión: son espacios distintos

Los espacios **no comparten coordenadas**. Cada uno es independiente y la
sensación de que forman un mismo diorama la da el **viaje de la cámara**.

Se probó primero la otra forma —todas las zonas superpuestas en un mismo
sistema de coordenadas— y falló por dos motivos medidos: hacía falta una
cámara de 36 unidades (todo diminuto), y cada zona tenía que abrirse en una
rotación distinta *a la vez*, así que **mover una rompía otra**.

Con zonas modulares, **cada una se valida sola**. Agregar una zona no puede
romper las demás. Eso es lo que hace que esto escale.

> **Simplificación conocida:** al entrar a una zona siempre aparecés en su
> celda de partida, no al lado del portal por el que llegaste. Se nota al
> volver a la ciudad desde la playa. Falta que cada portal declare su celda
> de llegada.

## El mecanismo dentro de cada zona

**Lo que convierte esto en un juego es que haya un lugar imposible de
alcanzar que, al rotar, se vuelve alcanzable.**

### Cómo jugarlo

1. Abrir `godot/project.godot` con Godot 4.x (NO la raíz del repo).
2. F5 / Play.

| | Teclado | Control |
|---|---|---|
| **Caminar** | Flechas | Stick izquierdo / D-pad |
| **Rotar el mundo** | `A` y `D` | `LB` y `RB` |

**Mantener apretado camina.** El personaje encadena pasos sin frenar entre
celda y celda, bambolea al andar y encara la dirección a la que va. Su
estado sigue siendo una celda discreta — lo que cambió es solo cómo se
dibuja. Números para tocar, arriba de `scripts/personaje.gd`:
`DURACION_PASO`, `AMPLITUD_BAMBOLEO`, `INCLINACION`, `VELOCIDAD_GIRO`.

### El acertijo

En la ciudad hay **dos islas**: las calles (donde arrancás, abajo) y las
torres (arriba, a 7 de altura), con una **esfera dorada** encima que marca
el mirador.

Están separadas por un abismo real de **22 celdas**. No hay puente, no hay
rampa, no hay escalera. Desde la rotación en la que arrancás, el mirador es
sencillamente **inalcanzable**.

**Rotá el mundo** y mirá qué pasa con las dos islas en pantalla. En una de
las cuatro rotaciones —y solo en una— se ven *pegadas*. Y si se ven
pegadas, se pueden pisar.

> Esa es la regla entera del juego, sin excepciones:
> **puedes pisar lo que se ve pegado a ti.**
> No lo que está al lado en el mundo — lo que está al lado en la PANTALLA.

### Si no se te ve, no podés romper la ilusión

Al rotar, el personaje puede quedar **tapado** por la otra isla. Desde ahí
**no se puede cruzar un puente** — pero sí se puede seguir caminando, y
sobre todo volver por donde viniste.

Quedar tapado es inevitable y está bien. Lo que no puede pasar es *saltar*
estando tapado: el salto se vería salir de la nada y aterrizar solo, que es
teletransporte y no descubrimiento — el jugador ni siquiera puede ver desde
dónde saltó. No es una excepción a la regla: es su otra mitad.

> Antes esto bloqueaba **todo** el movimiento y era un softlock. Se corrigió:
> el movimiento tiene que sentirse libre; lo único que se impide es romper
> la ilusión. Si intentás cruzar estando tapado, la consola avisa.

Cuando cruces, el paso se siente distinto a propósito: dura más y el
personaje describe un arco alto. Es la única pista que da el sistema de que
acabás de hacer algo que no era obvio. Por la terminal sale
`¡PUENTE IMPOSIBLE!` con el salto real en celdas.

### Qué mirar

- **¿Se entiende el truco?** ¿Se ve que en una rotación las islas se juntan?
- **¿El cruce se siente distinto a caminar?** Debería sentirse raro, casi
  ilegal.
- **¿La rotación se lee?** Tiene que dar tiempo a ver *qué* cambió sin
  aburrir. Ajustable: `DURACION_GIRO` (hoy `0.38`).
- **¿Se ven las dos islas siempre?** Es requisito: el acertijo se resuelve
  comparándolas. Si alguna se sale de cuadro, subir `tamano_camara` de esa
  zona.
- **¿El viaje entre zonas se siente como un salto?** RR lo pidió como
  "saltos de cámara". Ajustable: `DURACION_VIAJE` (hoy `0.55`).

## El nivel está verificado matemáticamente

No pude correr Godot, **pero sí pude correr la matemática**. El nivel se
buscó por barrido de parámetros con BFS, replicando `proyeccion.js` y
`navegacion.js`, y cumple:

| Propiedad | Valor |
|---|---|
| Superficie caminable (ciudad) | 72 celdas (2 islas de 6×6) |
| Rotaciones que resuelven | **solo la 0** |
| Rotación inicial | 2 (no resuelve → hay acertijo) |
| Salto del puente | 22 celdas de mundo |
| Celdas tapadas en rot. 0 | 16 (las islas se funden en pantalla) |

La luna tiene su propio acertijo, verificado igual y por separado.

El dato que mejor muestra el efecto Magic Eye: el nivel entero ocupa
**7.07 × 5.72** unidades de pantalla en la rotación 0 (todo superpuesto) y
**17.15** de alto en la rotación 2 (todo desplegado). Es el mismo mundo.

Además, `Navegacion.validar()` **vuelve a comprobarlo en cada arranque** y
avisa por consola. Un nivel se rompe de **tres** formas, y las tres son
mudas si nadie las comprueba:

1. El objetivo queda **inalcanzable** en las cuatro rotaciones.
2. El objetivo se alcanza **ya en la rotación inicial** → no es acertijo.
3. *(aviso, ya no falla)* Una celda que no se ve en **ninguna** rotación.
   Dejó de ser un softlock cuando el bloqueo pasó a impedir solo el salto,
   pero sigue siendo un olor de diseño: el jugador puede pararse donde no
   se lo ve nunca.

> El BFS **no puede detectar la tercera**: explora dentro de una rotación
> fija, nunca rota, así que jamás se topa con el caso "quedé tapado al
> rotar". Tiene su propia comprobación aparte.

> ⚠️ **Los números de cada zona no se tocan a ojo** (`_definir_zonas()` en
> `mundo.gd`). Mover una isla UNA celda puede romper el acertijo en
> cualquiera de las dos direcciones. Si los cambiás, mirá lo que dice
> `[nivel]` en la consola, o corré `herramientas/verificar_nivel.py`.

## Las dos trampas que este código evita a propósito

**1. Los dos contadores de rotación.** El giro guardado por zona nunca da
la vuelta (…, -1, 0, 1, 2, 3, 4, …) y sirve para animar; `_rotacion()` es
ese valor módulo 4 y es el que usa la matemática. Con un solo contador,
pasar de la rotación 3 a la 0 hacía girar el mundo **270° hacia atrás** en
vez de 90° adelante. Costó caro: 815% de desviación medida en pantalla, y
se sospechó de la proyección, que estaba bien (`INFORME.md` §6).

**2. Rotaciones con enteros, sin senos ni cosenos.** La comparación entre
dos posiciones de pantalla es de **igualdad exacta**. Con trigonometría, el
error de coma flotante haría que el puente apareciera y desapareciera de
forma intermitente — el peor tipo de bug, el que parece un fantasma.

Y una tercera, corregida al portar: `navegacion.js` decidía qué celda se ve
(cuando dos caen en el mismo píxel) comparando `x + z` **sin rotar**, lo
cual solo vale en la rotación 0. Acá se compara la **altura**, que es
equivalente y correcto en las cuatro — la demostración está en el comentario
de `navegacion.gd`.

## La regla que no se rompe

`personaje.gd` **no** es un `CharacterBody3D`, **no** usa `move_and_slide()`,
**no** tiene gravedad ni velocidad continua. El estado del personaje es una
celda entera (`Vector3i`).

No es preferencia de estilo: la regla del juego compara posiciones en
pantalla buscando igualdad **exacta**, y con posiciones continuas esa
igualdad no ocurre nunca. Ver `DISENO_GODOT.md` §3 — es la causa raíz del
prototipo que hubo que tirar.

Lo continuo es la **animación**. Lo discreto es el estado.

## Qué NO está, a propósito

- **La revelación** (la cámara que se suelta, la portada, la canción). Por
  ahora llegar al mirador solo apaga la baliza e imprime un mensaje.
- El zoom-cuerda y el dashboard (etapa 6), el tilt-shift (etapa 7).
- Las zonas del lore, el cometa, las épocas, el arte, el sonido.
- Identidad visual: todo gris neutro. El contraste entre celdas vecinas
  **sí** es funcional (sin él no se pueden contar celdas, y contar celdas
  es como se lee la alineación), no decorativo.

## Si algo falla

El agente **no puede correr Godot** (`DISENO_GODOT.md` §11) — esto se
escribió leyendo, sin ejecutar. Si tira un error:

**copiar el mensaje de la terminal tal cual, sin resumirlo.**

Al arrancar imprime el estado del nivel, y cada rotación y cada puente
salen por consola.

## Archivos

```
project.godot            escena principal: escenas/Mundo.tscn
escenas/Mundo.tscn       raíz + cámara + sol
scripts/proyeccion.gd    LA MATEMÁTICA: la ambigüedad isométrica (A, B)
scripts/navegacion.gd    LA REGLA: "puedes pisar lo que se ve pegado a ti"
scripts/personaje.gd     movimiento por celdas discretas + animación del paso
scripts/mundo.gd         las zonas, los pivotes que rotan, el viaje de cámara
herramientas/            validar niveles sin abrir Godot (ver su README)
```

`proyeccion.gd` y `navegacion.gd` son **datos puros**: no saben de mallas ni
de nodos. Es la misma separación en capas que rige en `src/` (`CLAUDE.md`).
