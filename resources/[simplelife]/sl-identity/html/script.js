(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const root = $('root');
  const screenSelect = $('screen-select');
  const screenCreate = $('screen-create');

  let state = {
    characters: [],
    nationalities: [],
    maxSlots: 1,
  };
  let selectedSlot = null;

  // Form state (create)
  let form = {
    firstName: '', lastName: '',
    dob: '',
    sex: 'm',
    nationality: 'FR',
  };

  // ===========================================================================
  // NUI bridge
  // ===========================================================================
  function fetchNui(name, data) {
    const url = `https://${GetParentResourceName ? GetParentResourceName() : 'sl-identity'}/${name}`;
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
    const host = $('toast-host');
    if (!host || !text) return;
    const el = document.createElement('div');
    el.className = 'toast t-' + (kind || 'inform');
    el.textContent = text;
    host.appendChild(el);
    setTimeout(() => {
      el.classList.add('removing');
      setTimeout(() => el.remove(), 200);
    }, duration || 3000);
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================
  function calcAge(dob) {
    if (!dob) return '—';
    const d = new Date(dob);
    if (isNaN(d.getTime())) return '—';
    const now = new Date(2026, 4, 15); // 2026-05-15
    let age = now.getFullYear() - d.getFullYear();
    const m = now.getMonth() - d.getMonth();
    if (m < 0 || (m === 0 && now.getDate() < d.getDate())) age--;
    return age + ' ans';
  }

  function natLabel(value) {
    const n = state.nationalities.find(x => x.value === value);
    return n ? n.label : value;
  }

  // ===========================================================================
  // SELECTOR : rendu liste
  // ===========================================================================
  function renderSlots() {
    const wrap = $('char-slots');
    wrap.innerHTML = '';
    const taken = {};

    (state.characters || []).forEach(c => {
      taken[c.slot] = true;
      const id = c.identity || {};
      const fullname = ((id.firstName || '?') + ' ' + (id.lastName || '?')).trim();
      const el = document.createElement('div');
      el.className = 'slot' + (selectedSlot === c.slot ? ' selected' : '');
      el.innerHTML = `
        <div class="slot-name">${escapeHtml(fullname)}</div>
        <div class="slot-cid">${c.citizenId || '—'}</div>
        <div class="slot-meta">${escapeHtml(id.dob || '?')} · ${id.sex === 'f' ? 'Femme' : 'Homme'} · ${escapeHtml(natLabel(id.nationality))}</div>
      `;
      el.addEventListener('click', () => selectSlot(c.slot));
      wrap.appendChild(el);
    });

    for (let s = 1; s <= state.maxSlots; s++) {
      if (!taken[s]) {
        const el = document.createElement('div');
        el.className = 'slot slot-create';
        el.innerHTML = `
          <div class="slot-name">+ NOUVEAU CITOYEN</div>
          <div class="slot-meta">Créer un personnage (slot ${s})</div>
        `;
        el.addEventListener('click', () => openCreate(s));
        wrap.appendChild(el);
      }
    }
  }

  function selectSlot(slotNum) {
    selectedSlot = slotNum;
    const c = state.characters.find(x => x.slot === slotNum);
    if (!c) return;
    renderSlots();
    showCharDetails(c);
    // Demande à Lua de mettre à jour la cam vers ce perso (si on a un preview ped)
    fetchNui('previewCharacter', { slot: slotNum, identity: c.identity });
  }

  function showCharDetails(c) {
    $('char-empty').classList.add('hidden');
    $('char-info').classList.remove('hidden');
    const id = c.identity || {};
    $('char-info-name').textContent = ((id.firstName || '?') + ' ' + (id.lastName || '?')).trim();
    $('char-info-cid').textContent  = c.citizenId || '—';
    $('ci-firstName').textContent   = id.firstName || '—';
    $('ci-lastName').textContent    = id.lastName || '—';
    $('ci-dob').textContent         = id.dob || '—';
    $('ci-age').textContent         = calcAge(id.dob);
    $('ci-sex').textContent         = id.sex === 'f' ? 'Femme' : 'Homme';
    $('ci-nationality').textContent = natLabel(id.nationality);
  }

  function escapeHtml(s) {
    return String(s || '').replace(/[&<>"']/g, c => ({
      '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
    })[c]);
  }

  // ===========================================================================
  // CREATE screen
  // ===========================================================================
  function openCreate(slot) {
    form = { firstName: '', lastName: '', dob: '1995-06-15', sex: 'm', nationality: 'FR', slot: slot };
    document.querySelectorAll('.sex-btn').forEach(b => {
      b.classList.toggle('active', b.dataset.sex === 'm');
    });
    $('f-firstName').value = '';
    $('f-lastName').value  = '';
    $('f-dob').value       = '1995-06-15';
    populateNationalities();
    $('f-nationality').value = 'FR';
    updateSummary();
    screenSelect.classList.add('hidden');
    screenCreate.classList.remove('hidden');
    // Préviens Lua qu'on doit basculer la cam sur un preview ped (default sex m)
    fetchNui('previewCreate', { sex: form.sex });
    setTimeout(() => $('f-firstName').focus(), 100);
  }

  function closeCreate() {
    screenCreate.classList.add('hidden');
    screenSelect.classList.remove('hidden');
    fetchNui('previewSelector', {});
    renderSlots();
  }

  function populateNationalities() {
    const sel = $('f-nationality');
    sel.innerHTML = '';
    (state.nationalities || []).forEach(n => {
      const o = document.createElement('option');
      o.value = n.value; o.textContent = n.label;
      sel.appendChild(o);
    });
  }

  function updateSummary() {
    const fn = (form.firstName || '').trim();
    const ln = (form.lastName  || '').trim();
    $('sum-name').textContent = (fn || ln) ? (fn + ' ' + ln).trim() : '—';
    $('sum-dob').textContent  = form.dob || '—';
    $('sum-sex').textContent  = form.sex === 'f' ? 'Femme' : 'Homme';
    $('sum-nat').textContent  = natLabel(form.nationality) || '—';

    const valid = fn.length >= 2 && ln.length >= 2 && /^\d{4}-\d{2}-\d{2}$/.test(form.dob) && (form.sex === 'm' || form.sex === 'f') && form.nationality;
    $('btn-create').disabled = !valid;
  }

  // ===========================================================================
  // CREATE event handlers
  // ===========================================================================
  $('f-firstName').addEventListener('input', (e) => { form.firstName = e.target.value; updateSummary(); });
  $('f-lastName' ).addEventListener('input', (e) => { form.lastName  = e.target.value; updateSummary(); });
  $('f-dob'      ).addEventListener('change',(e) => { form.dob       = e.target.value; updateSummary(); });
  $('f-nationality').addEventListener('change',(e) => { form.nationality = e.target.value; updateSummary(); });

  document.querySelectorAll('.sex-btn').forEach(b => {
    b.addEventListener('click', () => {
      form.sex = b.dataset.sex;
      document.querySelectorAll('.sex-btn').forEach(o => o.classList.toggle('active', o === b));
      updateSummary();
      // Préviens Lua : swap le modèle du preview ped
      fetchNui('changeSex', { sex: form.sex });
    });
  });

  $('btn-back').addEventListener('click', closeCreate);

  $('btn-create').addEventListener('click', async () => {
    $('btn-create').disabled = true;
    const res = await fetchNui('submitCreate', {
      slot: form.slot,
      firstName: form.firstName.trim(),
      lastName: form.lastName.trim(),
      dob: form.dob,
      sex: form.sex,
      nationality: form.nationality,
    });
    if (res && res.ok) {
      toast('✓ Personnage créé !', 'success');
      // Lua va fermer la NUI une fois sélection effective
    } else {
      toast('✕ ' + (res && res.error ? res.error : 'Échec'), 'error');
      $('btn-create').disabled = false;
    }
  });

  // ===========================================================================
  // SELECTOR event handlers
  // ===========================================================================
  $('btn-play').addEventListener('click', async () => {
    if (selectedSlot == null) return;
    $('btn-play').disabled = true;
    const res = await fetchNui('selectSlot', { slot: selectedSlot });
    if (!res || !res.ok) {
      toast('✕ ' + (res && res.error ? res.error : 'Sélection refusée'), 'error');
      $('btn-play').disabled = false;
    }
    // Sinon Lua ferme la NUI
  });

  $('btn-delete').addEventListener('click', async () => {
    if (selectedSlot == null) return;
    if (!confirm('Supprimer définitivement ce personnage ?')) return;
    const res = await fetchNui('deleteSlot', { slot: selectedSlot });
    if (res && res.ok) {
      toast('Personnage supprimé.', 'inform');
      selectedSlot = null;
      $('char-info').classList.add('hidden');
      $('char-empty').classList.remove('hidden');
    } else {
      toast('✕ ' + (res && res.error ? res.error : 'Suppression refusée'), 'error');
    }
  });

  // ===========================================================================
  // MESSAGES from Lua
  // ===========================================================================
  window.addEventListener('message', (event) => {
    const data = event.data || {};
    switch (data.action) {
      case 'open':
        state.characters = data.characters || [];
        state.nationalities = data.nationalities || [];
        state.maxSlots = data.maxSlots || 1;
        selectedSlot = null;
        screenCreate.classList.add('hidden');
        screenSelect.classList.remove('hidden');
        renderSlots();
        $('char-info').classList.add('hidden');
        $('char-empty').classList.remove('hidden');
        root.classList.remove('hidden');
        // Auto-select s'il n'y a qu'un perso
        if (state.characters.length === 1) {
          selectSlot(state.characters[0].slot);
        } else if (state.characters.length === 0 && state.maxSlots >= 1) {
          // Aucun perso → ouvre directement la création
          setTimeout(() => openCreate(1), 200);
        }
        break;
      case 'close':
        root.classList.add('hidden');
        break;
      case 'toast':
        toast(data.text, data.kind, data.duration);
        break;
    }
  });
})();
