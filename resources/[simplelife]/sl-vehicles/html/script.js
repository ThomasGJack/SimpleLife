(() => {
  'use strict';

  // ===========================================================================
  // Helpers
  // ===========================================================================
  const $ = (id) => document.getElementById(id);

  const CAT_ICONS = {
    compact: '🚗', sedan: '🚙', sport: '🏎', suv: '🚐', moto: '🏍', utility: '🚚',
  };

  function fmtPrice(n) {
    if (!n || n === 0) return 'GRATUIT';
    return '$' + n.toLocaleString('fr-FR');
  }

  function getParentResourceName() {
    return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'sl-vehicles';
  }

  function fetchNui(name, data) {
    const url = `https://${getParentResourceName()}/${name}`;
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then(r => r.json()).catch(() => ({}));
  }

  // ===========================================================================
  // TOAST
  // ===========================================================================
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

  // ===========================================================================
  // CONCESSION
  // ===========================================================================
  const vehRoot     = $('veh-root');
  const vehOverlay  = $('veh-overlay');
  const vehSidebar  = $('veh-sidebar');
  const vehGrid     = $('veh-grid');
  const detailEmpty = $('detail-empty');
  const detailContent = $('detail-content');
  const detailLabel = $('detail-label');
  const detailCat   = $('detail-cat');
  const detailModel = $('detail-model');
  const detailPrice = $('detail-price');
  const btnBuy      = $('btn-buy');

  let concessionState = {
    catalog: [],      // array {model, label, category, price}
    categories: [],   // array {key, label, icon}
    activeCategory: null,
    selectedModel: null,
    isBuying: false,
  };
  let concessionOpen = false;

  function buildSidebar() {
    vehSidebar.innerHTML = '<div class="sidebar-title">Categories</div>';
    concessionState.categories.forEach(cat => {
      const el = document.createElement('div');
      el.className = 'sidebar-cat' + (concessionState.activeCategory === cat.key ? ' active' : '');
      el.innerHTML = `<span class="sidebar-cat-icon">${cat.icon || ''}</span><span class="sidebar-cat-label">${cat.label}</span>`;
      el.addEventListener('click', () => {
        concessionState.activeCategory = cat.key;
        buildSidebar();
        buildGrid();
      });
      vehSidebar.appendChild(el);
    });
  }

  function buildGrid() {
    vehGrid.innerHTML = '';
    const activeCat = concessionState.activeCategory;
    concessionState.catalog.forEach(v => {
      if (activeCat && v.category !== activeCat) return;
      const card = document.createElement('div');
      card.className = 'veh-card' + (concessionState.selectedModel === v.model ? ' selected' : '');
      const icon = CAT_ICONS[v.category] || '🚗';
      const priceStr = fmtPrice(v.price);
      const priceClass = (!v.price || v.price === 0) ? 'card-price card-price-free' : 'card-price';
      card.innerHTML = `
        <div class="card-icon">${icon}</div>
        <div class="card-label">${v.label}</div>
        <div class="card-cat">${v.category}</div>
        <div class="${priceClass}">${priceStr}</div>
      `;
      card.addEventListener('click', () => selectVehicle(v));
      vehGrid.appendChild(card);
    });
  }

  function selectVehicle(v) {
    concessionState.selectedModel = v.model;
    buildGrid();
    // Detail panel
    detailEmpty.classList.add('hidden');
    detailContent.classList.remove('hidden');
    detailLabel.textContent = v.label;
    detailCat.textContent   = v.category.toUpperCase();
    detailModel.textContent = 'model: ' + v.model;
    if (!v.price || v.price === 0) {
      detailPrice.textContent = 'GRATUIT';
      detailPrice.classList.add('free');
    } else {
      detailPrice.textContent = fmtPrice(v.price);
      detailPrice.classList.remove('free');
    }
    btnBuy.disabled = false;
    // Preview
    fetchNui('concession:preview', { model: v.model });
  }

  function openConcession(data) {
    if (data) {
      concessionState.catalog    = data.catalog || [];
      concessionState.categories = data.categories || [];
      if (concessionState.categories.length > 0) {
        concessionState.activeCategory = concessionState.categories[0].key;
      }
      concessionState.selectedModel = null;
      concessionState.isBuying      = false;
    }
    buildSidebar();
    buildGrid();
    detailEmpty.classList.remove('hidden');
    detailContent.classList.add('hidden');
    vehRoot.classList.remove('hidden');
    concessionOpen = true;
  }

  function closeConcession() {
    if (!concessionOpen) return;
    vehRoot.classList.add('hidden');
    concessionOpen = false;
    fetchNui('concession:close', {});
  }

  btnBuy.addEventListener('click', () => {
    if (!concessionState.selectedModel || concessionState.isBuying) return;
    concessionState.isBuying = true;
    btnBuy.disabled = true;
    btnBuy.textContent = 'Achat en cours...';
    fetchNui('concession:buy', { model: concessionState.selectedModel }).then(res => {
      concessionState.isBuying = false;
      btnBuy.disabled = false;
      btnBuy.textContent = 'Acheter';
      if (res && res.ok) {
        showToast('Vehicule achete ! Plaque : ' + (res.plate || ''), 'success', 4000);
        closeConcession();
      } else {
        showToast('Achat echoue : ' + (res && res.err ? res.err : 'erreur'), 'error', 4000);
      }
    });
  });

  $('btn-close-concession').addEventListener('click', closeConcession);
  vehOverlay.addEventListener('click', closeConcession);

  // ===========================================================================
  // GARAGE
  // ===========================================================================
  const garageRoot    = $('garage-root');
  const garageOverlay = $('garage-overlay');
  const garageEmpty   = $('garage-empty');
  const garageList    = $('garage-list');

  let garageOpen = false;
  let garageVehicles = [];

  function buildGarageRow(v) {
    const row = document.createElement('div');
    row.className = 'garage-row';

    const icon = CAT_ICONS['sedan'] || '🚗';
    const stateClass = v.state === 'out' ? 'state-out' : 'state-garage';
    const stateLabel = v.state === 'out' ? 'En circulation' : 'Garage';
    const fuelPct    = Math.min(100, Math.max(0, parseInt(v.fuel, 10) || 0));
    const isOut      = v.state === 'out';

    row.innerHTML = `
      <div class="garage-row-icon">${icon}</div>
      <div class="garage-row-info">
        <div class="garage-row-model">${escHtml(v.model)}</div>
        <div class="garage-row-plate">${escHtml(v.plate)}</div>
      </div>
      <div class="garage-row-state ${stateClass}">${stateLabel}</div>
      <div class="garage-row-fuel">
        <div class="fuel-label">Carburant</div>
        <div class="fuel-bar"><div class="fuel-fill" style="width:${fuelPct}%"></div></div>
      </div>
      <div class="garage-row-actions">
        <button class="btn-action spawn" ${isOut ? 'disabled' : ''} title="Sortir le vehicule">Sortir</button>
        <button class="btn-action store" ${!isOut ? 'disabled' : ''} title="Ranger le vehicule">Rentrer</button>
      </div>
    `;

    const btnSpawn = row.querySelector('.btn-action.spawn');
    const btnStore = row.querySelector('.btn-action.store');

    btnSpawn.addEventListener('click', () => {
      if (btnSpawn.disabled) return;
      btnSpawn.disabled = true;
      btnSpawn.textContent = '...';
      fetchNui('garage:spawn', { plate: v.plate }).then(res => {
        if (res && res.ok) {
          showToast('Vehicule sorti !', 'success', 3000);
        } else {
          showToast('Impossible de sortir le vehicule.', 'error', 3500);
          btnSpawn.disabled = false;
          btnSpawn.textContent = 'Sortir';
        }
      });
    });

    btnStore.addEventListener('click', () => {
      if (btnStore.disabled) return;
      btnStore.disabled = true;
      btnStore.textContent = '...';
      fetchNui('garage:store', { plate: v.plate }).then(res => {
        if (res && res.ok) {
          showToast('Vehicule range.', 'success', 3000);
        } else {
          showToast('Impossible de ranger.', 'error', 3500);
          btnStore.disabled = false;
          btnStore.textContent = 'Rentrer';
        }
      });
    });

    return row;
  }

  function buildGarageList() {
    garageList.innerHTML = '';
    if (!garageVehicles || garageVehicles.length === 0) {
      garageEmpty.classList.remove('hidden');
      return;
    }
    garageEmpty.classList.add('hidden');
    garageVehicles.forEach(v => {
      garageList.appendChild(buildGarageRow(v));
    });
  }

  function openGarage(data) {
    garageVehicles = (data && data.vehicles) ? data.vehicles : [];
    buildGarageList();
    garageRoot.classList.remove('hidden');
    garageOpen = true;
  }

  function closeGarage() {
    if (!garageOpen) return;
    garageRoot.classList.add('hidden');
    garageOpen = false;
    fetchNui('garage:close', {});
  }

  $('btn-close-garage').addEventListener('click', closeGarage);
  garageOverlay.addEventListener('click', closeGarage);

  // ===========================================================================
  // Sanitize HTML
  // ===========================================================================
  function escHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  // ===========================================================================
  // SendNUIMessage handler
  // ===========================================================================
  window.addEventListener('message', (event) => {
    const data = event.data || {};
    switch (data.action) {
      case 'openConcession':
        openConcession(data);
        break;
      case 'openGarage':
        openGarage(data);
        break;
      case 'close':
        closeConcession();
        closeGarage();
        break;
      case 'toast':
        showToast(data.text, data.type, data.duration);
        break;
    }
  });

  // ===========================================================================
  // Escape global
  // ===========================================================================
  document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape') {
      if (concessionOpen) { fetchNui('concession:close', {}); closeConcession(); }
      if (garageOpen)     { fetchNui('garage:close', {});     closeGarage(); }
    }
  });
})();
