# CLAUDE.md — Enterrario

## Qué es esto
Prototipo de diorama 3D isométrico procedural del universo Aloesativo.
Repo hermano de `Aloesativo/Aloesativo` (catálogo/lore), pero **sin
conexión técnica** entre ambos — nada de submodules, exports automáticos
ni fetch de datos entre repos. La relación es curatorial: el lore se lee
como referencia de diseño (moodboard), no se importa como dato.

## Modo aprendiz (heredado del repo madre)
Explica antes de ejecutar cambios no triviales: qué vas a hacer, por qué,
y qué podría salir mal. El objetivo es que RR entienda cada decisión de
arquitectura, no solo reciba el resultado.

## Regla de las tres capas — NO MEZCLAR
- `src/generator/` — datos puros. Nunca importa `three` ni lee `theme/`.
- `src/render/` — traduce datos a mallas. Puede leer `theme/`, nunca
  contiene lógica de generación (alturas, ruido, colocación de props).
- `src/theme/` — paletas/materiales. Es la única capa que se reemplaza al
  definir identidad visual. Si una decisión de identidad visual termina
  escrita en `generator/` o hardcodeada en `render/`, es un error de
  arquitectura — repórtalo, no lo dejes pasar.

## Identidad visual
No se decide en este repo por el agente. RR define paleta/estilo/mood
(ver moodboard, referencias) y esas decisiones se traducen a
`src/theme/*.json`. El agente puede proponer estructura para el JSON,
nunca elegir colores o estilo por su cuenta.

## Disciplina de cambios
Todo cambio termina en commit con mensaje descriptivo en español.

## Flujo de fusión: directo a main, sin pedir permiso (2026-07-31)
RR quiere iterar rápido y ver el resultado en Pages sin fricción de
revisión. Instrucción explícita y permanente: cuando el agente termine
una propuesta funcional, la fusiona a `main` por su cuenta — abre PR,
lo pasa a "ready" y lo fusiona sin esperar aprobación de RR en el chat.
No importa si algo queda roto o a medio pulir: se prioriza ver el avance
funcionando ("al tiro") sobre la perfección del PR. Esto reemplaza el
comportamiento por defecto de pedir confirmación antes de fusionar —
para *este* repo, la fusión a main ya está autorizada de antemano en
cada tarea, no hace falta preguntar de nuevo cada vez.

## Despliegue: GitHub Pages, no local
RR no quiere instalar herramientas de desarrollo en su máquina (la usa
para música). El flujo de trabajo es: cambios → push a `main` →
`.github/workflows/deploy.yml` compila y publica solo en
`https://aloesativo.github.io/enterrario-aloesativo/`. Esa es LA URL para
que RR vea el estado del prototipo — nunca generar un Artifact ni mandar
un link de StackBlitz como sustituto; ya se probaron ambos y no
funcionaron como flujo estable (ver README, sección correspondiente).
Si se cambia `vite.config.js`, cuidado con `base: '/enterrario-aloesativo/'`
— tiene que coincidir con la subruta real de Pages o los assets no cargan.

## Lección del bug de niebla (2026-07-31)
La niebla (`theme.niebla`) tiene que tener `lejos` mayor a la distancia
real cámara↔objeto, si no todo se pinta invisible (color de niebla ≈
color de fondo) aunque geometría/luces/cámara estén bien. Si algo se ve
"negro" sin motivo aparente, revisar la niebla ANTES que luces o cámara —
es la causa más barata de descartar y la más fácil de pasar por alto.

**Actualización:** desde que la cámara se mueve entre planos, la distancia
cámara↔objeto dejó de ser constante, así que unos valores fijos de niebla
no podían servir para todos los encuadres. Ahora `theme.niebla` guarda
`factorCerca`/`factorLejos` (multiplicadores) y `render/camera.js`
recalcula `near`/`far` por frame a partir de la distancia real. Si se
vuelven a poner distancias absolutas ahí, el bug reaparece — pero solo en
algunos planos, que es peor porque parece intermitente.

## Migración a Godot (2026-08-09) — decisión de RR, registrada acá para no volver a perderla
RR ya había acordado esto en otra conversación que no quedó anotada en
ningún repo — se perdió y hubo que retomarla desde cero. Para que no
vuelva a pasar: **la intención es reemplazar** el pipeline Three.js/Vite
de `src/` por un prototipo en Godot, que RR corre en vivo en un
computador dedicado (no el que usa para música) con un control conectado
— necesita esa iteración rápida, con más autonomía y control que lo que
da iterar solo contra Pages. También quiere que el resultado siga siendo
liviano y exportable a web, no solo de escritorio.

El prototipo Godot vive en `godot/` (raíz de proyecto en
`godot/project.godot`, no en la raíz del repo). Mientras no esté
verificado corriendo en la máquina de RR, `src/` y el deploy a Pages
siguen intactos — así siempre hay algo mostrable. El día que Godot ande,
se retira `src/` y `.github/workflows/deploy.yml` pasa a exportar el
proyecto Godot en vez de compilar Vite. Ver `godot/README.md` para el
estado exacto de qué es mecánica real y qué es placeholder.

**Consecuencia sobre "Despliegue: GitHub Pages, no local" (arriba):** esa
regla seguía siendo "no instalar herramientas de desarrollo" pensando en
la máquina de música de RR. Con Godot esa restricción cambia de forma
puntual — RR instala el editor de Godot, pero en un computador aparte
dedicado a esto. La regla de Pages como única forma de ver el prototipo
sigue vigente para el track de Three.js; para Godot, la verificación es
local, en el editor de RR.

**Limitación técnica de esta sesión, anotada para la próxima:** el agente
no pudo instalar ni correr el editor de Godot en el entorno remoto donde
corre esta sesión (descarga bloqueada por política de red del entorno,
no algo que se pueda evitar). Los `.tscn`/`.gd` de `godot/` se escribieron
a mano sin poder probarlos — la primera verificación real es la de RR.

**RR siempre prueba Godot él mismo, en su máquina — nunca el agente.**
Esto ya estaba dicho arriba pero vale repetirlo explícito: el agente no
tiene forma de correr Godot en ningún entorno donde corren estas
sesiones. Cada cambio a `godot/` es código escrito leyendo con cuidado,
sin ejecutar — la primera vez que corre de verdad es cuando RR le da
play. Esto no es una limitación transitoria de "esta sesión": es
estructural, va a seguir siendo así.

## ANTES DE TOCAR `godot/`: leer `DISENO_GODOT.md` (2026-08-09)
Existe un documento de diseño acordado con RR, escrito después de que dos
prototipos en Godot se construyeran sin diseño previo y terminaran rotos.
**Si vas a escribir código en `godot/`, leelo primero.** Si lo que vas a
escribir no está ahí: no lo escribas — proponelo, acuérdenlo, anótalo, y
recién después constrúyelo.

Lo más importante que contiene, porque es la causa raíz del último
fracaso: **el personaje se mueve por celdas discretas, un paso por
empujón — nunca con velocidad continua ni `move_and_slide()`.** La regla
del juego ("puedes pisar lo que se ve pegado a ti") compara posiciones en
pantalla buscando igualdad exacta; con movimiento continuo esa igualdad
no ocurre nunca y el mecanismo central del juego directamente no puede
funcionar. No es preferencia de estilo, es condición de existencia.

## El diorama unificado rompió todo al probarlo — pausa para rediseñar (2026-08-09)
RR probó el PR #18 (diorama unificado, ver entrada de arriba) en su
máquina y reportó que "rompió completamente toda la funcionalidad" —
regresión total confirmada, no un detalle menor. No se diagnosticó línea
por línea todavía: en vez de seguir iterando a ciegas sobre código que el
agente no puede verificar, RR pidió frenar la implementación y hacer
primero una fase explícita de diseño (mecánicas, alcance, qué se
construye y en qué orden) antes de escribir una sola línea más de Godot.
Ver la sección correspondiente más abajo (o el documento de diseño que
resulte de esa conversación) para el estado actual de esa fase.

## Bug del mapa-zoom sin vuelta atrás (2026-08-09)
RR probó el prototipo Godot y reportó: el zoom hacia una zona funciona,
pero una vez adentro "se queda pegado" y no hay forma de volver al mapa.
Causa real: `escenario.gd` (el script que comparten las 5 escenas de
zona) nunca tuvo código para volver — no era un bug de estado, era una
mecánica directamente inexistente, un viaje solo de ida. Se agregó
`_volver_al_mapa()` con varios disparadores (Escape/`ui_cancel` — que ya
cubre el botón B de un control por defecto en Godot —, rueda del mouse
hacia abajo, y `-`/`KP_SUBTRACT`), simétrico a como `mapa.gd` ya entra a
una zona. Ver `godot/README.md` para los controles actualizados.

**Advertencia para la próxima sesión:** esto se corrigió leyendo el
código, no corriendo el proyecto — el agente sigue sin poder ejecutar
Godot en este entorno (ver limitación arriba). Si RR prueba esto y el
bug persiste o cambia de forma, copiar el mensaje de la terminal tal
cual, no resumirlo.

**Superado por el pivote de abajo ("Diorama unificado"):** el modelo de
5 escenas separadas + `escenario.gd` que este bug describe ya no existe
— se reemplazó por un único mundo, así que "volver al mapa" dejó de
tener sentido como mecánica (no hay a dónde volver, ya estás ahí). Se
deja esta entrada como historial de por qué el diseño cambió.

## Diorama unificado: se retiran las 5 escenas de zona (2026-08-09)
RR probó el fix de arriba y confirmó que andaba, pero al pedir el
siguiente paso quedó claro que el modelo de fondo estaba mal: "hay que
recuperar lo que existía antes, donde había un personaje... el mapa no
tiene que ser un plano, es tridimensional, con vista fija, y tiene que
dejar ver la ciudad, el cometa, la luna, la playa". Señal concreta de
que algo estaba desalineado: RR mencionó "el cometa" como zona y esa
zona **no existía** en `mapa.gd` (sí existe en `src/story/burdeo.json`).

Diagnóstico: `godot/` nunca se construyó a partir del diseño ya validado
de `src/mundo/` (proyeccion.js + navegacion.js + nivel.json — islas con
relieve real, cámara isométrica fija, personaje que camina y descubre).
Se inventó en su lugar un mecanismo distinto y más simple (mapa plano +
zoom que teletransporta a una escena aparte) — dos diseños de juego
conviviendo en el repo sin que nadie lo hubiera notado. Ver INFORME.md
para el diseño original completo.

RR eligió explícitamente el alcance para retomar esto: portar el
diorama 3D con relieve real + cámara fija + personaje visible, **sin**
todavía el acertijo de rotación/ambigüedad isométrica (eso queda para
un paso siguiente, a propósito). Se reescribió `mapa.gd` para plantar
las 5 zonas como plataformas a distinta altura (no cajas sobre un
plano), agregar el personaje directamente al diorama (ya no vive en una
escena aparte), y una cámara isométrica fija que lo sigue sin zoom
manual ni pan independiente. Se agregó "el cometa" como elemento del
cielo sin colisión, tal como lo describe el lore ("atraviesa el mapa
entero en vez de ocupar un lugar"). Se borraron `escenario.gd` y las 5
escenas de zona (`Ciudad.tscn`, `Playa.tscn`, `Bosque.tscn`, `Luna.tscn`,
`OtroPlaneta.tscn`) por quedar sin uso — el diorama entero es ahora
`escenas/Mapa.tscn`. Ver `godot/README.md` para el detalle de qué
conecta a pie hoy (ciudad/playa/bosque) y qué queda como isla elevada
visible pero inalcanzable a propósito (luna/otro-planeta), hasta que se
porte el acertijo de rotación.

**Lección para no repetir esto:** cuando este repo tiene un diseño ya
validado en otra capa (acá, `src/mundo/` + `INFORME.md`), un prototipo
nuevo en otra tecnología tiene que partir de ESE diseño, no improvisar
uno más simple porque es más rápido de escribir. Si hay una razón real
para simplificar (como acá, dejar el acertijo para después), documentarla
explícitamente como alcance reducido — no dejar que parezca el diseño
final por omisión.

## Ramas duplicadas/conflictivas — limpieza (2026-08-09)
Se encontraron 6 ramas de sesiones anteriores en el remoto cuyo contenido
ya estaba integrado a `main` (mismas ideas, distinto commit — sesiones
paralelas que no se enteraron entre sí). Una de ellas (PR #16,
`claude/godot-dev-workflow-sii48j`) estaba además en conflicto real
(`mergeable_state: dirty`) contra `main` porque RR había aplicado el
mismo cambio directo en el editor de Godot. Se cerró ese PR sin fusionar
y se documentó la razón en el comentario.

**Limitación encontrada:** el agente no tiene forma de borrar ramas en
este entorno — ni `git push --delete` (403 del proxy) ni las
herramientas de GitHub disponibles incluyen borrado de rama. Quedan
colgando (inertes, no van a volver a aparecer como conflicto salvo que
alguien abra un PR nuevo desde ellas): `claude/controls-config-lore-1zn5te`,
`claude/diorama-music-albums-q0zoze`, `claude/enterrario-lore-pendiente-9xxdht`,
`claude/godot-dev-workflow-sii48j`, `claude/lore-migration-godot-prototype-jukiqn`,
`claude/visual-controls-multidevice-5hpc67`. RR puede borrarlas con un
clic desde github.com/Aloesativo/enterrario-aloesativo/branches. Si una
próxima sesión tiene una herramienta de borrado disponible, puede
hacerlo directamente — ya están verificadas como seguras de borrar.

## Cómo verificar cambios visuales sin instalar nada (2026-07-31)
`npm run build` solo prueba que compila, no que se vea. Para validar de
verdad hay un script de humo con Playwright (Chromium ya viene en el
entorno del agente): levanta un servidor sobre `dist/`, carga la página en
apaisado y retrato, dispara secuencias de teclas y guarda capturas. Detalle
importante: leer píxeles con `readPixels` da falso "pantalla vacía" porque
Three.js no preserva el drawing buffer — hay que mirar las capturas, no
confiar en el muestreo de color.
