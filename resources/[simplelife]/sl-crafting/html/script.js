(() => {
  'use strict';

  // =========================================================================
  // Helpers DOM
  // =========================================================================
  const $  = (id) => document.getElementById(id);
  const root        = $('crafting-root');
  const benchTitle  = $('bench-title');
  const benchSub    = $('bench-sub');
  const recipeList  = $('recipe-list');
  const btnClose    = $('btn-close');
  const toastHost   = $('toast-host');

  // =========================================================================
  // Etat
  // =========================================================================
  let state = {
    bench:       null,     // { key, label }
    recipes:     [],       // tableau de recettes (objets Lua transcrits)
    playerItems: {},       // map { itemName -> count }
    crafting:    false,    // verrou : fabrication en cours
  };

  let isOpen = false;

  // =========================================================================
  // fetchNui — appel vers le client Lua
  // =========================================================================
  function fetchNui(eventName, data) {
    return fetch(`https://${GetParentResourceName()}/${eventName}`, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body:    JSON.stringify(data || {}),
    }).then(r => r.json()).catch(() => null);
  }

  // =========================================================================
  // Toast
  // =========================================================================
  const TOAST_ICONS = { success: '✔', error: '✖', inform: 'ℹ' };

  function slNotify(msg, type, duration) {
    type     = type     || 'inform';
    duration = duration || 3500;
    const el = document.createElement('div');
    el.className = `toast toast-${type}`;
    el.innerHTML =
      `<span class="toast-icon">${TOAST_ICONS[type] || 'ℹ'}</span>` +
      `<span class="toast-text">${msg}</span>`;
    toastHost.appendChild(el);
    setTimeout(() => {
      el.classList.add('removing');
      el.addEventListener('animationend', () => el.remove(), { once: true });
    }, duration);
  }

  // =========================================================================
  // Rendu d'une carte recette
  // =========================================================================

  // Libelle propre d'un item (on retire les underscores)
  function itemLabel(name) {
    return name.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
  }

  // Verifie si le joueur a assez d'un ingredient
  function playerHas(item, count) {
    const qty = (state.playerItems[item] || 0);
    return qty >= count;
  }

  // Verifie si toute la recette est craftable
  function isCraftable(recipe) {
    if (!recipe.inputs || recipe.inputs.length === 0) return true;
    for (const inp of recipe.inputs) {
      if (!playerHas(inp.item, inp.count)) return false;
    }
    return true;
  }

  function formatTime(ms) {
    if (ms < 1000) return ms + 'ms';
    return (ms / 1000).toFixed(1) + 's';
  }

  function buildRecipeCard(recipe) {
    const craftable = isCraftable(recipe);
    const locked    = !!(recipe.reqLevel && recipe.reqLevel > 0);

    const card = document.createElement('div');
    card.className = 'recipe-card' +
      (craftable ? ' craftable' : '') +
      (locked    ? ' locked'    : '');
    card.dataset.key = recipe.key;

    // Badge niveau si requis
    if (recipe.skill && recipe.reqLevel) {
      const badge = document.createElement('div');
      badge.className = 'recipe-lock-badge';
      badge.textContent = `Niv ${recipe.reqLevel} requis`;
      card.appendChild(badge);
    }

    // En-tete
    const rcHead = document.createElement('div');
    rcHead.className = 'rc-head';

    const icon = document.createElement('div');
    icon.className = 'rc-icon';
    icon.textContent = recipe.icon || '🔨';

    const info = document.createElement('div');
    info.className = 'rc-info';

    const label = document.createElement('div');
    label.className = 'rc-label';
    label.textContent = recipe.label || recipe.key;

    const output = document.createElement('div');
    output.className = 'rc-output';
    output.textContent = `→ ${itemLabel(recipe.output.item)} x${recipe.output.count}`;

    info.appendChild(label);
    info.appendChild(output);
    rcHead.appendChild(icon);
    rcHead.appendChild(info);
    card.appendChild(rcHead);

    // Description
    if (recipe.desc) {
      const desc = document.createElement('div');
      desc.className = 'rc-desc';
      desc.textContent = recipe.desc;
      card.appendChild(desc);
    }

    // Ingredients
    if (recipe.inputs && recipe.inputs.length > 0) {
      const inpTitle = document.createElement('div');
      inpTitle.className = 'rc-inputs-title';
      inpTitle.textContent = 'Ingredients';
      card.appendChild(inpTitle);

      const inputs = document.createElement('div');
      inputs.className = 'rc-inputs';

      for (const inp of recipe.inputs) {
        const have = state.playerItems[inp.item] || 0;
        const ok   = have >= inp.count;

        const row = document.createElement('div');
        row.className = 'rc-input-row ' + (ok ? 'ok' : 'nok');

        const name = document.createElement('span');
        name.className = 'rc-inp-name';
        name.textContent = itemLabel(inp.item);

        const qty = document.createElement('span');
        qty.className = 'rc-inp-qty ' + (ok ? 'ok' : 'nok');
        qty.textContent = `${have}/${inp.count}`;

        row.appendChild(name);
        row.appendChild(qty);
        inputs.appendChild(row);
      }
      card.appendChild(inputs);
    }

    // Footer
    const footer = document.createElement('div');
    footer.className = 'rc-footer';

    const timeEl = document.createElement('div');
    timeEl.className = 'rc-time';
    timeEl.textContent = '⏱ ' + formatTime(recipe.time || 5000);

    const btn = document.createElement('button');
    btn.className = 'btn-craft ' + (craftable ? 'enabled' : 'disabled');
    btn.textContent = 'FABRIQUER';
    btn.disabled = !craftable;
    if (craftable) {
      btn.addEventListener('click', () => onCraft(recipe, btn));
    }

    footer.appendChild(timeEl);
    footer.appendChild(btn);
    card.appendChild(footer);

    return card;
  }

  function renderRecipes() {
    recipeList.innerHTML = '';
    if (!state.recipes || state.recipes.length === 0) {
      const empty = document.createElement('div');
      empty.style.cssText = 'color:var(--text-mute);font-family:Oswald,sans-serif;font-size:14px;letter-spacing:2px;text-align:center;padding:40px;grid-column:1/-1;';
      empty.textContent = 'Aucune recette disponible sur cet etabli.';
      recipeList.appendChild(empty);
      return;
    }
    for (const r of state.recipes) {
      recipeList.appendChild(buildRecipeCard(r));
    }
  }

  // Re-rend uniquement les indicateurs ok/nok + etat bouton sans tout reconstruire
  function updateRecipesItems() {
    const cards = recipeList.querySelectorAll('.recipe-card');
    cards.forEach(card => {
      const key    = card.dataset.key;
      const recipe = state.recipes.find(r => r.key === key);
      if (!recipe) return;

      const craftable = isCraftable(recipe);

      card.classList.toggle('craftable', craftable);

      // Mise a jour des lignes ingredients
      const rows = card.querySelectorAll('.rc-input-row');
      (recipe.inputs || []).forEach((inp, i) => {
        const row = rows[i];
        if (!row) return;
        const have = state.playerItems[inp.item] || 0;
        const ok   = have >= inp.count;
        row.className = 'rc-input-row ' + (ok ? 'ok' : 'nok');
        const qty = row.querySelector('.rc-inp-qty');
        if (qty) {
          qty.className = 'rc-inp-qty ' + (ok ? 'ok' : 'nok');
          qty.textContent = `${have}/${inp.count}`;
        }
      });

      // Bouton
      const btn = card.querySelector('.btn-craft');
      if (btn && !state.crafting) {
        if (craftable) {
          btn.className = 'btn-craft enabled';
          btn.disabled  = false;
          // Re-bind click (simple : on repose un listener en reconstruisant)
          // Pour eviter les doublons on detruit et reconstruit le bouton
          const newBtn = btn.cloneNode(true);
          newBtn.className = 'btn-craft enabled';
          newBtn.disabled  = false;
          newBtn.addEventListener('click', () => onCraft(recipe, newBtn));
          btn.replaceWith(newBtn);
        } else {
          btn.className = 'btn-craft disabled';
          btn.disabled  = true;
        }
      }
    });
  }

  // =========================================================================
  // Action : Fabriquer
  // =========================================================================
  function onCraft(recipe, btnEl) {
    if (state.crafting) return;
    if (!isCraftable(recipe)) return;

    state.crafting = true;

    // Verouiller tous les boutons
    recipeList.querySelectorAll('.btn-craft').forEach(b => {
      b.className = 'btn-craft crafting';
      b.disabled  = true;
    });

    fetchNui('craft', {
      benchKey:  state.bench ? state.bench.key : '',
      recipeKey: recipe.key,
    }).then(result => {
      state.crafting = false;

      if (!result) {
        slNotify('Erreur de connexion au serveur.', 'error');
        reEnableButtons();
        return;
      }

      if (!result.ok) {
        slNotify(result.error || 'Fabrication echouee.', 'error');
        reEnableButtons();
        return;
      }

      // Succes
      slNotify(
        `${recipe.icon || ''} ${recipe.label} fabrique ! (+${result.xp || 0} XP)`,
        'success',
        4000
      );

      // Rafraichir l inventaire
      fetchNui('getPlayerItems', {}).then(items => {
        if (items) {
          state.playerItems = items;
          updateRecipesItems();
        } else {
          reEnableButtons();
        }
      }).catch(() => { reEnableButtons(); });
    }).catch(() => {
      state.crafting = false;
      slNotify('Erreur reseau.', 'error');
      reEnableButtons();
    });
  }

  function reEnableButtons() {
    state.crafting = false;
    updateRecipesItems();
  }

  // =========================================================================
  // Ouvrir / Fermer
  // =========================================================================
  function openWindow(data) {
    state.bench       = data.bench       || null;
    state.recipes     = data.recipes     || [];
    state.playerItems = data.playerItems || {};
    state.crafting    = false;

    // Titre etabli
    if (state.bench) {
      benchTitle.textContent = state.bench.label  || 'ETABLI';
      benchSub.textContent   = state.bench.key    || '';
    }

    renderRecipes();
    root.classList.remove('hidden');
    isOpen = true;
  }

  function closeWindow() {
    if (!isOpen) return;
    root.classList.add('hidden');
    isOpen = false;
    state.crafting = false;
    fetchNui('close', {}).catch(() => {});
  }

  // =========================================================================
  // SendNUIMessage listener
  // =========================================================================
  window.addEventListener('message', (ev) => {
    const data = ev.data;
    if (!data || !data.action) return;

    switch (data.action) {
      case 'open':
        openWindow(data);
        break;

      case 'close':
        root.classList.add('hidden');
        isOpen = false;
        state.crafting = false;
        break;

      case 'updateItems':
        state.playerItems = data.playerItems || {};
        updateRecipesItems();
        break;

      default:
        break;
    }
  });

  // =========================================================================
  // Fermeture
  // =========================================================================
  btnClose.addEventListener('click', closeWindow);

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && isOpen) closeWindow();
  });

})();
