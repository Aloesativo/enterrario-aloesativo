# Enterrario

Prototipo de un espacio 3D isométrico del universo Aloesativo, donde
descubrir un punto de vista revela una portada de álbum y hace sonar su
canción. Repo independiente del catálogo (`Aloesativo/Aloesativo`) — sin
conexión técnica entre ambos, la relación es implícita: el lore y el
catálogo son material de referencia/inspiración, no una fuente de datos
que este repo lea automáticamente.

- **Nombre técnico (slug):** `enterrario-aloesativo`
- **Nombre de marca:** Enterrario
- **Nombre coloquial:** terrario / terrarium

## La idea, en una frase

> Mueves al personaje para descubrir a dónde ir. Hay lugares a los que no
> se llega si no rotas el escenario. Al alcanzar ciertos puntos de vista,
> la cámara se suelta, se revela una portada y suena su canción — y luego
> te devuelve exactamente donde estabas.

Es un descubrimiento de canciones, no un mundo procedural. Todo lo demás
—lore, paleta, cadena de imagen— es accesorio y está al servicio de eso.

## El truco: la ambigüedad isométrica (inspirado en Fez)

En proyección isométrica, dos puntos del mundo que están lejísimos pueden
verse **exactamente pegados** desde cierta rotación del escenario. Girar
el mundo 90° no es "mirar mejor": es **cambiar qué está conectado con
qué**. Un abismo que separa dos islas puede desaparecer desde un ángulo y
reaparecer al girar.

Eso es lo que hace jugable el descubrimiento: hay caminos que solo existen
en una rotación, y encontrarlos es el acertijo. `src/mundo/proyeccion.js`
es la matemática exacta de esta ambigüedad; `src/mundo/navegacion.js`
convierte esa matemática en la única regla de movimiento del juego:
**puedes pisar lo que se ve pegado a ti**, sin excepciones.

## Los dos regímenes de cámara

1. **Mecánico** — isométrica fija, nunca se mueve. Su rigidez es la
   condición de que el acertijo se pueda leer: si la cámara se moviera
   sola, las alineaciones cambiarían sin que el jugador lo pidiera.
2. **Revelación** — al descubrir algo, la cámara se suelta (dolly zoom,
   ángulo holandés, retrato, cenital...), aparece la portada, suena algo, y
   la cámara **vuelve exactamente al encuadre del que salió**. El
   significado de un movimiento de cámara no está en el movimiento: está
   en la ruptura de una regla que el jugador llevaba rato obedeciendo. Por
   eso el régimen mecánico es aburrido a propósito.

## Arquitectura: tres capas

```
src/mundo/    → datos y reglas puras: proyección isométrica, navegación, el nivel. No sabe de Three.js.
src/render/   → Three.js: los dos regímenes de cámara, mallas, controles, la revelación.
src/theme/    → composición de cámara y paleta. Lo que cambia al definir identidad visual.
```

`src/mundo/nivel.json` declara el nivel como rectángulos de celdas (islas)
y una lista de revelaciones (celda → obra → plano cinematográfico). Mover
cualquier isla rompe la alineación exacta que hace posible el puente —
`validarNivel()` corre al arrancar y avisa en consola si un nivel dejó de
tener solución, o si dejó de ser un acertijo (se alcanza sin rotar).

## Cómo ver el prototipo funcionando (sin instalar nada)

**No hace falta instalar Node ni nada localmente para verlo.** Cada push a
`main` se compila y publica solo, vía GitHub Actions
(`.github/workflows/deploy.yml`), en:

**https://aloesativo.github.io/enterrario-aloesativo/**

Esa URL es fija — se actualiza sola en 1-2 minutos después de cada push.
`?postproceso=off` apaga la cadena de postproceso, para comparar el
antes/después del tilt-shift sin editar nada.

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

## Controles

Dos verbos, y solo dos:

| Entrada | Efecto |
|---|---|
| flechas, arrastre corto | Mueve al personaje |
| `A` / `D`, toque en el borde lateral, bumpers | Rota el escenario 90° |

No hay órbita libre ni movimiento de cámara manual: la cámara del juego no
se toca, ni siquiera un poco — es la condición de que el acertijo se
pueda leer.

Desde la consola del navegador (única herramienta de inspección
disponible, dado que no hay flujo local):

```js
enterrario.celda()          // dónde está el personaje ahora
enterrario.rotacion()       // 0..3
enterrario.alcanzables()    // qué celdas se pueden pisar desde aquí, en la rotación actual
enterrario.nivel.navegacion // acceso directo a las reglas de movimiento
```

## Estado actual

Un nivel de una sola revelación, verificado matemática y visualmente: dos
islas separadas por 16 celdas de mundo y 5 de altura que se ven pegadas
solo en la rotación 0 (medido en pantalla, no solo en teoría). Sin rotar,
el puente no existe — comprobado.

La portada y el acorde de la revelación son **placeholders descarados**:
un canvas generado y un sintetizador Web Audio, para poder sentir el
latido del hallazgo sin tener aún el arte ni los `.opus` reales. Cuando
existan, se reemplazan sin tocar la lógica de la revelación
(`src/render/revelacion.js`).

Sobre el greybox está montada la cadena de imagen: IBL, tone mapping
filmico, sombras proyectadas y postproceso con tilt-shift, bloom, viñeta y
grano. El tilt-shift cambia de fuerza según el régimen: ancho y funcional
mientras se juega, cerrado en miniatura fotografiada durante la
revelación — un valor fijo hacía el acertijo ilegible (desenfocaba la
alineación que hay que leer), así que quedó atado al régimen de cámara en
vez de sacrificado.

Todos los valores de cámara, color y postproceso viven en `src/theme/`
como placeholders marcados. El mecanismo está; el look lo define RR.

## Sobre `src/story/` (histórico)

`src/story/burdeo.json` guarda el lore de Burdeo transcrito a mano del
repo hermano — zonas, canciones, colores por nombre. Es una iteración
anterior que asumía otro mecanismo (viajar entre zonas con un reloj
temporal) y **ya no está conectada al juego**. El contenido narrativo
sigue siendo válido como referencia; la estructura que lo envolvía no.
Cuando se decida cómo mapear canciones concretas a revelaciones concretas
del nuevo sistema, ese archivo es el punto de partida — pero como fuente
de datos, no como mecánica a restaurar.

## El camino hacia el diorama autorado

La generación procedural resuelve "necesito contenido infinito y barato".
Este artefacto necesita lo contrario: unas pocas islas concretas,
modeladas a mano, que escondan un hallazgo. `src/render/nivel.js` usa
losas delgadas en vez de cubos altos a propósito — un cubo alto tapa lo
que hay detrás, y ver lo que hay detrás es el juego.
