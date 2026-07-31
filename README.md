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
src/generator/   → datos puros (grilla, alturas, semilla). No sabe de Three.js ni colores.
src/render/      → Three.js: cámara isométrica ortográfica + traduce datos a mallas.
src/theme/       → paleta/materiales. Es lo único que cambia cuando definas identidad visual.
```

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
