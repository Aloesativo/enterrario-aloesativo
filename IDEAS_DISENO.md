# Ideas de diseño — backlog sin construir

> **Origen.** Este archivo consolida dos notas que RR subió el 2026-08-09 al
> repo madre (`Aloesativo/Aloesativo`), en `ideas/2026-08-09-videojuego-
> mecanica-burdeo.md` e `ideas/2026-08-09-digivice-oraculo.md`. Ese repo las
> guardaba como staging ("no es lore ni derechos, no tiene esquema") a la
> espera de que RR decidiera dónde vivían de verdad — la propia bitácora del
> repo madre dejó anotado el pendiente: "¿se copian a mano a
> `enterrario-aloesativo` y se borran de acá, o se quedan como archivo
> histórico?". Esta sesión resolvió eso: se copian aquí (con las cabeceras de
> archivo adaptadas a este repo) y se borran de allá — el repo madre es
> catálogo/lore/derechos, no diseño de juego (ver su `CLAUDE.md`).
>
> **Qué es y qué no es este archivo.** Es un volcado de ideas de diseño,
> tal como las escribió RR, sin espec ni prioridad — igual que en el repo
> madre, "es staging, no arquitectura decidida". Varias de estas ideas
> describen un juego distinto del que existe hoy en `main` (ver más abajo,
> "Relación con el estado actual"). No se resume, no se recorta, no se
> completa nada por cuenta propia — el filtro de qué se construye y qué no
> le toca a RR, no a este archivo.

## Relación con el estado actual del repo

El pivote actual (`README.md`, "El truco: la ambigüedad isométrica") —
cámara isométrica fija, dos regímenes (mecánico/revelación), acertijo de
qué se ve pegado al rotar — nació de la lista de referencias que aparece
más abajo en este mismo documento (FEZ, Monument Valley). Esa parte ya está
construida.

El resto de las ideas de abajo — el mapa-zoom estilo Buscando a Wally, el
personaje punto de vista tipo Short Hike, la capa de plantas, el
reproductor-oráculo, el dashboard de distribución — describe una mecánica
más grande y distinta a la del acertijo isométrico actual, no una extensión
directa de ella. `INFORME.md` §9.0 ya señala la tensión concreta: el
`src/story/burdeo.json` heredado asume "desplazamiento sin rotar + zoom a
zonas" (la mecánica de mapa-zoom descrita aquí abajo), mientras que
`src/mundo/nivel.json` (lo que corre hoy) es islas + revelaciones puntuales
por rotación. Son dos mecánicas distintas conviviendo en el repo, ninguna
descartada formalmente — decisión pendiente de RR, no de este archivo.

---

# Videojuego / mecánica de Burdeo — ideas de diseño e implementación

## Referencias agrupadas
- **Cámara y puzzle**: FEZ, Monument Valley
- **Mundo de acción y atmósfera**: TUNIC, Death's Door (escenarios, jefes grandes, parry)
- **Coleccionismo cosy**: Ooblets (cosy, cultivo, coleccionismo, cartas), Balatro (animación de score, matemáticas, cartas)
- **Mapa y exploración**: Buscando a Wally, Short Hike (referencia principal)
- Coleccionismo y exploración están presentes en todas — posible base de un compendio/síntesis
- Densidad visual por época: Renacimiento/Archivista denso (Wally), moderno/Cabeza Hueca low-poly gris (TUNIC, Death's Door), futuro/Conejo geometría limpia (FEZ, Monument Valley). Las tres conviven en el mismo espacio, no son zonas separadas.
- Combate/conflicto jugable: sin definir, decisión pendiente a propósito
- Estereograma: forma de arte transversal a las tres épocas — "el juego es un puzle con exploración"

## Assets y arte
- Assets visuales actuales: portadas (fotos y collage en Photoshop)
- Arte del videojuego: fotografías reales transformadas en assets (RR no sabe de arte/diseño)
- No hacer cómic con IA (se notaría)
- Interés en mecanismo tipo Angel Engine: nodos interconectados donde serie y música se apunten mutuamente (solo la estructura, no la estética de terror)
- Espacio online mostrando el proceso en vivo desde día uno, forma psicomágica/onírica, sin romper la cuarta pared, sin explicar

## Navegación e interfaz
- Rechaza navegación de carpetas; interfaz explorable caminando/con dedo, hallazgos estilo D&D
- Mundo 3D pre-renderizado a 2D, escalable como vectorial (no navegación 3D en tiempo real)
- Zoom inteligente que se adecúa a la historia — la cámara se posiciona sola en ciertas áreas
- Localidades = ángulos distintos sobre un mismo suceso; caminos que conectan las áreas importan (cómo se mueve el personaje de forma bella); lo procedural al servicio de la belleza, no procedural porque sí
- Se recorre como Buscando a Wally: escanear visualmente hasta encontrar algo; al hacer zoom hasta cierto punto la cámara rota — ahí ocurre el plano cinemático donde suena la canción; al dejar de escuchar, la escena vuelve al estado anterior
- Decisión de simplificación: no mezclar las tres técnicas de render (foto-collage, fotogrametría low-poly, vectorial) en una misma escena — la convivencia de épocas ocurre a nivel de mapa, no dentro de un mismo cuadro
- Desbloqueo: todos los temas ocultos por defecto; al descubrirlos se desbloquean permanentemente, van a un reproductor aparte
- El bucle temporal es fundamental, no se elimina
- Nivel de enfoque/zoom determina nivel de control (personajes se mueven solos vs. usuario controla)

### Mecánica del mapa-zoom (detallada)
- Gran mapa tipo pantalla de pausa, parece estático a primera vista; en realidad 3D renderizado plano en 2D, estilo Buscando a Wally
- Muy alejado: solo líneas, puntos, X e íconos de lugares
- No hay botón de "ir al lugar": hay que hacer zoom al mapa para llegar, el zoom ES el viaje
- Una línea marca la posición del personaje sin importar la escala, sin interferir con la estética del nivel
- Al hacer zoom progresivo aparecen detalles: nubes, árboles, agua
- Al llegar al "plano de la ciudad" (zoom máximo) se puede mover un personaje — la luz señala dónde está; ya no se puede hacer más zoom
- Interacción tipo RPG (hablar con gente y cosas) pero no para mejorar estadísticas — para descubrir el mundo, estilo Disco Elysium
- El mundo se puede rotar 90° horizontal en cualquier momento, siempre anclado al punto de vista del jugador

## Personaje punto de vista
- Personaje controlable, distinto de Cabeza Hueca/Conejo/Archivista, que interactúa con ellos
- Según dónde se mueve, el mundo se alinea a su posición
- Referencia Short Hike para la sensación de viajar
- Cada lugar al que se llega debe ser contemplativo — dan ganas de quedarse
- Portales estilo Death's Door: entrar por una puerta, salir donde se necesite
- **No es Aloesativo** — es cualquiera que use la aplicación, postura de visitante real, tipo Google Street View
- No es scrollear, es descubrir — en cualquier punto uno se puede quedar y sentir que está en un santuario

## Capa de plantas — implementación (el concepto de lore vive en el repo madre, `lore/musica-para-hacer-nada.md`)
- Rechaza el loop de granja (preparar tierra/plantar/cosechar/vender/comprar upgrades/repetir)
- Contraste explícito con Roblox/Minecraft (busca lo opuesto a "funcionalmente divertido" genérico)
- Referencia: el juego "Garden Galaxy" (premisa de ir juntando cosas que aparecen)
- Metodología: pensar la idea, aterrizarla de inmediato en una arquitectura de prototipo, mejorar sobre la marcha — abierto a integrar tecnologías aún no conocidas
- Las plantas se generan proceduralmente a partir de especies reales (fuente: GBIF) — al descubrir una, el juego indica en base a qué especie real se generó (puente al mundo real)
- Modo reproductor también cinematográfico: al sonar una canción, el mundo se detiene, cambia de ángulo, se disfruta como un momento zen ("cuenco")
- Sin funciones sociales por ahora — jardines personales
- A futuro (no ahora): jardines visitables o "posteables" por tiempo limitado

## Reproductor cuenco: capa de streaming externo
- Streaming constante de mucha música externa (no solo la propia, que es limitada) — posibles fuentes: Bandcamp, SoundCloud
- Reproducción aleatoria y focalizada
- Visual: el personaje se encuentra con un mapa del planeta — idea de broma: mapa de tierra plana
- El mapa indica de qué parte del mundo es la canción/playlist, género, nombre de playlist/radio
- Se puede mover ese punto a otro lugar del mapa y descubrir música aleatoria según gustos propios
- Vida corta de la planta en este flujo externo (ej. dos semanas de tiempo del juego) — se puede escuchar cierto número de veces, luego muere y hay que replantar
- Al morir las plantas, se puede volver al mapa y sacar semillas de otras canciones ya escuchadas — "torrente de información"

## Reproductor como menú flotante
- Se esconde para ver la escena, o se muestra completo con la carátula
- El I Ching y los 72 Nombres de Dios (ver "Digivice / Oráculo" más abajo) se integran como un menú más, con animación 3D estilo Balatro
- Mismo esqueleto de interfaz para reproductor, streaming externo y oráculo

## Dashboard y distribución
- El juego/mapa funciona también como dashboard interactivo — landing page compartible con cronología explícita de lanzamientos
- Local (self-hosted)
- Conectividad con plataformas existentes (Spotify, SoundCloud, Deezer, Bandcamp, Tidal) sin falsear reproducciones ni buscar regalías — solo accesibilidad e interconexión
- Objetivo de diseño: coleccionismo y exploración
- Ha usado IA y no le incomoda si la transformó de forma propia, pero quiere relacionarse con artistas reales; problema abierto: cómo encontrarlos y trabajar con ellos sin perder control de la obra

## Perspectivas visuales del diorama
- Isométrica (diorama interactivo)
- Retrato cinematográfico (plano aéreo)
- Realista frontal (desde abajo)
- Cada diorama es un GIF 3D loopeado, con historia propia

---

# Digivice / Oráculo

- Ya existen apps propias de RR: una de I Ching, otra de los 72 Nombres de Dios.
- Idea antigua: mezclar los 72 Nombres de Dios con los 64 hexagramas del I Ching.
- La idea incluye cómo se muestra el entorno con movimiento diario, un elemento de oráculo y una herramienta de meditación.
- Un "digivice" — dispositivo con todo embebido, dashboard estilo Balatro — podría unificar estas apps con el jardín/reproductor de Aloesativo.
- No hace falta complicarlo: son apps ya hechas, solo integrarlas como un menú más dentro del juego, con animación 3D estilo Balatro — mismo esqueleto de interfaz que el reproductor.
