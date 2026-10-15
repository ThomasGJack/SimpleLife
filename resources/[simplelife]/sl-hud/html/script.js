(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const hud = $('hud');
  const elName = $('name');
  const elCid = $('citizen-id');
  const elCash = $('cash');
  const elBank = $('bank');
  const elCrypto = $('crypto');
  const elRowCash = $('row-cash');
  const elRowBank = $('row-bank');
  const elRowCrypto = $('row-crypto');
  const elHpFill = $('hp-fill');
  const elHpVal = $('hp-val');
  const elJobName = $('job-name');
  const elJobGrade = $('job-grade');
  const elJobIcon = $('job-icon');
  const elDutyBadge = $('duty-badge');
  const elFuelBar = $('fuel-bar');
  const elFuelFill = $('fuel-fill');
  const elFuelVal = $('fuel-val');
  const elCuffs = $('cuffs-indicator');
  const elDownOverlay = $('down-overlay');
  const elDownSub = $('down-sub');
  const elDownBleed = $('down-bleed');
  const elDownTimer = $('down-timer');

  const JOB_ICONS = {
    unemployed: '🏖️',
    police: '👮',
    ambulance: '🚑',
    mechanic: '🔧',
    taxi: '🚕',
    farmer: '🌾',
    trucker: '🚛',
  };

  const flashTimers = {};

  function flash(row, dir) {
    const key = row.id;
    const cls = dir > 0 ? 'flash-up' : 'flash-down';
    row.classList.add(cls);
    if (flashTimers[key]) clearTimeout(flashTimers[key]);
    flashTimers[key] = setTimeout(() => {
      row.classList.remove('flash-up');
      row.classList.remove('flash-down');
    }, 900);
  }

  function getRowByAccount(account) {
    if (account === 'cash') return elRowCash;
    if (account === 'bank') return elRowBank;
    if (account === 'crypto') return elRowCrypto;
    return null;
  }

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;

    switch (data.action) {
      case 'show':
        hud.classList.remove('hidden');
        break;
      case 'hide':
        hud.classList.add('hidden');
        break;
      case 'identity':
        elName.textContent = data.name || '—';
        elCid.textContent = data.citizenId || '—';
        break;
      case 'money':
        if (data.cash !== undefined) elCash.textContent = data.cash;
        if (data.bank !== undefined) elBank.textContent = data.bank;
        if (data.crypto !== undefined) elCrypto.textContent = data.crypto;
        break;
      case 'flash': {
        const row = getRowByAccount(data.account);
        if (row && data.delta != null) flash(row, data.delta);
        break;
      }
      case 'health':
        if (data.hp !== undefined) {
          elHpFill.style.width = data.hp + '%';
          elHpVal.textContent = data.hp;
        }
        break;
      case 'job':
        elJobName.textContent = data.label || 'Sans emploi';
        elJobGrade.textContent = data.gradeLabel || '—';
        elJobIcon.textContent = JOB_ICONS[data.name] || '💼';
        if (data.onDuty) {
          elDutyBadge.textContent = 'EN SERVICE';
          elDutyBadge.classList.add('on');
          elDutyBadge.classList.remove('off');
        } else {
          elDutyBadge.textContent = 'OFF';
          elDutyBadge.classList.add('off');
          elDutyBadge.classList.remove('on');
        }
        break;
      case 'fuel':
        if (data.show === false) {
          elFuelBar.classList.add('hidden');
        } else {
          elFuelBar.classList.remove('hidden');
          const lvl = Math.max(0, Math.min(100, Math.round(data.level || 0)));
          elFuelFill.style.width = lvl + '%';
          elFuelVal.textContent = lvl;
          elFuelFill.classList.toggle('low', lvl <= 20);
        }
        break;
      case 'cuffs':
        if (data.cuffed) elCuffs.classList.remove('hidden');
        else elCuffs.classList.add('hidden');
        break;
      case 'down':
        if (data.down) {
          elDownOverlay.classList.remove('hidden');
          if (data.sub !== undefined) elDownSub.textContent = data.sub;
        } else {
          elDownOverlay.classList.add('hidden');
        }
        break;
      case 'downInfo':
        if (data.bleed !== undefined) {
          elDownBleed.textContent = data.bleed > 0
            ? ('🩸 Hémorragie niveau ' + data.bleed)
            : '';
        }
        if (data.timer !== undefined) {
          elDownTimer.textContent = data.timer
            ? ('Réanimation possible — décès dans ' + data.timer)
            : '';
        }
        break;
    }
  });
})();
