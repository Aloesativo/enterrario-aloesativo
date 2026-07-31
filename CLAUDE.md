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
