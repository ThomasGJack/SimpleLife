-- =============================================================================
--  sl-jobmissions / shared/config.lua
-- =============================================================================

JobMissions = {}

-- ---------------------------------------------------------------------------
-- TAXI
-- ---------------------------------------------------------------------------
JobMissions.Taxi = {
  JobName       = 'taxi',
  TariffPerUnit = 8,          -- $ par unite de distance (1 unite ~ 1 metre GTA)
  DistanceDivisor = 40,       -- divise la distance brute pour obtenir le montant lisible
  MinFare       = 50,         -- course minimum en $
  MaxFare       = 800,        -- plafond
  XpPerFare     = 5,          -- XP driving par course livree
  PickupRadius  = 4.0,        -- metres pour declencher l interaciton pickup
  DropRadius    = 6.0,        -- metres pour valider la livraison

  -- PNJ modeles possibles (choix aleatoire)
  PedModels = {
    's_m_y_taxi_01',
    'a_f_y_tourist_01',
    'a_m_y_tourist_01',
    'a_f_m_business_02',
    'a_m_m_business_01',
    'a_f_y_shoppingbag_01',
  },

  -- Coins de rue aleatoires pour spawn passager (vec3 inlines)
  PickupSpawns = {
    { x =  -559.8, y = -922.1,  z = 23.7  },
    { x =  -312.1, y = -736.2,  z = 33.5  },
    { x =   121.6, y = -1026.2, z = 29.3  },
    { x =   420.4, y = -806.3,  z = 29.5  },
    { x =   -70.5, y = -820.0,  z = 326.2 },
    { x =  -1044.5,y = -1437.2, z = 5.0   },
    { x =   183.2, y = -173.9,  z = 55.6  },
    { x =  -1196.3,y = -771.7,  z = 17.3  },
    { x =   -42.8, y = -1743.7, z = 29.4  },
    { x =   348.3, y = -2060.9, z = 20.2  },
  },

  -- Destinations aleatoires
  Destinations = {
    { x =  -559.8, y = -922.1,  z = 23.7,  label = 'Vespucci' },
    { x =   323.1, y = -209.7,  z = 54.2,  label = 'Vinewood' },
    { x =  -1393.7,y = -619.0,  z = 30.4,  label = 'Little Seoul' },
    { x =   -73.2, y = -1756.5, z = 29.3,  label = 'Del Perro' },
    { x =  1151.4, y = -1529.6, z = 35.3,  label = 'East LS' },
    { x =   213.7, y =  -810.0, z = 30.7,  label = 'Garage Central' },
    { x =  -1044.5,y =  -479.5, z = 36.7,  label = 'Rockford Hills' },
    { x =   425.6, y = -979.4,  z = 30.7,  label = 'Police DP' },
    { x =  -312.0, y = -1473.1, z = 24.6,  label = 'Elysian Island' },
    { x =   -56.7, y = -1096.6, z = 26.4,  label = 'PDM' },
    { x =   266.8, y = -1261.1, z = 29.3,  label = 'Station-service' },
    { x =  -1095.7,y = 2658.1,  z = 18.8,  label = 'Paleto Bay' },
  },
}

-- ---------------------------------------------------------------------------
-- TRUCKER
-- ---------------------------------------------------------------------------
JobMissions.Trucker = {
  JobName       = 'trucker',
  PayPerPallet  = 200,        -- $ par palette livree
  XpPerDelivery = 10,         -- XP driving par livraison complete
  LoadTime      = 6000,       -- ms pour l animation de chargement d une palette
  PaletteCount  = 3,          -- nombre de palettes a charger avant la livraison

  -- Depot de chargement (PNJ + zone)
  Depot = {
    coords = { x = 51.6,  y = -1765.0, z = 29.3 },
    heading = 65.0,
    label   = 'Depot routier',
    pedModel = 's_m_y_dockwork_01',
  },

  -- Points de livraison
  Deliveries = {
    { x =  -316.1, y = -1462.3, z = 24.4,  label = 'Elysian Island' },
    { x =   -56.7, y = -1096.6, z = 26.4,  label = 'PDM Concession' },
    { x =   851.8, y = -1551.2, z = 29.7,  label = 'Terminal portuaire' },
    { x =  -453.3, y = -2029.3, z = 16.7,  label = 'Boulangerie Vespucci' },
    { x =  1207.4, y = -1389.3, z = 35.2,  label = 'Zone industrielle E' },
    { x =  2673.2, y = 3276.3,  z = 55.2,  label = 'Sandy Shores' },
  },

  -- Modeles de camions acceptes (si le joueur monte dans un vehicule de ce type)
  TruckModels = { 'hauler', 'phantom', 'mule', 'mule2', 'mule3', 'benson', 'packer' },
}

-- ---------------------------------------------------------------------------
-- MECANO
-- ---------------------------------------------------------------------------
JobMissions.Mechanic = {
  JobName     = 'mechanic',
  RepairItem  = 'repair_kit',    -- item consomme pour reparer
  RepairTime  = 8000,            -- ms animation de reparation
  BasePayment = 300,             -- $ facture de base
  XpPerRepair = 15,              -- XP mechanic par reparation
  ScanRadius  = 12.0,            -- metres de detection vehicule proche
  InteractDist= 3.0,

  -- Garage mecano (lieu ou trouver du travail)
  GarageCoords = { x = -337.4, y = -131.7, z = 38.3 },

  -- Seuils de sante vehicule
  MaxBodyHealth   = 1000.0,
  MaxEngineHealth = 1000.0,
}

-- ---------------------------------------------------------------------------
-- FARMER
-- ---------------------------------------------------------------------------
JobMissions.Farmer = {
  JobName     = 'farmer',
  HarvestItem = 'ble',           -- item recolte
  SeedItem    = 'graines_ble',   -- item optionnel pour planter
  HarvestTime = 5000,            -- ms animation recolte
  PlantTime   = 4000,            -- ms animation plantation
  HarvestGive = 3,               -- unites de ble par recolte
  XpPerHarvest= 8,               -- XP farming par recolte
  XpPerSell   = 4,               -- XP farming par vente
  PricePerKg  = 25,              -- $ par unite de ble vendue

  -- Zones de champ (recolte)
  Fields = {
    {
      coords = { x = 2510.0, y = 4778.0, z = 34.2 },
      radius = 30.0,
      label  = 'Champ Grapeseed',
    },
    {
      coords = { x = 1718.3, y = 4637.2, z = 37.5 },
      radius = 25.0,
      label  = 'Champ Route 68',
    },
    {
      coords = { x = -273.3, y = 6220.5, z = 31.5 },
      radius = 20.0,
      label  = 'Champ Paleto',
    },
  },

  -- Moulin / acheteur (PNJ)
  Mill = {
    coords  = { x = 2480.2, y = 4974.3, z = 34.1 },
    heading = 200.0,
    pedModel = 'a_m_m_farmer_01',
    label   = 'Vendre ble [E]',
  },
}
