# godot/ — prototipo en Godot (reemplazo en curso del pipeline Three.js)

## Qué es esto y por qué existe

RR decidió (2026-08-09, en una conversación aparte que no quedó registrada
en este repo — por eso esta nota) pasar el diorama de Three.js/Vite a
Godot: más control y autonomía, y sobre todo poder probarlo **en vivo, en
un computador dedicado (el Dell), con un control conectado**, en vez de
depender solo de lo que se ve en GitHub Pages.

**La intención es reemplazar** el prototipo de `src/` (Three.js), no
tener los dos para siempre. Pero mientras el de Godot no esté verificado
funcionando en la máquina de RR, `src/` se queda tal cual y Pages lo
sigue sirviendo — así siempre hay algo mostrable. El día que el de Godot
ande, se retira `src/` y el workflow de deploy (`.github/workflows/deploy.yml`,
hoy compila el proyecto Vite) se reemplaza por un export web de Godot.

## Aviso importante: el agente no puede correr Godot

El agente que escribió esto trabaja en un entorno remoto sin GUI y sin
acceso de red al sitio de descarga de Godot (política de egress de la
sesión — no es negociable ni algo que se pueda evitar). Los archivos de
Godot son texto plano (`.tscn`, `.gd`, `project.godot`) y se escriben a
mano con mucho cuidado de sintaxis, pero **cada verificación real es la
de RR, corriendo esto en su máquina.** Si algo no carga o tira un error,
copiá el mensaje tal cual aparece en la terminal (no lo resumas) — con
eso el agente lo corrige, no puede adivinar el error sin verlo.

Por eso el código de `mapa.gd` tiene mensajes `print()` en los puntos
clave (arranque, cada zoom). Corriendo el proyecto desde la terminal (no
solo con F5 en el editor) esos mensajes aparecen directo en la consola
donde lo lanzaste — es la forma más rápida de que el agente vea qué pasó
sin tener que adivinar.

## Cómo probarlo

1. Instalar Godot 4.x (cualquier versión 4.3 o más nueva debería abrir
   esto sin problema — bajar la última estable de godotengine.org).
2. Abrir este proyecto apuntando a `godot/project.godot` (NO a la raíz
   del repo — `godot/` es la raíz del proyecto Godot).
3. F5 o "Play" — arranca en `escenas/Mapa.tscn`, un único diorama.
4. Controles: WASD o flechas (o stick/D-pad de un control) mueven al
   personaje (cápsula gris) directamente sobre el relieve del mapa — no
   hay una cámara separada que pasear ni una escena distinta a la que
   "entrar". La cámara es isométrica fija y sigue al personaje sin girar.

## Qué es real y qué es placeholder

- **Mecánica real, funcionando (a falta de que RR la pruebe):** un solo
  mundo 3D con relieve — plataformas a distinta altura, no un plano — que
  representan ciudad/playa/bosque/luna/otro-planeta. El personaje camina
  con gravedad y colisión sobre ellas; la cámara isométrica lo sigue con
  un offset fijo (nunca gira, nunca hace zoom manual). "El cometa"
  (burdeo.json: "atraviesa el mapa entero en vez de ocupar un lugar") es
  un elemento sin colisión que cruza el cielo del diorama.
  Ciudad/playa/bosque están al mismo nivel y conectadas — se puede
  caminar de una a otra ya mismo, como dice el lore ("conectada dentro
  del mismo mapa"). Luna y otro-planeta son islas elevadas, visibles pero
  **no alcanzables todavía a pie** — ese vacío es intencional, ver
  "Qué falta a propósito" abajo.
- **Placeholder deliberado, no arte final:** todo es gris neutro (cajas,
  cápsula). Es la misma regla que ya rige en `src/theme/` — la identidad
  visual (paleta, formas, estilo) la define RR, el agente no elige
  colores. Dato curioso: `src/story/burdeo.json` ya etiqueta cada zona
  con un color de intención (`ciudad: "burdeo"`, `luna: "blanco"`,
  `otro-planeta: "celeste"`) — es una pista de diseño, no una decisión
  tomada; convertir eso en colores reales sigue siendo tarea de RR.
- **Datos de zonas hardcodeados, no leídos de ningún lado:** las 5 zonas
  (`mapa.gd`, constante `ZONAS`) son una copia mínima a mano de
  `src/story/burdeo.json` → `zonas` (id + título + posición/tamaño de
  plataforma inventados para que se vea algo). No hay ningún mecanismo
  que lea el JSON real.
- **Sin export web todavía.** Falta configurar `export_presets.cfg` y
  descargar las plantillas de export de Godot (se hace una vez desde el
  editor, Proyecto → Exportar). No se armó ahora para no dejar una
  configuración a medias sin poder probarla.

## Qué falta a propósito (siguiente paso, no este)

El diseño real de `src/mundo/` (proyeccion.js + navegacion.js +
nivel.json) no es solo "terreno con relieve" — es un acertijo: el mundo
se rota en pasos de 90° y eso cambia qué celdas se ven "pegadas" en
pantalla, lo que abre caminos que no existen en otra rotación. Ese
mecanismo es justo lo que va a conectar luna/otro-planeta con el resto
sin necesidad de una rampa literal. Portarlo es la razón de ser de este
diorama, pero es un paso aparte — se decidió a propósito no meterlo en
la misma pasada que armó el relieve 3D, para no dejar dos cosas grandes
a medio verificar al mismo tiempo.

## Qué NO se tocó

`src/` (Three.js), `.github/workflows/deploy.yml` y todo lo que compila y
publica en `https://aloesativo.github.io/enterrario-aloesativo/` sigue
exactamente igual. Este prototipo no está conectado a Pages.

## Próximos pasos posibles (sin decidir todavía)

- Que RR confirme que esto abre y corre en su máquina.
- Portar el acertijo de rotación/ambigüedad isométrica de `src/mundo/`
  (ver sección de arriba) — es lo que conecta luna/otro-planeta al resto.
- Diferenciar las 5 zonas entre sí (hoy son el mismo placeholder gris
  repetido) — depende de que RR defina identidad visual, no del agente.
- Decidir cómo se conecta esto con `src/story/burdeo.json` sin romper la
  regla de "sin integración técnica automática" que rige entre
  `Aloesativo/Aloesativo` y este repo — probablemente una copia curada a
  mano, igual que ya existe.
- Configurar el export web y, recién ahí, evaluar reemplazar el workflow
  de deploy.
