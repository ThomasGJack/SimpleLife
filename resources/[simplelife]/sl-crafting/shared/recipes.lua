-- sl-crafting / shared/recipes.lua
-- Toutes les recettes du module.
-- key        : identifiant unique
-- label      : nom affiche en NUI
-- icon       : emoji affiche sur la carte recette
-- output     : { item = 'item_name', count = n }
-- inputs     : tableau de { item = 'item_name', count = n }
-- time       : duree de fabrication en millisecondes
-- xpMult     : multiplicateur XP (optionnel, defaut 1)
-- skill      : skill requis (optionnel, affichage seulement)
-- reqLevel   : niveau minimum du skill (optionnel)
-- desc       : description courte (optionnel)

Recipes = {

  -- ============================================================
  -- MECANIQUE / OUTILS
  -- ============================================================

  repair_kit = {
    key      = 'repair_kit',
    label    = 'Kit de reparation',
    icon     = '🔧',
    desc     = 'Repare les dommages mecaniques d\'un vehicule.',
    output   = { item = 'repair_kit',   count = 1 },
    inputs   = {
      { item = 'metal_scrap',  count = 3 },
      { item = 'electronics',  count = 2 },
    },
    time     = 8000,
    xpMult   = 1.5,
  },

  tire_repair = {
    key      = 'tire_repair',
    label    = 'Kit pneu',
    icon     = '🛞',
    desc     = 'Repare un pneu creve sur place.',
    output   = { item = 'tire_repair',  count = 1 },
    inputs   = {
      { item = 'rubber',       count = 2 },
      { item = 'metal_scrap',  count = 1 },
    },
    time     = 6000,
    xpMult   = 1.0,
  },

  body_kit = {
    key      = 'body_kit',
    label    = 'Kit carrosserie',
    icon     = '🚗',
    desc     = 'Repare la carrosserie d\'un vehicule.',
    output   = { item = 'body_kit',     count = 1 },
    inputs   = {
      { item = 'aluminum',     count = 3 },
      { item = 'metal_scrap',  count = 2 },
    },
    time     = 10000,
    xpMult   = 2.0,
  },

  lockpick = {
    key      = 'lockpick',
    label    = 'Crochet de serrure',
    icon     = '🗝️',
    desc     = 'Permet de crocheter les serrures basiques.',
    output   = { item = 'lockpick',     count = 1 },
    inputs   = {
      { item = 'metal_scrap',  count = 2 },
      { item = 'plastic',      count = 1 },
    },
    time     = 7000,
    xpMult   = 1.2,
  },

  advanced_lockpick = {
    key      = 'advanced_lockpick',
    label    = 'Crochet avance',
    icon     = '🔑',
    desc     = 'Crochetage de serrures haute securite.',
    output   = { item = 'advanced_lockpick', count = 1 },
    inputs   = {
      { item = 'metal_scrap',  count = 3 },
      { item = 'electronics',  count = 1 },
      { item = 'plastic',      count = 2 },
    },
    time     = 12000,
    xpMult   = 2.5,
    skill    = 'crafting',
    reqLevel = 3,
  },

  -- ============================================================
  -- MUNITIONS
  -- ============================================================

  ammo_pistol = {
    key      = 'ammo_pistol',
    label    = 'Munitions pistolet',
    icon     = '🔫',
    desc     = 'Cartouches 9mm — +50 munitions pistolet.',
    output   = { item = 'ammo_pistol',  count = 50 },
    inputs   = {
      { item = 'metal_scrap',  count = 1 },
    },
    time     = 5000,
    xpMult   = 0.8,
  },

  ammo_smg = {
    key      = 'ammo_smg',
    label    = 'Munitions SMG',
    icon     = '🔫',
    desc     = 'Cartouches SMG — +50 munitions.',
    output   = { item = 'ammo_smg',     count = 50 },
    inputs   = {
      { item = 'metal_scrap',  count = 2 },
      { item = 'aluminum',     count = 1 },
    },
    time     = 6000,
    xpMult   = 0.9,
  },

  ammo_rifle = {
    key      = 'ammo_rifle',
    label    = 'Munitions rifle',
    icon     = '🔫',
    desc     = 'Cartouches rifle — +30 munitions.',
    output   = { item = 'ammo_rifle',   count = 30 },
    inputs   = {
      { item = 'metal_scrap',  count = 3 },
      { item = 'aluminum',     count = 2 },
    },
    time     = 8000,
    xpMult   = 1.2,
    skill    = 'crafting',
    reqLevel = 2,
  },

  ammo_shotgun = {
    key      = 'ammo_shotgun',
    label    = 'Munitions shotgun',
    icon     = '🔫',
    desc     = 'Cartouches shotgun — +20 munitions.',
    output   = { item = 'ammo_shotgun', count = 20 },
    inputs   = {
      { item = 'metal_scrap',  count = 2 },
      { item = 'rubber',       count = 1 },
    },
    time     = 7000,
    xpMult   = 1.0,
  },

  -- ============================================================
  -- SANTE / CONSOMMABLES
  -- ============================================================

  bandage = {
    key      = 'bandage',
    label    = 'Bandage',
    icon     = '🩹',
    desc     = 'Stoppe un leger saignement.',
    output   = { item = 'bandage',      count = 1 },
    inputs   = {
      { item = 'fabric',       count = 2 },
    },
    time     = 4000,
    xpMult   = 0.7,
  },

  -- ============================================================
  -- NOURRITURE / BOISSONS
  -- ============================================================

  sandwich = {
    key      = 'sandwich',
    label    = 'Sandwich',
    icon     = '🥪',
    desc     = 'Un sandwich maison, restaure la faim.',
    output   = { item = 'sandwich',     count = 1 },
    inputs   = {
      { item = 'pain',         count = 1 },
      { item = 'pomme',        count = 1 },
    },
    time     = 4000,
    xpMult   = 0.6,
  },

  water_bottle = {
    key      = 'water_bottle',
    label    = 'Bouteille d\'eau',
    icon     = '💧',
    desc     = 'Eau fraiche, restaure la soif.',
    output   = { item = 'eau',          count = 2 },
    inputs   = {
      { item = 'plastic',      count = 1 },
    },
    time     = 3000,
    xpMult   = 0.5,
  },

  energy_drink = {
    key      = 'energy_drink',
    label    = 'Cafe',
    icon     = '☕',
    desc     = 'Un coup de fouet, restaure la soif.',
    output   = { item = 'cafe',         count = 1 },
    inputs   = {
      { item = 'eau',          count = 1 },
      { item = 'plastic',      count = 1 },
    },
    time     = 5000,
    xpMult   = 0.8,
  },

}
