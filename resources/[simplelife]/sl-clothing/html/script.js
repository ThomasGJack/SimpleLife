(() => {
  'use strict';

  const RESOURCE = 'sl-clothing';

  const $ = (id) => document.getElementById(id);
  const app = $('app');
  const elTabs = $('tabs');
  const elCatName = $('cat-name');
  const elCatCount = $('cat-count');
  const elItemsList = $('items-list');
  const elCompatRow = $('compat-row');
  const elCompatCheck = $('compat-check');
  const elCompatLabel = $('compat-label');
  const elPresetsList = $('presets-list');
  const elTotalAmount = $('total-amount');
  const elCartItems = $('cart-items');
  const elCartCount = $('cart-count');
  const elBtnBuy = $('btn-buy');
  const elBtnCancel = $('btn-cancel');
  const elBtnEsc = $('btn-esc');
  const elVariationNum = $('variation-num');
  const elPrevTex = $('prev-tex');
  const elNextTex = $('next-tex');
  const elCamRotate = $('cam-rotate');
  const elCamZoomIn = $('cam-zoom-in');
  const elCamZoomOut = $('cam-zoom-out');

  let state = {
    open: false,
    appearance: null,
    categories: [],
    drawables: { components: {}, props: {} },
    presets: [],
    selected: null,
    current: { drawable: 0, texture: 0 },
    cart: {},
    camRotating: true,
    compatOnly: false,
    lastAutoTorso: null,
  };

  function postLua(action, payload) {
    fetch(`https://${RESOURCE}/${action}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload || {}),
    }).catch(() => {});
  }

  function moneyFormat(n) {
    n = Math.floor(Number(n) || 0);
    return n.toLocaleString('fr-FR').replace(/\s/g, ' ') + ' $';
  }

  function getDrawableList(kind, id) {
    const map = kind === 'component' ? state.drawables.components : state.drawables.props;
    return map[id] || map[String(id)] || map[Number(id)] || [];
  }

  function renderTabs() {
    elTabs.innerHTML = '';
    state.categories.forEach(cat => {
      const btn = document.createElement('button');
      btn.className = 'tab';
      btn.dataset.key = cat.key;
      btn.textContent = cat.label;
      btn.addEventListener('click', () => selectCategory(cat));
      elTabs.appendChild(btn);
    });
  }

  function selectCategory(cat) {
    state.selected = { kind: cat.kind, id: cat.id, label: cat.label, price: cat.price, key: cat.key };
    state.lastAutoTorso = null;

    document.querySelectorAll('.tab').forEach(t => {
      t.classList.toggle('active', t.dataset.key === cat.key);
    });

    elCatName.textContent = cat.label;

    const slot = state.appearance
      && (cat.kind === 'component' ? state.appearance.components : state.appearance.props)
      && (state.appearance[cat.kind === 'component' ? 'components' : 'props'][cat.id]);
    const def = slot || { drawable: cat.kind === 'prop' ? -1 : 0, texture: 0 };
    state.current.drawable = def.drawable != null ? def.drawable : 0;
    state.current.texture = def.texture || 0;

    const isJacket = cat.id === 11 && cat.kind === 'component';
    elCompatRow.classList.toggle('show', isJacket);
    elCompatLabel.textContent = isJacket
      ? 'Vestes compatibles uniquement'
      : 'Cacher les invalides';

    renderItems();
    updateVariation();
  }

  function renderItems() {
    if (!state.selected) { elItemsList.innerHTML = ''; return; }
    elItemsList.innerHTML = '';
    let list = getDrawableList(state.selected.kind, state.selected.id);
    const isJacket = state.selected.id === 11 && state.selected.kind === 'component';
    if (state.compatOnly) {
      if (isJacket) list = list.filter(x => x.compatible === true);
      else list = list.filter(x => x.valid !== false || x.drawable === -1);
    }
    elCatCount.textContent = `${list.length} / ${getDrawableList(state.selected.kind, state.selected.id).length}`;

    list.forEach(item => {
      const div = document.createElement('div');
      div.className = 'item';
      if (item.drawable === state.current.drawable) div.classList.add('active');
      if (item.valid === false) div.classList.add('invalid');
      if (isJacket && item.compatible === false) div.classList.add('incompat');
      const cartKey = state.selected.kind + ':' + state.selected.id;
      if (state.cart[cartKey] && state.cart[cartKey].drawable === item.drawable) div.classList.add('in-cart');

      let mark = '';
      if (isJacket) {
        mark = item.compatible === true ? '<span class="item-mark compat">✓</span>'
          : (item.compatible === false ? '<span class="item-mark incompat">✗</span>' : '');
      } else if (item.valid === false) {
        mark = '<span class="item-mark incompat">⚠</span>';
      }

      const name = item.drawable === -1
        ? 'Aucun'
        : `${state.selected.label} ${item.drawable}`;

      div.innerHTML = `
        <div class="item-name">${mark}${name}</div>
        <div class="item-price">${moneyFormat(state.selected.price)}</div>
      `;
      div.addEventListener('click', () => {
        state.current.drawable = item.drawable;
        state.current.texture = 0;
        pushPreview();
        renderItems();
        updateVariation();
      });
      elItemsList.appendChild(div);
    });
  }

  function updateVariation() {
    if (!state.selected) return;
    const list = getDrawableList(state.selected.kind, state.selected.id);
    const cur = list.find(x => x.drawable === state.current.drawable);
    const max = cur ? cur.textures : 0;
    elVariationNum.textContent = `#${state.current.texture} / ${max}`;
  }

  function changeTexture(dir) {
    if (!state.selected) return;
    const list = getDrawableList(state.selected.kind, state.selected.id);
    const cur = list.find(x => x.drawable === state.current.drawable);
    if (!cur) return;
    const max = cur.textures;
    state.current.texture += dir;
    if (state.current.texture < 0) state.current.texture = max;
    if (state.current.texture > max) state.current.texture = 0;
    pushPreview();
    updateVariation();
  }

  function pushPreview() {
    if (!state.selected) return;
    postLua('preview', {
      kind: state.selected.kind,
      id: state.selected.id,
      drawable: state.current.drawable,
      texture: state.current.texture,
    });
    addToCart();
  }

  function renderPresets() {
    elPresetsList.innerHTML = '';
    if (state.presets.length === 0) {
      elPresetsList.innerHTML = '<div class="cart-empty">Aucune tenue prête</div>';
      return;
    }
    state.presets.forEach(p => {
      const div = document.createElement('div');
      div.className = 'preset';
      div.innerHTML = `
        <div class="preset-name">${p.label}</div>
        <div class="preset-price">${moneyFormat(p.price)}</div>
      `;
      div.addEventListener('click', () => applyPreset(p));
      elPresetsList.appendChild(div);
    });
  }

  function applyPreset(preset) {
    postLua('applyPreset', { components: preset.components, props: preset.props });
    Object.entries(preset.components || {}).forEach(([id, v]) => {
      const idNum = Number(id);
      const cat = state.categories.find(c => c.kind === 'component' && c.id === idNum);
      if (!cat) return;
      state.cart['component:' + idNum] = {
        kind: 'component', id: idNum, drawable: v.drawable, texture: v.texture || 0,
        price: cat.price, label: cat.label + ' (' + preset.label + ')',
      };
    });
    Object.entries(preset.props || {}).forEach(([id, v]) => {
      const idNum = Number(id);
      const cat = state.categories.find(c => c.kind === 'prop' && c.id === idNum);
      if (!cat) return;
      state.cart['prop:' + idNum] = {
        kind: 'prop', id: idNum, drawable: v.drawable, texture: v.texture || 0,
        price: v.drawable === -1 ? 0 : cat.price,
        label: cat.label + ' (' + preset.label + ')',
      };
    });
    renderCart();
    renderItems();
  }

  function addToCart() {
    if (!state.selected) return;
    const key = state.selected.kind + ':' + state.selected.id;
    const entry = {
      kind: state.selected.kind,
      id: state.selected.id,
      drawable: state.current.drawable,
      texture: state.current.texture,
      price: state.selected.price,
      label: `${state.selected.label} ${state.current.drawable} - #${state.current.texture}`,
    };
    if (state.selected.id === 11 && state.selected.kind === 'component' && state.lastAutoTorso) {
      entry.autoTorso = {
        drawable: state.lastAutoTorso.drawable,
        texture: state.lastAutoTorso.texture || 0,
      };
    }
    if (state.selected.kind === 'prop' && state.current.drawable === -1) {
      entry.price = 0;
      entry.label = `${state.selected.label} retiré`;
    }
    state.cart[key] = entry;
    renderCart();
  }

  function renderCart() {
    const items = Object.values(state.cart);
    elCartCount.textContent = items.length;
    if (items.length === 0) {
      elCartItems.innerHTML = '<div class="cart-empty">Sélectionne un article à gauche</div>';
      elTotalAmount.textContent = '0 $';
      elBtnBuy.disabled = true;
      return;
    }
    elCartItems.innerHTML = items.map(it => `
      <div class="cart-item">
        <span class="cart-item-name">${it.label}</span>
        <span class="cart-item-price">${moneyFormat(it.price)}</span>
      </div>
    `).join('');
    const total = items.reduce((s, it) => s + (it.price || 0), 0);
    elTotalAmount.textContent = moneyFormat(total);
    elBtnBuy.disabled = false;
  }

  function open(payload) {
    state.open = true;
    state.appearance = payload.appearance;
    state.categories = payload.categories || [];
    state.drawables = payload.drawables || { components: {}, props: {} };
    state.presets = payload.presets || [];
    state.cart = {};
    state.selected = null;
    state.lastAutoTorso = null;
    state.compatOnly = false;
    elCompatCheck.checked = false;
    state.camRotating = payload.camRotating !== false;
    elCamRotate.classList.toggle('active', state.camRotating);
    renderTabs();
    renderPresets();
    renderCart();
    if (state.categories.length > 0) selectCategory(state.categories[0]);
    app.classList.remove('hidden');
  }

  function close() {
    state.open = false;
    app.classList.add('hidden');
  }

  elBtnEsc.addEventListener('click', () => postLua('cancel'));
  elBtnCancel.addEventListener('click', () => postLua('cancel'));
  elBtnBuy.addEventListener('click', () => {
    const changes = Object.values(state.cart);
    postLua('validate', { changes });
  });
  elPrevTex.addEventListener('click', () => changeTexture(-1));
  elNextTex.addEventListener('click', () => changeTexture(1));
  elCompatCheck.addEventListener('change', (e) => {
    state.compatOnly = e.target.checked;
    renderItems();
  });
  elCamRotate.addEventListener('click', () => {
    state.camRotating = !state.camRotating;
    elCamRotate.classList.toggle('active', state.camRotating);
    postLua('camRotate', { active: state.camRotating });
  });
  elCamZoomIn.addEventListener('click', () => postLua('camZoom', { delta: -0.25 }));
  elCamZoomOut.addEventListener('click', () => postLua('camZoom', { delta: 0.25 }));

  document.addEventListener('keydown', (e) => {
    if (!state.open) return;
    if (e.key === 'Escape') postLua('cancel');
    else if (e.key === 'ArrowLeft') changeTexture(-1);
    else if (e.key === 'ArrowRight') changeTexture(1);
  });

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;
    switch (data.action) {
      case 'open': open(data); break;
      case 'close': close(); break;
      case 'autoApplied':
        if (state.selected && state.selected.id === 11 && state.selected.kind === 'component') {
          if (data.compatible === false) {
            state.lastAutoTorso = null;
          } else {
            state.lastAutoTorso = { drawable: data.drawable, texture: data.texture };
          }
        }
        break;
    }
  });
})();
