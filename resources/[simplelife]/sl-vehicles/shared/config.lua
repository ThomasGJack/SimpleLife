-- =============================================================================
-- sl-vehicles / shared/config.lua
-- =============================================================================

Vehicles = Vehicles or {}

-- Coords NPC concession PDM
Vehicles.ConcessionCoords  = vec3(-56.7, -1096.6, 26.4)
Vehicles.ConcessionHeading = 160.0
Vehicles.ConcessionNpcModel = 'a_m_y_business_03'

-- Point de sortie vehicule (pres du garage)
Vehicles.GarageCoords      = vec3(215.9, -810.0, 30.7)
Vehicles.GarageHeading     = 70.0
Vehicles.GarageNpcModel    = 's_m_m_autoshop_01'

-- Spawn output : tableau de slots de sortie
Vehicles.SpawnPoints = {
  { coords = vec3(213.0, -804.0, 30.7), heading = 70.0 },
  { coords = vec3(213.0, -808.0, 30.7), heading = 70.0 },
  { coords = vec3(213.0, -812.0, 30.7), heading = 70.0 },
  { coords = vec3(217.0, -804.0, 30.7), heading = 70.0 },
  { coords = vec3(217.0, -808.0, 30.7), heading = 70.0 },
}

-- Preview camera : hauteur au-dessus du vehicule, rayon orbite, vitesse
Vehicles.PreviewCamera = {
  height = 2.0,
  radius = 6.0,
  speed  = 0.4,   -- radians/sec
}

-- Format de plaque : 'SL ' + 5 digits
Vehicles.PlatePrefix = 'SL '

-- Distance max pour interagir avec un vehicule (store, hotwire)
Vehicles.InteractDistance = 5.0

-- Hotwire : duree de la progressBar en ms
Vehicles.HotwireDuration = 12000

-- Item requis pour le hotwire
Vehicles.HotwireItem = 'lockpick'

-- Garage par defaut
Vehicles.DefaultGarage = 'central'

-- Categories affichees dans la NUI (ordre sidebar)
Vehicles.Categories = {
  { key = 'compact',  label = 'Compactes',   icon = '🚗' },
  { key = 'sedan',    label = 'Berlines',    icon = '🚙' },
  { key = 'sport',    label = 'Sportives',   icon = '🏎' },
  { key = 'suv',      label = 'SUV',         icon = '🚐' },
  { key = 'moto',     label = 'Motos',       icon = '🏍' },
  { key = 'utility',  label = 'Utilitaires', icon = '🚚' },
}
