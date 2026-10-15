(() => {
  'use strict';

  const TIPS = [
    "Bienvenue sur <b>SimpleLife</b> — le framework RP modulaire.",
    "Tape <b>/sl info</b> en jeu pour voir l'état de ton perso.",
    "Tu peux créer jusqu'à <b>3 personnages</b> par compte.",
    "Ton <b>citizen ID</b> est ton identifiant unique en ville.",
    "Les commandes admin commencent par <b>/sl</b>",
    "Tes données sont sauvegardées <b>toutes les 5 minutes</b>.",
    "SimpleLife est <b>ultra modulaire</b> — chaque feature est un module.",
    "Le RP commence par une bonne identité. Choisis bien ton nom.",
    "Les modules sont chargés dynamiquement au boot du serveur.",
    "<b>OneSync</b> est activé : on supporte de gros effectifs.",
    "Une question ? Demande à un admin sur le Discord.",
    "L'écran de chargement, c'est aussi du code — bienvenue dans le détail.",
  ];

  const SUB_PHASES = [
    "Préparation des assets...",
    "Chargement des modèles...",
    "Synchronisation avec le serveur...",
    "Configuration de l'environnement...",
    "Bientôt prêt...",
  ];

  const PHASE_LABELS = {
    'startInitFunction': 'Initialisation du moteur',
    'initFunctionInvoking': 'Chargement des fonctions',
    'initFunctionInvoked': 'Fonctions chargées',
    'endInitFunction': 'Initialisation terminée',
    'startDataFileEntries': 'Lecture des données',
    'performMapLoadFunction': 'Chargement de la carte',
    'onLogLine': 'Connexion au serveur',
    'loadProgress': 'Chargement',
    'startDataFileEntry': 'Lecture de fichier',
    'endDataFileEntries': 'Données prêtes',
  };

  const $ = (id) => document.getElementById(id);
  const phaseEl = $('phase');
  const subPhaseEl = $('sub-phase');
  const fillEl = $('progress-fill');
  const textEl = $('progress-text');
  const tipEl = $('tip-text');

  // Tips rotation
  let tipIndex = 0;
  tipEl.innerHTML = TIPS[0];

  function nextTip() {
    tipEl.style.opacity = 0;
    setTimeout(() => {
      tipIndex = (tipIndex + 1) % TIPS.length;
      tipEl.innerHTML = TIPS[tipIndex];
      tipEl.style.opacity = 1;
    }, 400);
  }
  setInterval(nextTip, 6000);

  // Sub-phase rotation
  let subIndex = 0;
  function nextSubPhase() {
    subPhaseEl.style.opacity = 0;
    setTimeout(() => {
      subIndex = (subIndex + 1) % SUB_PHASES.length;
      subPhaseEl.textContent = SUB_PHASES[subIndex];
      subPhaseEl.style.opacity = 1;
    }, 300);
  }
  setInterval(nextSubPhase, 3500);

  // Progress smoothing
  let displayedPct = 0;
  let targetPct = 0;

  function tick() {
    if (Math.abs(targetPct - displayedPct) > 0.1) {
      displayedPct += (targetPct - displayedPct) * 0.15;
      fillEl.style.width = displayedPct + '%';
      textEl.textContent = Math.round(displayedPct) + '%';
    }
    requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);

  function setProgress(pct) {
    targetPct = Math.min(100, Math.max(0, pct));
  }

  function setPhase(label) {
    if (label && label !== phaseEl.textContent) {
      phaseEl.textContent = label;
    }
  }

  // FiveM events
  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.eventName) return;

    const label = PHASE_LABELS[data.eventName];
    if (label) setPhase(label);

    switch (data.eventName) {
      case 'loadProgress':
        if (typeof data.loadFraction === 'number') {
          setProgress(data.loadFraction * 100);
        }
        break;

      case 'initFunctionInvoking':
        if (data.count && data.idx != null) {
          const pct = (data.idx / data.count) * 25;
          setProgress(Math.max(targetPct, pct));
          if (data.name) {
            subPhaseEl.textContent = `init: ${data.name}`;
          }
        }
        break;

      case 'startDataFileEntries':
        setProgress(Math.max(targetPct, 30));
        break;

      case 'performMapLoadFunction':
        if (data.count && data.idx != null) {
          const pct = 30 + (data.idx / data.count) * 40;
          setProgress(Math.max(targetPct, pct));
        }
        break;

      case 'endDataFileEntries':
        setProgress(Math.max(targetPct, 80));
        break;

      case 'onLogLine':
        if (data.message) {
          subPhaseEl.textContent = String(data.message).substring(0, 80);
        }
        setProgress(Math.max(targetPct, 90));
        break;

      case 'endInitFunction':
        setProgress(Math.max(targetPct, 100));
        break;
    }
  });

  // Fallback animation if no events arrive
  let fallbackProgress = 0;
  const fallbackInterval = setInterval(() => {
    fallbackProgress += 0.5;
    if (fallbackProgress > 95) {
      clearInterval(fallbackInterval);
      return;
    }
    setProgress(Math.max(targetPct, fallbackProgress));
  }, 200);
})();
