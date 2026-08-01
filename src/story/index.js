/**
 * Capa narrativa: datos puros. Igual que `generator/`, esta carpeta NO
 * importa `three` ni lee `theme/` — solo responde preguntas sobre el guion.
 *
 * La pregunta central del mecanismo, según el lore, es una sola:
 *   "estoy mirando la zona X en el momento T del bucle — ¿qué suena?"
 *
 * Y la respuesta tiene dos capas, que es lo más bonito del diseño:
 *   - Las INSTRUMENTALES ("música para hacer nada") suenan siempre que
 *     estés en su zona. No dependen del tiempo. Son plantas, gnomos y
 *     estatuas: puntos de contemplación fijos.
 *   - Las TEMÁTICAS suenan solo si el momento cae dentro de su ventana.
 *     Si llegas al lugar correcto en el momento equivocado, no suena nada
 *     — porque en ese momento está pasando otra cosa en otra parte.
 */

/** Estados posibles de la consulta, para no devolver silencio ambiguo. */
export const MOTIVO = {
  SUENA: 'suena',
  FUERA_DE_VENTANA: 'fuera-de-ventana',
  BUCLE_SIN_DEFINIR: 'bucle-sin-definir',
  ZONA_SIN_CANCIONES: 'zona-sin-canciones',
};

export function cargarGuion(datos) {
  const zonasPorId = new Map(datos.zonas.map((zona) => [zona.id, zona]));
  const ventanasPorId = new Map((datos.bucle?.ventanas ?? []).map((v) => [v.id, v]));

  /** ¿El bucle tiene números de verdad, o sigue siendo solo relaciones? */
  const bucleDefinido =
    typeof datos.bucle?.duracionSegundos === 'number' &&
    [...ventanasPorId.values()].every(
      (v) => typeof v.inicio === 'number' && typeof v.fin === 'number'
    );

  function cancionesDeZona(zonaId) {
    return datos.canciones.filter((cancion) => cancion.zona === zonaId);
  }

  /**
   * Instrumentales que corresponden a una zona. Hoy devuelve vacío porque
   * el lore describe la serie pero no lista los temas todavía; la forma de
   * la respuesta ya es la definitiva para no tener que cambiarla después.
   */
  function instrumentalesDeZona(zonaId) {
    return datos.seriesInstrumentales.flatMap((serie) =>
      (serie.temas ?? [])
        .filter((tema) => tema.zona === zonaId)
        .map((tema) => ({ ...tema, serie: serie.id, tipo: 'instrumental' }))
    );
  }

  /**
   * Una ventana puede cruzar el final del bucle (empezar en 0.9 y terminar
   * en 0.1 de la vuelta siguiente), así que el caso `inicio > fin` no es un
   * error: es una ventana que da la vuelta.
   */
  function ventanaContiene(ventana, segundos) {
    const t = ((segundos % datos.bucle.duracionSegundos) + datos.bucle.duracionSegundos)
      % datos.bucle.duracionSegundos;
    return ventana.inicio <= ventana.fin
      ? t >= ventana.inicio && t < ventana.fin
      : t >= ventana.inicio || t < ventana.fin;
  }

  function ventanasActivas(segundos) {
    if (!bucleDefinido) return [];
    return [...ventanasPorId.values()].filter((v) => ventanaContiene(v, segundos));
  }

  /**
   * La consulta principal. Devuelve SIEMPRE un motivo, para que quien
   * llame pueda distinguir "aquí no hay nada" de "aquí hay algo pero no
   * ahora" — que es justo la mecánica que el lore quiere que se sienta.
   */
  function queSuena({ zonaId, segundos = 0 }) {
    const instrumentales = instrumentalesDeZona(zonaId);
    const candidatas = cancionesDeZona(zonaId);

    if (candidatas.length === 0 && instrumentales.length === 0) {
      return { instrumentales, tematicas: [], motivo: MOTIVO.ZONA_SIN_CANCIONES };
    }

    // Sin bucle definido no se puede filtrar por tiempo. En vez de mentir
    // (devolver todo o devolver nada), se dice explícitamente que el
    // filtro temporal todavía no se puede aplicar.
    if (!bucleDefinido) {
      return { instrumentales, tematicas: candidatas, motivo: MOTIVO.BUCLE_SIN_DEFINIR };
    }

    const activas = new Set(ventanasActivas(segundos).map((v) => v.id));
    const tematicas = candidatas.filter((c) => c.ventana && activas.has(c.ventana));

    return {
      instrumentales,
      tematicas,
      motivo: tematicas.length > 0 ? MOTIVO.SUENA : MOTIVO.FUERA_DE_VENTANA,
    };
  }

  return {
    datos,
    bucleDefinido,
    zonas: datos.zonas,
    canciones: datos.canciones,
    zonaPorId: (id) => zonasPorId.get(id) ?? null,
    cancionesDeZona,
    instrumentalesDeZona,
    ventanasActivas,
    queSuena,
  };
}

/**
 * Validador del guion. Existe porque esta carpeta es una COPIA A MANO del
 * lore del repo hermano: no hay ningún proceso que garantice que lo
 * transcrito sea coherente, así que el riesgo real es la errata silenciosa
 * (una canción apuntando a una zona que se renombró, por ejemplo).
 *
 * Es el equivalente local de `validar_lore.py` del repo madre, pero sobre
 * el guion derivado en vez de sobre el lore.
 *
 * @returns {string[]} lista de problemas; vacía si el guion es coherente.
 */
export function validarGuion(datos) {
  const problemas = [];
  const zonas = new Set(datos.zonas.map((z) => z.id));
  const ventanas = new Set((datos.bucle?.ventanas ?? []).map((v) => v.id));

  const repetidas = datos.zonas.length - zonas.size;
  if (repetidas > 0) problemas.push(`hay ${repetidas} zona(s) con id repetido`);

  for (const cancion of datos.canciones) {
    if (!zonas.has(cancion.zona)) {
      problemas.push(`"${cancion.titulo}" apunta a la zona inexistente "${cancion.zona}"`);
    }
    if (cancion.ventana && !ventanas.has(cancion.ventana)) {
      problemas.push(`"${cancion.titulo}" apunta a la ventana inexistente "${cancion.ventana}"`);
    }
  }

  for (const serie of datos.seriesInstrumentales ?? []) {
    for (const tema of serie.temas ?? []) {
      if (!zonas.has(tema.zona)) {
        problemas.push(`el tema instrumental "${tema.titulo}" apunta a la zona inexistente "${tema.zona}"`);
      }
    }
  }

  return problemas;
}
