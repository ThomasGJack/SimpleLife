(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const promptEl = $('prompt');
  const keyEl = $('key');
  const labelEl = $('label');

  window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'show') {
      keyEl.textContent = (data.key || 'E').toUpperCase();
      labelEl.textContent = data.label || 'Interagir';
      promptEl.classList.remove('hidden');
    } else if (data.action === 'hide') {
      promptEl.classList.add('hidden');
    }
  });

  function tellReady() {
    const url = `https://${GetParentResourceName ? GetParentResourceName() : 'sl-interact'}/ready`;
    fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: '{}',
    }).catch(() => {});
  }
  setTimeout(tellReady, 50);
})();
