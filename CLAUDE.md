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
