(() => {
  'use strict';

  // =========================================================================
  // Helpers
  // =========================================================================
  const $ = (id) => document.getElementById(id);
  const root         = $('ems-root');
  const hdrDuty      = $('hdr-duty');
  const tabBtns      = document.querySelectorAll('.ems-tab');
  const panels       = document.querySelectorAll('.ems-panel');
  const patientList  = $('patient-list');
  const patientsEmpty = $('patients-empty');
  const btnRefresh   = $('btn-refresh-patients');
  const diagTarget   = $('diag-target');
  const btnDiag      = $('btn-diag');
  const diagBody     = $('diag-body');
  const billTarget   = $('bill-target');
  const billAmount   = $('bill-amount');
  const btnBill      = $('btn-bill');
  const billHistory  = $('bill-history');
  const toastContainer = $('ems-toast-container');

  let isOpen   = false;
  let selfData = null;
  let billLog  = [];

  // =========================================================================
  // fetchNui — pattern SimpleLife
  // =========================================================================
  function fetchNui(callback, data) {
    return fetch(`https://${GetParentResourceName()}/${callback}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data || {}),
    }).then(r => r.json()).catch(() => null);
  }

  function GetParentResourceName() {
    // Injecte par FiveM au runtime
    return (window.GetParentResourceName && window.GetParentResourceName()) || 'sl-ems';
  }

  // =========================================================================
  // Toast
  // =========================================================================
  function slNotify(message, type) {
    type = type || 'inform';
    const el = document.createElement('div');
    el.className = 'ems-toast ' + type;
    el.textContent = message;
    toastContainer.appendChild(el);
    setTimeout(() => {
      el.style.opacity = '0';
      el.style.transition = 'opacity 0.3s';
      setTimeout(() => el.remove(), 300);
    }, 3500);
  }

  // =========================================================================
  // Tabs
  // =========================================================================
  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const tab = btn.dataset.tab;
      tabBtns.forEach(b => b.classList.remove('active'));
      panels.forEach(p => p.classList.remove('active'));
      btn.classList.add('active');
      document.getElementById('tab-' + tab).classList.add('active');
    });
  });

  // =========================================================================
  // Fermeture
  // =========================================================================
  $('ems-close').addEventListener('click', () => fetchNui('close'));
  $('ems-overlay').addEventListener('click', () => fetchNui('close'));

  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && isOpen) fetchNui('close');
  });

  // =========================================================================
  // Patients
  // =========================================================================
  function renderPatients(patients) {
    patientList.innerHTML = '';
    if (!patients || patients.length === 0) {
      patientList.appendChild(patientsEmpty);
      patientsEmpty.style.display = '';
      return;
    }
    patientsEmpty.style.display = 'none';

    patients.forEach(p => {
      const card = document.createElement('div');
      card.className = 'patient-card';
      card.innerHTML = `
        <div class="patient-icon">&#10010;</div>
        <div class="patient-info">
          <div class="patient-name">Joueur #${p.source}</div>
          <div class="patient-meta">Citizen: ${p.citizenId || '---'}</div>
        </div>
        <div class="patient-hp">${Math.max(0, Math.floor((p.health || 0) - 100))} HP</div>
        <div class="patient-actions">
          <button class="btn-sm btn-revive" data-src="${p.source}">Ranimer</button>
          <button class="btn-sm btn-heal" data-src="${p.source}">Soigner</button>
        </div>
      `;
      card.querySelector('.btn-revive').addEventListener('click', () => {
        fetchNui('revivePatient', { targetSrc: p.source });
      });
      card.querySelector('.btn-heal').addEventListener('click', () => {
        fetchNui('healPatient', { targetSrc: p.source });
      });
      patientList.appendChild(card);
    });
  }

  async function refreshPatients() {
    btnRefresh.textContent = '...';
    const result = await fetchNui('getPatients');
    btnRefresh.textContent = 'Actualiser';
    renderPatients(result || []);
  }

  btnRefresh.addEventListener('click', refreshPatients);

  // =========================================================================
  // Diagnostic
  // =========================================================================
  function renderDiagnostic(injuries) {
    diagBody.innerHTML = '';
    if (!injuries || injuries.length === 0) {
      diagBody.innerHTML = '<div class="empty-state">Aucune donnee disponible.</div>';
      return;
    }
    injuries.forEach(inj => {
      const card = document.createElement('div');
      card.className = 'zone-card';
      card.innerHTML = `
        <div class="zone-name">${inj.label || inj.zone}</div>
        <div class="zone-severity" style="color:${inj.color || '#e8d9b8'}">${inj.severity || '---'}</div>
        <div class="zone-hp">HP zone : ${Math.max(0, Math.floor((inj.hp || 0) - 100))}</div>
      `;
      diagBody.appendChild(card);
    });
  }

  btnDiag.addEventListener('click', async () => {
    const targetSrc = parseInt(diagTarget.value, 10);
    if (!targetSrc || isNaN(targetSrc)) {
      slNotify('ID joueur invalide.', 'error');
      return;
    }
    diagBody.innerHTML = '<div class="empty-state">Analyse en cours...</div>';
    const injuries = await fetchNui('getInjuries', { targetSrc });
    renderDiagnostic(injuries || []);
  });

  // =========================================================================
  // Facturation
  // =========================================================================
  function addBillLog(targetSrc, amount) {
    billLog.unshift({ targetSrc, amount, time: new Date().toLocaleTimeString() });
    renderBillHistory();
  }

  function renderBillHistory() {
    billHistory.innerHTML = '';
    if (billLog.length === 0) {
      billHistory.innerHTML = '<div class="empty-state">Aucune facture emise dans cette session.</div>';
      return;
    }
    billLog.forEach(b => {
      const el = document.createElement('div');
      el.className = 'bill-entry';
      el.innerHTML = `
        <div class="bill-entry-info">Joueur #${b.targetSrc} — ${b.time}</div>
        <div class="bill-entry-amount">$${b.amount.toLocaleString()}</div>
      `;
      billHistory.appendChild(el);
    });
  }

  btnBill.addEventListener('click', async () => {
    const targetSrc = parseInt(billTarget.value, 10);
    const amount    = parseInt(billAmount.value, 10);
    if (!targetSrc || isNaN(targetSrc)) { slNotify('ID joueur invalide.', 'error'); return; }
    if (!amount || isNaN(amount) || amount <= 0) { slNotify('Montant invalide.', 'error'); return; }

    const res = await fetchNui('billPatient', { targetSrc, amount });
    if (res && res.ok) {
      addBillLog(targetSrc, amount);
      slNotify(`Facture $${amount.toLocaleString()} envoyee.`, 'success');
      billTarget.value = '';
      billAmount.value = '';
    } else {
      slNotify('Erreur lors de la facturation.', 'error');
    }
  });

  // =========================================================================
  // Ouverture / fermeture via SendNUIMessage
  // =========================================================================
  window.addEventListener('message', async (e) => {
    const data = e.data;
    if (!data || !data.action) return;

    if (data.action === 'open') {
      isOpen = true;
      root.classList.remove('hidden');
      // Charge les donnees perso
      selfData = await fetchNui('getSelfData');
      if (selfData) {
        if (selfData.onDuty) {
          hdrDuty.textContent = 'EN SERVICE';
          hdrDuty.className = 'duty-badge on';
        } else {
          hdrDuty.textContent = 'HORS SERVICE';
          hdrDuty.className = 'duty-badge off';
        }
      }
      await refreshPatients();
      renderBillHistory();
      // Signal ready
      fetchNui('ready');
    }

    if (data.action === 'close') {
      isOpen = false;
      root.classList.add('hidden');
    }
  });

})();
