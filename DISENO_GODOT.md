# Diseño del prototipo Godot — Enterrario

> **Qué es este documento.** El diseño acordado en conversación entre RR y
> el agente (2026-08-09), escrito ANTES de programar nada, después de que
> dos intentos de prototipo en Godot se construyeran sin un diseño escrito
> y terminaran rotos. No es un informe de lo que existe (eso es
> `INFORME.md`), ni un volcado de ideas sin filtrar (eso es
> `IDEAS_DISENO.md`): es lo que se va a construir, en qué orden, y qué
> queda explícitamente afuera por ahora.
>
> **Regla de uso.** Si una sesión futura va a escribir código en `godot/`,
> lee esto primero. Si lo que va a escribir no está acá, no lo escribe:
> lo propone, se acuerda, se anota, y recién después se construye.

---

## 0. Por qué existe este documento (los dos fracasos)

Vale la pena escribirlo porque el patrón se repitió dos veces y va a
volver a repetirse si nadie lo nombra.

**Fracaso 1 — el mapa-zoom inventado.** El primer `godot/` se construyó
sin mirar `src/mundo/`: mapa plano con cajas-marcador y un zoom que
teletransportaba a una escena separada por zona. No era el juego que RR
había diseñado; era un mecanismo más simple, inventado porque era más
rápido de escribir. Señal concreta de lo desalineado que estaba: RR
mencionó "el cometa" como un espacio del mundo y esa zona no existía en
`mapa.gd`, aunque sí estaba en `src/story/burdeo.json`.

**Fracaso 2 — el diorama unificado con el verbo equivocado.** El segundo
intento sí partió del diseño correcto en lo estructural (un solo mundo 3D
con relieve, cámara fija, personaje visible), pero portó el **verbo de
movimiento equivocado**: `personaje.gd` quedó con velocidad continua,
gravedad y `move_and_slide()` — un personaje de plataformas físico. RR lo
probó y reportó que "rompió completamente toda la funcionalidad".

La causa raíz del fracaso 2 es la lección más importante de este
documento, y está en §3.

---

## 1. La frase del juego

> Recorro un mundo que parece plano y chico. Camino, y lo que dejo queda.
> Cuando lo roto en pasos exactos, aparece una dimensión que no estaba —
> lugares que no se podían alcanzar ahora sí, capas del mundo que estaban
> superpuestas y no se veían. Voy descubriendo y coleccionando lo que hay.
> Cuando me alejo lo suficiente, el mundo entero se vuelve un mapa en
> miniatura donde veo todo lo que encontré.

**Verbo central: explorar y descubrir.** No hay disparos, no hay golpes,
no hay combate (decisión de RR, revisable, pero hoy es no). Toda
interacción es directa con el mundo, nunca con una UI de sistema.

---

## 2. El core: el estereograma

Esto es lo más importante del juego y la razón de ser de todo lo demás.

El mundo se ve **2D / 2.5D**, casi plano, casi ruido — y al rotarlo en
pasos exactos aparece la otra dimensión escondida, como un Magic Eye
(estereograma). No es "girar la cámara para ver mejor": es que girar
**cambia qué está conectado con qué**.

La matemática ya existe, probada, en `src/mundo/proyeccion.js`. En
proyección isométrica ortográfica verdadera (elevación
`atan(1/√2) ≈ 35.264°`), la posición en pantalla depende solo de:

```
A = x - z           (columna en pantalla)
B = x + z - 2y      (fila en pantalla)
```

Moverse `(+1,+1,+1)` en `(x,y,z)` no cambia `A` ni `B`: infinitos puntos
del mundo ocupan el mismo píxel. Rotar 90° cambia qué pares coinciden.

**La regla de movimiento, única y sin excepciones:** *puedes pisar lo que
se ve pegado a ti*. Sin casos especiales — el jugador tiene que poder
construir un modelo mental fiable, y una regla con excepciones se lo
impide. (`src/mundo/navegacion.js`.)

### La otra mitad de la regla: si no se te ve, no podés actuar (2026-08-10)

Decisión de RR al probar el prototipo. Al rotar, el personaje puede quedar
**tapado** por otra isla. Hasta ese momento igual podía saltar desde ahí, y
el resultado se veía como un salto que sale de la nada y aterriza solo:
teletransporte, no descubrimiento.

> Quedar tapado es inevitable y está bien. Lo que no puede pasar es
> **actuar** estando tapado. Se sale rotando.

No es una excepción a la regla: es su otra mitad. "Puedes pisar lo que se
ve pegado a ti" solo tiene sentido si vos también estás a la vista — si no,
el jugador ni siquiera puede ver desde dónde saltó.

**Consecuencia sobre el diseño de niveles — tercera forma de romper uno.**
A las dos ya conocidas (objetivo inalcanzable en las 4 rotaciones; objetivo
alcanzable ya en la inicial) se suma: **una celda tapada en las 4
rotaciones** deja al jugador trabado para siempre, sin poder moverse ni
salir rotando.

Y es la más traicionera, porque **el BFS de validación no la detecta**: el
BFS explora dentro de una rotación fija, nunca rota, así que nunca se topa
con el caso "quedé tapado al rotar". Necesita su propia comprobación.

> **Dato real:** al aplicar esta regla, el nivel de `src/mundo/nivel.json`
> (el de Three.js) **queda sin solución** — su celda de partida está tapada
> en la rotación 0, y desde ahí no se puede hacer nada. Comprobado con
> `godot/herramientas/verificar_nivel.py`. Si algún día se retoma ese
> nivel, hay que rediseñarlo.

### Por qué las rotaciones tienen que ser exactas

`INFORME.md` §6 documenta un bug real y caro: al interpolar el giro con
un contador que daba la vuelta (`(r+1)%4`), el mundo giraba 270° hacia
atrás en vez de 90° adelante, y la medición en pantalla dio **815% de
desviación**. La corrección: llevar **dos contadores** — uno continuo que
nunca da la vuelta (para animar) y uno módulo 4 (para la matemática de
alineación).

Y con trigonometría continua, la comparación de igualdad entre dos puntos
de pantalla falla de forma **intermitente** por error de coma flotante —
el puente aparece y desaparece sin patrón. Por eso las rotaciones son de
90° exactos, calculadas sin senos ni cosenos.

**Decisión de RR (explícita):** todo por pasos, nada suelto, sencillo. No
hay órbita libre de cámara. Ver §4.

---

## 3. LA LECCIÓN: movimiento por celdas, nunca continuo

**Este es el error que rompió el prototipo anterior. No repetirlo.**

El personaje se mueve **por celdas discretas, un paso por empujón**. No
hay velocidad continua, no hay `move_and_slide()`, no hay gravedad
simulada como base del movimiento.

`src/render/controls.js` ya lo dejaba escrito:

> El stick da UN paso por empujón, no un chorro continuo: el juego se
> piensa celda a celda y un movimiento continuo lo volvería resbaladizo.

**Por qué es obligatorio y no una preferencia de estilo:** la regla
"puedes pisar lo que se ve pegado a ti" compara posiciones en pantalla
buscando igualdad **exacta**. Con posiciones continuas nunca hay igualdad
exacta — el estereograma directamente no puede funcionar. El movimiento
por celdas no es un detalle de feel: es la condición de existencia del
core del juego.

El paso puede (y debe) *verse* suave: se anima la transición entre celda
y celda, con su arco, su peso y su tiempo. Lo que es discreto es el
**estado lógico**, no la animación.

### Qué significa "verse suave" (2026-08-10, RR probando)

La primera versión respetaba la regla pero animaba cada paso como un
saltito con frenada al final. RR lo describió exacto:

> El movimiento es como de un personaje de ajedrez, y eso no está bien. La
> idea es que se sienta más libre, como alguien caminando o **una bestia
> que se mueve**.

Las cuatro causas, y lo que las arregla — todo cosmético, **el estado
lógico sigue siendo la celda**:

| Causa | Arreglo |
|---|---|
| Un arquito de salto en cada celda | Sin arco al caminar; un **bamboleo** que *cruza* de celda a celda en vez de reiniciarse |
| Frenada completa al final de cada paso | Los pasos **encadenan**: mientras se sigue andando, la velocidad es pareja |
| Había que re-apretar por cada celda | **Mantener apretado camina** |
| La cápsula no miraba hacia dónde iba | El cuerpo **encara** la dirección, y se echa hacia delante al andar |

El **puente imposible** conserva a propósito el arco alto y la frenada: es
la única pista de que pasó algo que no era obvio, y tiene que romper el
ritmo del caminar.

> Nota sobre "un paso por empujón": la nota original de `controls.js` decía
> que el stick no debía dar un chorro continuo. Eso apuntaba a que no
> hubiera **velocidad continua** (que sí rompería la matemática), no a
> prohibir caminar sostenido. Mantener apretado da pasos discretos
> encadenados: la regla se respeta igual.

**Nota sobre física:** si en algún momento hace falta física (algo que
caiga, ruede, se mueva con viento), va como adorno de cuerpos puntuales,
**nunca como base del movimiento del personaje**. Ya estaba dicho en
`INFORME.md` §9.5.

---

## 4. Controles: dos verbos, cero UI

Resuelto y probado en `src/render/controls.js`. Se porta tal cual.

| | Teclado | Control (PS/Xbox) | Touch |
|---|---|---|---|
| **Mover personaje** | Flechas | Stick / D-pad | Arrastre corto |
| **Rotar mundo** | A / D | LB / RB | Toque en borde lateral |

**Que sean solo dos es deliberado.** La versión anterior tenía cinco
verbos peleando por los mismos dedos (mover, viajar entre zonas, orbitar
libre, inclinar a dos dedos, pasar planos) y el resultado fue que ninguno
se entendía.

**No hay órbita libre. La cámara del juego no se toca, ni un poco.** Su
rigidez es la condición de que el acertijo se pueda leer: si la cámara se
moviera sola, las alineaciones cambiarían sin que el jugador lo pidiera.

**Requisitos de RR sobre controles (duros):**
- Cero controles visibles en pantalla. Nada de HUD de botones, ni en touch.
- Todo pre-mapeado de fábrica: PS, Xbox, teclado+mouse y touch andan de
  entrada, sin pantalla de configuración.
- Tiene que estar listo para que RR conecte su control y pruebe sin
  configurar nada.

**Detalle isométrico ya resuelto (no re-descubrir):** en esta grilla en
diamante solo hay cuatro pasos posibles y los cuatro son diagonales en
pantalla. La asignación correcta es la **antihoraria** (Arriba→NO,
Derecha→NE, Abajo→SE, Izquierda→SO) — la horaria se probó y se sentía
"rotada". Verificado por captura.

---

## 5 bis bis. CORRECCIÓN: zonas modulares + ilusión de cámara (2026-08-10)

**Decisión de RR, y reemplaza la lectura literal de §5 de abajo.**

§5 decía "un único volumen 3D donde los espacios están superpuestos". RR lo
corrigió al ver el prototipo andando:

> Cada espacio de Burdeo es un espacio en sí mismo, prediseñado. La ilusión
> de que todos están en el mismo diorama se da con **saltos de cámara** —
> es solo ilusión, porque son espacios tridimensionales distintos. Eso da
> además la ventaja de que sea **modular**.

**Por qué es mejor, con evidencia concreta.** Se intentó primero la lectura
literal (todas las zonas del lore en un mismo sistema de coordenadas) y
falló por dos motivos medidos:

1. **Encuadre imposible.** El mundo entero orbita dentro de un disco
   alrededor del centro de giro: hacía falta una cámara de **36 unidades**,
   con todo diminuto.
2. **Restricciones globales acopladas.** Cada zona tenía que abrirse en una
   rotación distinta *a la vez*. Un intento falló porque luna y cometa se
   abrían las dos en la rotación 0. Mover una zona rompe otra — no se puede
   diseñar a mano ni escala.

Con zonas modulares, **cada una se valida sola** (comprobado: ciudad, luna
y playa validan por separado sin interferirse). Agregar una zona no puede
romper las demás.

**Lo que NO cambia:** el estereograma (§2) sigue viviendo *dentro* de cada
zona — rotación, alineaciones, puentes imposibles. Lo que ocurre *entre*
zonas es viaje de cámara, otro mecanismo. Los dos conviven sin pisarse.

**Cómo se implementa hoy:** todas las zonas existen en la misma escena,
separadas en el espacio, cada una con su propio pivote de giro y su propia
rotación recordada. La cámara viaja entre ellas. Se cambia de zona pisando
una celda de salida (portal), coherente con "portales estilo Death's Door"
de `IDEAS_DISENO.md`.

---

## 5. El mundo: uno solo, superpuesto, acotado

> ⚠️ Leer §5 bis bis (arriba) antes que esta sección: la superposición
> resultó ser una **ilusión de cámara entre zonas modulares**, no un
> volumen literal compartido.

**No son lugares separados conectados por viajes.** Es un único volumen
3D donde los espacios del lore están **superpuestos**, ocupando el mismo
diorama, y cada uno se vuelve legible/caminable según la rotación.

Espacios (de `src/story/burdeo.json` + conversación):
ciudad (Burdeo), playa/costas, bosque místico, luna, otro planeta,
cometa, **desierto boreal** (nuevo, aportado por RR, sin definir todavía).

**El cometa NO es un adorno del cielo.** El prototipo anterior lo puso
como esfera sin colisión cruzando el fondo — está mal. Es un espacio
caminable como cualquier otro, superpuesto al resto. El lore dice que
"atraviesa el mapa entero en vez de ocupar un lugar", y eso se cumple por
superposición, no por ser decorado.

**Acotado a propósito.** Un planeta, una luna, un cometa, una ciudad.
Sensación de mundo continuo habitable estilo GTA, pero limitado y
diseñado a mano — nada procedural, nada infinito. En palabras de RR: *"el
mundo parece grande, pero es grande en apariencia; está pensado para ser
habitado de cierta manera"*.

**Cómo se construye técnicamente:** cada capa vive en las mismas
coordenadas de grilla, y queda alcanzable solo en su(s) rotación(es)
exacta(s). Es el mismo mecanismo que hoy resuelve UN acertijo en
`nivel.json` (2 islas, 1 puente, 1 rotación correcta), escalado a N capas.

> ⚠️ **Salto de escala real, no subestimarlo.** Validar que N capas no se
> pisen mal entre sí es bastante más trabajo que el caso actual de dos
> islas. `validarNivel()` existe justamente porque un nivel puede quedar
> roto de dos formas mudas: inalcanzable (no hay rotación que lo conecte)
> o sin acertijo (se alcanza desde la rotación inicial). Ver §8.

---

## 5 bis. Los personajes y las tres épocas

**El jugador es un visitante, y no es nadie del lore.** No es Aloesativo
ni ninguno de los tres personajes: es *"cualquiera que use la aplicación,
postura de visitante real, tipo Google Street View"* (`IDEAS_DISENO.md`).
Encaja con el verbo central: no encarnás, mirás y descubrís.

**Los tres habitantes** (`src/story/burdeo.json` → `personajes`) son el
mismo ser manifestado en tres planos temporales, y ninguno sabe de los
otros dos:

| Personaje | Plano | Rol en el mapa |
|---|---|---|
| El Archivista de Burdeo | renacentista | vive en la sombra, entre bibliotecas y estudios |
| Cabeza Hueca | moderno (~80s) | el plano "ancla": la vigilia, la vida real |
| Conejo Pasta Music | futuro | plano dreamtime — onírico, psicodélico |

### Cómo conviven las épocas — DECIDIDO

**No por rotación.** Se propuso que rotar cambiara de plano temporal
(las tres épocas superpuestas en las mismas coordenadas, la rotación
eligiendo cuál se pisa). **RR lo descartó explícitamente.** La rotación
es y sigue siendo **solo espacial**: revela caminos y lugares, no épocas.

**Sí por densidad visual, a nivel de mapa.** Esto ya estaba resuelto en
`IDEAS_DISENO.md`, solo que suelto y sin conectar:

- Renacimiento / Archivista → **denso** (referencia: Buscando a Wally)
- Moderno / Cabeza Hueca → **low-poly gris** (TUNIC, Death's Door)
- Futuro / Conejo → **geometría limpia** (FEZ, Monument Valley)

Y la decisión de simplificación que lo ordena: *"no mezclar las tres
técnicas de render en una misma escena — la convivencia de épocas ocurre
a nivel de mapa, no dentro de un mismo cuadro"*.

O sea: las épocas son **regiones del mismo mundo continuo**, con
tratamiento visual distinto, y se pasa de una a otra **caminando**. No
son escenas separadas (eso contradiría §5) ni capas por rotación.

> Hilo que el lore deja servido, sin diseñar todavía: el puente entre el
> plano moderno y el onírico **es la droga** — cuando Cabeza Hueca
> consume, sin quererlo se conecta con Conejo Pasta Music. Sugiere que
> no todas las transiciones entre épocas tienen por qué sentirse iguales.
> Anotado, no decidido.

---

## 6. Caminar tiene peso, y el mundo recuerda

Referencia de RR: **Death Stranding**. Caminar no es transporte hacia lo
interesante: es el evento. Se siente el peso, el esfuerzo, el ritmo.

**El mundo tiene memoria de lo que hiciste**: lo que plantás sigue ahí, un
camino muy recorrido se nota. (Entendido como memoria del mundo propio de
cada jugador, **no** memoria social/multijugador como el juego original —
confirmar si alguna vez se quiere lo segundo.)

Modificar el espacio y plantar es mecánica central, pero **sin menú de
cultivo**: nada de pala/picota/regadera en una UI. RR lo rechazó
explícitamente, dos veces. Interacción directa, siempre.

### Cómo se implementa el peso (sin sistema nuevo)

El gancho ya existe. `src/render/personaje.js` tiene hoy **dos** pasos
distintos, no uno:

| | Paso normal | Puente imposible |
|---|---|---|
| Duración | 160 ms | 420 ms |
| Arco vertical | `ALTO * 0.12` | `ALTO * 0.9` |
| Vibración | `10` | `[18,40,18,40,30]` |

Y el porqué está escrito en el módulo: *"sin ella, cruzar un abismo se
siente igual que caminar, y el hallazgo pierde su peso."*

**La propuesta no es agregar un sistema de peso, es abrir esa perilla:**
que duración / arco / vibración / sonido del paso sean propiedad del
terreno y del estado, en vez de dos casos fijos. Caminar en la ciudad ≠
en la luna ≠ en el cometa. Mismo mecanismo, distinta sensación.

> ⚠️ **Límite duro, ya escrito en el código:** *"este juego se piensa con
> los ojos, no con los dedos: una animación larga castigaría probar
> alineaciones, que es exactamente lo que queremos que el jugador haga sin
> miedo."*
>
> El peso va en la **textura** del paso (sonido, arco, vibración, cómo
> aterriza), **no** en hacerlo lento. Un paso pesado-y-lento vuelve
> tedioso probar rotaciones, que es el core del juego (§2).

**Detalle ya resuelto, no re-descubrir:** mientras la animación corre, una
tecla nueva **no se descarta** — se guarda en una cola de un solo paso (el
más reciente gana) y se ejecuta al terminar. Antes se tiraba en silencio,
y eso era lo que hacía sentir las flechas como rotas al pulsarlas rápido.

---

## 6 bis. Iluminación y bucle temporal

### La contradicción, y cómo se resuelve

Había tres posiciones encontradas en el repo:

- `INFORME.md` §0 — el reloj temporal **se tiró**, porque *"castigaba el
  descubrimiento en vez de premiarlo: llegar al lugar correcto en el
  momento equivocado sonaba a silencio"*.
- `IDEAS_DISENO.md` — *"El bucle temporal es fundamental, no se elimina."*
- `burdeo.json` — *"las ventanas temporales NO son el punto central del
  diseño: sirven para separar los elementos y darles orden. No
  sobre-construir el sistema de tiempo."*

**DECIDIDO (RR):** el bucle manda sobre **la atmósfera, nunca sobre el
contenido**. Cambia la luz, el ánimo, cómo se ve el mundo — y **jamás**
bloquea un hallazgo. Nunca se llega al lugar correcto y hay silencio.

Así el bucle es fundamental (está siempre presente, se siente) sin
reintroducir el castigo que hizo que se tirara la primera vez.

### ⚠️ La trampa del sol cenital (verificada, cara si se descubre tarde)

`theme/default.json` lo deja anotado y verificado (2026-07-31): con el sol
alto (~55°, `[10,20,10]`) las sombras salen tan cortas que el propio
objeto las tapa desde la cámara casi cenital — **parecen no funcionar,
pero funcionan**. Con un sol rasante (`[16,5,7]`) aparecen de inmediato.

**Por qué esto es grave acá y no en otro juego:** las sombras no son
decoración, son **el dato que comunica a qué altura está cada cosa**. En
un mundo que se lee por alineación (§2), perder las sombras es perder la
información con la que se juega.

Si el sol recorre el ciclo completo con el bucle, hay un momento —el
mediodía— en que **el acertijo se vuelve ilegible**. Es el mismo tipo de
falla que ya ocurrió con el tilt-shift (el efecto emborronaba justo la
alineación que había que leer).

**Regla:** el sol recorre un arco **acotado que nunca pasa por el cenit**.
La hora del día cambia el ánimo; nunca borra la información de juego.

---

## 6 ter. Tres consideraciones que faltaban

**Persistencia / guardado.** "El mundo recuerda lo que dejaste" (§6)
implica guardado, y nunca se había mencionado. Define arquitectura: qué se
guarda (celdas modificadas, plantas, hallazgos, puzzles resueltos), cuándo
se guarda, y qué pasa con un guardado viejo cuando el mundo cambia de
versión. Decidirlo tarde duele. **Sin diseñar todavía.**

**El contraste es mecánica, no estética.** El acertijo se resuelve
*mirando* si dos cosas se ven pegadas. Cualquier decisión visual que baje
la legibilidad —colores muy cercanos entre capas, bloom quemando bordes,
niebla mal calibrada— **rompe el juego, no solo lo afea**. Hay tres
precedentes ya documentados: el tilt-shift, la niebla, y el sol cenital
de arriba. Además `theme/default.json` avisa que un color por encima de
~`#d0d0d0` supera el umbral de bloom y se quema hasta volverse ilegible.

> **Regla:** la identidad visual la elige RR (siempre), pero **no puede
> comerse la legibilidad de la alineación**. Si una elección de paleta
> vuelve ilegible el acertijo, eso se reporta como bug de jugabilidad, no
> se acepta en silencio.

**El borde del mundo.** El mundo es acotado a propósito (§5) — falta
decidir qué ve el jugador al llegar al límite: diorama flotando en negro,
agua, niebla, caída y reaparición. Es chico pero se nota mucho en un juego
contemplativo, donde la gente va a ir a mirar justo ahí. **Sin decidir.**

---

## 7. El zoom: la cuerda, y el dashboard

**El zoom-out es un gesto con peso.** En palabras de RR: *"tiene que ser
harto zoom para que se sienta como que es un trabajo, como tirar una
cuerda. Es satisfactorio pero no automático, no en dos tiradas. Tampoco
tedioso, pero tiene que tener un recorrido."*

**Regla de consistencia (dura):** por más torcido/rotado que hayas quedado
explorando, al hacer zoom out el mundo **siempre** vuelve a una
orientación "desde arriba" consistente. Siempre la misma, no
aproximadamente la misma.

> Este principio ya está probado en `src/render/camera.js`:
> `volverAMecanica()` devuelve la cámara **exactamente** al encuadre
> anterior (mismo azimut, elevación y fov), y se verificó comparando
> coordenadas de pantalla antes/después. Es un paréntesis, nunca una
> transición.

**El destino del zoom-out: el dashboard.** Al fondo del zoom, el mundo se
vuelve una miniatura con **tilt-shift**, cosy, mezclada con las portadas
de las canciones descubiertas y dónde se encontraron. Es la ilusión de
"tierra plana": se ve como un mapa plano visto desde arriba, pero sigue
siendo 3D al mismo tiempo. (Ya estaba anticipado en `IDEAS_DISENO.md`,
sección "Reproductor cuenco": *"idea de broma: mapa de tierra plana"*.)

> ⚠️ **Trampa conocida del tilt-shift** (`INFORME.md` §6): con la franja
> nítida estrecha, el efecto emborrona justamente la alineación que hay
> que leer para resolver el acertijo — verificado por captura. La solución
> no fue sacrificar el efecto sino atarlo al régimen: ancho mientras se
> juega, cerrado en la vista de miniatura. Aquí se ata al **nivel de
> zoom**: el look "miniatura" es correcto en el dashboard, y sería un bug
> jugándolo de cerca.

**El desbloqueo del mapa:** recorrer bien el mundo 3D es lo que habilita
más mapa. El límite no es geográfico ("el mundo es chico") sino de acceso
("se revela en el orden en que lo recorrés"). *Falta definir el gatillo
exacto — ver §9.*

---

## 8. Los puzzles

Estado: **la pieza menos definida de todo el diseño.** RR lo dijo
explícitamente ("eso es lo que no tengo tan claro").

Lo que sí está dicho:
- Puzzle lógico, tipo rompecabezas chino / matemático: mover un bloque,
  desatar un nudo.
- Resolverlos desbloquea **dos cosas**: más mapa, y **nuevas formas de
  rotar la cámara** — el repertorio de movimientos de cámara se amplía
  jugando, en vez de estar todo disponible desde el minuto uno.
- Detrás de los puzzles viven las canciones y los "espacios sagrados".

Pregunta abierta importante: ¿el puzzle es el mismo mecanismo del
estereograma evolucionado, o es literalmente otro sistema (un
rompecabezas aparte que se manipula)? No decidido.

---

## 9. Ideas parqueadas (acordadas, sin diseñar)

No se construyen ahora. Se anotan para que no se pierdan.

- **El libro / almanaque / necronomicón.** Objeto 3D dentro del mundo, no
  un menú: se puede recorrer, tiene páginas que se pasan como hojas de
  verdad, páginas en blanco, insignias/medallas por lo descubierto. RR
  pidió explícitamente parquearlo ("dejémoslo como una idea").
- **Distorsiones espaciales y temporales como efecto ajustable.** El
  espacio "circular, levemente no euclideano" es un efecto óptico
  regulable, **no** geometría no-euclideana real. Puede acompañarse de
  distorsión temporal (acelerando, crescendo). Familia "juice" estilo
  Balatro (animación, tipografía, feedback).
- **Tono y referencias:** cozy, Animal Crossing, point-and-click, estética
  rara (Hylics). El juego trata en parte de descubrir de qué va el juego —
  no se explica de entrada.
- **Arte: fotografía propia** transformada en assets, porque es lo que RR
  sabe hacer. Ya estaba en `IDEAS_DISENO.md`.
- **Capas mayores sin tocar todavía:** reproductor-oráculo (I Ching + 72
  Nombres), streaming externo, dashboard de distribución, plantas
  generadas desde especies reales (GBIF).
- **Sin decidir, anotado en su sección:** el guardado (§6 ter), el borde
  del mundo (§6 ter), cómo se sienten las transiciones entre épocas
  (§5 bis), y los puzzles enteros (§8).

---

## 10. Plan por etapas

Cada etapa es chica, termina en algo que RR puede **probar y sentir**, y
no se avanza a la siguiente sin que RR confirme que la anterior anda.

> **Por qué tan chico.** El agente no puede correr Godot (§11). Cada etapa
> grande es una apuesta a ciegas, y las dos apuestas grandes anteriores
> salieron mal. Etapas chicas = errores chicos y localizables.

**Etapa 1 — Un personaje que camina por celdas.**
Grilla plana, sin relieve, sin rotación, sin arte. El personaje se mueve
un paso por empujón, con la animación del paso. Nada más.
*Se prueba:* el paso se siente discreto y con peso; no resbala; el control
funciona sin configurar nada.

**Etapa 2 — La cámara isométrica fija.**
Cámara ortográfica en el ángulo isométrico verdadero. No se mueve, no se
toca, sigue al personaje sin girar.
*Se prueba:* la vista se ve plana/2.5D, y nada la mueve por accidente.

**Etapa 3 — Rotación en pasos exactos.**
A/D y bumpers rotan el mundo 90° exactos. Dos contadores desde el día uno
(continuo para animar, módulo 4 para la matemática) — §2.
*Se prueba:* rotar cuatro veces vuelve exactamente al estado inicial, sin
deriva; la animación nunca toma el camino largo.

**Etapa 4 — El estereograma: la regla de movimiento.**
Relieve real (celdas a distinta altura) + "puedes pisar lo que se ve
pegado a ti". Un solo puente, una sola rotación correcta — la rebanada
mínima, igual que `nivel.json` hoy.
*Se prueba:* hay un lugar imposible de alcanzar que, al rotar, se vuelve
alcanzable. **Si esto se siente bien, el juego existe.**

**Etapa 5 — Validación del nivel.**
Portar `validarNivel()`: avisar por consola si un acertijo quedó
inalcanzable o dejó de ser acertijo. Sin esto, los niveles se rompen en
silencio (§5).

**Etapa 6 — El zoom-cuerda y la vuelta al arriba consistente.**
Zoom out con recorrido y peso, que siempre reorienta a "arriba"
consistente (§7).

**Etapa 7 — Miniatura + tilt-shift.**
El look cosy en miniatura, atado al nivel de zoom, no al juego de cerca.

**Etapa 8 en adelante — sin comprometer todavía:**
capas superpuestas del lore (§5), regiones por época (§5 bis),
descubrimientos y colección, puzzles (§8), memoria del mundo y su
guardado (§6, §6 ter), iluminación con bucle (§6 bis), el libro (§9).

> **Nota sobre la luz:** la iluminación con bucle temporal (§6 bis) NO va
> antes de la etapa 5. Hasta que `validarNivel()` exista, un cambio de luz
> que vuelva ilegible una alineación es indistinguible de un nivel roto —
> y se perdería tiempo buscando el bug en el lugar equivocado.

---

## 11. Cómo se trabaja (restricción estructural)

**RR siempre prueba Godot él mismo, en su máquina. El agente nunca puede.**
No es una limitación transitoria de una sesión: el agente no tiene forma
de correr Godot en ningún entorno donde corren estas sesiones. Todo
`.gd`/`.tscn` es código escrito leyendo con cuidado, sin ejecutar — la
primera vez que corre de verdad es cuando RR le da play.

Consecuencias prácticas:
- Etapas chicas, verificables de a una (§10).
- `print()` de diagnóstico en los puntos clave, para que RR pueda pegar la
  salida de la terminal tal cual.
- Si algo falla, **copiar el mensaje literal, no resumirlo.**
- El agente no elige identidad visual (paleta, estilo). Todo placeholder
  gris hasta que RR defina. Regla heredada de `CLAUDE.md`.

---

## 12. Relación con `src/` (Three.js)

`src/` **no se toca ni se borra** mientras Godot no esté verificado. Es la
referencia funcional del diseño y lo único mostrable hoy. Módulos que son
la fuente de verdad a portar:

| Módulo | Qué resuelve |
|---|---|
| `src/mundo/proyeccion.js` | La matemática del estereograma (§2) |
| `src/mundo/navegacion.js` | "Pisa lo que ves pegado" (§2) |
| `src/mundo/index.js` | `validarNivel()` — acertijos rotos (§10, etapa 5) |
| `src/render/controls.js` | Los dos verbos, ya calibrados (§4) |
| `src/render/camera.js` | Vuelta exacta al encuadre (§7) |
| `src/story/burdeo.json` | Los espacios del lore (§5) |

**Regla:** portar desde estos módulos, no reinventar. Los dos fracasos de
§0 fueron exactamente eso — inventar algo más simple en vez de partir del
diseño ya validado.
