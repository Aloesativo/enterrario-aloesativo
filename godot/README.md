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

## Aviso importante: esto NO se probó corriendo

El agente que escribió esto trabaja en un entorno remoto sin GUI y sin
acceso de red al sitio de descarga de Godot (política de egress de la
sesión — no es negociable ni algo que se pueda evitar). Los archivos de
Godot son texto plano (`.tscn`, `.gd`, `project.godot`) y se escribieron
a mano con mucho cuidado de sintaxis, pero **la primera vez que esto se
abre de verdad en el editor es en la máquina de RR.** Si algo no carga o
tira un error, decílo tal cual lo veas — el agente lo corrige desde ahí,
no puede adivinar el error sin verlo.

## Cómo probarlo

1. Instalar Godot 4.x (cualquier versión 4.3 o más nueva debería abrir
   esto sin problema — bajar la última estable de godotengine.org).
2. Abrir este proyecto apuntando a `godot/project.godot` (NO a la raíz
   del repo — `godot/` es la raíz del proyecto Godot).
3. F5 o "Play" — arranca en `escenas/Mapa.tscn`.
4. Controles del mapa: WASD o flechas (o stick/D-pad de un control) para
   moverse por el mapa; rueda del mouse o `+`/`-` para hacer zoom. Al
   acercar el zoom sobre el marcador "Burdeo (ciudad)" pasa a
   `escenas/Ciudad.tscn`.
5. En Ciudad: un personaje (cápsula gris) se mueve con los mismos
   controles.

## Qué es real y qué es placeholder

- **Mecánica real, funcionando (a falta de que RR la pruebe):** el pan y
  zoom del mapa, la transición de escena al acercar zoom a una zona, el
  movimiento del personaje con gravedad y colisión contra el piso.
- **Placeholder deliberado, no arte final:** todo es gris neutro (cajas,
  cápsula, piso). Es la misma regla que ya rige en `src/theme/` — la
  identidad visual (paleta, formas, estilo) la define RR, el agente no
  elige colores. Acá directamente no hay tema todavía: ni siquiera hay
  una capa `theme/` equivalente en Godot aún.
- **Datos de zonas hardcodeados, no leídos de ningún lado:** las 5 zonas
  del mapa (`mapa.gd`, constante `ZONAS`) son una copia mínima a mano de
  `src/story/burdeo.json` → `zonas` (solo id + título + una posición de
  layout inventada para que se vea algo). No hay ningún mecanismo que
  lea el JSON real — construir eso (o una copia paralela versionada a
  mano, siguiendo la misma disciplina que ya usa `src/story/`) queda
  pendiente.
- **Solo la zona "ciudad" dispara la transición.** Las otras 4 zonas
  (playa, bosque, luna, otro-planeta) están dibujadas pero no llevan a
  ninguna escena todavía — no existe esa escena.
- **Sin export web todavía.** Falta configurar `export_presets.cfg` y
  descargar las plantillas de export de Godot (se hace una vez desde el
  editor, Proyecto → Exportar). No se armó ahora para no dejar una
  configuración a medias sin poder probarla.

## Qué NO se tocó

`src/` (Three.js), `.github/workflows/deploy.yml` y todo lo que compila y
publica en `https://aloesativo.github.io/enterrario-aloesativo/` sigue
exactamente igual. Este prototipo no está conectado a Pages.

## Próximos pasos posibles (sin decidir todavía)

- Que RR confirme que esto abre y corre en su máquina.
- Sumar las otras 4 zonas con su propia escena (aunque sea un esqueleto
  igual de mínimo que "Ciudad").
- Decidir cómo se conecta esto con `src/story/burdeo.json` sin romper la
  regla de "sin integración técnica automática" que rige entre
  `Aloesativo/Aloesativo` y este repo — probablemente una copia curada a
  mano, igual que ya existe.
- Configurar el export web y, recién ahí, evaluar reemplazar el workflow
  de deploy.
