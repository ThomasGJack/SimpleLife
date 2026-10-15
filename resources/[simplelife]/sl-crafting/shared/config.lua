-- sl-crafting / shared/config.lua
-- Etablis de crafting : coordonnees, label, recettes disponibles.

Crafting = Crafting or {}

-- Liste des etablis. key = identifiant unique, coords = vec3, recipes = liste de cles de recettes.
Crafting.Benches = {
  {
    key     = 'mechanic_bench',
    label   = 'Atelier mecano',
    coords  = vec3(-360.8, -133.7, 38.0),   -- LS Customs zone
    radius  = 2.5,
    recipes = {
      'repair_kit',
      'tire_repair',
      'body_kit',
      'lockpick',
      'advanced_lockpick',
      'ammo_pistol',
      'ammo_smg',
    },
  },
  {
    key     = 'kitchen',
    label   = 'Cuisine',
    coords  = vec3(224.6, -791.6, 31.0),    -- cuisine diner central
    radius  = 2.5,
    recipes = {
      'sandwich',
      'bandage',
      'water_bottle',
      'energy_drink',
    },
  },
  {
    key     = 'ammo_bench',
    label   = 'Etabli munitions',
    coords  = vec3(813.6, -2157.9, 29.6),   -- zone industrielle sud
    radius  = 2.5,
    recipes = {
      'ammo_pistol',
      'ammo_smg',
      'ammo_rifle',
      'ammo_shotgun',
      'lockpick',
      'advanced_lockpick',
    },
  },
}

-- XP crafting gagne par fabrication reussie (multiplie par recipe.xpMult si defini)
Crafting.BaseXP = 10

-- Skill utilise pour le XP (sl-skills)
Crafting.Skill = 'crafting'
