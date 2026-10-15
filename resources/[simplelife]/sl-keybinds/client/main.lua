print('[sl-keybinds/client] main.lua loaded')

-- ===========================================================================
-- Hub centralisé des raccourcis clavier SimpleLife.
--
-- Chaque RegisterKeyMapping ici associe une touche à une commande qui est
-- enregistrée AILLEURS (dans le module qui implémente la fonctionnalité).
-- Les commands sont accessibles cross-resource via leur nom global, donc on
-- peut tout brancher depuis cette ressource unique.
--
-- Résultat : dans GTA V → Paramètres → Affectations des touches → FiveM,
-- toutes les touches SimpleLife apparaissent dans UNE SEULE catégorie
-- "SimpleLife" (cf. directive `name 'SimpleLife'` dans fxmanifest).
--
-- L'utilisateur peut ensuite réassigner chaque touche depuis ce menu.
-- ===========================================================================

-- Format : RegisterKeyMapping(commandString, description, mapper, defaultKey)
--   commandString : nom de la commande sans le `/`
--   description   : texte affiché dans le menu Settings
--   mapper        : 'keyboard' (touches) ou 'mouse_button' (souris)
--   defaultKey    : touche par défaut (modifiable par le joueur)

-- ── Inventaire ──────────────────────────────────────────────────────────────
RegisterKeyMapping('inventory', 'Ouvrir l\'inventaire',         'keyboard', 'I')
RegisterKeyMapping('holster',   'Holster : sortir/ranger l\'arme', 'keyboard', 'H')

-- ── Téléphone ───────────────────────────────────────────────────────────────
RegisterKeyMapping('phone',     'Ouvrir le téléphone',          'keyboard', 'F1')

-- ── Voix de proximité ───────────────────────────────────────────────────────
RegisterKeyMapping('voicemode', 'Voix : chuchoter / normal / crier', 'keyboard', 'N')

-- ── Métier ──────────────────────────────────────────────────────────────────
RegisterKeyMapping('duty',      'Service : on / off (métier)',  'keyboard', 'B')

-- ── HUD ─────────────────────────────────────────────────────────────────────
RegisterKeyMapping('hud',       'Afficher / cacher le HUD',     'keyboard', 'F9')

-- ── Admin (ne fonctionne que si l'utilisateur a l'ACE permission) ───────────
RegisterKeyMapping('sladmin',   'Menu admin SimpleLife',        'keyboard', 'F7')

-- ── Véhicules ────────────────────────────────────────────────────────────────
RegisterKeyMapping('vehlock',   'Verrouiller / déverrouiller le véhicule', 'keyboard', 'L')

-- ── Police ───────────────────────────────────────────────────────────────────
RegisterKeyMapping('sl_cuff_nearest', 'Police : menotter le plus proche', 'keyboard', 'G')

print('[sl-keybinds] 9 raccourcis enregistrés sous "SimpleLife" (Settings → Affectations)')
