(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const root = $('root');
  const tabsEl = $('tabs');
  const bodyEl = $('body');
  const modal  = $('modal');
  const toastHost = $('toast-host');

  let state = { tabs: [], data: {} };
  let activeTab = null;

  // ===========================================================================
  // NUI bridge
  // ===========================================================================
  function fetchNui(name, data) {
    const url = `https://${GetParentResourceName ? GetParentResourceName() : 'sl-admin'}/${name}`;
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then(r => r.json()).catch(() => ({}));
  }

  // ===========================================================================
  // Toast
  // ===========================================================================
  function toast(text, kind, duration) {
    if (!toastHost) return;
    const el = document.createElement('div');
    el.className = 'toast t-' + (kind || 'inform');
    el.textContent = text;
    toastHost.appendChild(el);
    setTimeout(() => {
      el.classList.add('removing');
      setTimeout(() => el.remove(), 200);
    }, duration || 3000);
  }

  // ===========================================================================
  // Modal (input dialog generic)
  // ===========================================================================
  function openModal(title, fields, onConfirm) {
    $('modal-title').textContent = title;
    const body = $('modal-body');
    body.innerHTML = '';
    fields.forEach((f, i) => {
      const wrap = document.createElement('div');
      wrap.innerHTML = `<label>${f.label}</label>`;
      let input;
      if (f.type === 'select') {
        input = document.createElement('select');
        (f.options || []).forEach(opt => {
          const o = document.createElement('option');
          o.value = opt.value; o.textContent = opt.label;
          if (opt.value === f.default) o.selected = true;
          input.appendChild(o);
        });
      } else {
        input = document.createElement('input');
        input.type = f.type === 'number' ? 'number' : 'text';
        input.value = f.default || '';
        if (f.placeholder) input.placeholder = f.placeholder;
        if (f.min !== undefined) input.min = f.min;
        if (f.max !== undefined) input.max = f.max;
      }
      input.id = 'mf-' + i;
      wrap.appendChild(input);
      body.appendChild(wrap);
    });
    modal.classList.remove('hidden');
    setTimeout(() => { const first = body.querySelector('input,select'); if (first) first.focus(); }, 50);

    $('modal-confirm').onclick = () => {
      const values = fields.map((f, i) => $('mf-' + i).value);
      modal.classList.add('hidden');
      if (onConfirm) onConfirm(values);
    };
    $('modal-cancel').onclick = () => modal.classList.add('hidden');
  }

  // ===========================================================================
  // Tab rendering
  // ===========================================================================
  const TAB_DEFS = [
    { key: 'debug',  label: 'Debug',  icon: '🐛' },
    { key: 'player', label: 'Joueur', icon: '🧍' },
    { key: 'online', label: 'Online', icon: '👥' },
  ];

  function renderTabs() {
    tabsEl.innerHTML = '';
    TAB_DEFS.forEach(t => {
      const btn = document.createElement('button');
      btn.className = 'tab' + (activeTab === t.key ? ' active' : '');
      btn.innerHTML = `<span class="tab-icon">${t.icon}</span><span>${t.label}</span>`;
      btn.addEventListener('click', () => setTab(t.key));
      tabsEl.appendChild(btn);
    });
  }

  function setTab(key) {
    activeTab = key;
    renderTabs();
    renderBody();
    if (key === 'debug')  fetchNui('refreshDebug', {});
    if (key === 'online') fetchNui('refreshOnline', {});
  }

  // ===========================================================================
  // Body rendering by tab
  // ===========================================================================
  function renderBody() {
    bodyEl.innerHTML = '';
    if (activeTab === 'debug') renderDebug();
    else if (activeTab === 'player') renderPlayer();
    else if (activeTab === 'online') renderOnline();
  }

  function makeOption({ icon, title, desc, aux, type, onClick }) {
    const el = document.createElement('div');
    el.className = 'option' + (type ? ' type-' + type : '');
    el.innerHTML = `
      <div class="option-icon">${icon || '•'}</div>
      <div class="option-content">
        <div class="option-title">${title}</div>
        ${desc ? `<div class="option-desc">${desc}</div>` : ''}
      </div>
      ${aux ? `<div class="option-aux">${aux}</div>` : '<div class="option-arrow">›</div>'}
    `;
    if (onClick) el.addEventListener('click', onClick);
    return el;
  }

  function section(label) {
    const el = document.createElement('div');
    el.className = 'section-header';
    el.textContent = label;
    return el;
  }

  // -------- DEBUG TAB --------
  function renderDebug() {
    const d = state.data.debug || {};
    bodyEl.appendChild(section('Position & ped'));
    bodyEl.appendChild(makeOption({
      icon: '📍', title: 'Coordonnées',
      desc: 'Copier dans la console F8',
      aux: d.coords || '—',
      onClick: () => fetchNui('copyCoords', {}),
    }));
    bodyEl.appendChild(makeOption({
      icon: '🗺️', title: 'Zone GTA',
      desc: d.zone || '—',
    }));
    bodyEl.appendChild(makeOption({
      icon: '🚗', title: 'Véhicule courant',
      desc: d.vehicle || 'Aucun',
    }));
    bodyEl.appendChild(makeOption({
      icon: '⏱️', title: 'Heure / Météo',
      desc: d.time || '—',
    }));

    bodyEl.appendChild(section('Actions'));
    bodyEl.appendChild(makeOption({
      icon: '🎯', title: 'Entité visée', type: 'info',
      desc: 'Pointe ton arme sur une cible',
      onClick: () => fetchNui('aimedEntity', {}),
    }));
    bodyEl.appendChild(makeOption({
      icon: '🚀', title: 'TP au waypoint',
      desc: 'Vers ton GPS marker',
      onClick: () => fetchNui('tpWaypoint', {}),
    }));
    bodyEl.appendChild(makeOption({
      icon: '✈️', title: 'NoClip (toggle)', type: 'warn',
      desc: 'ZQSD · espace=haut · ctrl=bas · shift=x3',
      onClick: () => fetchNui('toggleNoclip', {}),
    }));
    bodyEl.appendChild(makeOption({
      icon: '🧹', title: 'Heal complet',
      desc: 'PV + armure max',
      onClick: () => fetchNui('healSelf', {}),
    }));
  }

  // -------- PLAYER TAB --------
  function renderPlayer() {
    bodyEl.appendChild(section('Économie'));
    bodyEl.appendChild(makeOption({
      icon: '💵', title: '+1 000 $ cash',
      onClick: () => fetchNui('giveMoneySelf', { account: 'cash', amount: 1000 }),
    }));
    bodyEl.appendChild(makeOption({
      icon: '🏦', title: '+10 000 $ bank',
      onClick: () => fetchNui('giveMoneySelf', { account: 'bank', amount: 10000 }),
    }));
    bodyEl.appendChild(makeOption({
      icon: '💰', title: 'Montant custom…',
      desc: 'Demande compte + montant',
      onClick: () => {
        openModal('Donner de l\'argent', [
          { label: 'Compte', type: 'select', default: 'cash',
            options: [{value:'cash',label:'Cash'},{value:'bank',label:'Bank'},{value:'crypto',label:'Crypto'}] },
          { label: 'Montant', type: 'number', default: 1000, min: 1 },
        ], (vals) => {
          fetchNui('giveMoneySelf', { account: vals[0], amount: parseInt(vals[1], 10) || 0 });
        });
      },
    }));

    bodyEl.appendChild(section('Survie'));
    bodyEl.appendChild(makeOption({
      icon: '🍖', title: 'Refill faim / soif',
      onClick: () => fetchNui('refillHungerSelf', {}),
    }));
    bodyEl.appendChild(makeOption({
      icon: '❤️', title: 'Heal complet',
      onClick: () => fetchNui('healSelf', {}),
    }));

    bodyEl.appendChild(section('Inventaire'));
    bodyEl.appendChild(makeOption({
      icon: '📦', title: 'Donner un item…',
      desc: 'Choisir nom + quantité',
      onClick: () => {
        openModal('Donner un item', [
          { label: 'Item', type: 'text', default: 'pain', placeholder: 'pain, eau, telephone, ...' },
          { label: 'Quantité', type: 'number', default: 1, min: 1, max: 999 },
        ], (vals) => {
          fetchNui('giveItemSelf', { item: vals[0], qty: parseInt(vals[1], 10) || 1 });
        });
      },
    }));
  }

  // -------- ONLINE TAB --------
  function renderOnline() {
    const players = state.data.players || [];
    if (players.length === 0) {
      const empty = document.createElement('div');
      empty.style.cssText = 'padding:40px 20px;text-align:center;color:var(--text-mute);font-style:italic;';
      empty.textContent = 'Chargement des joueurs…';
      bodyEl.appendChild(empty);
      return;
    }
    bodyEl.appendChild(section(`${players.length} joueur${players.length > 1 ? 's' : ''} en ligne`));
    players.forEach(p => {
      bodyEl.appendChild(makeOption({
        icon: '🧍', title: `[${p.source}] ${p.name}`,
        desc: `ping ${p.ping || 0}ms · cid=${p.characterId || '—'}`,
        onClick: () => openPlayerActions(p),
      }));
    });
  }

  function openPlayerActions(p) {
    openModal(`Actions sur ${p.name}`, [], () => {});
    const body = $('modal-body');
    body.innerHTML = '';
    const list = [
      { icon:'🚀', label:'TP vers ce joueur',  act: () => fetchNui('tpToPlayer', { target: p.source }) },
      { icon:'💵', label:'+1 000 $ cash',      act: () => fetchNui('giveMoney', { target: p.source, account:'cash', amount: 1000 }) },
      { icon:'🏦', label:'+10 000 $ bank',     act: () => fetchNui('giveMoney', { target: p.source, account:'bank', amount: 10000 }) },
      { icon:'🍖', label:'Refill faim/soif',   act: () => fetchNui('refillHunger', { target: p.source }) },
      { icon:'❤️', label:'Heal',               act: () => fetchNui('heal', { target: p.source }) },
      { icon:'📦', label:'Donner un item…',    act: () => {
        modal.classList.add('hidden');
        openModal(`Donner un item à ${p.name}`, [
          { label:'Item', type:'text', default:'pain' },
          { label:'Quantité', type:'number', default:1, min:1, max:999 },
        ], (vals) => fetchNui('giveItem', { target: p.source, item: vals[0], qty: parseInt(vals[1],10)||1 }));
      }},
    ];
    list.forEach(it => {
      const opt = makeOption({ icon: it.icon, title: it.label, onClick: () => { modal.classList.add('hidden'); it.act(); } });
      opt.style.margin = '0 0 6px';
      body.appendChild(opt);
    });
    // hide default action footer
    $('modal-confirm').style.display = 'none';
    $('modal-cancel').textContent = 'Fermer';
    $('modal-cancel').onclick = () => { $('modal-confirm').style.display = ''; modal.classList.add('hidden'); };
  }

  // ===========================================================================
  // MESSAGE HANDLER
  // ===========================================================================
  window.addEventListener('message', (event) => {
    const data = event.data || {};
    switch (data.action) {
      case 'open':
        if (data.tabs) state.tabs = data.tabs;
        if (data.data) state.data = Object.assign(state.data, data.data);
        if (!activeTab) activeTab = 'debug';
        renderTabs();
        renderBody();
        root.classList.remove('hidden');
        if (activeTab === 'debug')  fetchNui('refreshDebug', {});
        if (activeTab === 'online') fetchNui('refreshOnline', {});
        break;
      case 'close':
        root.classList.add('hidden');
        modal.classList.add('hidden');
        break;
      case 'updateDebug':
        state.data.debug = data.debug;
        if (activeTab === 'debug') renderBody();
        break;
      case 'updateOnline':
        state.data.players = data.players;
        if (activeTab === 'online') renderBody();
        break;
      case 'toast':
        toast(data.text, data.kind, data.duration);
        break;
    }
  });

  // ===========================================================================
  // CLOSE / ESC
  // ===========================================================================
  $('btn-close').addEventListener('click', () => fetchNui('close', {}));
  document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape') {
      if (!modal.classList.contains('hidden')) {
        modal.classList.add('hidden');
        return;
      }
      fetchNui('close', {});
    }
  });
})();
