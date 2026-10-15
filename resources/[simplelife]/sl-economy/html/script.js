(() => {
  'use strict';

  // =====================================================================
  // DOM refs
  // =====================================================================
  const $ = (id) => document.getElementById(id);

  const root       = $('atm-root');
  const overlay    = $('atm-overlay');
  const btnClose   = $('btn-close');
  const toastHost  = $('toast-host');

  // Balances
  const balCash    = $('bal-cash');
  const balBank    = $('bal-bank');
  const balCrypto  = $('bal-crypto');

  // Tabs
  const tabs       = document.querySelectorAll('.atm-tab');
  const panels     = document.querySelectorAll('.tab-panel');

  // Depot
  const depositAmount = $('deposit-amount');
  const depositAvail  = $('deposit-avail');
  const depositMax    = $('deposit-max');
  const depositQuick  = $('deposit-quick');
  const btnDeposit    = $('btn-deposit');

  // Retrait
  const withdrawAmount = $('withdraw-amount');
  const withdrawAvail  = $('withdraw-avail');
  const withdrawMax    = $('withdraw-max');
  const withdrawQuick  = $('withdraw-quick');
  const btnWithdraw    = $('btn-withdraw');

  // Virement
  const transferNumber = $('transfer-number');
  const transferAmount = $('transfer-amount');
  const transferAvail  = $('transfer-avail');
  const transferMax    = $('transfer-max');
  const transferReason = $('transfer-reason');
  const btnTransfer    = $('btn-transfer');

  // Historique
  const txList          = $('tx-list');
  const txEmpty         = $('tx-empty');
  const historyFilters  = document.querySelectorAll('.hfilter');

  // =====================================================================
  // State
  // =====================================================================
  let state = {
    cash: 0,
    bank: 0,
    crypto: 0,
    transactions: [],
  };
  let histAccFilter = 'all';
  let isOpen = false;

  const QUICK_AMOUNTS = [100, 500, 1000, 5000, 10000, 50000];

  // =====================================================================
  // Helpers
  // =====================================================================
  function fmtMoney(n) {
    n = Math.floor(Number(n) || 0);
    const neg = n < 0 ? '-' : '';
    const abs = Math.abs(n);
    return neg + abs.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + '$';
  }

  function fetchNui(callback, data) {
    const resourceName = typeof GetParentResourceName === 'function'
      ? GetParentResourceName()
      : 'sl-economy';
    return fetch(`https://${resourceName}/${callback}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then(r => r.json()).catch(() => ({}));
  }

  function clamp(val, min, max) {
    return Math.min(Math.max(val, min), max);
  }

  // =====================================================================
  // Toast
  // =====================================================================
  function showToast(text, kind, duration) {
    if (!text) return;
    duration = Math.max(800, parseInt(duration, 10) || 3500);
    const icons = { success: '✓', error: '✕', inform: 'ℹ' };
    const icon  = icons[kind] || 'ℹ';
    const el = document.createElement('div');
    el.className = 'toast toast-' + (kind || 'inform');
    el.innerHTML = '<span class="toast-icon"></span><span class="toast-text"></span>';
    el.querySelector('.toast-icon').textContent = icon;
    el.querySelector('.toast-text').textContent = text;
    toastHost.appendChild(el);
    setTimeout(() => {
      el.classList.add('removing');
      setTimeout(() => el.remove(), 220);
    }, duration);
  }

  // =====================================================================
  // Tabs
  // =====================================================================
  function switchTab(tabKey) {
    tabs.forEach(t => t.classList.toggle('active', t.dataset.tab === tabKey));
    panels.forEach(p => p.classList.toggle('active', p.id === 'panel-' + tabKey));
    if (tabKey === 'history') loadHistory();
  }

  tabs.forEach(tab => {
    tab.addEventListener('click', () => switchTab(tab.dataset.tab));
  });

  // =====================================================================
  // Balance display
  // =====================================================================
  function refreshBalances() {
    balCash.textContent   = fmtMoney(state.cash);
    balBank.textContent   = fmtMoney(state.bank);
    balCrypto.textContent = fmtMoney(state.crypto);

    depositAvail.textContent  = fmtMoney(state.cash);
    withdrawAvail.textContent = fmtMoney(state.bank);
    transferAvail.textContent = fmtMoney(state.bank);

    if (depositAmount) depositAmount.max = state.cash;
    if (withdrawAmount) withdrawAmount.max = state.bank;
    if (transferAmount) transferAmount.max = state.bank;
  }

  // =====================================================================
  // Quick amounts
  // =====================================================================
  function buildQuick(container, inputEl, maxVal) {
    container.innerHTML = '';
    QUICK_AMOUNTS.forEach(amt => {
      if (amt > maxVal) return;
      const btn = document.createElement('button');
      btn.className = 'quick-btn';
      btn.textContent = fmtMoney(amt);
      btn.addEventListener('click', () => {
        inputEl.value = amt;
      });
      container.appendChild(btn);
    });
  }

  function rebuildQuicks() {
    buildQuick(depositQuick,  depositAmount,  state.cash);
    buildQuick(withdrawQuick, withdrawAmount, state.bank);
  }

  // MAX buttons
  depositMax.addEventListener('click',  () => { depositAmount.value  = state.cash;  });
  withdrawMax.addEventListener('click', () => { withdrawAmount.value = state.bank;  });
  transferMax.addEventListener('click', () => { transferAmount.value = state.bank;  });

  // =====================================================================
  // DEPOT
  // =====================================================================
  btnDeposit.addEventListener('click', async () => {
    const amount = Math.floor(Number(depositAmount.value) || 0);
    if (amount <= 0) { showToast('Montant invalide.', 'error'); return; }
    if (amount > state.cash) { showToast('Liquide insuffisant.', 'error'); return; }

    btnDeposit.disabled = true;
    const res = await fetchNui('atm:deposit', { amount });
    btnDeposit.disabled = false;

    if (res && res.ok) {
      state.cash  = res.newCash  !== undefined ? res.newCash  : Math.max(0, state.cash  - amount);
      state.bank  = res.newBank  !== undefined ? res.newBank  : (state.bank + amount);
      refreshBalances();
      rebuildQuicks();
      depositAmount.value = '';
      showToast('Depot de ' + fmtMoney(amount) + ' effectue.', 'success');
    } else {
      showToast('Erreur : ' + ((res && res.error) || 'depot echoue.'), 'error');
    }
  });

  // =====================================================================
  // RETRAIT
  // =====================================================================
  btnWithdraw.addEventListener('click', async () => {
    const amount = Math.floor(Number(withdrawAmount.value) || 0);
    if (amount <= 0) { showToast('Montant invalide.', 'error'); return; }
    if (amount > state.bank) { showToast('Fonds bancaires insuffisants.', 'error'); return; }

    btnWithdraw.disabled = true;
    const res = await fetchNui('atm:withdraw', { amount });
    btnWithdraw.disabled = false;

    if (res && res.ok) {
      state.cash  = res.newCash  !== undefined ? res.newCash  : (state.cash  + amount);
      state.bank  = res.newBank  !== undefined ? res.newBank  : Math.max(0, state.bank - amount);
      if (res.fee && res.fee > 0) {
        showToast('Retrait ' + fmtMoney(amount) + ' (frais : ' + fmtMoney(res.fee) + ').', 'success');
      } else {
        showToast('Retrait de ' + fmtMoney(amount) + ' effectue.', 'success');
      }
      refreshBalances();
      rebuildQuicks();
      withdrawAmount.value = '';
    } else {
      showToast('Erreur : ' + ((res && res.error) || 'retrait echoue.'), 'error');
    }
  });

  // =====================================================================
  // VIREMENT
  // =====================================================================
  btnTransfer.addEventListener('click', async () => {
    const number = (transferNumber.value || '').trim();
    const amount = Math.floor(Number(transferAmount.value) || 0);
    const reason = (transferReason.value || '').trim();

    if (!number) { showToast('Numero de telephone requis.', 'error'); return; }
    if (amount <= 0) { showToast('Montant invalide.', 'error'); return; }
    if (amount > state.bank) { showToast('Fonds bancaires insuffisants.', 'error'); return; }

    btnTransfer.disabled = true;
    const res = await fetchNui('atm:transfer', { number, amount, reason });
    btnTransfer.disabled = false;

    if (res && res.ok) {
      state.bank = res.newBank !== undefined ? res.newBank : Math.max(0, state.bank - amount);
      refreshBalances();
      rebuildQuicks();
      transferNumber.value = '';
      transferAmount.value = '';
      transferReason.value = '';
      showToast('Virement de ' + fmtMoney(amount) + ' envoye.', 'success');
    } else {
      showToast('Erreur : ' + ((res && res.error) || 'virement echoue.'), 'error');
    }
  });

  // =====================================================================
  // HISTORIQUE
  // =====================================================================
  function renderHistory() {
    const rows = state.transactions || [];
    const filtered = histAccFilter === 'all'
      ? rows
      : rows.filter(r => r.account === histAccFilter);

    txList.innerHTML = '';
    if (filtered.length === 0) {
      const empty = document.createElement('div');
      empty.className = 'tx-empty';
      empty.textContent = 'Aucune transaction.';
      txList.appendChild(empty);
      return;
    }

    filtered.forEach(r => {
      const delta = Number(r.delta) || 0;
      const isPlus = delta >= 0;
      const signClass = isPlus ? 'plus' : 'minus';
      const signChar  = isPlus ? '+' : '';

      const row = document.createElement('div');
      row.className = 'tx-row';

      const sign = document.createElement('div');
      sign.className = 'tx-sign ' + signClass;
      sign.textContent = isPlus ? '+' : '-';

      const info = document.createElement('div');
      info.className = 'tx-info';

      const reason = document.createElement('div');
      reason.className = 'tx-reason';
      reason.textContent = r.reason || 'transaction';

      const meta = document.createElement('div');
      meta.className = 'tx-meta';
      const acct = (r.account || '').toUpperCase();
      const dateStr = r.created_at
        ? new Date(r.created_at).toLocaleString('fr-FR', { day:'2-digit', month:'2-digit', hour:'2-digit', minute:'2-digit' })
        : '';
      meta.textContent = acct + (dateStr ? '  •  ' + dateStr : '');

      info.appendChild(reason);
      info.appendChild(meta);

      const amount = document.createElement('div');
      amount.className = 'tx-amount ' + signClass;
      amount.textContent = signChar + fmtMoney(Math.abs(delta));

      const bal = document.createElement('div');
      bal.className = 'tx-bal';
      if (r.balance_after !== undefined && r.balance_after !== null) {
        bal.textContent = fmtMoney(r.balance_after);
      }

      row.appendChild(sign);
      row.appendChild(info);
      row.appendChild(amount);
      row.appendChild(bal);
      txList.appendChild(row);
    });
  }

  async function loadHistory() {
    txList.innerHTML = '';
    const empty = document.createElement('div');
    empty.className = 'tx-empty';
    empty.textContent = 'Chargement...';
    txList.appendChild(empty);

    const res = await fetchNui('atm:transactions', { limit: 50 });
    state.transactions = Array.isArray(res) ? res : [];
    renderHistory();
  }

  historyFilters.forEach(btn => {
    btn.addEventListener('click', () => {
      historyFilters.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      histAccFilter = btn.dataset.acc || 'all';
      renderHistory();
    });
  });

  // =====================================================================
  // OPEN / CLOSE
  // =====================================================================
  function openWindow(data) {
    if (data) {
      state.cash   = Number(data.cash   || 0);
      state.bank   = Number(data.bank   || 0);
      state.crypto = Number(data.crypto || 0);
    }
    refreshBalances();
    rebuildQuicks();
    depositAmount.value  = '';
    withdrawAmount.value = '';
    transferNumber.value = '';
    transferAmount.value = '';
    transferReason.value = '';
    switchTab('deposit');
    histAccFilter = 'all';
    historyFilters.forEach(b => b.classList.toggle('active', b.dataset.acc === 'all'));
    state.transactions = [];

    isOpen = true;
    root.classList.remove('hidden');
  }

  function closeWindow() {
    if (!isOpen) return;
    isOpen = false;
    root.classList.add('hidden');
    fetchNui('atm:close', {});
  }

  // =====================================================================
  // NUI MESSAGES
  // =====================================================================
  window.addEventListener('message', (ev) => {
    const data = ev.data || {};
    switch (data.action) {
      case 'open':
        openWindow(data.balances || data.state || null);
        break;
      case 'close':
        root.classList.add('hidden');
        isOpen = false;
        break;
      case 'balances':
        if (data.balances) {
          state.cash   = Number(data.balances.cash   || 0);
          state.bank   = Number(data.balances.bank   || 0);
          state.crypto = Number(data.balances.crypto || 0);
          refreshBalances();
          rebuildQuicks();
        }
        break;
      case 'toast':
        showToast(data.text, data.type, data.duration);
        break;
    }
  });

  // =====================================================================
  // ESC / Close
  // =====================================================================
  btnClose.addEventListener('click', closeWindow);
  overlay.addEventListener('click', closeWindow);
  document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape') closeWindow();
  });

})();
