(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const hud      = $('voice-hud');
  const elIcon   = $('voice-icon');
  const elLabel  = $('voice-label');
  const elDist   = $('voice-distance');

  function applyState(s) {
    if (!s) return;
    hud.dataset.mode    = s.key || 'normal';
    hud.dataset.talking = s.talking ? 'true' : 'false';
    elIcon.textContent  = s.icon  || '🗣️';
    elLabel.textContent = s.label || 'Normal';
    elDist.textContent  = Math.round(s.distance || 8);
    if (s.color) {
      hud.style.setProperty('--accent', s.color);
    }
  }

  window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'state') applyState(data);
  });

  // Signale au client Lua qu'on est prêt à recevoir l'état initial.
  function tellReady() {
    const url = `https://${GetParentResourceName ? GetParentResourceName() : 'sl-voice'}/ready`;
    fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: '{}',
    }).catch(() => {});
  }
  // Petit délai pour laisser le DOM se monter avant d'envoyer ready
  setTimeout(tellReady, 50);
})();
