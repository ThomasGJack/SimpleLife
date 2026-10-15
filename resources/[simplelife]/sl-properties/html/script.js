(() => {
  'use strict';

  // =====================================================================
  // Helpers DOM
  // =====================================================================
  const $  = (id) => document.getElementById(id);
  const el = (tag, cls) => { const e = document.createElement(tag); if (cls) e.className = cls; return e; };

  // Récupère un slot depuis une map qui peut avoir des clés number ou string
  function pickSlot(map, idx) {
    if (!map) return null;
    return map[idx] || map[String(idx)] || null;
  }

  function fmtMoney(n) {
    return new Intl.NumberFormat('fr-FR').format(n) + ' $';
  }

  function fmtWeightKg(g) {
    if (g >= 1000) return (g / 1000).toFixed(2);
    return (g / 1000).toFixed(3);
  }

  // =====================================================================
  // TOAST
  // =====================================================================
  const toastHost = $('toast-host');

  function slNotify(text, kind, duration) {
    if (!toastHost || !text) return;
    duration = Math.max(800, parseInt(duration, 10) || 3500);
    const icons = { success: '✓', error: '✕', inform: 'ℹ' };
    const t = el('div', 'toast toast-' + (kind || 'inform'));
    t.innerHTML = '<span class="toast-icon"></span><span class="toast-text"></span>';
    t.querySelector('.toast-icon').textContent = icons[kind] || 'ℹ';
    t.querySelector('.toast-text').textContent  = text;
    toastHost.appendChild(t);
    setTimeout(() => {
      t.classList.add('removing');
      setTimeout(() => t.remove(), 200);
    }, duration);
  }

  // =====================================================================
  // fetchNui
  // =====================================================================
  function fetchNui(name, data) {
    const resource = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'sl-properties';
    return fetch(`https://${resource}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then(r => r.json()).catch(() => ({}));
  }

  // =====================================================================
  // TOOLTIP
  // =====================================================================
  const tipEl      = $('tip');
  const tipIcon    = $('tip-icon');
  const tipName    = $('tip-name');
  const tipCat     = $('tip-cat');
  const tipDesc    = $('tip-desc');
  const tipCount   = $('tip-count');

  // Catalogue items (clé = item name)
  let catalog = {};

  function showTip(item, count) {
    const def = catalog[item] || {};
    tipIcon.textContent  = def.icon || '📦';
    tipName.textContent  = def.label || item;
    tipCat.textContent   = def.category || 'misc';
    tipDesc.textContent  = def.description || '—';
    tipCount.textContent = 'x' + (count || 1);
    tipEl.classList.remove('hidden');
  }
  function hideTip() { tipEl.classList.add('hidden'); }
  function moveTip(ev) {
    const w = tipEl.offsetWidth || 240;
    const h = tipEl.offsetHeight || 160;
    let x = ev.clientX + 16;
    let y = ev.clientY + 16;
    if (x + w > window.innerWidth)  x = ev.clientX - w - 16;
    if (y + h > window.innerHeight) y = ev.clientY - h - 16;
    tipEl.style.transform = `translate(${x}px,${y}px)`;
  }

  // =====================================================================
  // AGENCE IMMOBILIÈRE
  // =====================================================================
  const agencyRoot     = $('agency-root');
  const agencyOverlay  = $('agency-overlay');
  const agencyClose    = $('agency-close');
  const availableList  = $('available-list');
  const ownedList      = $('owned-list');

  let agencyOpen = false;

  function openAgency(available, owned) {
    agencyOpen = true;
    buildAvailableList(available || []);
    buildOwnedList(owned || []);
    agencyRoot.classList.remove('hidden');
  }

  function closeAgency() {
    agencyOpen = false;
    agencyRoot.classList.add('hidden');
    hideTip();
    fetchNui('close', {});
  }

  function buildAvailableList(list) {
    availableList.innerHTML = '';
    if (!list.length) {
      const e = el('div', 'prop-empty'); e.textContent = 'Aucun bien disponible'; availableList.appendChild(e);
      return;
    }
    list.forEach(prop => {
      const card = el('div', 'prop-card');
      card.innerHTML = `
        <div class="card-label">${prop.label || '—'}</div>
        <div class="card-type">${prop.type || 'apartment'}</div>
        <div class="card-price">${fmtMoney(prop.price || 0)}</div>
        <div class="card-btn-row">
          <button class="card-btn card-btn-buy" data-id="${prop.id}">Acheter</button>
        </div>`;
      card.querySelector('.card-btn-buy').addEventListener('click', () => {
        fetchNui('buy', { propId: prop.id });
        slNotify('Achat en cours...', 'inform', 2000);
        // On ferme après achat (le serveur notifiera)
        closeAgency();
      });
      availableList.appendChild(card);
    });
  }

  function buildOwnedList(list) {
    ownedList.innerHTML = '';
    if (!list.length) {
      const e = el('div', 'prop-empty'); e.textContent = 'Aucune propriété'; ownedList.appendChild(e);
      return;
    }
    list.forEach(prop => {
      const card = el('div', 'prop-card');
      card.innerHTML = `
        <div class="card-label">${prop.label || '—'}</div>
        <div class="card-type">${prop.type || 'apartment'} • PROPRIÉTAIRE</div>
        <div class="card-price" style="color:var(--gold)">${fmtMoney(prop.price || 0)}</div>
        <div class="card-btn-row">
          <button class="card-btn card-btn-enter" data-id="${prop.id}">Entrer</button>
        </div>`;
      card.querySelector('.card-btn-enter').addEventListener('click', () => {
        fetchNui('enterProp', { propId: prop.id });
        closeAgency();
      });
      ownedList.appendChild(card);
    });
  }

  agencyClose.addEventListener('click', closeAgency);
  agencyOverlay.addEventListener('click', closeAgency);

  // =====================================================================
  // COFFRE
  // =====================================================================
  const stashRoot       = $('stash-root');
  const stashOverlay    = $('stash-overlay');
  const stashClose      = $('stash-close');
  const stashGrid       = $('stash-grid');
  const stashTitle      = $('stash-title');
  const stashSub        = $('stash-sub');
  const stashWeightFill = $('stash-weight-fill');
  const stashWeightCur  = $('stash-weight-cur');
  const stashWeightMax  = $('stash-weight-max');
  const stashAction     = $('stash-action');
  const actionSlotNum   = $('action-slot-num');
  const actionQty       = $('action-qty');
  const btnWithdraw     = $('btn-withdraw');
  const btnCancel       = $('btn-cancel');

  let stashOpen      = false;
  let stashState     = { slots: {}, slotCount: 30, maxWeight: 30000, propId: null };
  let selectedSlot   = null;   // slot sélectionné dans le coffre (numérique)
  let selectedItem   = null;

  function openStash(payload) {
    stashOpen = true;
    stashState.slots     = payload.slots || {};
    stashState.slotCount = payload.slotCount || 30;
    stashState.maxWeight = payload.maxWeight || 30000;
    stashState.propId    = payload.propId;
    stashTitle.textContent = 'Coffre — ' + (payload.label || '');
    stashSub.textContent   = 'Stockage personnel';
    updateStashWeight();
    buildStashGrid();
    stashAction.classList.add('hidden');
    selectedSlot = null;
    selectedItem = null;
    stashRoot.classList.remove('hidden');
  }

  function closeStash() {
    stashOpen = false;
    stashRoot.classList.add('hidden');
    selectedSlot = null;
    selectedItem = null;
    hideTip();
    fetchNui('close', {});
  }

  function computeStashWeight() {
    let w = 0;
    for (const key of Object.keys(stashState.slots)) {
      const s = stashState.slots[key];
      if (!s) continue;
      const def = catalog[s.item] || {};
      w += (def.weight || 0) * (s.count || 1);
    }
    return w;
  }

  function updateStashWeight() {
    const w   = computeStashWeight();
    const max = stashState.maxWeight;
    const pct = max > 0 ? Math.min(100, Math.round((w / max) * 100)) : 0;
    stashWeightFill.style.width = pct + '%';
    stashWeightCur.textContent  = fmtWeightKg(w);
    stashWeightMax.textContent  = fmtWeightKg(max);
  }

  function buildStashGrid() {
    stashGrid.innerHTML = '';
    for (let i = 1; i <= stashState.slotCount; i++) {
      const s   = pickSlot(stashState.slots, i);
      const def = s ? (catalog[s.item] || {}) : {};

      const cell = el('div', 's-cell' + (s ? ' has-item' : ''));
      cell.dataset.slot = i;

      const numEl = el('div', 's-cell-num');
      numEl.textContent = String(i).padStart(2, '0');
      cell.appendChild(numEl);

      if (s) {
        const iconEl = el('div', 's-cell-icon');
        iconEl.textContent = def.icon || '📦';
        cell.appendChild(iconEl);

        if (s.count > 1) {
          const cntEl = el('div', 's-cell-count');
          cntEl.textContent = 'x' + s.count;
          cell.appendChild(cntEl);
        }

        // Tooltip
        cell.addEventListener('mouseenter', () => showTip(s.item, s.count));
        cell.addEventListener('mousemove',  moveTip);
        cell.addEventListener('mouseleave', hideTip);

        // Clic gauche : sélectionner le slot -> panneau retrait
        cell.addEventListener('click', () => selectStashSlot(i, s));

        // Clic droit : retrait rapide (1)
        cell.addEventListener('contextmenu', (ev) => {
          ev.preventDefault();
          doWithdraw(i, 1);
        });
      } else {
        // Slot vide : clic droit = déposer item actif
        cell.addEventListener('contextmenu', (ev) => {
          ev.preventDefault();
          doDeposit(i);
        });
      }

      stashGrid.appendChild(cell);
    }
  }

  function selectStashSlot(slotIdx, slotData) {
    // Désélection si re-clic
    if (selectedSlot === slotIdx) {
      clearStashSelection();
      return;
    }
    selectedSlot = slotIdx;
    selectedItem = slotData;

    // Highlight DOM
    stashGrid.querySelectorAll('.s-cell').forEach(c => c.classList.remove('selected'));
    const cell = stashGrid.querySelector(`.s-cell[data-slot="${slotIdx}"]`);
    if (cell) cell.classList.add('selected');

    // Affiche panneau action
    actionSlotNum.textContent = slotIdx;
    actionQty.value = slotData.count || 1;
    actionQty.max   = slotData.count || 1;
    stashAction.classList.remove('hidden');
  }

  function clearStashSelection() {
    selectedSlot = null;
    selectedItem = null;
    stashGrid.querySelectorAll('.s-cell').forEach(c => c.classList.remove('selected'));
    stashAction.classList.add('hidden');
  }

  function doWithdraw(slotIdx, qty) {
    if (!slotIdx) return;
    qty = Math.max(1, parseInt(qty, 10) || 1);
    fetchNui('stashWithdraw', { slot: slotIdx, count: qty });
    clearStashSelection();
  }

  function doDeposit(slotIdx) {
    // Le client doit avoir un item "actif" sélectionné dans son inventaire.
    // On passe par une NUI callback simple (pas de drag depuis sl-inventory ici).
    // On demande via prompt JS natif (simple v1), ou on envoie un event
    // au client pour sélectionner depuis l'inventaire.
    // Pour V1 : on envoie slot cible, le client Lua ouvrira sl-inventory pour choisir.
    fetchNui('stashDeposit', { slot: slotIdx, item: null, count: 1 });
  }

  // Bouton Retirer
  btnWithdraw.addEventListener('click', () => {
    if (selectedSlot === null) return;
    const qty = Math.max(1, parseInt(actionQty.value, 10) || 1);
    doWithdraw(selectedSlot, qty);
  });

  // Bouton Annuler
  btnCancel.addEventListener('click', clearStashSelection);

  stashClose.addEventListener('click', closeStash);
  stashOverlay.addEventListener('click', closeStash);

  // =====================================================================
  // NUI MESSAGES
  // =====================================================================
  window.addEventListener('message', (event) => {
    const data = event.data || {};
    switch (data.action) {

      case 'openAgency':
        // Construit l'index catalog si fourni
        if (data.catalog) {
          catalog = {};
          (data.catalog || []).forEach(it => { catalog[it.name] = it; });
        }
        openAgency(data.available, data.owned);
        break;

      case 'openStash':
        if (data.catalog) {
          catalog = {};
          (data.catalog || []).forEach(it => { catalog[it.name] = it; });
        }
        openStash(data);
        break;

      case 'stashSync':
        // Mise à jour partielle (après depot/retrait)
        if (data.slots !== undefined) {
          stashState.slots = data.slots;
          buildStashGrid();
          updateStashWeight();
          clearStashSelection();
        }
        break;

      case 'close':
        if (agencyOpen) { agencyOpen = false; agencyRoot.classList.add('hidden'); }
        if (stashOpen)  { stashOpen  = false; stashRoot.classList.add('hidden'); }
        hideTip();
        break;

      case 'toast':
        slNotify(data.text, data.type, data.duration);
        break;
    }
  });

  // =====================================================================
  // Escape global
  // =====================================================================
  document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape') {
      if (agencyOpen) closeAgency();
      else if (stashOpen) closeStash();
    }
  });

})();
