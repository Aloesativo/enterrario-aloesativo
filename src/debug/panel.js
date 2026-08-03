import GUI from 'lil-gui';

/**
 * Panel de ajuste en vivo. Existe para un solo propósito: probar valores
 * de sensación/jugabilidad y de la niebla sin tener que abrir una rama y
 * un PR por cada número — eso era la fricción que RR pidió resolver.
 *
 * Vive fuera de generator/render/theme a propósito (regla de las tres
 * capas en CLAUDE.md): no genera datos, no traduce a mallas, no es una
 * paleta. Es una herramienta de sesión que muta en memoria el `theme` que
 * ya cargaron los demás módulos — nada se guarda en disco ni sobrevive a
 * un F5. El botón "copiar" exporta el JSON resultante para que sea RR
 * quien decida a mano qué pegar en theme/default.json: el panel propone
 * el mecanismo, nunca elige la identidad visual final.
 *
 * Solo se importa (y solo entonces se descarga el bundle de lil-gui) si
 * la URL trae ?config=1 — ver main.js.
 */
export function montarPanel({ theme, luzDireccional }) {
  const gui = new GUI({ title: 'Config — sesión, no se guarda' });
  gui.$title.insertAdjacentHTML(
    'afterend',
    '<div style="font:11px/1.4 monospace;color:#999;padding:0 6px 6px">' +
      'Cambios solo en esta pestaña. "Copiar" exporta el JSON para pegarlo ' +
      'a mano en theme/default.json.</div>'
  );

  theme.personaje ??= { duracionPaso: 160, duracionPuente: 420 };
  theme.controles ??= { umbralArrastre: 26, bandaBorde: 0.16 };

  const fPersonaje = gui.addFolder('Personaje');
  fPersonaje.add(theme.personaje, 'duracionPaso', 40, 400, 10).name('duración paso (ms)');
  fPersonaje.add(theme.personaje, 'duracionPuente', 100, 900, 10).name('duración puente (ms)');

  const fControles = gui.addFolder('Controles táctiles');
  fControles.add(theme.controles, 'umbralArrastre', 8, 60, 1).name('umbral arrastre (px)');
  fControles.add(theme.controles, 'bandaBorde', 0.05, 0.3, 0.01).name('banda borde (%)');

  const fNiebla = gui.addFolder('Niebla');
  fNiebla.add(theme.niebla, 'factorCerca', 0.1, 1.5, 0.01).name('factorCerca');
  fNiebla
    .add(theme.niebla, 'factorLejos', 1.3, 4, 0.05)
    .name('factorLejos ⚠️ <1.5 = invisible');

  if (luzDireccional) {
    const fLuz = gui.addFolder('Luz');
    fLuz
      .add(theme.luz, 'intensidadDireccional', 0, 3, 0.05)
      .name('intensidad direccional')
      .onChange((valor) => {
        luzDireccional.intensity = valor;
      });
  }

  const accion = {
    async copiar() {
      const texto = JSON.stringify(theme, null, 2);
      try {
        await navigator.clipboard.writeText(texto);
        controladorCopiar.name('✓ copiado al portapapeles');
        setTimeout(() => controladorCopiar.name('Copiar theme actual (JSON)'), 1500);
      } catch {
        console.log('[enterrario] theme actual:', texto);
      }
    },
  };
  const controladorCopiar = gui.add(accion, 'copiar').name('Copiar theme actual (JSON)');

  return gui;
}
