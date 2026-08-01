# Informe del repositorio — Enterrario

Documento de traspaso de contexto. Sirve para abrir un chat nuevo y entrar
directo a discutir arquitectura sin tener que redescubrir el estado del
prototipo. Fecha del corte: 2026-08-01 — **reescrito entero** tras un
pivote de diseño; las secciones anteriores describían un sistema que ya
no existe (ver §0).

---

## 0. El pivote: de "diorama observado" a "descubrimiento de canciones"

La versión anterior (informe hasta 2026-07-31) era un terrario procedural
con una cámara cinematográfica que el jugador navegaba por una grilla de
planos, más un "mapa" de zonas conectado a un reloj temporal que
determinaba qué canción sonaba dónde.

RR identificó que ese diseño estaba roto en su raíz: el personaje había
quedado degradado a marcador de presencia mientras el gesto principal era
viajar entre zonas; dos verbos de movimiento (personaje / cámara) peleaban
por los mismos dedos; los planos cinematográficos se alcanzaban con una
tecla y por eso no contaban nada; y el reloj castigaba el descubrimiento
en vez de premiarlo (llegar al lugar correcto en el momento equivocado
sonaba a silencio).

La frase de diseño que reemplaza a todo lo anterior:

> Mueves al personaje para descubrir a dónde ir. Hay lugares a los que no
> se llega si no rotas el escenario. Al alcanzar ciertos puntos de vista,
> la cámara se suelta, se revela una portada y suena su canción — y luego
> te devuelve exactamente donde estabas.

Referencias de diseño explícitas de RR: **Fez** (Polytron) para el truco
espacial — la ambigüedad de profundidad de la proyección isométrica hace
que dos puntos lejanos del mundo se vean pegados desde cierta rotación, y
girar el escenario cambia qué está conectado con qué; **Metroid Dread**
para el ritmo de cámara — un régimen de juego rígido y aburrido a
propósito, roto por una toma cinematográfica solo en el momento del
hallazgo.

Se tiró: el reloj temporal, el mapa de zonas, la navegación por teclado de
planos cinematográficos, el generador procedural de terreno. Se conservó
y reubicó: el motor de transición de cámara (curado, con ease), la cadena
de imagen (IBL, sombras, tilt-shift, postproceso), el shot list como
biblioteca de tomas — pero indexado por revelación, no por celda de
grilla.

---

## 1. Qué es

Un espacio isométrico donde el jugador mueve un personaje por islas de
celdas y rota el escenario en pasos de 90° para descubrir caminos que solo
existen en cierta rotación. Al llegar a un punto marcado, la cámara se
suelta de su rigidez, revela la portada de un álbum, suena algo, y
devuelve al jugador exactamente donde estaba.

Repo hermano de `Aloesativo/Aloesativo` (catálogo/lore), **sin ninguna
conexión técnica** — la relación es curatorial.

Stack: Vite + Three.js + `postprocessing` (pmndrs), sin framework. Todo
el código es JavaScript de módulos ES, en español.

**URL de verdad del prototipo:**
`https://aloesativo.github.io/enterrario-aloesativo/`
No hay flujo local: RR no instala herramientas de desarrollo en su
máquina. Cada push a `main` compila y publica vía
`.github/workflows/deploy.yml`.

---

## 2. El truco central: la ambigüedad isométrica

En una cámara isométrica ortográfica verdadera (elevación
`atan(1/√2) ≈ 35.264°`), la posición en pantalla de una celda del mundo
depende solo de dos números derivados de su posición 3D:

```
A = x - z          (columna en pantalla)
B = x + z - 2y      (fila en pantalla)
```

Consecuencia: moverse `(+1, +1, +1)` en `(x, y, z)` no cambia ni `A` ni
`B` — hay infinitos puntos del mundo que ocupan el mismo píxel. Girar el
escenario 90° cambia la fórmula (rota `x, z` sobre el centro) y por tanto
qué pares de celdas coinciden en pantalla. Eso es lo que permite el
"puente imposible": dos islas separadas por un abismo real pueden verse
pegadas desde una rotación concreta, y solo desde esa.

`src/mundo/proyeccion.js` es esta matemática, pura y sin THREE.js. Usa
rotaciones de 90° exactas (sin trigonometría) para que la comparación de
igualdad entre dos puntos de pantalla sea exacta — con senos/cosenos el
puente aparecería de forma intermitente por error de coma flotante.

`src/mundo/navegacion.js` convierte esa matemática en la única regla de
movimiento del juego: **puedes pisar lo que se ve pegado a ti**. Sin
excepciones — el jugador tiene que poder construir un modelo mental
fiable, y una regla con casos especiales se lo impide.

**Esto se verificó, no se asumió.** Un bug real (§6) hizo que la
matemática y la imagen estuvieran de acuerdo en los números pero en
desacuerdo en la pantalla durante buena parte del desarrollo. La lección:
medir la posición real en píxeles (`window.enterrario.proyectarEnPantalla`)
es la única prueba de que el truco funciona, no basta con que el código
"tenga sentido".

---

## 3. Los dos regímenes de cámara (`src/render/camera.js`)

1. **Mecánico** — isométrica fija (azimut, elevación y fov constantes,
   definidos en `theme/planos.json → mecanica`). Nunca se mueve, nunca se
   inclina. Es aburrida a propósito: si la cámara se moviera sola, las
   alineaciones que el jugador tiene que leer cambiarían sin que él lo
   pidiera, y el acertijo dejaría de ser legible. Esa rigidez es también
   lo que le da poder a la ruptura de la regla en la revelación.

2. **Revelación** — al descubrir algo, `director.revelar({plano, punto})`
   dispara una transición a un plano curado de `theme/planos.json →
   planosRevelacion` (vertigo/dolly zoom, holandés, retrato, cenital), con
   el objetivo puesto en el punto exacto del hallazgo. Se sostiene, y
   `director.volverAMecanica()` la devuelve **exactamente** al encuadre
   mecánico — mismo azimut, misma elevación, mismo fov. Es un paréntesis,
   nunca una transición: si el jugador vuelve a un mundo que quedó girado
   distinto, pierde el modelo mental que construyó.

El encuadre mecánico se deriva del nivel (esfera envolvente × margen), no
es un número fijo — con un número fijo, mover una isla puede dejarla fuera
de cuadro sin que nada avise.

---

## 4. Mapa de módulos

```
index.html                    Canvas + HUD
vite.config.js                base: '/enterrario-aloesativo/'  (crítico para Pages)
src/main.js                   Cableado: arma el grafo, la revelación como máquina de estados, el bucle
src/mundo/proyeccion.js       Matemática pura de la ambigüedad isométrica
src/mundo/navegacion.js       La regla de movimiento ("pisa lo que ves pegado")
src/mundo/index.js            Carga el nivel + validarNivel (detecta acertijos rotos)
src/mundo/nivel.json          El nivel: islas (rectángulos) + revelaciones
src/render/scene.js           Escena, luces, sombras, renderer, resize
src/render/camera.js          Los dos regímenes de cámara
src/render/controls.js        Entrada: mover (flechas/arrastre) y rotar (A/D/borde/bumper)
src/render/nivel.js           Islas → mallas (losas delgadas, a propósito)
src/render/personaje.js       Malla + movimiento por celdas con arco de salto
src/render/revelacion.js      Portada (canvas placeholder) + sonido (Web Audio placeholder)
src/render/entorno.js         IBL (luz de entorno) + tone mapping
src/render/postproceso.js     tilt-shift/bloom/viñeta/grano/SMAA, atado al régimen de cámara
src/theme/default.json        Paleta, luces, niebla, entorno, sombras, postproceso
src/theme/planos.json         Cámara mecánica + biblioteca de planos de revelación
src/story/burdeo.json         HISTÓRICO — lore transcrito, ya no conectado (ver §9.0)
```

---

## 5. El nivel y su validación (`src/mundo/`)

`nivel.json` declara islas como rectángulos (`x0,x1,z0,z1,y`) y una lista
de `revelaciones` (celda exacta → plano cinematográfico → obra). La
alineación isométrica es **exacta y frágil**: mover una isla una sola
celda puede abrir el puente en las cuatro rotaciones (deja de ser
acertijo) o cerrarlo en las cuatro (deja de tener solución). Las dos
fallas son mudas si nadie las comprueba.

`validarNivel()` corre al arrancar (`main.js`) y hace justo eso: por cada
revelación, comprueba que exista alguna rotación desde la que se llegue
(si no, inalcanzable) y que la rotación inicial NO sea una de ellas (si lo
es, no hay acertijo). Avisa en consola, no rompe el arranque.

**Búsqueda de nivel, no diseño a mano.** El nivel actual (`orilla` en
`y=0`, `hallazgo` en `y=5`, desplazada 6 celdas en x/z) no se adivinó: se
generó por barrido de parámetros comprobando conectividad por rotación
con BFS, para encontrar una configuración donde el puente existiera en
**una sola** rotación y el salto real fuera grande (16 celdas de mundo).
Diseñar un nivel manualmente sin este tipo de comprobación es la forma
más fácil de terminar con un acertijo que parece bueno en el editor y
está roto en el juego.

---

## 6. Trampas conocidas (leer antes de tocar)

**El fallo más caro de este pivote: interpolar el giro por el camino
largo.** El contador de rotación (0..3) se usaba directamente para animar
el ángulo del rig. Pasar de rotación 3 a 0 con `((r+1)%4)` hacía que el
mundo girara 270° hacia atrás en vez de 90° hacia delante — la animación
tomaba el camino largo. La medición en pantalla (ver §2) daba **815% de
desviación** entre la posición esperada y la real, y por un momento se
sospechó erróneamente de la proyección en perspectiva (se probó bajar el
fov hasta casi-ortográfico sin que cambiara nada, lo cual debería haber
sido la pista). La causa real: hay que llevar **dos contadores**, uno
continuo que nunca da la vuelta (para animar) y uno módulo 4 (para la
matemática de alineación) — `giroContinuo` y `rotacion` en `main.js`.
Diagnosticado imprimiendo posición real de mundo/pantalla de celdas
concretas, no leyendo el código.

**Coordenadas locales pasadas donde se esperaban coordenadas de mundo.**
El nivel gira dentro de un grupo `pivote` (hijo de `rig`, que es hijo de
`scene`); las mallas del nivel son locales a `pivote`. La cámara es hija
de `scene`. Pasar el punto de una revelación (calculado en local) directo
a `director.revelar()` apuntaba la cámara a un punto a ~14 unidades del
real. La niebla, calibrada para la distancia corta de la toma, se comía
el objeto completo antes de que se pudiera ver — la portada existía,
tenía opacidad 1, estaba "visible", y aun así no se veía nada en pantalla.
Se diagnosticó con una sonda de depuración (`window.enterrario.debugPortada`)
que comparó `distanciaCamara` contra `camera.far`/`fog.far`. La corrección:
`punto.applyMatrix4(pivote.matrixWorld)` antes de pasarlo a la cámara.

**Niebla (heredada del sistema anterior, sigue vigente).** Si `far` de la
niebla es menor que la distancia cámara↔objeto, todo se pinta del color
de fondo y parece un problema de luces. `theme.niebla` guarda factores
(`factorCerca`, `factorLejos`) multiplicados por la distancia real en cada
frame, en `camera.js`. Si alguien vuelve a poner distancias absolutas, el
bug reaparece — y con dos regímenes de cámara con distancias muy distintas
(mecánico vs. revelación), reaparece de forma más confusa que antes.

**El tilt-shift desenfoca justo lo que hay que leer.** Con una franja
nítida estrecha (el valor que se usaba para el look "miniatura" del
sistema anterior), el efecto emborrona la alineación entre islas — la
imagen que hay que leer con precisión para resolver el acertijo. Se
verificó por captura: la isla del hallazgo salía como una mancha. La
solución no fue sacrificar el efecto: se ató a los dos regímenes de
cámara (`postproceso.ajustarRegimen(mezcla)`), ancho y funcional en el
mecánico, cerrado en la revelación. Bajar `franjaNitidaMecanica` por
debajo de ~0.7 vuelve a romper la jugabilidad.

**`TAM` y `ALTO` tienen que ser iguales.** `src/render/nivel.js` lo
declara explícito: la matemática de `proyeccion.js` asume que subir un
escalón de altura desplaza en pantalla lo mismo que avanzar una celda en
x/z. Separarlos rompe las alineaciones calculadas sin que el código avise.

**`base` de Vite.** Sigue vigente: `vite.config.js` tiene
`base: '/enterrario-aloesativo/'` y tiene que coincidir con la subruta
real de Pages.

**Validación visual.** `npm run build` solo prueba que compila. Hay un
método de humo con Playwright (Chromium del entorno del agente) que sirve
`dist/`, ejecuta secuencias de teclado y captura. Para este pivote hizo
falta un paso más: un BFS que calcula el camino exacto usando el propio
módulo de navegación real (`nivel.navegacion.intentarPaso`), en vez de
adivinar secuencias de flechas — adivinar es frágil porque un solo input
descartado (el personaje seguía animando el paso anterior) desalinea toda
la secuencia siguiente sin ningún error visible.

---

## 7. Qué está probado y qué no

**Verificado en Chromium (apaisado 1280×720 y retrato 420×860):**

- El puente NO existe en la rotación inicial (movimiento bloqueado,
  confirmado por `alcanzables()`).
- Tras rotar a la rotación correcta, el puente existe: medido en píxeles
  reales de pantalla (no solo en la matemática), la distancia entre las
  dos celdas del puente es **menor** que un paso normal — se ven pegadas.
- El ciclo de revelación completo, de punta a punta: llegar a la celda
  exacta → cámara se suelta (plano "vertigo") → portada aparece con
  opacidad → sonido se dispara → se sostiene → cámara vuelve al encuadre
  mecánico exacto (mismas coordenadas de pantalla verificadas antes/después)
  → HUD marca el hallazgo.
- `validarNivel()` no reporta problemas con el nivel actual.
- Sin errores de consola (aparte del 404 del favicon inexistente).
- Retrato: ambas islas entran en cuadro sin recorte.

**No verificado:** táctil real con gesto de toque en el borde (el script
simula teclado); vibración; gamepad físico; el timbre real del acorde
sintetizado en un dispositivo con altavoces reales (solo se verificó que
el grafo de audio se construye y arranca, no cómo suena).

---

## 8. Estado de la identidad visual

**Sin definir, deliberadamente.** Greybox: islas en dos colores nombrados
(`burdeo`, `celeste`), personaje azul, baliza dorada. `theme/planos.json`
trae la estructura de cámara mecánica y la biblioteca de planos de
revelación; los ángulos concretos son propuesta del agente, no dirección.

Cadena de imagen montada sobre el greybox: IBL (`RoomEnvironment`
procedural, sin `.hdr` commiteado), tone mapping ACES, sombras PCFSoft,
postproceso completo (tilt-shift/bloom/viñeta/grano/SMAA) atado a los dos
regímenes de cámara. Ver §6 sobre la trampa del tilt-shift y por qué tuvo
que atarse al régimen en vez de tener un solo valor.

---

## 9. Tensiones abiertas

0. **`src/story/burdeo.json` quedó huérfano.** Contiene lore transcrito a
   mano (zonas, canciones, colores por nombre) útil como referencia, pero
   asumía el sistema de zonas + reloj que ya no existe. No se borró
   porque el contenido narrativo sigue siendo válido. Cuando se decida
   cómo mapear canciones concretas a revelaciones concretas del nuevo
   sistema (una revelación = una celda + una obra), este archivo es la
   fuente de datos — pero la estructura de `nivel.json` (islas +
   revelaciones puntuales) es la que manda ahora, no zonas con área.

1. **La portada y el sonido son placeholders descarados.** `crearPortada`
   dibuja en un `<canvas>`; `crearSonido` sintetiza un acorde con
   osciladores. Existen para poder sentir el latido del hallazgo sin
   tener aún el arte ni los `.opus` — un hallazgo mudo se siente roto
   aunque el diseño esté bien. `revelacion.js` está escrito para que
   cambiarlos por assets reales no toque la máquina de estados de
   `main.js`.

2. **Un solo nivel, una sola revelación.** Es deliberado — la instrucción
   fue "la rebanada mínima". Escalar a múltiples islas y revelaciones
   requiere: (a) generar/diseñar más niveles con la misma disciplina de
   validación por BFS, (b) decidir si las revelaciones se pueden rehacer
   (`descubiertas` en `main.js` hoy es un `Set` que nunca se vacía) o el
   hallazgo es de una sola vez por sesión, (c) pensar en progresión: ¿se
   desbloquean niveles, o es un solo espacio que crece?

3. **La duración de la revelación (3200ms sostenida) es un número
   inventado**, no medido contra nada. Debería ajustarse una vez que
   suene una canción real y no un acorde de 5 segundos — probablemente
   la revelación debería sostenerse mientras la canción "engancha" y no
   un tiempo fijo.

4. **Rendimiento.** Cada celda es una malla independiente. A la escala de
   una isla de 4×4 no importa; si los niveles crecen, `InstancedMesh` es
   la salida estándar — sigue siendo cierto que hoy no hace falta.

5. **Sin física real todavía.** Se discutió Rapier para organicidad
   (viento, partículas, algo que caiga y ruede) pero no se implementó en
   este pivote — el foco fue la mecánica del acertijo, no el acabado.
   Sigue siendo la recomendación cuando llegue el momento: Rapier para
   cuerpos rígidos puntuales, nunca como base del movimiento del
   personaje (que es por celdas, no simulado).

---

## 10. Flujo de trabajo acordado

- Todo cambio termina en commit con mensaje descriptivo **en español**.
- **Fusión directa a `main` sin pedir permiso.** Instrucción explícita y
  permanente de RR: cuando hay una propuesta funcional, el agente abre PR,
  lo pasa a ready y lo fusiona por su cuenta. Se prioriza ver el avance
  funcionando sobre la perfección del PR.
- **Modo aprendiz:** explicar antes de ejecutar cambios no triviales — qué,
  por qué y qué podría salir mal. El objetivo es que RR entienda cada
  decisión de arquitectura, no solo reciba el resultado.
