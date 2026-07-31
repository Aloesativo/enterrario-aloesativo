# Informe del repositorio — Enterrario

Documento de traspaso de contexto. Sirve para abrir un chat nuevo y entrar
directo a discutir arquitectura sin tener que redescubrir el estado del
prototipo. Fecha del corte: 2026-07-31.

---

## 1. Qué es

Prototipo de diorama 3D procedural del universo Aloesativo: un terrario
generado por semilla, observado con cámara cinematográfica, con un
personaje que camina por la grilla. Repo hermano de `Aloesativo/Aloesativo`
(catálogo/lore), **sin ninguna conexión técnica** — la relación es
curatorial, el lore se lee como moodboard y no se importa como dato.

Stack: Vite + Three.js, sin framework. Todo el código es JavaScript de
módulos ES, en español.

**URL de verdad del prototipo:**
`https://aloesativo.github.io/enterrario-aloesativo/`
No hay flujo local: RR no instala herramientas de desarrollo en su máquina.
Cada push a `main` compila y publica vía `.github/workflows/deploy.yml`.
Se probaron Artifacts y StackBlitz como sustitutos y ninguno dio un flujo
estable.

---

## 2. La regla de las tres capas

Es la restricción arquitectónica central del repo y está pensada para que
la identidad visual sea reemplazable sin tocar la lógica.

| Capa | Carpeta | Puede | No puede |
|---|---|---|---|
| Datos | `src/generator/` | Generar estructura pura | Importar `three`, leer `theme/` |
| Traducción | `src/render/` | Leer `theme/`, crear mallas y cámara | Contener lógica de generación ni valores de identidad hardcodeados |
| Identidad | `src/theme/` | Definir paleta, materiales, composición | — |

Regla operativa: **si una decisión de identidad visual termina escrita en
`generator/` o hardcodeada en `render/`, es un error de arquitectura y hay
que reportarlo, no dejarlo pasar.**

Corolario que ya se aplicó una vez: el shot list de cámara vive en
`src/theme/planos.json`, no en `render/`, porque decidir dónde se para la
cámara y qué cuenta cada plano es composición — o sea identidad visual.

---

## 3. Mapa de módulos

```
index.html                 Canvas + HUD + reglas anti-fricción táctil
vite.config.js             base: '/enterrario-aloesativo/'  (crítico para Pages)
src/main.js                Cableado: arma el grafo y corre el bucle
src/generator/seed.js      PRNG determinista (mulberry32) + hash de texto a semilla
src/generator/grid.js      Genera la grilla de celdas (altura, tipo, props)
src/render/scene.js        Escena, luces, sombras, renderer, resize
src/render/camera.js       Director de cámara (el módulo más denso)
src/render/controls.js     Entrada → órdenes al director
src/render/tiles.js        Celdas de datos → mallas de bloques
src/render/personaje.js    Malla del personaje + movimiento por la grilla
src/render/entorno.js      IBL (luz de entorno) + tone mapping
src/render/postproceso.js  Efectos: tilt-shift, bloom, viñeta, grano, SMAA
src/render/modelo.js       Carga de diorama autorado (.glb), con respaldo
src/theme/default.json     Paleta, luces, niebla, entorno, sombras, postproceso
src/theme/planos.json      Grilla de encuadres + shot list
```

### Flujo de datos

```
semilla (URL) ─▶ grid.js ─▶ {celdas} ─┬─▶ tiles.js ──▶ mallas ─┐
                                       └─▶ personaje.js         ├─▶ rig (Group)
                                                                │
theme/*.json ──────────────────────────────────────────────────┘
                                                                 │
controls.js ─▶ camera.js (director) ─▶ cámara + niebla ◀─────────┘
```

El `rig` es un `THREE.Group` que contiene el diorama y el personaje. Casi
siempre está quieto: quien se mueve es la cámara. Solo gira cuando un plano
declara un `volteo`.

---

## 4. El director de cámara (`src/render/camera.js`)

Es donde está la decisión de diseño más fuerte del prototipo, así que
conviene entenderla antes de proponer cambios.

**Qué reemplazó.** Antes había una `OrthographicCamera` fija y los cambios
de vista rotaban el diorama alrededor del eje Y. Como la cámara nunca se
movía, la altura del punto de vista era siempre la misma: cambiaba qué cara
quedaba al frente, nunca la composición. Girar un objeto sobre un plato, no
lenguaje de cámara.

**Decisiones clave:**

1. **Una sola `PerspectiveCamera` con `fov` animable.** Alternar entre
   cámara ortográfica y cámara en perspectiva significa dos objetos
   distintos, y no se pueden interpolar. Con un fov muy bajo a mucha
   distancia el resultado es visualmente indistinguible de una proyección
   ortográfica (el look isométrico original), y con fov alto hay fuga real.
   Al ser un solo número, se anima: mantener el encuadre mientras el fov
   sube es literalmente un dolly zoom.

2. **La distancia se deriva, no se elige:**
   `distancia = encuadre / (2·tan(fov/2))`.
   Así "cuánto se ve" (encuadre) y "cuánta fuga hay" (fov) son parámetros
   independientes, igual que encuadre y focal en una cámara real.

3. **Grilla de celdas + planos curados.** El estado discreto son dos
   índices: azimut (8 pasos) y elevación (5 escalones). Cada par es una
   celda. Las celdas que aparecen en `planos.json` traen encuadre, fov,
   roll, objetivo y volteo propios; las demás usan el encuadre genérico.
   Esto da el comportamiento pedido: pasos regulares que *caen* en planos,
   en vez de un rango continuo recorrido a mano.

4. **Objetivo vivo.** Un plano mira al centro del diorama o al personaje.
   Durante una transición se interpola entre ambos, recalculando el destino
   cada frame porque el personaje se mueve mientras tanto.

5. **Híbrido cámara/mundo.** Un plano puede declarar `volteo` y entonces lo
   que gira es el rig, no la cámara. Es el momento rubik.

6. **Niebla derivada de la distancia.** Ver sección 6.

7. **Corrección por aspecto.** En pantallas verticales se encuadra más alto
   para que el diorama entre a lo ancho. Sin esto el mismo plano se ve bien
   en apaisado y recortado en retrato.

---

## 5. Controles

Diseñados bajo el requisito de que sean intuitivos **sin mapeo previo** y
funcionen igual en móvil, tableta, desktop y gamepad.

| Entrada | Efecto |
|---|---|
| `A` / `D` | Paso de azimut (gira alrededor) |
| `W` / `S` | Escalón de elevación (sube / baja) |
| `R`, doble tap, botón A del gamepad | Vuelve al plano base |
| Flechas | Mueven al personaje |
| Arrastrar (1 dedo / mouse) | Órbita libre con inercia |
| 2 dedos (torsión) | Inclinación de cámara (ángulo holandés) |
| Stick izquierdo | Órbita libre |
| Gatillos LT/RT | Inclinación |
| Bumpers LB/RB | Pasos de azimut (acceso a planos sin teclado) |

Dos detalles que resuelven fricción real y conviene no romper:

- **Las flechas son relativas a la pantalla, no a la grilla.** El director
  expone los ejes de pantalla traducidos a coordenadas de grilla (y los
  destuerce si el mundo está volteado). Sin esto, después de girar el
  encuadre la flecha "arriba" movería al personaje en diagonal respecto de
  lo que el ojo espera.
- **Vibración diferenciada.** Llegar a un plano con nombre vibra distinto
  que caer en una celda genérica; chocar contra agua o borde vibra distinto
  que caminar.

---

## 6. Trampas conocidas (leer antes de tocar)

**Niebla.** Fue el bug más caro del proyecto. Si `far` de la niebla es
menor que la distancia cámara↔objeto, todo se pinta del color de fondo y
parece un problema de luces o de cámara. Desde que la cámara se mueve entre
planos la distancia dejó de ser constante, así que `theme.niebla` guarda
**factores** (`factorCerca`, `factorLejos`) y `camera.js` recalcula
`near`/`far` por frame. Si alguien vuelve a poner distancias absolutas, el
bug reaparece solo en algunos planos — peor, porque parece intermitente.

**Sombras que parecen no funcionar.** Con el sol en `[10, 20, 10]`
(~55° de altura) las sombras salen tan cortas que el propio objeto las tapa
desde la cámara casi cenital del plano base. Parece que `castShadow` no
está haciendo nada. **Lo está haciendo**: con un sol rasante tipo
`[16, 5, 7]` aparecen de inmediato. Verificado por captura el 2026-07-31.
Trampa dentro de la trampa: bajar la luz ambiental o `entorno.intensidad`
NO es lo que las hace visibles — se probaron ambas y el cambio es marginal.
El ángulo es la variable, y vive en `theme.luz.posicion`.

**`base` de Vite.** `vite.config.js` tiene `base: '/enterrario-aloesativo/'`
y tiene que coincidir con la subruta real de Pages o no carga ningún asset.

**Validación visual.** `npm run build` solo prueba que compila. Para saber
si se *ve*, hay un método de humo con Playwright y el Chromium que ya trae
el entorno del agente: servidor sobre `dist/`, carga en apaisado y retrato,
secuencias de teclas, capturas. Trampa dentro de la trampa: leer píxeles con
`readPixels` da falso "pantalla vacía" porque Three.js no preserva el
drawing buffer — hay que mirar las capturas.

---

## 7. Qué está probado y qué no

**Verificado en Chromium (apaisado 1280×720 y retrato 420×860):** carga sin
errores de consola; todos los planos del shot list se alcanzan por
combinación de teclas; el volteo del mundo se ejecuta; el personaje se mueve
y respeta bordes y agua; el reset vuelve al plano base; en retrato el
diorama entra completo sin recortes.

**No verificado:** táctil real con dos dedos (el script simula teclado);
vibración (no hay hardware en el entorno de prueba); gamepad físico
Xbox/Android; rendimiento en un teléfono real.

---

## 8. Estado de la identidad visual

**Sin definir, deliberadamente.** `theme/default.json` es un greybox: grises
para el suelo, rojo para props, azul para el personaje. Son placeholders
arbitrarios, no propuestas. Lo mismo vale para los números de
`theme/planos.json`: la estructura es propuesta del agente, los valores
concretos (qué ángulo, qué encuadre, qué cuenta cada plano) le corresponden
a RR.

Direcciones técnicas discutidas para darle personalidad. **El mecanismo de
1, 2 y 4 ya está montado** (2026-07-31); los valores siguen siendo
placeholders a la espera de RR:

1. ✅ **Tilt-shift / profundidad de campo falsa** — montado en
   `render/postproceso.js`. Es el efecto que hace que un diorama se lea
   como miniatura fotografiada: al desenfocar arriba y abajo dejando una
   franja nítida, el ojo interpreta profundidad de campo corta, y eso solo
   ocurre de verdad al fotografiar algo muy pequeño muy de cerca.
   Comparación directa con `?postproceso=off`.
2. ✅ **Sombras proyectadas** — activas en `render/scene.js`. Ver abajo la
   trampa del ángulo del sol.
3. ⬜ **Ambient occlusion en las juntas** — hace que el voxel-grid se lea
   como objeto físico. Pendiente; con `postprocessing` ya instalado, es
   añadir un efecto más a la cadena.
4. ✅ **Grano + viñeta** — montados en la misma cadena.
5. ⬜ **Cel-shading con contorno** — cambia el lenguaje visual entero; es
   una decisión de identidad grande, no un ajuste incremental.
6. ⬜ **Wobble sutil en vértices** — rompe la perfección geométrica, da
   sensación artesanal.

**Añadido: iluminación de entorno (IBL).** `render/entorno.js` instala un
entorno procedural (`RoomEnvironment`) más tone mapping ACES. Es lo que
separa "tiene luz" de "está en un lugar": una `AmbientLight` suma un color
plano a todas las caras por igual, un entorno aporta luz distinta según
hacia dónde mira cada cara. No se commiteó ningún `.hdr` para no meter
binarios ni licencias al repo; el enchufe queda listo en `theme.entorno`.

---

## 9. Tensiones arquitectónicas abiertas

Los puntos que valen una conversación de diseño:

0. **Hornear la luz rompe la regla de las tres capas.** Es la tensión nueva
   y la más incómoda. Si el diorama pasa a modelarse en Blender con la
   iluminación horneada en las texturas (que es la vía de más calidad por
   menos coste en runtime), entonces decisiones de identidad visual —luz,
   color, materiales— quedan **dentro del `.glb`**, o sea fuera de
   `theme/`. La regla dice que `theme/` es la única capa que se reemplaza
   al definir identidad, y con un modelo horneado eso deja de ser cierto.
   Salida posible: que `theme/` gobierne "qué `.glb` se carga y qué
   postproceso se le aplica" en vez de "qué color tiene cada cosa". No
   está decidido — le toca a RR.

1. **¿`planos.json` es identidad o es lógica?** Hoy vive en `theme/` con el
   argumento de que la composición es identidad visual. Pero mezcla dos
   cosas: parámetros de mecanismo (cuántos pasos de azimut, qué elevaciones
   existen) y decisiones de dirección (qué cuenta cada plano). Podrían
   separarse.

2. **El generador no sabe nada del personaje.** `grid.js` produce terreno;
   la celda inicial se elige después, en `render/`. Si el personaje va a
   tener reglas de juego (objetivos, colisiones ricas, items), esa lógica no
   cabe ni en `generator/` (que es datos puros) ni en `render/` (que es
   traducción). **Probablemente falta una cuarta capa de simulación/juego.**
   Es la decisión estructural más importante pendiente.

3. **El volteo del mundo y la gravedad.** Hoy `volteo` es puramente visual:
   el mundo gira pero el personaje sigue caminando sobre la misma grilla.
   El brief original hablaba de "un rubik con gravedad". Si la gravedad va a
   cambiar de dirección al voltear, eso es mecánica de juego y refuerza el
   punto 2.

4. **El shot list está desconectado de la narrativa.** Cada plano declara
   qué cuenta, pero nada dispara planos por evento de juego. El paso natural
   sería que el estado del mundo, y no solo el teclado, pueda pedir un plano.

5. **Rendimiento.** Cada celda es una malla independiente
   (12×12 = 144 mallas + props). Funciona holgado a esta escala, pero no
   escala a dioramas grandes. La solución estándar sería `InstancedMesh`.

6. **Un plano del shot list produce un encuadre pobre.** `volteo del
   terrario` da vuelta el mundo 180° y deja a la vista la cara inferior, que
   es una losa plana sin props ni personaje. El mecanismo funciona; el valor
   elegido no cuenta nada. Es exactamente el tipo de número que le toca
   ajustar a RR.

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
