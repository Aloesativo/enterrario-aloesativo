# Preproducción — Enterrario

> **Qué es este documento.** La fase de diseño general que RR pidió el
> 2026-08-10, *antes* de escribir más código: "siento que me falta más
> diseño general y una preproducción antes de empezar a hacer código".
>
> **Cómo se relaciona con los otros documentos del repo:**
>
> | Documento | Qué es |
> |---|---|
> | `IDEAS_DISENO.md` | volcado de ideas sin filtrar (staging) |
> | `INFORME.md` | qué existe hoy en `src/` (Three.js) y por qué |
> | `DISENO_GODOT.md` | el diseño de lo que se construye en `godot/` |
> | **este archivo** | **la estructura del juego entero: registros, bucle, alcance, riesgos** |
>
> `DISENO_GODOT.md` sigue siendo la fuente de verdad de *cómo* se
> construye. Este documento define *qué* se construye y en qué jerarquía —
> y corrige a `DISENO_GODOT.md` en un punto estructural (§3 de ese archivo).

---

## 0. El problema que disparó esta fase

RR probó el prototipo y detectó algo que ningún documento del repo había
nombrado:

> El personaje tiene que verse en tercera persona y habitar un entorno 3D
> común y corriente. Ahora se ve solamente isométrico, y la idea es que la
> isometría funcione de manera **cinematográfica**. Siento que estamos
> construyendo mal el juego.

Esto no era una queja de encuadre. Era un choque estructural, y vale
escribirlo entero porque explica por qué había que parar:

**En el diseño anterior, la isometría no era un look: era el mecanismo.**
La regla central ("puedes pisar lo que se ve pegado a ti") compara
posiciones en pantalla buscando **igualdad exacta**, y esa igualdad solo
existe en proyección ortográfica isométrica verdadera con la cámara
**rígida**. `INFORME.md` §3 lo dice sin ambigüedad: la cámara mecánica *es
aburrida a propósito*, porque si se moviera sola las alineaciones que el
jugador tiene que leer cambiarían sin que él lo pidiera.

De ahí la incompatibilidad: **"la isometría es cinematográfica" y "el
estereograma es el core" no podían ser verdad al mismo tiempo.** Una
cámara de tercera persona en perspectiva, al hombro, no degrada la
matemática del puente imposible: la elimina.

Había además una segunda causa, más barata y más fácil de pasar por alto:
la cámara de Godot está en `size = 20` con un personaje de ~1 celda. El
personaje ocupa alrededor del 5% del cuadro. **Eso solo ya hace que se lea
como ficha sobre una maqueta y no como cuerpo en un lugar**, con total
independencia de la proyección. FEZ y Monument Valley son ortográficos y
se habitan igual: lo que hace la diferencia es el tamaño del personaje en
cuadro, la arquitectura vertical y la intimidad de la cámara.

Las dos causas juntas explican por qué la sensación era "esto está mal
construido" y no "esto está mal encuadrado".

---

## 1. La decisión: dos registros con frontera explícita

**Decisión de RR, 2026-08-10.** El juego tiene **dos registros de juego**,
con una frontera visible y deliberada entre ambos.

| | **Registro HABITAR** | **Registro ACERTIJO** |
|---|---|---|
| Qué es | un entorno 3D común y corriente, habitado en tercera persona | el estereograma: el truco isométrico |
| Cámara | perspectiva, tercera persona, sigue al personaje | ortográfica isométrica verdadera, **rígida** |
| Movimiento | **continuo** — libre, con peso | **celdas discretas** — un paso por empujón |
| Verbos | caminar, mirar, interactuar con el mundo | paso a celda, rotar el mundo 90° exactos |
| Referencias | Short Hike, Death Stranding, Death's Door | FEZ, Monument Valley |
| Estado hoy | **no existe** — hay que construirlo | **existe y anda** (`godot/`) |

**La isometría pasa a ser un plano de cámara *y sigue siendo mecánica*
donde importa.** No se sacrifica ninguna de las dos cosas: se las separa.

### Por qué esto no relaja la regla que mató al prototipo 2

`DISENO_GODOT.md` §3 prohibía el movimiento continuo de forma **universal**
("nunca con velocidad continua ni `move_and_slide()`"), y esa prohibición
es la causa raíz documentada del prototipo que hubo que tirar.

Esa regla **no se relaja: se localiza.**

> **Dentro del registro acertijo la prohibición sigue siendo absoluta.**
> Celdas discretas, `Vector3i`, sin `move_and_slide()`, sin gravedad, sin
> velocidad continua. Ahí no cambió nada, y no puede cambiar: es condición
> de existencia del core (§2 de `DISENO_GODOT.md`).
>
> **Dentro del registro habitar el movimiento continuo es lo correcto**,
> porque ahí no hay ninguna comparación de igualdad exacta que romper.

Lo que antes era una bomba (movimiento continuo en cualquier parte del
código) ahora tiene un lugar legítimo y acotado. Pero el peligro cambia de
forma, y hay que nombrarlo:

> ⚠️ **El nuevo modo de fallar.** Antes el error era escribir movimiento
> continuo. Ahora el error es **filtrar un registro dentro del otro**:
> meter `move_and_slide()` en el acertijo (lo rompe), o exigir celdas
> discretas al caminar por la ciudad (lo vuelve rígido sin motivo). Cada
> registro tiene su carpeta y sus scripts; si un script necesita saber en
> qué registro está para decidir cómo se mueve, eso ya es un olor.

---

## 2. La frontera: cómo se pasa de un registro al otro

Esta es la pieza de diseño **nueva**, y la más importante de este
documento: no existía en ningún diseño anterior.

### El umbral es un objeto del mundo, no un menú

Se entra al registro acertijo **cruzando un umbral físico visible** —
una puerta, un arco, un círculo en el suelo, un santuario. El jugador
entra a propósito; la cámara nunca lo agarra por sorpresa.

Esto respeta dos requisitos duros ya establecidos: **cero UI** (§4 de
`DISENO_GODOT.md`) e **interacción directa con el mundo, nunca con una
interfaz de sistema** (§1). Y encaja con "portales estilo Death's Door",
que ya estaba en `IDEAS_DISENO.md`.

**El santuario se ve desde afuera, desde el registro habitar.** Es
requisito, no adorno: desde lejos se lee como una maqueta imposible,
y eso es lo que hace que entrar sea deseable. Un umbral que no se ve
venir no es una invitación, es una trampa.

### La transición ES la isometría funcionando de manera cinematográfica

No hay fundido a negro, ni cambio de escena, ni pantalla de carga. La
cámara viaja en **una sola toma continua** desde el hombro del personaje
hasta la isométrica verdadera: **el mundo se aplana ante tus ojos.**

Y el mecanismo para hacerlo ya existe en el repo con otro nombre. El
*dolly zoom* (efecto vértigo) de `theme/planos.json → planosRevelacion`:
alejar la cámara mientras se baja el FOV. A FOV muy bajo la perspectiva es
**visualmente indistinguible** de la ortográfica, y ahí el cambio a
`Camera3D.PROJECTION_ORTHOGONAL` no se percibe.

> **Precedente concreto, no teoría:** `src/render/camera.js` renderiza hoy
> con una `PerspectiveCamera` de FOV bajo, y la matemática del estereograma
> es ortográfica — y el truco funciona igual, verificado por captura. El
> jugador **lee** la alineación, no la mide con un calibre. Esa tolerancia
> es exactamente el espacio donde vive la transición.
>
> Corolario importante: la transición se puede animar en perspectiva y el
> cambio de proyección puede ocurrir en el frame en que la diferencia es
> imperceptible. No hace falta interpolar entre dos proyecciones (Godot no
> lo permite) — hace falta llegar al punto donde da lo mismo.

**Lo que la construcción agregó a este diseño (2026-08-10, al implementarlo).**
El plan era apagar el mundo habitado al final de la toma, asumiendo que para
entonces habría quedado fuera de cuadro. Se comprobó con números y **es falso**:
con la cámara isométrica a 35.264° la isla habitable cae DENTRO del encuadre de
los tres santuarios, y elevarlos no lo arregla (empuja fuera los puntos de abajo
pero mete los de arriba). Así que la toma termina en un **fundido cruzado**: el
mundo habitado se disuelve mientras el personaje aparece dentro del santuario.

No es solo un parche: el cruce dice algo que el corte no decía — tu cuerpo se
disuelve en el mundo y reaparece dentro del acertijo. Y a diferencia del apagón,
no depende del encuadre, así que es correcto por construcción y no por suerte
geométrica.

### Las cuatro reglas de la frontera

1. **Al entrar, el personaje se acopla a la grilla.** La posición continua
   se convierte en celda. **El umbral declara su celda de entrada** — no se
   redondea a la más cercana. Redondear puede caer en una celda inválida o
   tapada, y eso es un softlock nacido en la costura.
   *(Esto resuelve de paso la simplificación pendiente de los portales,
   anotada en `godot/README.md`: "falta que cada portal declare su celda de
   llegada".)*

2. **Al salir, el personaje se desacopla desde el centro de su celda.**
   Vuelve a posición continua sin salto visible.

3. **El estado del acertijo se recuerda, la orientación también.** Cada
   zona ya guarda su propia rotación (`acertijo.gd`). Volvés a entrar y está
   como lo dejaste. Un acertijo resuelto queda resuelto para siempre —
   es la misma promesa que "el mundo recuerda lo que hiciste" (§6 de
   `DISENO_GODOT.md`).

4. **Volver al registro habitar devuelve la cámara a una orientación
   consistente, siempre la misma.** Es la misma regla dura que §7 de
   `DISENO_GODOT.md` ya exige para el zoom-out, y por el mismo motivo: si
   el jugador vuelve a un mundo orientado distinto, pierde el modelo mental
   que acababa de construir.

### Consecuencia sobre la órbita de cámara — corrige §4 de `DISENO_GODOT.md`

§4 decía: *"No hay órbita libre. La cámara del juego no se toca, ni un
poco."* Con dos registros, esa regla se parte en dos:

- **En habitar: sí hay control de cámara.** Es una tercera persona normal;
  el stick derecho / el mouse la mueven. Sin eso no se habita nada.
- **En acertijo: la prohibición sigue intacta y absoluta.** Ni un poco. La
  rigidez es la condición de que la alineación se pueda leer.

---

## 3. El bucle de juego (10 segundos / 10 minutos / 10 horas)

**Esto no existía en ningún documento del repo, y es la ausencia más
grande que encontró esta revisión.** Sin bucle, cada mecánica se justifica
sola y ninguna se justifica junto a las otras.

> ⚠️ Propuesta del agente, derivada de material ya acordado. Necesita el
> visto bueno de RR.

- **10 segundos — caminar y notar.** Camino por un entorno 3D en tercera
  persona y algo me llama: una silueta, un brillo, una forma que no calza
  con lo que la rodea. Me acerco a mirar.
  *Verbos: caminar, mirar.*

- **10 minutos — entrar y leer.** Encuentro un santuario. Cruzo el umbral,
  la cámara se aplana en una toma, y ahí el juego cambia de registro: el
  espacio se vuelve ambiguo y tengo que rotarlo hasta que dos cosas que
  estaban lejísimo se vean pegadas. Salgo con algo concreto: una canción,
  un lugar nuevo que ahora se ve, una forma nueva de mover la cámara.
  *Verbos: rotar, alinear, pisar lo imposible.*

- **10 horas — coleccionar y contemplar.** El mundo que parecía chico
  resultó tener capas. Tengo una colección de lo que encontré y de dónde lo
  saqué. Tiro la cuerda del zoom-out y el mundo entero se vuelve una
  miniatura con lo que junté, y suena.
  *Verbos: coleccionar, mirar de lejos, quedarse.*

### El problema #1 que abre esta estructura

**El registro habitar no tiene mecánica propia todavía.** Caminar y mirar
no es una mecánica: es un traslado. Si no se le da algo que hacer, el
resultado es un pasillo entre cuartos de acertijo — el modo de fallar
clásico de "Monument Valley pero caminando".

Lo que tiene que llenar ese registro **ya está escrito, suelto, en §6 de
`DISENO_GODOT.md`**, y ahora se entiende dónde va:

- **El peso del paso** (Death Stranding): caminar es el evento, no el
  transporte hacia lo interesante. Textura del paso por terreno.
- **El mundo recuerda**: lo que plantás sigue ahí, un camino muy recorrido
  se nota.
- **Plantar y modificar el espacio**, siempre sin menú.

O sea: el registro habitar es **el hogar de todo el material de §6**, que
hasta ahora no tenía dónde vivir porque en un juego de celdas discretas
esas ideas no calzaban bien. **Es la ganancia de diseño más grande de esta
decisión, y no era obvia de antemano.**

---

## 4. Qué pasa con los puzzles (§8 de `DISENO_GODOT.md`)

§8 estaba declarado como *"la pieza menos definida de todo el diseño"*, con
una pregunta abierta explícita: ¿el puzzle es el estereograma evolucionado,
o es otro sistema aparte?

**Esta decisión la responde en parte, gratis:** el estereograma **es** el
puzzle, y su lugar en la estructura son los santuarios. No es otro sistema.

Lo que sigue abierto de §8:
- Si además hay rompecabezas de otro tipo (mover un bloque, desatar un
  nudo) dentro de los santuarios, o si el estereograma alcanza solo.
- El gatillo exacto de desbloqueo. Lo dicho hasta hoy: resolver un
  santuario habilita **más mapa** y **nuevas formas de rotar la cámara**.

---

## 5. El alcance: la rebanada vertical

**Propuesta del agente.** La rebanada mínima que demuestra el juego
**entero** — no una pieza, el juego:

> Un tramo de la ciudad de Burdeo caminable en tercera persona · un
> santuario visible desde ese tramo · el acertijo que ya funciona, adentro ·
> la transición dolly zoom entre los dos · y una revelación al resolverlo.

Por qué esta y no otra: es lo único que pone a prueba **la frontera**, que
es la pieza nueva y la única que nadie ha visto funcionar. Todo lo demás
del repo o está verificado (el acertijo) o es contenido que se agrega
después sin riesgo estructural.

Lo que queda **explícitamente afuera** de la rebanada: las 7 zonas del
lore, las tres épocas, el cometa, los puzzles adicionales, el libro, el
reproductor-oráculo, el guardado, el arte, el sonido definitivo.

---

## 6. Plan por etapas — reemplaza §10 de `DISENO_GODOT.md`

El plan anterior (etapas 1 a 8) asumía **un solo registro**, el de celdas
discretas. Las etapas 1 a 5 de ese plan están **hechas y verificadas por
RR**, y siguen valiendo: son el registro acertijo. Lo que cambia es lo que
viene después.

Se mantiene el principio que sí funcionó: **etapas chicas, cada una
termina en algo que RR puede probar y sentir, y no se avanza sin que
confirme que la anterior anda.** El motivo sigue siendo el de §11 de
`DISENO_GODOT.md`: el agente no puede correr Godot, así que cada etapa
grande es una apuesta a ciegas — y las dos apuestas grandes que se hicieron
salieron mal.

| Etapa | Qué se construye | Qué prueba RR |
|---|---|---|
| **A** | **El registro habitar, solo.** Un tramo de suelo con relieve y algo de arquitectura vertical, personaje en tercera persona, cámara con `SpringArm3D`, movimiento continuo con peso. Sin acertijo, sin umbral, sin rotación. | ¿Se siente que **habito un lugar** y no que muevo una ficha? ¿El personaje tiene escala creíble? |
| **B** | **El registro acertijo: nada.** Ya existe y ya lo probaste. Solo se aísla en su propia carpeta/escena para que la frontera de la etapa C tenga dos lados limpios. | Que siga andando igual que hoy (prueba de no-regresión). |
| **C** | **La frontera.** El umbral visible, el dolly zoom que aplana el mundo en una toma, el acople/desacople a la grilla, la vuelta a orientación consistente. | ¿El aplanado se siente **como un plano de cine**? ¿Entrar y salir se entiende sin que nadie lo explique? |
| **D** | **La revelación al resolver.** Hoy resolver solo apaga una baliza e imprime por consola. Acá aparece la portada y suena. | ¿Resolver **paga**? |
| **E** | El zoom-cuerda y el dashboard en miniatura (§7 de `DISENO_GODOT.md`). | ¿Tirar la cuerda se siente como trabajo satisfactorio? |
| **F+** | Sin comprometer: las zonas del lore, las épocas por región, el guardado, la iluminación con bucle, el libro. | — |

> **La etapa C es la única con riesgo estructural real.** A y B son
> conocidas por separado. Si la frontera no se siente bien, el problema es
> de diseño y no de código, y hay que volver acá antes de seguir.

---

## 7. Riesgos, dichos en voz alta

1. **El registro habitar es contenido nuevo, no un port.** Ni `src/` ni
   `godot/` tienen nada de tercera persona, arquitectura a escala de cuerpo,
   colisiones o props. Todo lo verificado del repo sirve para el *otro*
   registro. Es la primera vez en este proyecto que hay que construir algo
   sin un diseño previo ya validado del que partir — exactamente la
   situación que produjo los dos fracasos de `DISENO_GODOT.md` §0. La
   mitigación es la etapa A aislada y chica.

2. **Dos sistemas de movimiento es el doble de superficie de bugs**, y el
   agente no puede probar Godot (§11). Mitigación: la frontera se construye
   **última** (etapa C), con cada lado ya probado por separado.

3. **El contraste sigue siendo mecánica, no estética** (§6 ter de
   `DISENO_GODOT.md`). En el registro habitar aparece un riesgo nuevo:
   una cámara de tercera persona con niebla, profundidad de campo o bloom
   puede verse preciosa y volver **ilegible** el santuario que hay que ver
   desde lejos. Ya hay tres precedentes documentados de esto (el
   tilt-shift, la niebla, el sol cenital).

4. **La legibilidad de dos registros para el jugador.** Un juego que cambia
   de reglas de movimiento a mitad de camino puede confundir. La mitigación
   es que la frontera sea **visible y física** (§2): el umbral se ve, la
   cámara hace un gesto inconfundible, y el cambio de reglas coincide
   exactamente con el cambio de imagen. Si alguna vez el registro cambia
   sin que se vea, eso es un bug de diseño.

---

## 8. Lo que sigue sin decidir

Se anota para que no se pierda, tal como está.

- **El guardado.** "El mundo recuerda lo que dejaste" implica persistencia
  y nunca se diseñó. Ahora hay más que guardar que antes: estado de cada
  santuario, rotación por zona, posición continua en el mundo habitado,
  hallazgos. Decidirlo tarde duele.
- **El borde del mundo.** El mundo es acotado a propósito; falta decidir
  qué ve el jugador al llegar al límite. En tercera persona esto se nota
  **mucho más** que en isométrica fija, porque el jugador puede ir a
  mirarlo de cerca.
- **Cómo se sienten las transiciones entre épocas** (el hilo de la droga
  como puente entre el plano moderno y el onírico).
- **Combate / conflicto jugable:** hoy es no. Revisable, pero es no.
- **Identidad visual.** La elige RR, siempre. Todo placeholder gris hasta
  entonces, con una sola restricción no negociable: una elección de paleta
  que vuelva ilegible una alineación se reporta como **bug de jugabilidad**,
  no se acepta en silencio.

---

## 9. Qué pasa con `src/` (Three.js)

Sin cambios respecto de lo ya acordado: **no se toca ni se borra** mientras
Godot no esté verificado corriendo en la máquina de RR. Es la referencia
funcional del diseño y lo único mostrable hoy en
`https://aloesativo.github.io/enterrario-aloesativo/`.

Con esta decisión, `src/` gana un rol adicional: **es la única
implementación existente de la transición perspectiva → casi-ortográfica**
(`camera.js`, el dolly zoom de `planos.json`). La etapa C porta desde ahí,
no reinventa. La regla de `DISENO_GODOT.md` §12 sigue valiendo palabra por
palabra: **portar, no reinventar** — los dos fracasos fueron exactamente
inventar algo más simple en vez de partir del diseño ya validado.
