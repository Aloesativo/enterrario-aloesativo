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

## Correr el prototipo

```bash
npm install
npm run dev
```

Abre la URL que imprime Vite. Parámetros de prueba en la URL:

- `?semilla=texto-o-numero` — misma semilla, mismo diorama (reproducible).
- `?tamano=20` — tamaño de la grilla (default 12x12).

## Estado actual

Greybox: terreno con altura por ruido (senos, no Perlin real — no hace
falta más para el prototipo), agua en las celdas más bajas, props cúbicos
esparcidos al azar. Sin identidad visual todavía — es exactamente lo que
se espera del prototipo en esta etapa: validar que la *composición*
generada se vea bien en isométrico antes de gastar tiempo en arte.
