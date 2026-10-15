(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const root = $('root');
  const overlay = $('overlay');
  const grid = $('grid');

  let catalog = null;
  let qtyMap = {};            // item → quantité courante dans son selector
  let toastHost = null;

  // ===========================================================================
  // Toast (rendu dans cette même NUI, donc au-dessus de tout le reste)
  // ===========================================================================
  function ensureToastHost() {
    if (toastHost) return toastHost;
    toastHost = document.createElement('div');
    toastHost.id = 'toast-host';
    document.body.appendChild(toastHost);
    return toastHost;
  }
  function showToast(text, kind, duration) {
    const host = ensureToastHost();
    if (!text) return;
    duration = duration || 2800;
    const el = document.createElement('div');
    el.className = 'toast toast-' + (kind || 'inform');
    el.textContent = text;
    host.appendChild(el);
    setTimeout(() => {
      el.classList.add('removing');
      setTimeout(() => el.remove(), 200);
    }, duration);
  }

  // ===========================================================================
  // Formatters
  // ===========================================================================
  function formatMoney(n) {
    n = Math.floor(Number(n) || 0);
    return '$' + n.toLocaleString('en-US').replace(/,/g, ' ');
  }
  function formatWeight(g) {
    if (g >= 1000) return (g / 1000).toFixed(2) + ' kg';
    return g + ' g';
  }

  // ===========================================================================
  // Render
  // ===========================================================================
  function applyCatalog(c) {
    catalog = c;
    qtyMap = {};
    root.dataset.theme = c.theme || 'green';
    $('shop-name').textContent = c.label || 'Boutique';
    $('shop-tag').textContent  = `${c.items.length} article${c.items.length > 1 ? 's' : ''} disponible${c.items.length > 1 ? 's' : ''}`;
    $('shop-icon').textContent = themeIcon(c.theme);
    updateBalances(c.balances);
    renderGrid();
  }

  function themeIcon(theme) {
    if (theme === 'green')  return '🛒';
    if (theme === 'blue')   return '📱';
    if (theme === 'orange') return '🔧';
    if (theme === 'red')    return '🔫';
    return '🏪';
  }

  function updateBalances(b) {
    if (!b) return;
    $('bal-cash').textContent = formatMoney(b.cash);
    $('bal-bank').textContent = formatMoney(b.bank);
  }

  function renderGrid() {
    grid.innerHTML = '';
    catalog.items.forEach(it => {
      const qty = qtyMap[it.item] || 1;
      const card = document.createElement('div');
      card.className = 'card';
      const tags = [];
      if (it.unique) tags.push('<span class="tag unique">Unique</span>');
      if (it.weight) tags.push(`<span class="tag">${formatWeight(it.weight)}</span>`);
      if (it.stack && it.stack > 1) tags.push(`<span class="tag">x${it.stack} max</span>`);

      card.innerHTML = `
        <div class="card-top">
          <div class="card-icon">${it.icon || '📦'}</div>
          <div class="card-price">
            <div class="card-price-label">PRIX</div>
            <div class="card-price-value">${formatMoney(it.price)}</div>
          </div>
        </div>
        <div class="card-name">${escapeHtml(it.label)}</div>
        <div class="card-desc">${escapeHtml(it.description || '')}</div>
        <div class="card-meta">${tags.join('')}</div>
        <div class="card-actions">
          <button class="qty-btn" data-act="minus" data-item="${it.item}">−</button>
          <input class="qty-input" data-item="${it.item}" type="text" inputmode="numeric" value="${qty}">
          <button class="qty-btn" data-act="plus" data-item="${it.item}">+</button>
          <button class="buy-btn" data-buy="${it.item}">Acheter</button>
        </div>
      `;
      // For unique items, force qty = 1 and lock
      if (it.unique) {
        card.querySelectorAll('.qty-btn, .qty-input').forEach(el => {
          el.setAttribute('disabled', 'disabled');
          el.style.opacity = '0.5';
          el.style.cursor = 'not-allowed';
        });
        qtyMap[it.item] = 1;
        card.querySelector('.qty-input').value = '1';
      }
      grid.appendChild(card);
    });
  }

  function escapeHtml(s) {
    return String(s || '').replace(/[&<>"']/g, c => ({
      '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'
    })[c]);
  }

  // ===========================================================================
  // Interactions
  // ===========================================================================

  grid.addEventListener('click', async (ev) => {
    const t = ev.target;
    const item = t.dataset.item || t.dataset.buy;
    if (!item) return;
    const maxQty = (catalog && catalog.maxQty) || 50;

    if (t.dataset.act === 'plus' || t.dataset.act === 'minus') {
      const itemDef = catalog.items.find(i => i.item === item);
      if (itemDef && itemDef.unique) return;   // qty locked
      const cap = Math.min(maxQty, itemDef && itemDef.stack ? itemDef.stack : maxQty);
      let q = qtyMap[item] || 1;
      q = t.dataset.act === 'plus' ? q + 1 : q - 1;
      q = Math.max(1, Math.min(cap, q));
      qtyMap[item] = q;
      const input = grid.querySelector(`.qty-input[data-item="${item}"]`);
      if (input) input.value = q;
      return;
    }

    if (t.dataset.buy) {
      const qty = qtyMap[t.dataset.buy] || 1;
      t.disabled = true;
      const res = await fetchNui('purchase', { item: t.dataset.buy, qty });
      t.disabled = false;
      if (res && res.ok) {
        const def = catalog.items.find(i => i.item === res.item) || {};
        showToast(`✓ Acheté ${res.qty}× ${def.label || res.item}  ·  ${formatMoney(res.total)} (${res.payment})`, 'success');
        if (res.balances) updateBalances(res.balances);
      } else {
        showToast('✕ ' + (res && res.error ? res.error : 'Achat échoué'), 'error');
      }
    }
  });

  // Qty input direct
  grid.addEventListener('input', (ev) => {
    if (!ev.target.classList.contains('qty-input')) return;
    const item = ev.target.dataset.item;
    const itemDef = catalog.items.find(i => i.item === item);
    if (!itemDef) return;
    const maxQty = (catalog.maxQty || 50);
    const cap = Math.min(maxQty, itemDef.stack || maxQty);
    let v = parseInt(ev.target.value.replace(/\D/g, ''), 10);
    if (isNaN(v) || v < 1) v = 1;
    if (v > cap) v = cap;
    qtyMap[item] = v;
    ev.target.value = v;
  });

  // Close
  $('btn-close').addEventListener('click', () => fetchNui('close', {}));
  overlay.addEventListener('click', () => fetchNui('close', {}));

  document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape') fetchNui('close', {});
  });

  // ===========================================================================
  // NUI bridge
  // ===========================================================================
  function fetchNui(name, data) {
    const url = `https://${GetParentResourceName ? GetParentResourceName() : 'sl-shops'}/${name}`;
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then(r => r.json()).catch(() => ({}));
  }

  window.addEventListener('message', (event) => {
    const data = event.data || {};
    switch (data.action) {
      case 'open':
        applyCatalog(data.catalog);
        root.classList.remove('hidden');
        break;
      case 'close':
        root.classList.add('hidden');
        break;
    }
  });
})();
