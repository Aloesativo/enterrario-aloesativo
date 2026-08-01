# src/story/ — la capa narrativa

## Qué es y qué NO es

Esta carpeta es una **copia curada a mano** del lore que vive en el repo
hermano `Aloesativo/Aloesativo`. No es un fetch, no es un submodule, no
hay ningún script que sincronice nada. Esa separación es deliberada y
está escrita en `CLAUDE.md`: la relación entre los dos repos es
curatorial, no técnica.

La consecuencia práctica: **el repo madre es la fuente de verdad del
lore; este archivo es un guion derivado.** Si el lore cambia, alguien lo
transcribe a mano. La duplicación es consciente y el precio de mantener
los repos desacoplados.

El filtro al transcribir es: *¿esto es narrable en un diorama?* El lore
tiene material que es contexto de autor y no se traduce a espacio ni a
tiempo. Eso no entra aquí.

## Por qué es una cuarta capa

El INFORME (§9.2) ya había detectado que faltaba una capa y la llamó
"simulación/juego". Con el lore a la vista, el nombre correcto es
**narrativa**: lo que falta no son reglas de juego, es el guion que dice
qué zona existe, qué canción le corresponde y en qué momento del bucle.

Dónde encaja en la regla de las tres capas: `story/` es hermana de
`generator/`, no de `render/`. Ambas son **datos puros** — no importan
`three` ni leen `theme/`. La diferencia es el origen: `generator/`
produce datos por algoritmo, `story/` los trae autorados.

```
src/generator/  datos generados   ─┐
src/story/      datos autorados   ─┼─▶ src/render/ ─▶ mallas
src/theme/      identidad visual  ─┘
```

## La regla del color

El lore dice que cada tema tiene una paleta propia derivada de su portada,
y nombra algunos colores: *burdeo/morado*, *celeste*, *blanco*.

Para no romper la regla de las tres capas, aquí se guarda **el nombre del
color, nunca el valor**. `story/` declara que la ciudad se lee en
"burdeo"; `theme/` es quien decide qué hexadecimal es "burdeo". Así el
guion sigue siendo verdad aunque cambie la identidad visual, y la
identidad sigue siendo reemplazable sin tocar el guion.

## Qué está pendiente

El propio lore avisa (`cronologia-canciones.md`) que hoy esa tabla es
prosa escrita a mano y que ninguna de esas canciones existe todavía como
nota en `obras/`. O sea: **los datos de aquí son provisionales por
diseño**, no por descuido.

Todo lo que este guion NO sabe está marcado con `null` y anotado en
`_pendiente`. En particular: la duración del bucle y los momentos
concretos. El lore da *relaciones* entre canciones ("comparte ventana
con", "otro momento"), no números — y los números le tocan a RR.
