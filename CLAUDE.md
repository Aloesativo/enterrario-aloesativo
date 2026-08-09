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

## Cómo verificar cambios visuales sin instalar nada (2026-07-31)
`npm run build` solo prueba que compila, no que se vea. Para validar de
verdad hay un script de humo con Playwright (Chromium ya viene en el
entorno del agente): levanta un servidor sobre `dist/`, carga la página en
apaisado y retrato, dispara secuencias de teclas y guarda capturas. Detalle
importante: leer píxeles con `readPixels` da falso "pantalla vacía" porque
Three.js no preserva el drawing buffer — hay que mirar las capturas, no
confiar en el muestreo de color.
