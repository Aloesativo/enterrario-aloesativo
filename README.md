# Enterrario

Prototipo de diorama 3D isométrico procedural del universo Aloesativo.
Repo independiente del catálogo (`Aloesativo/Aloesativo`) — sin conexión
técnica entre ambos, la relación es implícita: el lore y el catálogo son
material de referencia/inspiración, no una fuente de datos que este repo
lea automáticamente.

- **Nombre técnico (slug):** `enterrario-aloesativo`
- **Nombre de marca:** Enterrario
- **Nombre coloquial:** terrario / terrarium

## Arquitectura: tres capas independientes

```
src/generator/   → datos puros generados (grilla, alturas, semilla). No sabe de Three.js ni colores.
src/story/       → datos puros autorados: el guion (zonas, canciones, bucle). Tampoco sabe de Three.js.
src/render/      → Three.js: cámara + traduce datos a mallas.
src/theme/       → paleta/materiales. Es lo único que cambia cuando definas identidad visual.
```

(Son cuatro carpetas pero tres capas: `generator/` y `story/` son la misma
capa de datos puros — una los genera por algoritmo, la otra los trae
autorados desde el lore. Ver `src/story/README.md`.)

La razón de separarlas así: hoy no hay identidad visual definida, pero la
generación procedural sí se puede empezar a probar. `src/theme/default.json`
es un placeholder "greybox" (grises lisos) — cuando tengas paleta y estilo
de material definidos, se reemplaza ese archivo (o se agregan temas
alternativos) sin tocar `generator/` ni la lógica de `render/`.

## Cómo ver el prototipo funcionando (sin instalar nada)

**No hace falta instalar Node ni nada localmente para verlo.** Cada push a
`main` se compila y publica solo, vía GitHub Actions
(`.github/workflows/deploy.yml`), en:

**https://aloesativo.github.io/enterrario-aloesativo/**

Esa URL es fija — se actualiza sola en 1-2 minutos después de cada push.
Basta con abrirla en cualquier navegador. Parámetros de prueba en la URL:

- `?semilla=texto-o-numero` — misma semilla, mismo diorama (reproducible).
- `?tamano=20` — tamaño de la grilla (default 12x12).
- `?postproceso=off` — apaga la cadena de postproceso, para comparar el
  antes/después del tilt-shift sin editar nada.
- `?velocidad=8` — acelera el bucle temporal, para no esperar dos minutos
  a que se abra una ventana.
- `?modelo=archivo.glb` — carga un diorama autorado en vez del procedural.
  El archivo tiene que estar en `public/`. Si falla, se ve el greybox.

Nota histórica: se evaluaron StackBlitz y Claude Artifacts como formas de
previsualizar sin instalar nada — ninguna terminó siendo la vía estable
(StackBlitz requiere que el usuario abra sesión con su GitHub; Artifacts
requiere republicar a mano cada vez y no acepta HTML con `<html>/<head>/
<body>` propios). GitHub Pages + Actions es la que quedó como flujo
definitivo: una sola URL, se actualiza sola, cero pasos manuales.

## Desarrollo (para quien sí quiera correrlo local)

```bash
npm install
npm run dev
```

## Estado actual

Greybox: terreno con altura por ruido (senos, no Perlin real — no hace
falta más para el prototipo), agua en las celdas más bajas, props cúbicos
esparcidos al azar. Sin identidad visual todavía — es exactamente lo que
se espera del prototipo en esta etapa: validar que la *composición*
generada se vea bien en isométrico antes de gastar tiempo en arte.

Sobre ese greybox ya está montada la cadena de imagen completa:
iluminación de entorno (IBL), tone mapping filmico, sombras proyectadas y
postproceso con tilt-shift, bloom, viñeta y grano. El tilt-shift es el
que hace que la escena se lea como *miniatura fotografiada* en vez de
render genérico — compáralo con `?postproceso=off`.

Todos los valores viven en `src/theme/default.json` como placeholders
marcados. El mecanismo está; el look lo define RR.

## Cómo se recorre

El verbo primario es **viajar entre zonas del mapa**, como pide el lore
(*"vista desde arriba, desplazamiento sin rotar, zoom a zonas
específicas"*). Orbitar sigue disponible, pero como gesto secundario.

| Entrada | Efecto |
|---|---|
| `←` `→`, toque en el borde lateral, bumpers | Zona anterior / siguiente |
| `A` `D` `W` `S`, arrastre, stick | Órbita y elevación (secundario) |
| `↑` `↓` | Mueven al personaje dentro de la zona |
| `espacio` | Pausa el reloj del bucle |
| `R`, botón A | Vuelve a la zona inicial |

Se descartó el swipe horizontal para cambiar de zona: un arrastre rápido
de lado a lado es exactamente lo que hace alguien orbitando, así que los
dos gestos competirían. Un toque sin desplazamiento en el borde es
inequívoco.

Desde la consola del navegador (única herramienta de inspección
disponible, dado que no hay flujo local):

```js
enterrario.situar(90)      // salta al segundo 90 del bucle
enterrario.zona('luna')    // viaja a una zona por id
enterrario.queSuena()      // qué sonaría aquí y ahora, y por qué
```

## Qué suena y cuándo

La regla del lore: **la canción depende de dónde miras y de cuándo**. Si
llegas al lugar correcto en el momento equivocado, no suena — porque en
ese momento está pasando otra cosa en otra parte.

Hay dos capas:

- **Instrumentales** (*"música para hacer nada"*) — suenan siempre que
  estés en su zona, sin importar el bucle. Plantas, gnomos, estatuas:
  puntos de contemplación fijos.
- **Temáticas** — solo dentro de su ventana temporal.

Mientras no haya audio, **el HUD es la demostración**: dice qué suena, o
por qué no. Distingue "aquí hay canción pero no es su momento" de "aquí
falta lore todavía", para que el trabajo pendiente se vea.

## El camino hacia el diorama autorado

La generación procedural resuelve "necesito contenido infinito y barato".
El Enterrario necesita lo contrario: unas pocas escenas concretas que
cuenten algo. Por eso `src/render/modelo.js` permite cargar un `.glb`
modelado en Blender, que además habilita **hornear la iluminación**
(calidad de raytracing incrustada en las texturas, coste cero en runtime).

Mientras no exista ese `.glb`, el greybox procedural sigue siendo lo que
se ve. Se puede probar uno sin tocar código con `?modelo=archivo.glb`.

Nota al exportar desde Blender: **sin compresión Draco**. El decodificador
es un wasm aparte que el cargador no incluye, así que un `.glb` con Draco
falla y cae al greybox (queda avisado en la consola).
