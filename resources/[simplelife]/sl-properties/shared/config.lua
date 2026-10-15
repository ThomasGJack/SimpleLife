-- sl-properties / shared/config.lua
-- Liste des proprietes et parametres globaux.

Properties = Properties or {}

-- Catalogue des proprietes. Seed en DB au premier boot (voir server/main.lua).
-- enter_pos  : coords de la porte en ville (AddZone interaction).
-- interior_pos : coords de l'interieur (TP destination).
-- ipl         : nom de l'IPL a charger (nil si non necessaire).
Properties.Catalog = {
  {
    id            = 1,
    label         = 'Appartement Del Perro',
    type          = 'apartment',
    price         = 80000,
    enter_pos     = { x = -1449.07, y = -536.36, z = 35.50 },
    interior_pos  = { x = -1452.60, y = -520.32, z = 34.43, heading = 90.0 },
    ipl           = nil,
  },
  {
    id            = 2,
    label         = 'Appartement Vinewood',
    type          = 'apartment',
    price         = 150000,
    enter_pos     = { x = 372.60, y = 330.62, z = 103.57 },
    interior_pos  = { x = 375.36, y = 341.42, z = 102.57, heading = 180.0 },
    ipl           = nil,
  },
  {
    id            = 3,
    label         = 'Studio Strawberry',
    type          = 'apartment',
    price         = 45000,
    enter_pos     = { x = -263.11, y = -955.87, z = 31.22 },
    interior_pos  = { x = -260.36, y = -943.66, z = 30.22, heading = 0.0 },
    ipl           = nil,
  },
  {
    id            = 4,
    label         = 'Loft Mirror Park',
    type          = 'apartment',
    price         = 200000,
    enter_pos     = { x = 1097.10, y = -526.78, z = 57.60 },
    interior_pos  = { x = 1097.00, y = -512.55, z = 56.60, heading = 270.0 },
    ipl           = nil,
  },
  {
    id            = 5,
    label         = 'Appartement Rockford Hills',
    type          = 'apartment',
    price         = 320000,
    enter_pos     = { x = -743.43, y = 609.72, z = 144.29 },
    interior_pos  = { x = -740.00, y = 621.93, z = 143.29, heading = 180.0 },
    ipl           = nil,
  },
  {
    id            = 6,
    label         = 'Studio East LS',
    type          = 'apartment',
    price         = 35000,
    enter_pos     = { x = 73.77, y = -1383.12, z = 29.37 },
    interior_pos  = { x = 78.60, y = -1372.30, z = 28.37, heading = 90.0 },
    ipl           = nil,
  },
}

-- PNJ agents immobiliers (modele + coords + heading).
Properties.Agents = {
  {
    model   = 'a_m_y_business_01',
    coords  = vec4(-264.49, -959.56, 31.22, 205.0),
    label   = 'Agence immobiliere [E]',
  },
  {
    model   = 'a_m_y_business_01',
    coords  = vec4(372.49, 327.40, 103.57, 350.0),
    label   = 'Agence immobiliere [E]',
  },
}

-- Coffre : grille de slots par propriete.
Properties.StashSlots  = 30
Properties.StashMaxWeight = 30000  -- grammes

-- Rayon des zones d'interaction (portes + coffre + sortie).
Properties.EnterRadius  = 2.5
Properties.StashRadius  = 1.8
Properties.ExitRadius   = 2.0
