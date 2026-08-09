# godot/ — prototipo por etapas

> **Antes de tocar cualquier cosa acá: leer `../DISENO_GODOT.md`.**
> Este prototipo se construye por etapas chicas definidas ahí (§10). Si lo
> que vas a escribir no está en ese documento, no se escribe: se propone,
> se acuerda, se anota, y recién después se construye.

## Estado: ETAPA 1 — un personaje que camina por celdas

Es a propósito lo mínimo posible. Grilla plana de 9×9, un damero gris, una
cápsula gris que camina. **Nada más.**

Lo único que hay que juzgar en esta etapa es **cómo se siente el paso.**

### Cómo probarlo

1. Abrir `godot/project.godot` con Godot 4.x (NO la raíz del repo).
2. F5 / Play. Arranca en `escenas/Mundo.tscn`.
3. Mover con flechas del teclado, o D-pad, o stick izquierdo de un control
   (PS o Xbox — funciona de fábrica, sin configurar nada).

### Qué mirar, concretamente

- **¿El paso se siente discreto?** Tiene que sentirse como saltar de
  casilla a casilla, nunca como deslizarse. Si resbala, algo está mal.
- **¿Tiene peso?** Sale rápido y aterriza suave (ease-out cúbico), con un
  arquito vertical. ¿Se siente bien, o se siente plano/flojo?
- **¿Los controles responden al pulsar rápido?** Un empujón que llega
  mientras el paso anterior todavía anima **no se descarta**: queda en
  cola y sale apenas termina el anterior.
- **¿El control anda sin configurar nada?** Es requisito duro.

### ⚠️ Decisión a evaluar: un paso por empujón

**Mantener apretado NO camina solo.** Hay que soltar y volver a empujar
por cada paso — y con el stick, hay que devolverlo a la zona muerta.

Está implementado así porque `DISENO_GODOT.md` §3 lo dice literal (*"el
stick da UN paso por empujón, no un chorro continuo"*), pero puede que en
la mano se sienta tedioso. **Es exactamente el tipo de cosa que esta etapa
existe para detectar.** Si molesta, decilo: cambiarlo a "mantener apretado
camina" es una línea (`is_action_just_pressed` → `is_action_pressed`).

### Números para tocar

Están arriba de todo en `scripts/personaje.gd`, juntos a propósito:

| Constante | Hoy | Qué hace |
|---|---|---|
| `DURACION_PASO` | `0.16` s | cuánto dura el paso |
| `ALTURA_ARCO` | `0.12` | cuánto se levanta a mitad de paso |

> ⚠️ **No hagas el paso lento para darle peso.** `DISENO_GODOT.md` §6: el
> peso va en la textura del paso (arco, aterrizaje, sonido), nunca en la
> duración. Un paso lento vuelve tedioso probar rotaciones, y probar
> rotaciones es el core del juego.

## Qué NO está, a propósito

Rotación del mundo, relieve/alturas, el estereograma, el zoom-cuerda, el
tilt-shift, las zonas del lore, el cometa, sonido, arte. **Todo eso son
etapas 2 a 7** (`DISENO_GODOT.md` §10) y meterlas ahora sería repetir el
error que ya rompió dos prototipos: construir mucho de una vez sin poder
verificar nada.

## La regla que no se rompe

`scripts/personaje.gd` **no** es un `CharacterBody3D`, **no** usa
`move_and_slide()`, **no** tiene gravedad ni velocidad continua. El estado
del personaje es una celda entera (`Vector2i`).

No es preferencia de estilo: la regla del juego ("puedes pisar lo que se
ve pegado a ti", etapa 4) compara posiciones en pantalla buscando igualdad
**exacta**, y con posiciones continuas esa igualdad no ocurre nunca. Ver
`DISENO_GODOT.md` §3 — es la causa raíz del último prototipo roto.

Lo que sí es continuo es la **animación**. Lo discreto es el estado.

## Si algo falla

El agente **no puede correr Godot** (`DISENO_GODOT.md` §11) — esto se
escribió leyendo, sin ejecutar. Si tira un error:

**copiar el mensaje de la terminal tal cual, sin resumirlo.**

Hay `print()` de diagnóstico al arrancar; corriendo el proyecto desde la
terminal aparecen directo en la consola.

## Archivos

```
project.godot           escena principal: escenas/Mundo.tscn
escenas/Mundo.tscn      raíz + cámara + sol (lo demás se construye por código)
scripts/mundo.gd        arma la grilla, el personaje y la cámara; lee la entrada
scripts/personaje.gd    LA REGLA: movimiento por celdas discretas
```

## Sobre la cámara (nota de alcance)

La cámara ya está en el ángulo isométrico **verdadero** (elevación
35.264°, azimut 45°), aunque eso pertenece formalmente a la etapa 2. Se
adelantó porque Godot necesita alguna cámara para que se vea algo, y
poner el ángulo correcto no costaba nada y evita rehacer.

Sale solo de poner la cámara en `centro + (k, k, k)` mirando al centro: la
dirección de vista queda `(-1,-1,-1)/√3`, o sea `asin(1/√3) = 35.264°`. No
hay ningún ángulo escrito a mano.

Lo que **sí** queda para la etapa 2 es la matemática de proyección
(`proyeccion.js`), que es lo que de verdad define esa etapa.
