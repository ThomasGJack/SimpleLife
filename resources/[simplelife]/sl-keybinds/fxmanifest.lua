fx_version 'cerulean'
game 'gta5'
lua54 'yes'

-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ Le NOM affiché dans le menu Paramètres GTA V → Affectations des touches │
-- │ → FiveM utilise la directive `name` ci-dessous.                         │
-- │ → Folder = sl-keybinds, mais affichage = "SimpleLife".                  │
-- └─────────────────────────────────────────────────────────────────────────┘
name 'SimpleLife'

author 'SimpleLife'
description 'SimpleLife — hub centralisé des raccourcis clavier (RegisterKeyMapping)'
version '0.1.0'

dependencies {
  -- pas de dépendances dures : les commands sont enregistrées globalement,
  -- on bind juste les touches dessus. Charge en dernier dans server.cfg pour
  -- que les commands existent au moment du bind.
}

client_scripts {
  'client/main.lua',
}
