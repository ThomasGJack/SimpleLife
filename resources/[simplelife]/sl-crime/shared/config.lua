-- ============================================================================
-- sl-crime — Configuration partagee (serveur + client)
-- ============================================================================

Crime = Crime or {}

-- ---------------------------------------------------------------------------
-- BRAQUAGES MAGASINS (caisses)
-- Chaque entree : coords (vec3), label, cooldownMin (minutes),
--                 lootMin, lootMax (cash), requiredItem (lockpick|advanced_lockpick)
--                 progressMs : duree de la barre de progression
-- ---------------------------------------------------------------------------
Crime.Shops = {
  {
    id          = 'market_vinewood',
    label       = 'Superette Vinewood',
    coords      = vec3(-44.5, -1754.5, 29.4),
    radius      = 1.5,
    cooldownMin = 30,
    lootMin     = 800,
    lootMax     = 2200,
    requiredItem= 'lockpick',
    progressMs  = 18000,
  },
  {
    id          = 'market_pillbox',
    label       = 'Superette Pillbox',
    coords      = vec3(24.5, -1347.0, 29.5),
    radius      = 1.5,
    cooldownMin = 30,
    lootMin     = 900,
    lootMax     = 2400,
    requiredItem= 'lockpick',
    progressMs  = 18000,
  },
  {
    id          = 'market_strawberry',
    label       = 'Superette Strawberry',
    coords      = vec3(-703.4, -910.8, 19.2),
    radius      = 1.5,
    cooldownMin = 30,
    lootMin     = 700,
    lootMax     = 2000,
    requiredItem= 'lockpick',
    progressMs  = 18000,
  },
  {
    id          = 'market_grove',
    label       = 'Superette Grove St.',
    coords      = vec3(18.0, -1107.2, 29.8),
    radius      = 1.5,
    cooldownMin = 30,
    lootMin     = 600,
    lootMax     = 1800,
    requiredItem= 'lockpick',
    progressMs  = 18000,
  },
}

-- ---------------------------------------------------------------------------
-- COFFRES-FORTS
-- requiredItem : drill ou thermite
-- ---------------------------------------------------------------------------
Crime.Safes = {
  {
    id          = 'safe_fleeca_east',
    label       = 'Coffre Fleeca East',
    coords      = vec3(-350.8, -49.5, 49.0),
    radius      = 1.5,
    cooldownMin = 90,
    lootMin     = 8000,
    lootMax     = 25000,
    requiredItem= 'drill',
    progressMs  = 40000,
  },
  {
    id          = 'safe_vangelico',
    label       = 'Coffre bijouterie',
    coords      = vec3(-628.4, -232.3, 38.1),
    radius      = 1.5,
    cooldownMin = 120,
    lootMin     = 15000,
    lootMax     = 40000,
    requiredItem= 'thermite',
    progressMs  = 55000,
  },
}

-- ---------------------------------------------------------------------------
-- DROGUE — culture (planting)
-- ---------------------------------------------------------------------------
Crime.Drugs = {
  -- Duree de pousse en secondes (serveur)
  GrowTimeSec    = 600,    -- 10 minutes
  -- Prop utilise pour le plant de weed
  PlantPropHash  = 'prop_weed_01',
  -- Nombre de weed_bud obtenus a la recolte
  HarvestMin     = 2,
  HarvestMax     = 5,
  -- Max plants simultanes (anti-grief)
  MaxPlantsPerPlayer = 6,
}

-- ---------------------------------------------------------------------------
-- DROGUE — packaging (transformation)
-- Chaque entree : drug, inputItem, inputCount, outputItem, outputCount
-- ---------------------------------------------------------------------------
Crime.Packaging = {
  {
    id          = 'weed_pack',
    label       = 'Emballer la weed',
    coords      = vec3(1972.3, 3816.5, 33.0),
    radius      = 3.0,
    inputItem   = 'weed_bud',
    inputCount  = 4,
    outputItem  = 'weed_packaged',
    outputCount = 1,
    progressMs  = 8000,
  },
  {
    id          = 'coke_pack',
    label       = 'Emballer la coke',
    coords      = vec3(2461.0, 3783.0, 44.0),
    radius      = 3.0,
    inputItem   = 'coke_raw',
    inputCount  = 3,
    outputItem  = 'coke_packaged',
    outputCount = 1,
    progressMs  = 9000,
  },
  {
    id          = 'meth_pack',
    label       = 'Emballer le meth',
    coords      = vec3(2475.5, 3759.8, 44.0),
    radius      = 3.0,
    inputItem   = 'meth_raw',
    inputCount  = 3,
    outputItem  = 'meth_packaged',
    outputCount = 1,
    progressMs  = 9000,
  },
}

-- ---------------------------------------------------------------------------
-- DROGUE — vente (zones de deal)
-- ---------------------------------------------------------------------------
Crime.DealZones = {
  {
    id        = 'deal_grove',
    label     = 'Zone de deal',
    coords    = vec3(116.0, -1953.0, 21.0),
    radius    = 5.0,
    -- Pourcentage de chances qu'un PNJ achete
    buyChance = 65,
    -- Pourcentage de chances d'alerter la police si achat
    alertChanceOnBuy = 12,
    -- Pourcentage de chances d'alerter la police si refus
    alertChanceOnRefuse = 5,
    -- Prix par item vendu (cash)
    prices = {
      weed_packaged  = 180,
      coke_packaged  = 420,
      meth_packaged  = 380,
    },
    cooldownMin = 5,
  },
  {
    id        = 'deal_banning',
    label     = 'Zone de deal',
    coords    = vec3(-144.6, -1685.5, 32.6),
    radius    = 5.0,
    buyChance = 55,
    alertChanceOnBuy = 15,
    alertChanceOnRefuse = 7,
    prices = {
      weed_packaged  = 160,
      coke_packaged  = 400,
      meth_packaged  = 360,
    },
    cooldownMin = 5,
  },
  {
    id        = 'deal_strawberry',
    label     = 'Zone de deal',
    coords    = vec3(-619.5, -1215.7, 22.2),
    radius    = 5.0,
    buyChance = 70,
    alertChanceOnBuy = 10,
    alertChanceOnRefuse = 4,
    prices = {
      weed_packaged  = 190,
      coke_packaged  = 440,
      meth_packaged  = 400,
    },
    cooldownMin = 5,
  },
}

-- Drogues vendables (ordre de priorite auto-selection)
Crime.SellableDrugs = { 'coke_packaged', 'meth_packaged', 'weed_packaged' }

-- XP accordes (via sl-skills si dispo)
Crime.XP = {
  robberyCash   = 30,
  robberyVault  = 80,
  deal          = 15,
}

-- Alertes police : rayon de spawn (si sl-police ecoute sl:crime:robberyStarted)
Crime.PoliceAlertRadius = 500.0
