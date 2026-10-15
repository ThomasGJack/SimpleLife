(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const hud = document.getElementById('hud');
  const elH = document.querySelector('.stat[data-stat="hunger"]');
  const elT = document.querySelector('.stat[data-stat="thirst"]');
  const elS = document.querySelector('.stat[data-stat="stamina"]');

  function levelClass(value) {
    if (value >= 60) return 'level-green';   // → caché en CSS
    if (value >= 30) return 'level-yellow';
    if (value >= 10) return 'level-orange';
    return 'level-red';
  }

  function setStat(el, valEl, value) {
    if (!el || !valEl) return null;
    const v = Math.max(0, Math.min(100, Math.floor(value)));
    valEl.textContent = v;
    el.classList.remove('level-green', 'level-yellow', 'level-orange', 'level-red');
    const cls = levelClass(v);
    el.classList.add(cls);
    return cls;
  }

  function applyState(s) {
    const levels = [];
    if (s.hunger  !== undefined) levels.push(setStat(elH, $('val-hunger'),  s.hunger));
    if (s.thirst  !== undefined) levels.push(setStat(elT, $('val-thirst'),  s.thirst));
    if (s.stamina !== undefined) levels.push(setStat(elS, $('val-stamina'), s.stamina));

    // Met à jour la classe globale du HUD pour ajuster l'opacité ambiante
    hud.classList.remove('has-warning', 'has-critical');
    if (levels.indexOf('level-red') !== -1)         hud.classList.add('has-critical');
    else if (levels.indexOf('level-orange') !== -1) hud.classList.add('has-warning');
  }

  window.addEventListener('message', (event) => {
    const d = event.data || {};
    if (d.action === 'state') applyState(d);
  });

  // Signale au client Lua qu'on est prêt à recevoir l'état initial.
  function tellReady() {
    const url = `https://${GetParentResourceName ? GetParentResourceName() : 'sl-hunger'}/ready`;
    fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: '{}',
    }).catch(() => {});
  }
  setTimeout(tellReady, 50);
})();
