Blips = Blips or {}

-- ===========================================================================
-- Tous les blips de la map SimpleLife, centralisés.
-- Les coords correspondent aux points d'interaction des modules respectifs.
-- Si tu changes une coord dans un module, mets-la à jour ici aussi.
--
-- Champs : { x, y, z, sprite, color, scale, label, shortRange, category }
--   sprite : ID de l'icône GTA (https://docs.fivem.net/docs/game-references/blips/)
--   color  : ID couleur GTA (1=rouge 2=vert 3=bleu 5=jaune 17=orange 27=cyan
--            38=bleu clair 47=violet 48=blanc-ish ...)
--   shortRange : true = visible seulement de près (réduit l'encombrement map)
--
-- Mets `category = '...'` à false dans Blips.Enabled pour cacher une famille.
-- ===========================================================================

Blips.Enabled = {
  shops      = true,   -- magasins légaux (gérés par sl-shops, déjà blippés -> off ici)
  vehicles   = true,   -- concession + garage
  properties = true,   -- agences immobilières
  crafting   = true,   -- établis
  fuel       = true,   -- stations-service
  services   = true,   -- hôpital
  crime      = true,   -- braquages + zones de deal (mets false pour les cacher en "vrai" RP)
}

Blips.List = {

  -- ===================== VÉHICULES =====================
  { category = 'vehicles', x = -56.7,  y = -1096.6, z = 26.4, sprite = 326, color = 5,  scale = 0.9, label = 'Concession auto',  shortRange = false },
  { category = 'vehicles', x = 215.9,  y = -810.0,  z = 30.7, sprite = 357, color = 3,  scale = 0.8, label = 'Garage',          shortRange = true },

  -- ===================== PROPRIÉTÉS (agents immo) =====================
  { category = 'properties', x = -264.49, y = -959.56, z = 31.22, sprite = 374, color = 2, scale = 0.8, label = 'Agence immobilière', shortRange = true },
  { category = 'properties', x = 372.49,  y = 327.40,  z = 103.57, sprite = 374, color = 2, scale = 0.8, label = 'Agence immobilière', shortRange = true },

  -- ===================== CRAFTING (établis) =====================
  { category = 'crafting', x = -360.8, y = -133.7,  z = 38.0, sprite = 566, color = 17, scale = 0.8, label = 'Atelier mécano',    shortRange = true },
  { category = 'crafting', x = 224.6,  y = -791.6,  z = 31.0, sprite = 52,  color = 17, scale = 0.8, label = 'Cuisine (craft)',   shortRange = true },
  { category = 'crafting', x = 813.6,  y = -2157.9, z = 29.6, sprite = 110, color = 17, scale = 0.8, label = 'Établi munitions',  shortRange = true },

  -- ===================== STATIONS-SERVICE =====================
  { category = 'fuel', x = 265.0,   y = -1261.3, z = 29.3,  sprite = 361, color = 48, scale = 0.7, label = 'Station-service', shortRange = true },
  { category = 'fuel', x = 1693.0,  y = 3760.5,  z = 34.7,  sprite = 361, color = 48, scale = 0.7, label = 'Station-service', shortRange = true },
  { category = 'fuel', x = -71.0,   y = 6248.0,  z = 31.1,  sprite = 361, color = 48, scale = 0.7, label = 'Station-service', shortRange = true },
  { category = 'fuel', x = 819.0,   y = -1028.3, z = 26.4,  sprite = 361, color = 48, scale = 0.7, label = 'Station-service', shortRange = true },
  { category = 'fuel', x = -2095.0, y = -320.0,  z = 13.2,  sprite = 361, color = 48, scale = 0.7, label = 'Station-service', shortRange = true },
  { category = 'fuel', x = -1800.0, y = 792.0,   z = 138.0, sprite = 361, color = 48, scale = 0.7, label = 'Station-service', shortRange = true },
  { category = 'fuel', x = -724.0,  y = -933.5,  z = 19.2,  sprite = 361, color = 48, scale = 0.7, label = 'Station-service', shortRange = true },
  { category = 'fuel', x = -1437.0, y = -278.0,  z = 46.3,  sprite = 361, color = 48, scale = 0.7, label = 'Station-service', shortRange = true },

  -- ===================== SERVICES =====================
  { category = 'services', x = 341.0, y = -1397.3, z = 32.5, sprite = 61, color = 1, scale = 0.9, label = 'Hôpital Pillbox', shortRange = false },

  -- ===================== CRIME (discret, désactivable) =====================
  -- Braquages supérettes
  { category = 'crime', x = -44.5,  y = -1754.5, z = 29.4, sprite = 52,  color = 1,  scale = 0.7, label = 'Cible braquage',  shortRange = true },
  { category = 'crime', x = 24.5,   y = -1347.0, z = 29.5, sprite = 52,  color = 1,  scale = 0.7, label = 'Cible braquage',  shortRange = true },
  { category = 'crime', x = -703.4, y = -910.8,  z = 19.2, sprite = 52,  color = 1,  scale = 0.7, label = 'Cible braquage',  shortRange = true },
  { category = 'crime', x = 18.0,   y = -1107.2, z = 29.8, sprite = 52,  color = 1,  scale = 0.7, label = 'Cible braquage',  shortRange = true },
  -- Coffres-forts
  { category = 'crime', x = -350.8, y = -49.5,   z = 49.0, sprite = 500, color = 1,  scale = 0.8, label = 'Coffre-fort',    shortRange = true },
  { category = 'crime', x = -628.4, y = -232.3,  z = 38.1, sprite = 617, color = 1,  scale = 0.8, label = 'Bijouterie',     shortRange = true },
  -- Zones de deal
  { category = 'crime', x = 116.0,   y = -1953.0, z = 21.0, sprite = 51, color = 47, scale = 0.7, label = 'Zone de deal',   shortRange = true },
  { category = 'crime', x = -144.6,  y = -1685.5, z = 32.6, sprite = 51, color = 47, scale = 0.7, label = 'Zone de deal',   shortRange = true },
  { category = 'crime', x = -619.5,  y = -1215.7, z = 22.2, sprite = 51, color = 47, scale = 0.7, label = 'Zone de deal',   shortRange = true },
}
