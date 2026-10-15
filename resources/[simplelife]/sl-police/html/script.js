(() => {
  'use strict';

  // =====================================================================
  // Helpers
  // =====================================================================
  const $ = (id) => document.getElementById(id);

  function fetchNui(name, data) {
    const res = typeof GetParentResourceName === 'function'
      ? GetParentResourceName()
      : 'sl-police';
    return fetch(`https://${res}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then(r => r.json()).catch(() => ({}));
  }

  // =====================================================================
  // TOAST
  // =====================================================================
  const toastHost = $('toast-host');
  function slNotify(text, kind, duration) {
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
  // TABS
  // =====================================================================
  const tabs   = document.querySelectorAll('.mdt-tab');
  const panels = document.querySelectorAll('.mdt-panel');

  function switchTab(tabKey) {
    tabs.forEach(t => t.classList.toggle('active', t.dataset.tab === tabKey));
    panels.forEach(p => {
      const active = p.id === 'panel-' + tabKey;
      p.classList.toggle('active', active);
    });
    if (tabKey === 'bolos') loadBolos();
    if (tabKey === 'duty')  loadDuty();
  }

  tabs.forEach(t => {
    t.addEventListener('click', () => switchTab(t.dataset.tab));
  });

  // =====================================================================
  // MDT OPEN / CLOSE
  // =====================================================================
  const mdtRoot = $('mdt-root');

  function openMDT() {
    mdtRoot.classList.remove('hidden');
    switchTab('search');
  }
  function closeMDT() {
    mdtRoot.classList.add('hidden');
    fetchNui('mdt:close', {});
  }

  $('mdt-close-btn').addEventListener('click', closeMDT);
  $('mdt-overlay').addEventListener('click', closeMDT);

  // =====================================================================
  // RECHERCHE CITOYEN
  // =====================================================================
  const searchInput   = $('search-input');
  const searchBtn     = $('search-btn');
  const searchResults = $('search-results');
  const searchEmpty   = $('search-empty');
  const citizenDetail = $('citizen-detail');

  let currentCitizen = null;

  function buildSearchResults(results) {
    searchResults.innerHTML = '';
    if (!results || results.length === 0) {
      const el = document.createElement('div');
      el.className = 'results-empty';
      el.innerHTML = '<div class="empty-glyph">🔍</div><div class="empty-text">Aucun resultat</div>';
      searchResults.appendChild(el);
      return;
    }
    results.forEach(r => {
      const row = document.createElement('div');
      row.className = 'result-row' + (r.totalFine > 0 ? ' flagged' : '');
      row.innerHTML = `
        <div class="result-avatar">👤</div>
        <div class="result-info">
          <div class="result-name">${escHtml(r.firstName)} ${escHtml(r.lastName)}</div>
          <div class="result-czid">ID : ${escHtml(r.citizenId)}</div>
        </div>
        <div class="result-fine ${r.totalFine === 0 ? 'clean' : ''}">
          ${r.totalFine === 0 ? 'Casier vierge' : '$' + r.totalFine.toLocaleString()}
        </div>
      `;
      row.addEventListener('click', () => showCitizenDetail(r));
      searchResults.appendChild(row);
    });
  }

  function doSearch() {
    const q = searchInput.value.trim();
    if (!q) return;
    fetchNui('mdt:searchCitizen', { query: q }).then(results => {
      citizenDetail.classList.add('hidden');
      searchResults.classList.remove('hidden');
      buildSearchResults(results);
    });
  }

  searchBtn.addEventListener('click', doSearch);
  searchInput.addEventListener('keydown', e => { if (e.key === 'Enter') doSearch(); });

  // =====================================================================
  // DETAIL CITOYEN + CHARGES
  // =====================================================================
  const chargeSelect = $('charge-select');

  function populateChargeSelect() {
    // Charges predefinies injectees depuis la config Lua via NUI message
    // ou hardcodees ici si non disponibles
    const defaults = window._policeDefaultCharges || {
      'Attaque avec violence': 5000,
      'Meurtre': 25000,
      'Tentative de meurtre': 15000,
      'Vol de vehicule': 3000,
      'Braquage': 20000,
      'Trafic de drogue': 10000,
      'Possession de drogue': 2000,
      'Port illegale d arme': 4000,
      'Fuite de police': 3000,
      'Obstruction a la justice': 2500,
      'Conduite en etat d ivresse': 1500,
      'Depassement de vitesse': 800,
      'Stationnement illegal': 300,
      'Agression verbale': 500,
    };
    chargeSelect.innerHTML = '<option value="">-- Charges predefinies --</option>';
    Object.entries(defaults).forEach(([label, fine]) => {
      const opt = document.createElement('option');
      opt.value = JSON.stringify({ label, fine });
      opt.textContent = label + ' — $' + fine;
      chargeSelect.appendChild(opt);
    });
  }

  chargeSelect.addEventListener('change', () => {
    if (!chargeSelect.value) return;
    const data = JSON.parse(chargeSelect.value);
    $('charge-fine').value  = data.fine;
    $('charge-label').value = data.label;
  });

  function showCitizenDetail(citizen) {
    currentCitizen = citizen;
    searchResults.classList.add('hidden');
    citizenDetail.classList.remove('hidden');

    $('detail-name').textContent = citizen.firstName + ' ' + citizen.lastName;
    $('detail-czid').textContent = 'ID : ' + citizen.citizenId;
    $('detail-fine').textContent = 'Amendes totales : $' + (citizen.totalFine || 0).toLocaleString();

    const chargesList = $('detail-charges');
    chargesList.innerHTML = '';
    if (!citizen.charges || citizen.charges.length === 0) {
      chargesList.innerHTML = '<div style="color:var(--text-mute);font-size:12px;padding:12px;text-align:center;">Aucune charge</div>';
    } else {
      citizen.charges.forEach(c => {
        const row = document.createElement('div');
        row.className = 'charge-row';
        row.innerHTML = `
          <div class="charge-label">${escHtml(c.label || '—')}</div>
          <div class="charge-fine">$${(c.fine || 0).toLocaleString()}</div>
          <div class="charge-date">${escHtml(c.created_at || '')}</div>
        `;
        chargesList.appendChild(row);
      });
    }

    populateChargeSelect();
  }

  $('detail-back-btn').addEventListener('click', () => {
    currentCitizen = null;
    citizenDetail.classList.add('hidden');
    searchResults.classList.remove('hidden');
  });

  $('charge-add-btn').addEventListener('click', () => {
    if (!currentCitizen) return;
    const label = $('charge-label').value.trim();
    const fine  = parseInt($('charge-fine').value, 10) || 0;
    if (!label) { slNotify('Entrez un motif de charge.', 'error'); return; }

    fetchNui('mdt:addCharge', {
      citizenId: currentCitizen.citizenId,
      charge:    label,
      fine:      fine,
    }).then(res => {
      if (res && res.ok) {
        slNotify('Charge ajoutee.', 'success');
        // MAJ locale de la liste
        if (!currentCitizen.charges) currentCitizen.charges = [];
        currentCitizen.charges.push({ label, fine, created_at: new Date().toLocaleString() });
        currentCitizen.totalFine = (currentCitizen.totalFine || 0) + fine;
        showCitizenDetail(currentCitizen);
        $('charge-label').value = '';
        $('charge-fine').value  = '';
        chargeSelect.value = '';
      } else {
        slNotify('Echec de l ajout de charge.', 'error');
      }
    });
  });

  // =====================================================================
  // BOLOS
  // =====================================================================
  function loadBolos() {
    fetchNui('mdt:getBolos', {}).then(bolos => {
      const list  = $('bolo-list');
      const empty = $('bolo-empty');
      list.innerHTML = '';
      if (!bolos || bolos.length === 0) {
        list.appendChild(empty);
        empty.classList.remove('hidden');
        return;
      }
      bolos.forEach(b => {
        const row = document.createElement('div');
        row.className = 'bolo-row';
        const name = (b.first_name || '') + ' ' + (b.last_name || '');
        row.innerHTML = `
          <div class="bolo-content">
            <div class="bolo-czid">ID : ${escHtml(b.citizen_id)}</div>
            ${name.trim() ? `<div class="bolo-name">${escHtml(name)}</div>` : ''}
            <div class="bolo-reason">${escHtml(b.reason)}</div>
            <div class="bolo-meta">Emis par ${escHtml(b.created_by)} — ${escHtml(b.created_at || '')}</div>
          </div>
          <button class="bolo-del" data-id="${escHtml(String(b.id))}">Retirer</button>
        `;
        row.querySelector('.bolo-del').addEventListener('click', (e) => {
          e.stopPropagation();
          const id = parseInt(e.target.dataset.id, 10);
          fetchNui('mdt:deleteBolo', { id }).then(res => {
            if (res && res.ok) { slNotify('BOLO retire.', 'success'); loadBolos(); }
            else slNotify('Echec.', 'error');
          });
        });
        list.appendChild(row);
      });
    });
  }

  $('bolo-add-btn').addEventListener('click', () => {
    const czid   = $('bolo-czid').value.trim();
    const reason = $('bolo-reason').value.trim();
    if (!czid || !reason) { slNotify('Renseignez l ID et la raison.', 'error'); return; }
    fetchNui('mdt:addBolo', { citizenId: czid, reason }).then(res => {
      if (res && res.ok) {
        slNotify('BOLO emis.', 'success');
        $('bolo-czid').value   = '';
        $('bolo-reason').value = '';
        loadBolos();
      } else slNotify('Echec.', 'error');
    });
  });

  // =====================================================================
  // MEMBRES EN SERVICE
  // =====================================================================
  function loadDuty() {
    fetchNui('mdt:getOnDuty', {}).then(members => {
      const list  = $('duty-list');
      const empty = $('duty-empty');
      list.innerHTML = '';
      if (!members || members.length === 0) {
        list.appendChild(empty);
        empty.classList.remove('hidden');
        return;
      }
      members.forEach(m => {
        const row = document.createElement('div');
        row.className = 'duty-row';
        const name  = m.firstName ? (m.firstName + ' ' + m.lastName) : (m.name || 'Officier');
        const grade = m.grade || m.gradeName || '';
        row.innerHTML = `
          <div class="duty-avatar">👮</div>
          <div class="duty-name">${escHtml(name)}</div>
          ${grade ? `<div class="duty-grade">${escHtml(grade)}</div>` : ''}
          <div class="duty-badge">En service</div>
        `;
        list.appendChild(row);
      });
    });
  }

  $('duty-refresh-btn').addEventListener('click', loadDuty);

  // =====================================================================
  // FOUILLE (search window)
  // =====================================================================
  const searchRoot  = $('search-root');
  let searchTargetSrc = null;

  function openSearch(targetSrc, items) {
    searchTargetSrc = targetSrc;
    $('search-target-label').textContent = 'Inventaire du suspect (ID ' + targetSrc + ')';
    renderSearchItems(items);
    searchRoot.classList.remove('hidden');
  }

  function closeSearchWindow() {
    searchRoot.classList.add('hidden');
    searchTargetSrc = null;
    fetchNui('search:close', {});
  }

  function renderSearchItems(items) {
    const body = $('search-items-list');
    body.innerHTML = '';
    const itemArr = Array.isArray(items) ? items : Object.values(items || {});
    const filtered = itemArr.filter(it => it && it.item);
    if (filtered.length === 0) {
      body.innerHTML = '<div class="results-empty"><div class="empty-glyph">📦</div><div class="empty-text">Inventaire vide</div></div>';
      return;
    }
    filtered.forEach(it => {
      const row = document.createElement('div');
      row.className = 'search-item-row';
      row.innerHTML = `
        <div class="search-item-icon">📦</div>
        <div class="search-item-name">${escHtml(it.item)}</div>
        <div class="search-item-count">x${it.count || 1}</div>
        <button class="search-item-seize">Saisir</button>
      `;
      row.querySelector('.search-item-seize').addEventListener('click', (e) => {
        e.stopPropagation();
        if (!searchTargetSrc) return;
        fetchNui('search:seize', {
          targetSrc: searchTargetSrc,
          item:      it.item,
          count:     it.count || 1,
        }).then(() => {
          slNotify('Item saisi : ' + it.item, 'success');
          row.remove();
        });
      });
      body.appendChild(row);
    });
  }

  $('search-close-btn').addEventListener('click', closeSearchWindow);
  $('search-overlay').addEventListener('click', closeSearchWindow);

  // =====================================================================
  // NUI addCharge callback (depuis NUI vers serveur)
  // =====================================================================
  // On crée un endpoint NUI "mdt:addCharge" qui appelle le serveur
  // via RegisterNUICallback côté Lua (client/main.lua)

  // =====================================================================
  // NUI MESSAGES depuis le jeu
  // =====================================================================
  window.addEventListener('message', (event) => {
    const data = event.data || {};
    switch (data.action) {
      case 'openMDT':
        openMDT();
        break;
      case 'closeMDT':
        mdtRoot.classList.add('hidden');
        break;
      case 'openSearch':
        openSearch(data.targetSrc, data.items || {});
        break;
      case 'syncSearch':
        if (data.targetSrc === searchTargetSrc) {
          renderSearchItems(data.items || {});
        }
        break;
      case 'closeSearch':
        searchRoot.classList.add('hidden');
        searchTargetSrc = null;
        break;
      case 'setDefaultCharges':
        window._policeDefaultCharges = data.charges || {};
        break;
      case 'toast':
        slNotify(data.text, data.type, data.duration);
        break;
    }
  });

  // =====================================================================
  // Keyboard Escape
  // =====================================================================
  document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape') {
      if (!mdtRoot.classList.contains('hidden')) closeMDT();
      if (!searchRoot.classList.contains('hidden')) closeSearchWindow();
    }
  });

  // =====================================================================
  // HTML escape
  // =====================================================================
  function escHtml(str) {
    return String(str || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  // =====================================================================
  // INIT
  // =====================================================================
  populateChargeSelect();

})();
