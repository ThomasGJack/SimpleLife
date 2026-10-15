(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);

  // ===========================================================================
  // STATE
  // ===========================================================================
  let state = {
    number: '',
    contacts: [],
    conversations: [],
    recentCalls: [],
    unread: 0,
    apps: [],
  };

  let currentScreen = 'home';
  let activeChatPeer = null;    // raw number de l'interlocuteur courant
  let dialerDigits = '';
  let currentCall  = null;      // { status, peer }
  let callTimerInt = null;

  // New-apps state
  let bankLoaded          = false;
  let socialComposeOpen   = false;
  let emergencyService    = 'police';
  let emergencyHistory    = []; // { service, message, time }[]

  // ===========================================================================
  // UTILS
  // ===========================================================================
  function formatNumber(raw) {
    if (!raw) return '';
    const d = String(raw).replace(/\D/g, '');
    if (d.length === 10) return `(${d.slice(0,3)}) ${d.slice(3,6)}-${d.slice(6,10)}`;
    if (d.length === 7)  return `${d.slice(0,3)}-${d.slice(3,7)}`;
    return d;
  }

  function normalize(raw) {
    return String(raw || '').replace(/\D/g, '');
  }

  function nameForNumber(raw) {
    const n = normalize(raw);
    const c = state.contacts.find(c => normalize(c.number) === n);
    return c ? c.name : null;
  }

  function fmtTime(timestamp) {
    if (!timestamp) return '';
    const d = (typeof timestamp === 'string') ? new Date(timestamp) : new Date(timestamp * 1000);
    if (isNaN(d.getTime())) return '';
    const now = new Date();
    const sameDay = d.toDateString() === now.toDateString();
    const yest = new Date(now); yest.setDate(now.getDate() - 1);
    const isYesterday = d.toDateString() === yest.toDateString();
    if (sameDay) {
      return d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
    }
    if (isYesterday) return 'Hier';
    return d.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });
  }

  function fmtDuration(sec) {
    sec = Math.max(0, Math.floor(sec || 0));
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    return `${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
  }

  function initial(label) {
    if (!label) return '?';
    const cleaned = String(label).trim();
    if (!cleaned) return '?';
    const parts = cleaned.split(/\s+/);
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return cleaned.slice(0, 2).toUpperCase();
  }

  // ===========================================================================
  // SCREENS ROUTER
  // ===========================================================================
  function showScreen(name) {
    currentScreen = name;
    document.querySelectorAll('.screen').forEach(s => {
      s.classList.toggle('active', s.dataset.screen === name);
    });
  }

  // ===========================================================================
  // HOME RENDER
  // ===========================================================================
  function renderHome() {
    const now = new Date();
    $('home-time').textContent = now.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
    $('home-date').textContent = now.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });
    $('status-time').textContent = now.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
    $('home-number-value').textContent = formatNumber(state.number) || '--';

    const grid = $('apps-grid');
    grid.innerHTML = '';
    (state.apps || []).forEach(app => {
      const tile = document.createElement('div');
      tile.className = 'app-tile';
      tile.dataset.app = app.key;
      const badge = (app.key === 'messages' && state.unread > 0)
        ? `<div class="app-tile-badge">${state.unread > 99 ? '99+' : state.unread}</div>` : '';
      tile.innerHTML = `
        <div class="app-tile-icon" data-app="${app.key}">${app.icon}${badge}</div>
        <div class="app-tile-label">${app.label}</div>
      `;
      tile.addEventListener('click', () => openApp(app.key));
      grid.appendChild(tile);
    });
  }

  function openApp(key) {
    if      (key === 'messages')  { renderMessages(); showScreen('messages'); }
    else if (key === 'contacts')  { renderContacts(); showScreen('contacts'); }
    else if (key === 'phone')     { renderRecents(); dialerDigits = ''; updateDialer(); showScreen('phone'); }
    else if (key === 'settings')  { renderSettings(); showScreen('settings'); }
    else if (key === 'bank')      { openBankApp(); }
    else if (key === 'social')    { openSocialApp(); }
    else if (key === 'market')    { openMarketApp(); }
    else if (key === 'emergency') { openEmergencyApp(); }
  }

  // ===========================================================================
  // MESSAGES (conv list)
  // ===========================================================================
  function renderMessages() {
    const list = $('conv-list');
    const empty = $('conv-empty');
    list.innerHTML = '';
    const convs = state.conversations || [];
    if (convs.length === 0) {
      empty.classList.add('active');
      return;
    }
    empty.classList.remove('active');
    convs.forEach(c => {
      const name = nameForNumber(c.peer_number) || formatNumber(c.peer_number);
      const preview = (c.last_outgoing ? 'Vous : ' : '') + (c.last_body || '');
      const item = document.createElement('div');
      item.className = 'conv-item';
      item.innerHTML = `
        <div class="conv-avatar">${initial(nameForNumber(c.peer_number) || c.peer_number)}</div>
        <div class="conv-main">
          <div class="conv-name">${name}</div>
          <div class="conv-preview">${preview}</div>
        </div>
        <div class="conv-meta">
          <div class="conv-time">${fmtTime(c.last_at)}</div>
          ${c.unread > 0 ? `<div class="conv-unread">${c.unread}</div>` : ''}
        </div>
      `;
      item.addEventListener('click', () => openChat(c.peer_number));
      list.appendChild(item);
    });
  }

  // ===========================================================================
  // CHAT
  // ===========================================================================
  async function openChat(peerNumber) {
    activeChatPeer = normalize(peerNumber);
    const name = nameForNumber(activeChatPeer) || formatNumber(activeChatPeer);
    $('chat-peer-name').textContent = name;
    $('chat-peer-number').textContent = formatNumber(activeChatPeer);
    $('chat-input').value = '';
    showScreen('chat');
    $('chat-messages').innerHTML = '<div class="msg-time">Chargement…</div>';
    const res = await fetchNui('getMessages', { peer: activeChatPeer });
    renderChat(res && res.messages ? res.messages : []);
    // Marquer comme lu localement
    state.unread = Math.max(0, state.unread - ((state.conversations.find(c => normalize(c.peer_number) === activeChatPeer) || {}).unread || 0));
    setTimeout(() => $('chat-input').focus(), 100);
  }

  function renderChat(messages) {
    const box = $('chat-messages');
    box.innerHTML = '';
    let lastDate = null;
    messages.forEach(m => {
      const d = new Date(m.created_at);
      const dateKey = d.toDateString();
      if (dateKey !== lastDate) {
        const sep = document.createElement('div');
        sep.className = 'msg-time';
        sep.textContent = d.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });
        box.appendChild(sep);
        lastDate = dateKey;
      }
      const bub = document.createElement('div');
      bub.className = 'msg-bubble ' + (m.outgoing ? 'outgoing' : 'incoming');
      bub.textContent = m.body;
      box.appendChild(bub);
    });
    box.scrollTop = box.scrollHeight;
  }

  async function sendCurrentMessage() {
    const input = $('chat-input');
    const body = input.value.trim();
    if (!body || !activeChatPeer) return;
    input.value = '';
    const res = await fetchNui('sendSMS', { to: activeChatPeer, body });
    if (res && res.ok) {
      // Recharge la conv pour voir le message envoyé immédiatement
      const msgs = await fetchNui('getMessages', { peer: activeChatPeer });
      renderChat(msgs && msgs.messages ? msgs.messages : []);
    } else {
      showToast(res && res.error ? res.error : 'Échec envoi', 'error');
    }
  }

  // ===========================================================================
  // CONTACTS
  // ===========================================================================
  function renderContacts() {
    const list = $('contacts-list');
    const empty = $('contacts-empty');
    list.innerHTML = '';
    const contacts = state.contacts || [];
    if (contacts.length === 0) {
      empty.classList.add('active');
      return;
    }
    empty.classList.remove('active');
    contacts.forEach(c => {
      const item = document.createElement('div');
      item.className = 'contact-item';
      item.innerHTML = `
        <div class="contact-avatar">${initial(c.name)}</div>
        <div class="contact-info">
          <div class="contact-name">${c.name}${c.favorite ? ' <span class="contact-fav active">★</span>' : ''}</div>
          <div class="contact-number">${formatNumber(c.number)}</div>
        </div>
        <div class="contact-actions">
          <button class="contact-action" data-action="sms" title="Message">💬</button>
          <button class="contact-action" data-action="call" title="Appeler">📞</button>
        </div>
      `;
      item.querySelector('[data-action="sms"]').addEventListener('click', (e) => {
        e.stopPropagation();
        openChat(c.number);
      });
      item.querySelector('[data-action="call"]').addEventListener('click', (e) => {
        e.stopPropagation();
        ringPeer(c.number);
      });
      item.addEventListener('click', () => openContactEdit(c));
      list.appendChild(item);
    });
  }

  function openContactNew() {
    openModalContact({ name: '', number: '', favorite: false }, null);
  }
  function openContactEdit(contact) {
    openModalContact(contact, contact.id);
  }

  function openModalContact(contact, id) {
    $('modal-title').textContent = id ? 'Modifier contact' : 'Nouveau contact';
    $('modal-body').innerHTML = `
      <label>Nom</label>
      <input type="text" id="m-name" maxlength="64" value="${contact.name || ''}">
      <label>Numéro</label>
      <input type="tel" id="m-number" inputmode="tel" placeholder="(555) 123-4567" value="${formatNumber(contact.number) || ''}">
      <div class="check-row">
        <span>Favori</span>
        <input type="checkbox" id="m-fav" ${contact.favorite ? 'checked' : ''}>
      </div>
    `;
    const actions = document.querySelector('.modal-actions');
    actions.innerHTML = `
      <button class="btn-ghost" id="modal-cancel">Annuler</button>
      ${id ? '<button class="btn-danger" id="modal-delete">Suppr.</button>' : ''}
      <button class="btn-primary" id="modal-confirm">${id ? 'Enregistrer' : 'Créer'}</button>
    `;
    document.getElementById('modal-cancel').onclick = closeModal;
    document.getElementById('modal-confirm').onclick = async () => {
      const name = document.getElementById('m-name').value.trim();
      const number = normalize(document.getElementById('m-number').value);
      const fav = document.getElementById('m-fav').checked;
      if (!name || number.length < 10) {
        showToast('Nom et numéro requis (10 chiffres)', 'error'); return;
      }
      let res;
      if (id) {
        res = await fetchNui('updateContact', { id, name, number, favorite: fav });
      } else {
        res = await fetchNui('addContact', { name, number });
      }
      if (res && res.ok) {
        closeModal();
        await refresh();
        renderContacts();
      } else {
        showToast(res && res.error ? res.error : 'Échec', 'error');
      }
    };
    if (id) {
      document.getElementById('modal-delete').onclick = async () => {
        const res = await fetchNui('deleteContact', { id });
        if (res && res.ok) {
          closeModal();
          await refresh();
          renderContacts();
        }
      };
    }
    $('modal').classList.remove('hidden');
    setTimeout(() => document.getElementById('m-name').focus(), 50);
  }

  function closeModal() { $('modal').classList.add('hidden'); }

  // ===========================================================================
  // NEW CONVERSATION
  // ===========================================================================
  function openNewConv() {
    $('modal-title').textContent = 'Nouvelle conversation';
    $('modal-body').innerHTML = `
      <label>Numéro du destinataire</label>
      <input type="tel" id="m-conv-num" inputmode="tel" placeholder="(555) 123-4567">
    `;
    const actions = document.querySelector('.modal-actions');
    actions.innerHTML = `
      <button class="btn-ghost" id="modal-cancel">Annuler</button>
      <button class="btn-primary" id="modal-confirm">Discuter</button>
    `;
    document.getElementById('modal-cancel').onclick = closeModal;
    document.getElementById('modal-confirm').onclick = () => {
      const number = normalize(document.getElementById('m-conv-num').value);
      if (number.length < 10) { showToast('Numéro invalide', 'error'); return; }
      closeModal();
      openChat(number);
    };
    $('modal').classList.remove('hidden');
    setTimeout(() => document.getElementById('m-conv-num').focus(), 50);
  }

  // ===========================================================================
  // PHONE (dialer + recents)
  // ===========================================================================
  function updateDialer() {
    $('dialer-display').textContent = formatNumber(dialerDigits) || (dialerDigits.length ? dialerDigits : ' ');
    document.getElementById('dialer-call').disabled = (dialerDigits.length < 10);
  }

  function dialerAddDigit(d) {
    if (dialerDigits.length >= 10) return;
    dialerDigits += d;
    updateDialer();
  }
  function dialerBackspace() {
    dialerDigits = dialerDigits.slice(0, -1);
    updateDialer();
  }

  function renderRecents() {
    const list = $('recents-list');
    const empty = $('recents-empty');
    list.innerHTML = '';
    const calls = state.recentCalls || [];
    if (calls.length === 0) {
      empty.classList.add('active');
      return;
    }
    empty.classList.remove('active');
    calls.forEach(c => {
      const isMissed = (c.status === 'missed' || c.status === 'declined');
      const dirCls = isMissed ? 'missed' : (c.outgoing ? 'outgoing' : 'incoming');
      const dirArrow = c.outgoing ? '↗' : '↙';
      const item = document.createElement('div');
      item.className = 'recent-item';
      const name = nameForNumber(c.peer_number) || formatNumber(c.peer_number);
      item.innerHTML = `
        <div class="recent-icon ${dirCls}">${dirArrow}</div>
        <div class="recent-info">
          <div class="recent-number">${name}</div>
          <div class="recent-meta">${labelForStatus(c.status, c.duration_sec, c.outgoing)}</div>
        </div>
        <div class="recent-time">${fmtTime(c.created_at)}</div>
      `;
      item.addEventListener('click', () => {
        dialerDigits = normalize(c.peer_number);
        showScreen('phone');
        document.querySelectorAll('.phone-tab').forEach(t => t.classList.toggle('active', t.dataset.tab === 'dialer'));
        document.querySelectorAll('.phone-tab-body').forEach(b => b.classList.toggle('active', b.dataset.tabBody === 'dialer'));
        updateDialer();
      });
      list.appendChild(item);
    });
  }

  function labelForStatus(status, duration, outgoing) {
    if (status === 'missed')   return 'Manqué';
    if (status === 'declined') return outgoing ? 'Refusé par l\'autre' : 'Refusé';
    if (status === 'ended')    return outgoing ? 'Appel sortant · ' + fmtDuration(duration) : 'Appel · ' + fmtDuration(duration);
    return status;
  }

  // ===========================================================================
  // SETTINGS
  // ===========================================================================
  function renderSettings() {
    $('settings-number').textContent = formatNumber(state.number) || '--';
  }

  // ===========================================================================
  // CALL screen logic
  // ===========================================================================
  function showCallScreen(payload) {
    currentCall = payload;
    document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
    $('call-status').textContent = ({
      outgoing: 'Appel sortant…',
      incoming: 'Appel entrant',
      inCall:   'En cours',
      ended:    'Terminé',
    })[payload.status] || payload.status;
    $('call-peer').textContent = nameForNumber(payload.peer) || formatNumber(payload.peer);

    const actions = $('call-actions');
    actions.innerHTML = '';
    if (payload.status === 'incoming') {
      actions.innerHTML = `
        <button class="call-action-btn decline" id="ca-decline">✕</button>
        <button class="call-action-btn answer" id="ca-answer">📞</button>
      `;
      document.getElementById('ca-answer').onclick  = () => fetchNui('answerCall', {});
      document.getElementById('ca-decline').onclick = () => fetchNui('declineCall', {});
    } else if (payload.status === 'outgoing' || payload.status === 'inCall') {
      actions.innerHTML = `
        <button class="call-action-btn hangup" id="ca-hangup">📵</button>
      `;
      document.getElementById('ca-hangup').onclick = () => fetchNui('hangup', {});
    }

    if (callTimerInt) { clearInterval(callTimerInt); callTimerInt = null; }
    if (payload.status === 'inCall') {
      const start = Date.now();
      $('call-timer').textContent = '00:00';
      callTimerInt = setInterval(() => {
        const sec = Math.floor((Date.now() - start) / 1000);
        $('call-timer').textContent = fmtDuration(sec);
      }, 1000);
    } else if (payload.status === 'outgoing') {
      $('call-timer').textContent = 'Sonnerie…';
    } else if (payload.status === 'incoming') {
      $('call-timer').textContent = 'Décrochez ?';
    }

    $('phone').classList.add('open');
    $('phone').classList.remove('hidden');
    document.querySelector('[data-screen="call"]').classList.add('active');
  }

  function endCall(reason) {
    if (callTimerInt) { clearInterval(callTimerInt); callTimerInt = null; }
    if (currentCall) {
      const msg = ({
        'hangup': 'Vous avez raccroché.',
        'peer-hangup': 'Appel terminé.',
        'declined': 'Appel refusé.',
        'missed': 'Appel manqué.',
        'no-answer': 'Pas de réponse.',
      })[reason] || 'Appel terminé.';
      showToast(msg, reason === 'declined' || reason === 'missed' ? 'error' : 'inform');
    }
    currentCall = null;
    document.querySelector('[data-screen="call"]').classList.remove('active');
    showScreen(currentScreen || 'home');
    refresh();
  }

  async function ringPeer(numberRaw) {
    const number = normalize(numberRaw);
    if (number.length < 10) { showToast('Numéro invalide', 'error'); return; }
    const res = await fetchNui('ringPeer', { number });
    if (!res || !res.ok) {
      showToast(res && res.error ? res.error : 'Appel impossible', 'error');
    }
  }

  // ===========================================================================
  // BANQUE MOBILE
  // ===========================================================================

  async function openBankApp() {
    showScreen('bank');
    const balancesEl = $('bank-balances');
    balancesEl.innerHTML = '<div style="padding:20px;text-align:center;color:var(--text-2);">Chargement…</div>';
    const res = await fetchNui('bankBalances', {});
    if (!res || !res.ok) {
      balancesEl.innerHTML = '<div style="padding:20px;text-align:center;color:var(--red);">' + (res && res.error ? res.error : 'Erreur') + '</div>';
      return;
    }
    const bals = res.balances || {};
    balancesEl.innerHTML = '';
    const labels = { cash: 'Especes', bank: 'Banque', crypto: 'Crypto' };
    const classes = { cash: 'cash', bank: 'bank', crypto: 'crypto' };
    const accounts = ['cash', 'bank', 'crypto'];
    accounts.forEach(acc => {
      const val = bals[acc];
      if (val === undefined && acc !== 'cash') return;
      const card = document.createElement('div');
      card.className = 'bank-card';
      card.innerHTML = `
        <div class="bank-card-label">${labels[acc] || acc}</div>
        <div class="bank-card-amount ${classes[acc] || ''}">$${Number(val || 0).toLocaleString('fr-FR')}</div>
      `;
      balancesEl.appendChild(card);
    });
  }

  $('bank-transfer-btn').addEventListener('click', async () => {
    const toNumber = normalize($('bank-to-number').value);
    const account  = $('bank-account').value;
    const amount   = parseInt($('bank-amount').value, 10);
    const reason   = $('bank-reason').value.trim() || 'Virement';
    if (toNumber.length < 10) { showToast('Numéro invalide', 'error'); return; }
    if (!amount || amount <= 0) { showToast('Montant invalide', 'error'); return; }
    const btn = $('bank-transfer-btn');
    btn.disabled = true;
    const res = await fetchNui('bankTransfer', { toNumber, account, amount, reason });
    btn.disabled = false;
    if (res && res.ok) {
      showToast('Virement effectué', 'success');
      $('bank-to-number').value = '';
      $('bank-amount').value = '';
      $('bank-reason').value = '';
      openBankApp(); // reload balances
    } else {
      showToast(res && res.error ? res.error : 'Erreur', 'error');
    }
  });

  // ===========================================================================
  // RESEAU SOCIAL
  // ===========================================================================

  async function openSocialApp() {
    socialComposeOpen = false;
    $('social-compose-bar').style.display = 'none';
    showScreen('social');
    await loadSocialFeed();
  }

  async function loadSocialFeed() {
    const feed = $('social-feed');
    feed.innerHTML = '<div style="padding:20px;text-align:center;color:var(--text-2);">Chargement…</div>';
    const res = await fetchNui('social:getFeed', {});
    feed.innerHTML = '';
    if (!res || !res.ok) {
      feed.innerHTML = '<div style="padding:20px;text-align:center;color:var(--text-2);">Erreur de chargement</div>';
      return;
    }
    const posts = res.posts || [];
    if (posts.length === 0) {
      feed.innerHTML = '<div style="padding:40px;text-align:center;color:var(--text-2);">Aucun post pour le moment.</div>';
      return;
    }
    posts.forEach(p => {
      const el = document.createElement('div');
      el.className = 'social-post';
      const authorDisplay = formatNumber(p.author_number);
      const imgHtml = p.image
        ? `<img class="social-post-image" src="${escapeHtml(p.image)}" alt="image" onerror="this.style.display='none'">`
        : '';
      const deleteBtn = p.is_mine
        ? `<button class="social-post-delete" data-id="${p.id}" title="Supprimer">&#128465;</button>`
        : '';
      el.innerHTML = `
        <div class="social-post-header">
          <div class="social-avatar">${initial(p.author_number)}</div>
          <div class="social-author">
            <div class="social-author-number">${authorDisplay}</div>
            <div class="social-post-time">${fmtTime(p.created_at)}</div>
          </div>
          ${deleteBtn}
        </div>
        ${imgHtml}
        <div class="social-post-body">${escapeHtml(p.body)}</div>
        <div class="social-post-footer">
          <button class="social-like-btn" data-post-id="${p.id}">&#10084; <span>${p.likes || 0}</span></button>
        </div>
      `;
      if (p.is_mine) {
        el.querySelector('.social-post-delete').addEventListener('click', async (e) => {
          e.stopPropagation();
          const id = parseInt(e.currentTarget.dataset.id, 10);
          const r = await fetchNui('social:deletePost', { id });
          if (r && r.ok) { await loadSocialFeed(); }
          else showToast(r && r.error ? r.error : 'Erreur', 'error');
        });
      }
      el.querySelector('.social-like-btn').addEventListener('click', async (ev) => {
        const postId = parseInt(ev.currentTarget.dataset.postId, 10);
        const r = await fetchNui('social:likePost', { id: postId });
        if (r && r.ok) {
          const span = ev.currentTarget.querySelector('span');
          if (span) span.textContent = r.likes;
          ev.currentTarget.classList.add('liked');
        }
      });
      feed.appendChild(el);
    });
  }

  $('social-new-btn').addEventListener('click', () => {
    socialComposeOpen = !socialComposeOpen;
    $('social-compose-bar').style.display = socialComposeOpen ? 'flex' : 'none';
    if (socialComposeOpen) setTimeout(() => $('social-compose-input').focus(), 50);
  });

  async function submitSocialPost() {
    const input = $('social-compose-input');
    const body = input.value.trim();
    if (!body) { showToast('Contenu requis', 'error'); return; }
    input.value = '';
    socialComposeOpen = false;
    $('social-compose-bar').style.display = 'none';
    const res = await fetchNui('social:createPost', { body, image: '' });
    if (res && res.ok) {
      await loadSocialFeed();
    } else {
      showToast(res && res.error ? res.error : 'Erreur', 'error');
    }
  }
  $('social-compose-send').addEventListener('click', submitSocialPost);
  $('social-compose-input').addEventListener('keydown', (ev) => {
    if (ev.key === 'Enter') { ev.preventDefault(); submitSocialPost(); }
  });

  // ===========================================================================
  // MARKETPLACE
  // ===========================================================================

  async function openMarketApp() {
    showScreen('market');
    await loadMarketListings();
  }

  async function loadMarketListings() {
    const list   = $('market-list');
    const empty  = $('market-empty');
    list.innerHTML = '<div style="padding:20px;text-align:center;color:var(--text-2);">Chargement…</div>';
    empty.classList.remove('active');
    const res = await fetchNui('market:getListings', {});
    list.innerHTML = '';
    if (!res || !res.ok) {
      list.innerHTML = '<div style="padding:20px;text-align:center;color:var(--text-2);">Erreur de chargement</div>';
      return;
    }
    const listings = res.listings || [];
    if (listings.length === 0) {
      empty.classList.add('active');
      return;
    }
    listings.forEach(l => {
      const el = document.createElement('div');
      el.className = 'market-item';
      const deleteBtn = l.is_mine
        ? `<button class="market-delete-btn" data-id="${l.id}">Retirer</button>`
        : '';
      const contactBtn = !l.is_mine
        ? `<button class="market-contact-btn" data-number="${escapeHtml(l.number)}">Contacter</button>`
        : '';
      el.innerHTML = `
        <div class="market-item-header">
          <div class="market-item-title">${escapeHtml(l.title)}</div>
          <div class="market-item-price">$${Number(l.price || 0).toLocaleString('fr-FR')}</div>
        </div>
        <div class="market-item-body">${escapeHtml(l.body)}</div>
        <div class="market-item-footer">
          <div class="market-item-number">${formatNumber(l.number)} · ${fmtTime(l.created_at)}</div>
          <div style="display:flex;gap:8px;">${deleteBtn}${contactBtn}</div>
        </div>
      `;
      if (l.is_mine) {
        el.querySelector('.market-delete-btn').addEventListener('click', async (e) => {
          const id = parseInt(e.currentTarget.dataset.id, 10);
          const r = await fetchNui('market:deleteListing', { id });
          if (r && r.ok) { await loadMarketListings(); }
          else showToast(r && r.error ? r.error : 'Erreur', 'error');
        });
      } else {
        el.querySelector('.market-contact-btn').addEventListener('click', (e) => {
          const num = normalize(e.currentTarget.dataset.number);
          openChat(num);
        });
      }
      list.appendChild(el);
    });
  }

  $('market-new-btn').addEventListener('click', () => openMarketCreateModal());

  function openMarketCreateModal() {
    $('modal-title').textContent = 'Nouvelle annonce';
    $('modal-body').innerHTML = `
      <label>Titre</label>
      <input type="text" id="mk-title" maxlength="80" placeholder="Vends…">
      <label>Prix ($)</label>
      <input type="number" id="mk-price" inputmode="numeric" placeholder="0" min="0">
      <label>Description</label>
      <input type="text" id="mk-body" maxlength="280" placeholder="Details, etat, lieu de remise…">
    `;
    const actions = document.querySelector('.modal-actions');
    actions.innerHTML = `
      <button class="btn-ghost" id="modal-cancel">Annuler</button>
      <button class="btn-primary" id="modal-confirm">Publier</button>
    `;
    document.getElementById('modal-cancel').onclick = closeModal;
    document.getElementById('modal-confirm').onclick = async () => {
      const title = document.getElementById('mk-title').value.trim();
      const price = parseInt(document.getElementById('mk-price').value, 10) || 0;
      const body  = document.getElementById('mk-body').value.trim();
      if (!title) { showToast('Titre requis', 'error'); return; }
      if (!body)  { showToast('Description requise', 'error'); return; }
      const res = await fetchNui('market:createListing', { title, price, body });
      if (res && res.ok) {
        closeModal();
        await loadMarketListings();
      } else {
        showToast(res && res.error ? res.error : 'Erreur', 'error');
      }
    };
    $('modal').classList.remove('hidden');
    setTimeout(() => document.getElementById('mk-title').focus(), 50);
  }

  // ===========================================================================
  // URGENCES 911 / SAMU
  // ===========================================================================

  function openEmergencyApp() {
    // Restore selected service button state
    document.querySelectorAll('.emergency-service-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.service === emergencyService);
    });
    $('emergency-message').value = '';
    renderEmergencyHistory();
    showScreen('emergency');
  }

  function renderEmergencyHistory() {
    const listEl = $('emergency-history-list');
    if (!emergencyHistory || emergencyHistory.length === 0) {
      listEl.innerHTML = '<div class="emergency-history-item" style="color:var(--text-3);">Aucun appel recemment.</div>';
      return;
    }
    listEl.innerHTML = '';
    emergencyHistory.slice(-3).reverse().forEach(h => {
      const el = document.createElement('div');
      el.className = 'emergency-history-item';
      const svcLabel = h.service === 'police' ? 'Police' : 'SAMU';
      el.textContent = `${svcLabel} · ${h.message} (${fmtTime(h.time)})`;
      listEl.appendChild(el);
    });
  }

  document.querySelectorAll('.emergency-service-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      emergencyService = btn.dataset.service;
      document.querySelectorAll('.emergency-service-btn').forEach(b => {
        b.classList.toggle('active', b === btn);
      });
    });
  });

  $('emergency-send-btn').addEventListener('click', async () => {
    const message = $('emergency-message').value.trim();
    if (!message) { showToast('Decrivez votre urgence', 'error'); return; }
    const btn = $('emergency-send-btn');
    btn.disabled = true;
    btn.textContent = 'Envoi…';
    const res = await fetchNui('emergency', { service: emergencyService, message });
    btn.disabled = false;
    btn.innerHTML = '&#128680; Envoyer l\'alerte';
    if (res && res.ok) {
      emergencyHistory.push({ service: emergencyService, message, time: new Date().toISOString() });
      $('emergency-message').value = '';
      renderEmergencyHistory();
      const svcLabel = emergencyService === 'police' ? 'Police' : 'SAMU';
      showToast('Alerte ' + svcLabel + ' envoyee', 'success');
    } else {
      showToast(res && res.error ? res.error : 'Erreur', 'error');
    }
  });

  // ===========================================================================
  // UTILS (supplement)
  // ===========================================================================

  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  // ===========================================================================
  // TOAST host
  // ===========================================================================
  const toastHost = $('toast-host');
  function showToast(text, kind, duration) {
    if (!toastHost || !text) return;
    duration = Math.max(800, parseInt(duration, 10) || 3000);
    const el = document.createElement('div');
    el.className = 'toast toast-' + (kind || 'inform');
    el.textContent = text;
    toastHost.appendChild(el);
    setTimeout(() => {
      el.classList.add('removing');
      setTimeout(() => el.remove(), 200);
    }, duration);
  }

  // ===========================================================================
  // NUI bridge
  // ===========================================================================
  function fetchNui(name, data) {
    const url = `https://${GetParentResourceName ? GetParentResourceName() : 'sl-phone'}/${name}`;
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then(r => r.json()).catch(() => ({}));
  }

  async function refresh() {
    const res = await fetchNui('refresh', {});
    if (res && res.state) applyState(res.state);
  }

  function applyState(s) {
    if (!s) return;
    state = Object.assign({}, state, s);
    renderHome();
  }

  // ===========================================================================
  // EVENTS
  // ===========================================================================
  window.addEventListener('message', (event) => {
    const data = event.data || {};
    switch (data.action) {
      case 'open':
        if (data.state) applyState(data.state);
        $('phone').classList.remove('hidden');
        requestAnimationFrame(() => $('phone').classList.add('open'));
        showScreen('home');
        break;
      case 'close':
        $('phone').classList.remove('open');
        setTimeout(() => $('phone').classList.add('hidden'), 280);
        closeModal();
        break;
      case 'sync':
        if (data.state) applyState(data.state);
        // re-render écran courant
        if (currentScreen === 'messages') renderMessages();
        else if (currentScreen === 'contacts') renderContacts();
        else if (currentScreen === 'phone') renderRecents();
        else if (currentScreen === 'settings') renderSettings();
        break;
      case 'toast':
        showToast(data.text, data.type, data.duration);
        // refresh aussi (nouveau SMS = nouvelle conv)
        refresh().then(() => {
          if (currentScreen === 'chat' && activeChatPeer) {
            fetchNui('getMessages', { peer: activeChatPeer }).then(r => {
              renderChat(r && r.messages ? r.messages : []);
            });
          } else if (currentScreen === 'messages') {
            renderMessages();
          }
        });
        break;
      case 'callUpdate':
        if (data.call) {
          if (data.call.status === 'ended') {
            endCall(data.call.reason);
          } else {
            showCallScreen(data.call);
          }
        }
        break;
    }
  });

  // ===========================================================================
  // INPUT WIRING
  // ===========================================================================

  // Boutons header
  document.querySelectorAll('.back-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const target = btn.dataset.back || 'home';
      showScreen(target);
    });
  });

  // New conv / new contact
  $('new-conv-btn').addEventListener('click', openNewConv);
  $('new-contact-btn').addEventListener('click', openContactNew);

  // Chat
  $('chat-send').addEventListener('click', sendCurrentMessage);
  $('chat-input').addEventListener('keydown', (ev) => {
    if (ev.key === 'Enter') { ev.preventDefault(); sendCurrentMessage(); }
  });
  $('chat-call-btn').addEventListener('click', () => {
    if (activeChatPeer) ringPeer(activeChatPeer);
  });

  // Phone tabs
  document.querySelectorAll('.phone-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      const which = tab.dataset.tab;
      document.querySelectorAll('.phone-tab').forEach(t => t.classList.toggle('active', t === tab));
      document.querySelectorAll('.phone-tab-body').forEach(b => b.classList.toggle('active', b.dataset.tabBody === which));
      if (which === 'recents') renderRecents();
    });
  });

  // Dialer keys
  document.querySelectorAll('.dial-key[data-digit]').forEach(k => {
    k.addEventListener('click', () => dialerAddDigit(k.dataset.digit));
  });
  $('dial-back').addEventListener('click', dialerBackspace);
  document.getElementById('dialer-call').addEventListener('click', () => {
    if (dialerDigits.length >= 10) ringPeer(dialerDigits);
  });

  // Home indicator (raccourci home)
  $('home-indicator').addEventListener('click', () => showScreen('home'));

  // Close phone via Escape (le client Lua le gère aussi, mais doublon utile)
  document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape') {
      if (!$('modal').classList.contains('hidden')) { closeModal(); return; }
      fetchNui('close', {});
    }
  });

  // Time tick (refresh chaque minute)
  setInterval(() => {
    if (currentScreen === 'home') renderHome();
    const now = new Date();
    $('status-time').textContent = now.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
  }, 30000);

})();
