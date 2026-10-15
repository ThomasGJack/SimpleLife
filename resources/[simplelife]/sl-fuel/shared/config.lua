Fuel = Fuel or {}

-- ===========================================================================
-- Paramètres généraux
-- ===========================================================================
Fuel.MaxLevel    = 100.0   -- niveau max (0-100)
Fuel.StartLevel  = 80.0    -- niveau par défaut si sl-vehicles ne fournit pas de valeur

-- ===========================================================================
-- Consommation en conduite (client-only, non persisté en RAM serveur)
-- Consommation calculée à chaque tick : base * rpmMult * speedMult * dt
--   rpmMult  : 1.0 + (rpm * RpmFactor)        -- régime moteur
--   speedMult: 1.0 + (speed_mps * SpeedFactor) -- vitesse
-- Résultat en unités / seconde.
-- Exemples approximatifs :
--   ralenti  : ~0.002 u/s → 0.12 u/min → ~833 min pour vider tank complet
--   route    : ~0.015 u/s → 0.9 u/min  → ~111 min pour vider
--   autoroute: ~0.030 u/s → 1.8 u/min  → ~55  min pour vider
-- ===========================================================================
Fuel.BaseConsumption  = 0.0020   -- u/s à l'arrêt moteur tournant
Fuel.RpmFactor        = 0.0180   -- multiplicateur RPM (0-1 GTA)
Fuel.SpeedFactor      = 0.0006   -- multiplicateur vitesse (m/s)

-- Seuil moteur calé : le moteur coupe en dessous de ce niveau
Fuel.StallLevel = 0.5

-- Intervalle du tick de consommation côté client (ms)
Fuel.ConsumeTickMs = 500

-- ===========================================================================
-- Notifications (seuils en %)
-- ===========================================================================
Fuel.AlertThresholds = { 20.0, 5.0 }   -- alerts à la descente

-- ===========================================================================
-- Stations-service
-- ===========================================================================
Fuel.PricePerUnit = 2.5   -- $ par litre/unité

-- Coordonnées des pompes (stations-service GTA V)
-- Chaque entrée : { coords = vec3, label = '...', radius = n }
Fuel.Stations = {
  -- Station Pillbox Hill / Davis
  { coords = vec3(265.0,  -1261.3, 29.3),  label = 'Station LTD',       radius = 4.0 },
  -- Sandy Shores
  { coords = vec3(1693.0, 3760.5,  34.7),  label = 'Station Sandy',     radius = 4.0 },
  -- Paleto Bay
  { coords = vec3(-71.0,  6248.0,  31.1),  label = 'Station Paleto',    radius = 4.0 },
  -- La Mesa
  { coords = vec3(819.0,  -1028.3, 26.4),  label = 'Station La Mesa',   radius = 4.0 },
  -- Route 1 / Great Ocean
  { coords = vec3(-2095.0, -320.0, 13.2),  label = 'Station Route 1',   radius = 4.0 },
  -- Burton / Rockford Hills
  { coords = vec3(-1800.0, 792.0,  138.0), label = 'Station Burton',    radius = 4.0 },
  -- Strawberry / Forum Dr
  { coords = vec3(-724.0,  -933.5, 19.2),  label = 'Station Strawberry',radius = 4.0 },
  -- Vespucci Canals
  { coords = vec3(-1437.0, -278.0, 46.3),  label = 'Station Vespucci',  radius = 4.0 },
}

-- Quantité versée par le bidon essence (item bidon_essence)
Fuel.CanAmount   = 20.0   -- litres versés par usage du bidon

-- Distance max pour remplir depuis un bidon (m)
Fuel.CanDistance = 5.0

-- Distance max pour utiliser une station (le véhicule doit être proche)
Fuel.StationVehicleDistance = 8.0
