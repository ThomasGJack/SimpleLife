(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const root      = $('inv-root');
  const overlay   = $('inv-overlay');
  const grid      = $('grid');
  const charName  = $('char-name');
  const weightFill= $('weight-fill');
  const weightCur = $('weight-cur');
  const weightMax = $('weight-max');
  const filtersEl = $('filters');
  const nearbyEmpty = $('nearby-empty');
  const nearbyGrid  = $('nearby-grid');
  const tip       = $('tip');
  const tipIcon   = $('tip-icon');
  const tipName   = $('tip-name');
  const tipCat    = $('tip-cat');
  const tipDesc   = $('tip-desc');
  const tipWeight = $('tip-weight');
  const tipCount  = $('tip-count');
  const tipTotal  = $('tip-total');
  const tipMeta   = $('tip-meta');
  const tipMetaWrap = $('tip-meta-wrap');

  // état complet reçu du serveur (rebuilt à chaque sync)
  let state = {
    slots: {},          // 1..30 + 201..205
    equipment: {},      // { backpack: {slot, content}, ... }
    rules: {},          // map "201": { items: [...], categories: [...], label }
    slotCount: 30,
    equipmentSlots: { backpack: 201, holster: 202, phone: 203, radio: 204, docs: 205 },
    weight: 0,
    maxWeight: 40000,
    catalog: [],
    nearby: null,
  };
  let catalogByName = {};
  let activeFilter = 'all';
  let isWindowOpen = false;

  const FILTERS = [
    { key: 'all',     label: 'Tout' },
    { key: 'food',    label: 'Bouffe' },
    { key: 'drink',   label: 'Boisson' },
    { key: 'tool',    label: 'Outils' },
    { key: 'weapon',  label: 'Armes' },
    { key: 'key',     label: 'Clés' },
    { key: 'license', label: 'Permis' },
    { key: 'badge',   label: 'Badges' },
    { key: 'doc',     label: 'Docs' },
    { key: 'valuable',label: 'Valeurs' },
    { key: 'misc',    label: 'Divers' },
  ];

  // =====================================================================
  // Helpers
  // =====================================================================
  function rebuildCatalogIndex() {
    catalogByName = {};
    (state.catalog || []).forEach(it => { catalogByName[it.name] = it; });
  }

  // Récupère l'occupant d'un slot (number ou string) — JSON peut sérialiser
  // les clés numériques en strings.
  function pickSlot(map, idx) {
    if (!map) return null;
    return map[idx] || map[String(idx)] || null;
  }

  function fmtWeightKg(g) {
    if (g >= 1000) return (g / 1000).toFixed(2);
    return (g / 1000).toFixed(3);
  }

  function categoryOf(itemName) {
    const def = catalogByName[itemName];
    return def && def.category ? def.category : 'misc';
  }

  function ruleAcceptsItem(slotIndex, itemName) {
    const rule = state.rules ? (state.rules[slotIndex] || state.rules[String(slotIndex)]) : null;
    if (!rule) return true;
    if (rule.items && rule.items.indexOf(itemName) !== -1) return true;
    if (rule.categories && rule.categories.indexOf(categoryOf(itemName)) !== -1) return true;
    return false;
  }

  // =====================================================================
  // Rendu d'une cellule (réutilisable : grid + paper-doll)
  // =====================================================================
  function renderCellInto(container, slotIndex, slotData, opts) {
    opts = opts || {};
    container.innerHTML = '';
    const cell = container.closest('.cell, .pd-slot') || container;
    // On NE retire PAS `.selected`, `.target-invalid`, `.target-valid` :
    // ce sont des états de sélection persistants entre les syncs.
    cell.classList.remove('has-item', 'empty', 'unique', 'dim');

    if (!slotData) {
      if (cell.classList.contains('cell')) cell.classList.add('empty');
      return;
    }

    cell.classList.add('has-item');
    const def = catalogByName[slotData.item] || {};
    if (def.unique) cell.classList.add('unique');

    const icon = document.createElement('div');
    icon.className = 'cell-icon';
    icon.textContent = def.icon || '📦';
    container.appendChild(icon);

    if ((slotData.count || 1) > 1) {
      const c = document.createElement('div');
      c.className = 'cell-count';
      c.textContent = 'x' + slotData.count;
      container.appendChild(c);
    }

    // Le filtre estompe la cellule
    if (opts.applyFilter && activeFilter !== 'all' && categoryOf(slotData.item) !== activeFilter) {
      cell.classList.add('dim');
    }
  }

  // =====================================================================
  // RENDU GRILLE
  // =====================================================================
  function buildGrid() {
    grid.innerHTML = '';
    for (let i = 1; i <= state.slotCount; i++) {
      const cell = document.createElement('div');
      cell.className = 'cell';
      cell.dataset.slot = i;

      const slotLabel = document.createElement('div');
      slotLabel.className = 'cell-slot';
      slotLabel.textContent = String(i).padStart(2, '0');
      cell.appendChild(slotLabel);

      const content = document.createElement('div');
      content.className = 'cell-content';
      cell.appendChild(content);

      wireSlot(cell, i, () => pickSlot(state.slots, i));
      grid.appendChild(cell);
    }
  }

  function refreshGrid() {
    grid.querySelectorAll('.cell').forEach(cell => {
      const i = Number(cell.dataset.slot);
      const content = cell.querySelector('.cell-content');
      renderCellInto(content, i, pickSlot(state.slots, i), { applyFilter: true });
    });
  }

  // =====================================================================
  // RENDU PAPER-DOLL
  // =====================================================================
  function refreshPaperdoll() {
    document.querySelectorAll('.pd-slot').forEach(cell => {
      const i = Number(cell.dataset.slot);
      const content = cell.querySelector('.cell-content');
      renderCellInto(content, i, pickSlot(state.slots, i));
    });
  }

  // =====================================================================
  // Câblage des slots paper-doll statiques (présents dès le HTML).
  // =====================================================================
  function wireStaticSlots() {
    document.querySelectorAll('.pd-slot').forEach(cell => {
      const i = Number(cell.dataset.slot);
      wireSlot(cell, i, () => pickSlot(state.slots, i));
    });
  }

  // =====================================================================
  // Wire un slot — click pick & place + clic-droit (utiliser) + tooltip
  //
  // UX :
  //   Clic sur slot avec item   → sélectionne (cellule pulse en doré).
  //                                Les slots qui REFUSERAIENT l'item se
  //                                grisent pour indiquer où ne PAS cliquer.
  //   Clic sur un autre slot    → déplace la sélection ici (server valide).
  //   Clic sur la sélection     → désélectionne.
  //   Clic droit                → utiliser l'item (manger, badge, etc.).
  //   Maj + clic                → jeter l'item.
  // =====================================================================
  function wireSlot(cell, slotIndex, getter) {

    cell.addEventListener('click', (ev) => {
      const data = getter();

      if (ev.shiftKey) {
        if (!data) return;
        fetchNui('drop', { slot: slotIndex, count: data.count });
        clearSelection();
        return;
      }

      handleClickSelection(cell, slotIndex, data);
    });

    cell.addEventListener('contextmenu', (ev) => {
      ev.preventDefault();
      const data = getter();
      if (!data) return;
      const def = catalogByName[data.item];
      if (!def || !def.usable) return;
      fetchNui('use', { slot: slotIndex });
    });

    cell.addEventListener('mouseenter', () => {
      const data = getter();
      if (!data) { hideTip(); return; }
      showTip(data);
    });
    cell.addEventListener('mousemove', moveTip);
    cell.addEventListener('mouseleave', hideTip);
  }

  // =====================================================================
  // Click pick & place : sélection puis dépôt
  // =====================================================================
  let selectedSlot = null;

  function handleClickSelection(cell, slotIndex, data) {
    // Rien sélectionné : on sélectionne ce slot (s'il a un item)
    if (selectedSlot === null) {
      if (!data) return;
      selectedSlot = slotIndex;
      markSelected(cell, data.item);
      return;
    }
    // Re-clic sur la sélection : on désélectionne
    if (selectedSlot === slotIndex) {
      clearSelection();
      return;
    }
    // On a déjà une sélection : on essaye de la déposer ici
    const srcData = findSlotByIndex(selectedSlot);
    if (!srcData) { clearSelection(); return; }
    if (!ruleAcceptsItem(slotIndex, srcData.item)) {
      flashInvalid(cell);
      // On garde la sélection : l'utilisateur peut retenter ailleurs
      return;
    }
    fetchNui('move', { fromSlot: selectedSlot, toSlot: slotIndex, count: srcData.count || 1 });
    clearSelection();
  }

  function markSelected(cell, itemName) {
    // Nettoyage DOM uniquement (sans toucher à `selectedSlot` que le caller
    // vient juste de définir).
    document.querySelectorAll('.selected, .target-invalid, .target-valid').forEach(c => {
      c.classList.remove('selected', 'target-invalid', 'target-valid');
    });
    cell.classList.add('selected');
    // Grise les slots qui REFUSERAIENT cet item (paper-doll uniquement, la
    // grille n'a pas de règle d'acceptation).
    document.querySelectorAll('.pd-slot').forEach(c => {
      const idx = Number(c.dataset.slot);
      if (!idx || idx === selectedSlot) return;
      if (!ruleAcceptsItem(idx, itemName)) {
        c.classList.add('target-invalid');
      } else {
        c.classList.add('target-valid');
      }
    });
  }

  function clearSelection() {
    selectedSlot = null;
    document.querySelectorAll('.selected, .target-invalid, .target-valid').forEach(c => {
      c.classList.remove('selected', 'target-invalid', 'target-valid');
    });
  }

  function findSlotByIndex(idx) {
    return pickSlot(state.slots, idx);
  }

  function flashInvalid(cell) {
    cell.classList.add('drag-invalid');
    setTimeout(() => cell.classList.remove('drag-invalid'), 400);
  }

  // =====================================================================
  // TOOLTIP
  // =====================================================================
  function showTip(slotData) {
    const def = catalogByName[slotData.item] || {};
    tipIcon.textContent = def.icon || '📦';
    tipName.textContent = def.label || slotData.item;
    tipCat.textContent  = (def.category || 'misc') + (def.unique ? ' • UNIQUE' : '');
    tipDesc.textContent = def.description || '—';
    tipWeight.textContent = ((def.weight || 0) / 1000).toFixed(3) + ' kg';
    tipCount.textContent  = 'x' + (slotData.count || 1);
    tipTotal.textContent  = (((def.weight || 0) * (slotData.count || 0)) / 1000).toFixed(3) + ' kg';

    if (slotData.metadata && Object.keys(slotData.metadata).length > 0) {
      tipMetaWrap.classList.remove('hidden');
      tipMeta.textContent = JSON.stringify(slotData.metadata, null, 2);
    } else {
      tipMetaWrap.classList.add('hidden');
    }
    tip.classList.remove('hidden');
  }
  function hideTip() { tip.classList.add('hidden'); }
  function moveTip(ev) {
    const w = tip.offsetWidth || 260;
    const h = tip.offsetHeight || 200;
    let x = ev.clientX + 18;
    let y = ev.clientY + 18;
    if (x + w > window.innerWidth)  x = ev.clientX - w - 18;
    if (y + h > window.innerHeight) y = ev.clientY - h - 18;
    tip.style.transform = `translate(${x}px, ${y}px)`;
  }

  // =====================================================================
  // FILTERS
  // =====================================================================
  function buildFilters() {
    filtersEl.innerHTML = '';
    FILTERS.forEach(f => {
      const el = document.createElement('div');
      el.className = 'filter' + (activeFilter === f.key ? ' active' : '');
      el.textContent = f.label;
      el.addEventListener('click', () => {
        activeFilter = f.key;
        buildFilters();
        refreshGrid();
      });
      filtersEl.appendChild(el);
    });
  }

  // =====================================================================
  // NEARBY
  // =====================================================================
  function refreshNearby() {
    if (state.nearby && Array.isArray(state.nearby) && state.nearby.length > 0) {
      nearbyEmpty.classList.add('hidden');
      nearbyGrid.classList.remove('hidden');
      nearbyGrid.innerHTML = state.nearby.map((it, i) => {
        const def = catalogByName[it.item] || {};
        return `<div class="cell has-item" data-nearby-slot="${i}">
          <div class="cell-content">
            <div class="cell-icon">${def.icon || '📦'}</div>
            ${it.count > 1 ? `<div class="cell-count">x${it.count}</div>` : ''}
          </div>
        </div>`;
      }).join('');
    } else {
      nearbyEmpty.classList.remove('hidden');
      nearbyGrid.classList.add('hidden');
      nearbyGrid.innerHTML = '';
    }
  }

  // =====================================================================
  // HEADER (weight)
  // =====================================================================
  function refreshHeader() {
    weightCur.textContent = fmtWeightKg(state.weight || 0);
    weightMax.textContent = fmtWeightKg(state.maxWeight || 0);
    const pct = state.maxWeight > 0 ? Math.min(100, Math.round((state.weight / state.maxWeight) * 100)) : 0;
    weightFill.style.width = pct + '%';
  }

  // =====================================================================
  // STATE APPLICATION
  // =====================================================================
  function applyState(s) {
    if (!s) return;
    state = Object.assign({}, state, s);
    rebuildCatalogIndex();
    refreshHeader();
    refreshGrid();
    refreshPaperdoll();
    refreshNearby();
    // Si la sélection courante ne pointe plus vers un item valide, on l'annule.
    if (selectedSlot !== null && !findSlotByIndex(selectedSlot)) {
      clearSelection();
    }
  }

  // =====================================================================
  // OPEN / CLOSE
  // =====================================================================
  function openWindow(s) {
    if (s) applyState(s);
    isWindowOpen = true;
    root.classList.remove('hidden');
  }
  function closeWindow() {
    if (!isWindowOpen) return;
    isWindowOpen = false;
    root.classList.add('hidden');
    hideTip();
  }

  // =====================================================================
  // TOAST host
  // =====================================================================
  const toastHost = $('toast-host');

  function showToast(text, kind, duration) {
    if (!toastHost || !text) return;
    duration = Math.max(800, parseInt(duration, 10) || 3500);
    const icon = kind === 'success' ? '✓' : kind === 'error' ? '✕' : 'ℹ';
    const el = document.createElement('div');
    el.className = 'toast toast-' + (kind || 'inform');
    el.innerHTML = '<span class="toast-icon"></span><span class="toast-text"></span>';
    el.querySelector('.toast-icon').textContent = icon;
    el.querySelector('.toast-text').textContent = text;
    toastHost.appendChild(el);
    setTimeout(() => {
      el.classList.add('removing');
      setTimeout(() => el.remove(), 200);
    }, duration);
  }

  // =====================================================================
  // NUI MESSAGES
  // =====================================================================
  window.addEventListener('message', (event) => {
    const data = event.data || {};
    switch (data.action) {
      case 'open':  openWindow(data.state); break;
      case 'sync':  if (data.state) applyState(data.state); break;
      case 'close': closeWindow(); break;
      case 'toast': showToast(data.text, data.type, data.duration); break;
    }
  });

  // =====================================================================
  // NUI bridge
  // =====================================================================
  function fetchNui(name, data) {
    const url = `https://${GetParentResourceName ? GetParentResourceName() : 'sl-inventory'}/${name}`;
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then(r => r.json()).catch(() => ({}));
  }

  // =====================================================================
  // GLOBAL HANDLERS
  // =====================================================================
  $('btn-close').addEventListener('click', () => fetchNui('close', {}));
  overlay.addEventListener('click', () => fetchNui('close', {}));

  document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape') fetchNui('close', {});
  });

  // =====================================================================
  // BOOT
  // =====================================================================
  buildGrid();
  buildFilters();
  wireStaticSlots();
})();
