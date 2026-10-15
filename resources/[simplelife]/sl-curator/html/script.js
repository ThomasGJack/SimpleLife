(() => {
  'use strict';
  const RESOURCE = 'sl-curator';
  const $ = (id) => document.getElementById(id);
  const app = $('app');
  const elPhaseTabs = $('phase-tabs');
  const elPhaseTitleNum = $('phase-title-num');
  const elPhaseTitle = $('phase-title');
  const elPhaseDesc = $('phase-desc');
  const elSlots = $('slots');
  const elStatPhase = $('stat-phase');
  const elStatTotal = $('stat-total');
  const elActiveCount = $('active-count');
  const elBtnYes = $('btn-yes');
  const elBtnNext = $('btn-next');
  const elBtnBack = $('btn-back');
  const elBtnClose = $('btn-close');
  const elBanner = $('banner-error');
  const elModeNormal = $('mode-normal');
  const elModeReview = $('mode-review');
  const elBtnYesText = $('btn-yes-text');
  const elBtnYesSub = $('btn-yes-sub');
  const elBtnNextText = $('btn-next-text');
  const elBtnNextSub = $('btn-next-sub');

  let state = {
    open: false,
    phase: 'p1',
    phases: [],
    outfit: null,
    slots: [],
    extraSlot: null,
    mode: 'normal',
  };

  function updateModeButtons() {
    elModeNormal.classList.toggle('active', state.mode === 'normal');
    elModeReview.classList.toggle('active', state.mode === 'review');
    app.classList.toggle('mode-review', state.mode === 'review');
    if (state.mode === 'review') {
      elBtnYesText.textContent = 'CONFIRMER';
      elBtnYesSub.textContent = 'Marque comme double-validé';
      elBtnNextText.textContent = 'REJETER';
      elBtnNextSub.textContent = 'Retire de la base';
    } else {
      elBtnYesText.textContent = 'COMPATIBLE';
      elBtnYesSub.textContent = 'Enregistre la tenue';
      elBtnNextText.textContent = 'SUIVANT';
      elBtnNextSub.textContent = 'Sans noter';
    }
  }

  function postLua(action, payload) {
    fetch(`https://${RESOURCE}/${action}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload || {}),
    }).catch(() => {});
  }

  function renderPhaseTabs() {
    elPhaseTabs.innerHTML = '';
    state.phases.forEach(p => {
      const btn = document.createElement('button');
      btn.className = 'phase-tab';
      if (p.id === state.phase) btn.classList.add('active');
      const breakdown = state.activeBreakdown || {};
      const onPhase = breakdown[p.id] || 0;
      const badge = onPhase > 0
        ? `<span class="phase-tab-badge" title="${onPhase} joueur(s) actuellement">${onPhase}</span>`
        : '';
      btn.innerHTML = `
        <div class="phase-tab-label">${p.label}</div>
        <div class="phase-tab-title">${p.title}</div>
        ${badge}
      `;
      btn.addEventListener('click', () => postLua('setPhase', { phase: p.id }));
      elPhaseTabs.appendChild(btn);
    });
  }

  function renderSlots() {
    elSlots.innerHTML = '';
    state.slots.forEach(slot => {
      const key = slot.kind + ':' + slot.id;
      const entry = state.outfit && state.outfit[key];
      const drawable = entry && entry.drawable != null ? entry.drawable : '?';
      const li = document.createElement('li');
      li.className = 'slot';
      if (key === state.extraSlot) li.classList.add('extra');
      li.innerHTML = `
        <span class="slot-name">${slot.label}</span>
        <span class="slot-value">#${drawable}</span>
      `;
      elSlots.appendChild(li);
    });
  }

  function showError(msg) {
    elBanner.textContent = msg;
    elBanner.classList.remove('hidden');
    setTimeout(() => elBanner.classList.add('hidden'), 4000);
  }

  function setStats(stats) {
    if (!stats) return;
    if (state.mode === 'review') {
      elStatPhase.textContent = (stats.yes_to_review || 0) + ' à voir';
    } else {
      elStatPhase.textContent = stats.yes_phase || 0;
    }
    elStatTotal.textContent = stats.yes_total || 0;
    elActiveCount.textContent = stats.active_users || 1;

    if (stats.active_breakdown) {
      state.activeBreakdown = stats.active_breakdown;
      renderPhaseTabs();
    }
  }

  elBtnYes.addEventListener('click', () => postLua('voteYes'));
  elBtnNext.addEventListener('click', () => {
    if (state.mode === 'review') postLua('voteNo');
    else postLua('next');
  });
  elBtnBack.addEventListener('click', () => postLua('back'));
  elBtnClose.addEventListener('click', () => postLua('close'));
  elModeNormal.addEventListener('click', () => postLua('setMode', { mode: 'normal' }));
  elModeReview.addEventListener('click', () => postLua('setMode', { mode: 'review' }));

  let rotateHeld = null;
  let rotateLoopActive = false;
  function rotateLoop() {
    if (!rotateHeld) { rotateLoopActive = false; return; }
    rotateLoopActive = true;
    postLua('rotate', { delta: rotateHeld === 'left' ? -3 : 3 });
    setTimeout(rotateLoop, 40);
  }

  document.addEventListener('keydown', (e) => {
    if (!state.open) return;
    const k = e.key.toLowerCase();
    if (k === 'v') postLua('voteYes');
    else if (k === 'r' || k === 'n' || e.key === ' ') {
      e.preventDefault();
      if (state.mode === 'review') postLua('voteNo'); else postLua('next');
    }
    else if (k === 't') {
      postLua('setMode', { mode: state.mode === 'review' ? 'normal' : 'review' });
    }
    else if (k === 'z') postLua('back');
    else if (e.key === 'Escape') postLua('close');
    else if (e.key >= '1' && e.key <= '4') {
      const idx = parseInt(e.key) - 1;
      const p = state.phases[idx];
      if (p) postLua('setPhase', { phase: p.id });
    } else if (e.key === 'ArrowLeft') {
      if (rotateHeld !== 'left') { rotateHeld = 'left'; if (!rotateLoopActive) rotateLoop(); }
    } else if (e.key === 'ArrowRight') {
      if (rotateHeld !== 'right') { rotateHeld = 'right'; if (!rotateLoopActive) rotateLoop(); }
    } else if (e.key === 'ArrowUp') {
      postLua('zoom', { delta: -0.3 });
    } else if (e.key === 'ArrowDown') {
      postLua('zoom', { delta: 0.3 });
    }
  });

  document.addEventListener('keyup', (e) => {
    if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') rotateHeld = null;
  });

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;
    switch (data.action) {
      case 'init':
        state.open = true;
        state.phases = data.phases || [];
        renderPhaseTabs();
        app.classList.remove('hidden');
        break;
      case 'show':
        if (!state.open) { state.open = true; app.classList.remove('hidden'); }
        state.outfit = data.outfit;
        state.phase = data.phase;
        state.slots = data.slots || [];
        state.extraSlot = data.extraSlot;
        state.mode = data.mode || 'normal';
        updateModeButtons();
        elPhaseTitleNum.textContent = (data.mode === 'review' ? '2ᵉ PASSE • ' : '') + (data.phaseLabel || '—');
        elPhaseTitle.textContent = data.phaseTitle || '—';
        elPhaseDesc.textContent = data.mode === 'review'
          ? 'Tu revois tes validations. Confirme ou rejette pour épurer ta base.'
          : (data.phaseDesc || '');
        if (data.stats) setStats(data.stats);
        elBtnBack.disabled = !data.canBack || state.mode === 'review';
        renderPhaseTabs();
        renderSlots();
        elBanner.classList.add('hidden');
        break;
      case 'error':
        showError(data.error || 'Erreur');
        break;
      case 'stats':
        setStats(data.stats);
        break;
      case 'close':
        state.open = false;
        app.classList.add('hidden');
        break;
    }
  });
})();
