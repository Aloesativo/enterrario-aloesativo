# godot/ — prototipo por etapas

> **Antes de tocar cualquier cosa acá: leer `../PREPRODUCCION.md` y después
> `../DISENO_GODOT.md`.** Si lo que vas a escribir no está en esos
> documentos, no se escribe: se propone, se acuerda, se anota, y recién
> después se construye.

## Estado: los DOS registros, con la frontera entre ellos

RR probó el prototipo y dijo que el personaje tiene que verse **en tercera
persona**, habitando un entorno 3D común y corriente, y que la isometría pase
a funcionar **de manera cinematográfica**. Eso es lo que hay ahora:

| | **Registro HABITAR** | **Registro ACERTIJO** |
|---|---|---|
| Qué es | una isla habitable en tercera persona | el estereograma: el truco isométrico |
| Cámara | perspectiva, sigue al personaje, la movés vos | ortográfica isométrica verdadera, **rígida** |
| Movimiento | continuo, con peso | celdas discretas, un paso por empujón |
| Script | `habitar.gd` + `caminante.gd` | `acertijo.gd` + `personaje.gd` |

Y entre los dos, `frontera.gd`.

### Lo que hay que mirar primero: la toma

Los tres santuarios **flotan sobre la isla**, visibles desde abajo como
monumentos, cada uno con su arco al pie. Cruzás el arco caminando y:

> **la cámara vuela hacia el santuario mientras cierra el FOV, y el mundo se
> aplana ante tus ojos en una sola toma continua.**

No es un corte ni una pantalla de carga: es un dolly zoom. Una perspectiva de
FOV muy chico es visualmente indistinguible de una ortográfica, así que al
final de la toma el cambio de proyección ocurre en un frame donde no se ve. El
FOV exacto sale de igualar lo que abarcan las dos proyecciones a la distancia
del objetivo — la derivación está arriba de `frontera.gd`.

Eso es "la isometría funcionando de manera cinematográfica": la isometría es
un **plano de cámara** y sigue siendo la **mecánica**, sin sacrificar ninguna
de las dos.

## Cómo jugarlo

1. Abrir `godot/project.godot` con Godot 4.x (NO la raíz del repo).
2. F5 / Play. Arrancás en el registro **habitar**, en el centro de la isla.

| | Teclado / mouse | Control |
|---|---|---|
| **Caminar** (habitar) | Flechas | Stick izquierdo / D-pad |
| **Mirar** (habitar) | `Q` y `E`, o arrastrar con el botón **derecho** | Stick derecho |
| **Entrar a un santuario** | caminar y cruzar el arco | ídem |
| **Dar un paso** (acertijo) | Flechas | Stick izquierdo / D-pad |
| **Rotar el mundo** (acertijo) | `A` y `D` | `LB` y `RB` |
| **Volver al mundo habitado** | pisar la esfera **verde**, o `Escape` | botón `B` |

Cero controles en pantalla y todo pre-mapeado de fábrica: conectás el control
y anda, sin pantalla de configuración (requisito duro de RR).

> **Dos formas de salir del acertijo, a propósito.** La esfera verde es la
> salida diegética; `Escape`/`B` es la de emergencia. Quedar encerrado dentro
> de una zona **ya pasó una vez** en este proyecto (CLAUDE.md, "Bug del
> mapa-zoom sin vuelta atrás") y no se repite por ahorrar un `if`.

## Qué mirar, y en este orden

Son dos preguntas distintas y conviene no mezclarlas — si la primera falla, la
segunda no se puede juzgar:

**1. El registro habitar (etapa A).** Antes de cruzar ningún arco, caminá un
rato por la isla.
- **¿Se siente que habitás un lugar, o que movés una ficha?** Es LA pregunta.
- ¿El personaje tiene escala creíble contra las torres, los muros bajos y los
  arcos? (los arcos miden 2.4 contra 1.0 del personaje, a propósito)
- ¿La cámara acompaña bien, o marea / va por detrás?
- Números para tocar, arriba de `habitar.gd`: `DISTANCIA_CAMARA` (lo primero
  que hay que mover si no se siente tercera persona), `ALTURA_FOCO`,
  `PITCH_REPOSO`, `SUAVIZADO_FOCO`. Y en `caminante.gd`: `VELOCIDAD`,
  `ACELERACION`, `FRENADA`.

**2. La frontera (etapa C).** Recién después, cruzá un arco.
- **¿El aplanado se siente como un plano de cine?**
- ¿Entrar y salir se entiende sin que nadie lo explique?
- ¿El **fundido cruzado** se lee? Cerca del final de la toma la isla se
  disuelve mientras el personaje aparece dentro del santuario. Si se siente
  apurado, bajar `INICIO_FUNDIDO` en `frontera.gd` (0.55 → 0.40); si tapa
  demasiado pronto el vuelo, subirlo (0.70).
- Duración: `DURACION_ENTRADA` (1.6) y `DURACION_SALIDA` (1.2).

> **Por qué un fundido y no un apagón.** La primera versión apagaba el mundo
> habitado de golpe al final de la toma, dando por hecho que a esa altura ya
> había quedado fuera de cuadro. Se comprobó con números y **era falso**: con
> la cámara isométrica a 35.264° la isla de 40×40 cae DENTRO del encuadre de
> los tres santuarios, y elevar las zonas no lo arregla (empuja fuera los
> puntos de abajo pero mete los de arriba — playa tendría que estar a y=50).
> El fundido no depende del encuadre, así que es correcto por construcción y
> no por suerte geométrica.

**3. El acertijo (ya probado).** Debería andar igual que antes — si cambió
algo, es una regresión y vale reportarla como tal.

## El mecanismo dentro de cada santuario

**Lo que convierte esto en un juego es que haya un lugar imposible de
alcanzar que, al rotar, se vuelve alcanzable.**

En la ciudad hay **dos islas**: las calles (donde arrancás, abajo) y las
torres (arriba, a 7 de altura), con una **esfera dorada** encima que marca el
mirador. Están separadas por un abismo real de **22 celdas**. No hay puente,
no hay rampa, no hay escalera. Desde la rotación en la que arrancás, el
mirador es sencillamente **inalcanzable**.

**Rotá el mundo** y mirá qué pasa con las dos islas en pantalla. En una de las
cuatro rotaciones —y solo en una— se ven *pegadas*. Y si se ven pegadas, se
pueden pisar.

> Esa es la regla entera del juego, sin excepciones:
> **puedes pisar lo que se ve pegado a ti.**
> No lo que está al lado en el mundo — lo que está al lado en la PANTALLA.

Se viaja entre santuarios pisando las **esferas celestes**. Arriba de las
torres —a donde solo se llega resolviendo el acertijo— está el portal a la
luna: el premio de resolverlo.

### Si no se te ve, no podés romper la ilusión

Al rotar, el personaje puede quedar **tapado** por la otra isla. Desde ahí
**no se puede cruzar un puente** — pero sí se puede seguir caminando, y sobre
todo volver por donde viniste.

Quedar tapado es inevitable y está bien. Lo que no puede pasar es *saltar*
estando tapado: el salto se vería salir de la nada y aterrizar solo, que es
teletransporte y no descubrimiento. No es una excepción a la regla: es su otra
mitad.

Cuando cruces, el paso se siente distinto a propósito: dura más y el personaje
describe un arco alto. Es la única pista que da el sistema de que acabás de
hacer algo que no era obvio. Por la terminal sale `¡PUENTE IMPOSIBLE!` con el
salto real en celdas.

## El nivel está verificado matemáticamente

No pude correr Godot, **pero sí pude correr la matemática**. El nivel se buscó
por barrido de parámetros con BFS, replicando `proyeccion.js` y
`navegacion.js`, y cumple:

| Propiedad | Valor |
|---|---|
| Superficie caminable (ciudad) | 72 celdas (2 islas de 6×6) |
| Rotaciones que resuelven | **solo la 0** |
| Rotación inicial | 2 (no resuelve → hay acertijo) |
| Salto del puente | 22 celdas de mundo |
| Celdas tapadas en rot. 0 | 16 (las islas se funden en pantalla) |

La luna tiene su propio acertijo, verificado igual y por separado. Además,
`Navegacion.validar()` **vuelve a comprobarlo en cada arranque** y avisa por
consola.

> ⚠️ **Qué se puede tocar y qué no** (`_definir_zonas()` en `acertijo.gd`) — la
> distinción importa y no era obvia:
>
> - **`origen` es SEGURO de mover.** Solo coloca la zona en el espacio del
>   mundo. La matemática trabaja en coordenadas de **celda** relativas a
>   `centro`, así que trasladar una zona no cambia ninguna alineación. (Es lo
>   que se hizo para elevar los santuarios sobre la isla: comprobado corriendo
>   `herramientas/verificar_nivel.py` después del cambio.)
> - **`areas`, `centro`, `partida`, `acertijo` y `rotacion_inicial` NO se
>   tocan a ojo.** Mover una isla UNA celda puede dejar el acertijo sin
>   solución o quitarle la gracia, **en silencio**.

## Las trampas que este código evita a propósito

**1. Los dos contadores de rotación.** El giro guardado por zona nunca da la
vuelta (…, -1, 0, 1, 2, 3, 4, …) y sirve para animar; `_rotacion()` es ese
valor módulo 4 y es el que usa la matemática. Con un solo contador, pasar de
la rotación 3 a la 0 hacía girar el mundo **270° hacia atrás**. Costó caro:
815% de desviación medida en pantalla (`INFORME.md` §6).

**2. Rotaciones con enteros, sin senos ni cosenos.** La comparación entre dos
posiciones de pantalla es de **igualdad exacta**. Con trigonometría, el error
de coma flotante haría que el puente apareciera y desapareciera de forma
intermitente — el peor tipo de bug, el que parece un fantasma.

**3. El giro se sigue animando aunque el registro esté apagado.** Si no,
apagar el acertijo a mitad de una rotación dejaría el pivote en un ángulo que
no es múltiplo de 90°, y ahí **todas** las alineaciones quedan mal sin que
nada avise.

**4. El fundido va en tramos distintos según el sentido.** Entrando se vuela de
cerca a lejos, así que el fundido va **al final**; saliendo se vuela de lejos a
cerca, así que va **al principio**. En los dos casos ocurre con la cámara
lejos, que es donde se lee como una disolución. Usar el mismo tramo para los
dos hace que al volver el mundo se materialice en la cara del jugador.

**5. Sin niebla, y a propósito.** La cámara pasa de ~6.5 a ~69 unidades de
distancia durante la toma, así que cualquier distancia de niebla fija estaría
mal en alguno de los dos extremos. Es la misma trampa que ya costó cara en el
track de Three.js (CLAUDE.md, "Lección del bug de niebla").

## La regla que no se rompe — y cómo cambió de alcance

`personaje.gd` (registro acertijo) **no** es un `CharacterBody3D`, **no** usa
`move_and_slide()`, **no** tiene gravedad ni velocidad continua. Su estado es
una celda entera (`Vector3i`).

`caminante.gd` (registro habitar) **sí** es todo eso — y ahí es lo correcto.

No es una contradicción: la prohibición **se localizó, no se relajó**. Existe
porque la regla del acertijo compara posiciones en pantalla buscando igualdad
**exacta**, y esa comparación solo vive dentro del acertijo. En el registro
habitar no hay ninguna igualdad exacta que romper.

> ⚠️ **El modo de fallar nuevo:** filtrar un registro dentro del otro. Si
> algún día `move_and_slide()` aparece en `personaje.gd`, el juego se rompe
> igual que se rompió antes. Por eso son dos scripts que no se importan entre
> sí y no comparten estado: lo único que comparten es el cuerpo que dibujan
> (`cuerpo.gd`), para que se lea como **un solo ser** en los dos registros.

## Qué NO está, a propósito

- **El registro habitar no tiene mecánica propia todavía** — caminar y mirar
  es traslado, no mecánica. Es el **riesgo #1** de esta estructura
  (`PREPRODUCCION.md` §3): si no se llena, el juego queda como un pasillo
  entre cuartos de acertijo. Lo que va ahí es el material de `DISENO_GODOT.md`
  §6: el peso del paso, plantar, el mundo que recuerda.
- **La revelación** al resolver (la portada, la canción) — etapa D. Hoy llegar
  al mirador solo apaga la baliza e imprime un mensaje.
- El zoom-cuerda y el dashboard en miniatura (etapa E).
- **El borde del mundo** sigue sin decidir (`PREPRODUCCION.md` §8). Mientras
  tanto hay muros invisibles en el perímetro de la isla: caerse al vacío sin
  fondo sería un softlock, y eso es peor que un límite provisional.
- **La cámara de habitar no esquiva obstáculos.** Si se mete dentro de una
  torre, es esto: se dejó fuera a propósito para no depender de un
  `SpringArm3D` que el agente no puede probar. Si molesta, se agrega.
- Las zonas del lore que faltan, el cometa, las épocas, el arte, el sonido.
- Identidad visual: todo gris neutro. El contraste entre celdas vecinas **sí**
  es funcional (sin él no se pueden contar celdas, y contar celdas es como se
  lee la alineación), no decorativo.
- **El guardado** no existe: cada arranque empieza de cero.

## Si algo falla

El agente **no puede correr Godot** (`DISENO_GODOT.md` §11) — esto se escribió
leyendo, sin ejecutar. Si tira un error:

**copiar el mensaje de la terminal tal cual, sin resumirlo.**

Al arrancar imprime el estado de cada nivel, y cada cambio de registro,
rotación y puente sale por consola con su prefijo (`[frontera]`, `[habitar]`,
`[acertijo]`, `[nivel]`).

## Archivos

```
project.godot            escena principal: escenas/Mundo.tscn
escenas/Mundo.tscn       raíz + cámara + sol + los dos registros

scripts/frontera.gd      EL ÁRBITRO: qué registro manda + la toma que aplana
scripts/habitar.gd         registro habitar: la isla, los arcos, la cámara 3ª persona
scripts/caminante.gd       registro habitar: movimiento continuo (CharacterBody3D)
scripts/acertijo.gd        registro acertijo: las zonas, los pivotes, el viaje de cámara
scripts/personaje.gd       registro acertijo: pasos por celdas + animación del andar
scripts/cuerpo.gd        el cuerpo visual, COMPARTIDO por los dos registros

scripts/proyeccion.gd    LA MATEMÁTICA: la ambigüedad isométrica (A, B)
scripts/navegacion.gd    LA REGLA: "puedes pisar lo que se ve pegado a ti"
herramientas/            validar niveles sin abrir Godot (ver su README)
```

`proyeccion.gd` y `navegacion.gd` son **datos puros**: no saben de mallas ni de
nodos. Es la misma separación en capas que rige en `src/` (`CLAUDE.md`).
