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
