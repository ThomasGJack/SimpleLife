Clothing = Clothing or {}

Clothing.DefaultModels = {
  m = 'mp_m_freemode_01',
  f = 'mp_f_freemode_01',
}

Clothing.Shops = {
  { x = 75.21, y = -1392.16, z = 29.38, h = 207.0, label = 'Binco Pillbox' },
  { x = -703.07, y = -152.20, z = 36.42, h = 119.0, label = 'Suburban Hawick' },
  { x = -169.39, y = -302.66, z = 39.73, h = 248.0, label = 'Suburban Downtown' },
  { x = 425.40, y = -806.46, z = 28.49, h = 87.0, label = 'Ponsonbys' },
  { x = -1098.10, y = -2702.40, z = 13.83, h = 232.0, label = 'Aeroport' },
  { x = 1696.30, y = 4830.20, z = 41.99, h = 90.0, label = 'Grapeseed' },
  { x = 6.32, y = 6512.20, z = 31.40, h = 31.0, label = 'Paleto' },
}

Clothing.Blip = {
  sprite = 73,
  color = 47,
  scale = 0.8,
  name = 'Magasin de vetements',
}

Clothing.Components = {
  { id = 11, label = 'Torse', price = 120, key = 'torso' },
  { id = 3, label = 'Bras', price = 50, key = 'arms' },
  { id = 8, label = 'T-shirt', price = 40, key = 'tshirt' },
  { id = 9, label = 'Gilet', price = 90, key = 'vest' },
  { id = 10, label = 'Decalque', price = 25, key = 'decal' },
  { id = 4, label = 'Pantalon', price = 80, key = 'pants' },
  { id = 6, label = 'Chaussures', price = 60, key = 'shoes' },
  { id = 5, label = 'Sac', price = 100, key = 'bag' },
  { id = 7, label = 'Chaine', price = 30, key = 'chain' },
}

Clothing.Props = {
  { id = 0, label = 'Casque', price = 50, key = 'helmet' },
  { id = 1, label = 'Lunettes', price = 40, key = 'glasses' },
  { id = 2, label = 'Oreilles', price = 30, key = 'ears' },
  { id = 6, label = 'Montre', price = 70, key = 'watch' },
  { id = 7, label = 'Bracelet', price = 60, key = 'bracelet' },
}

Clothing.DefaultAppearance = function(sex)
  local model = (sex == 'f') and Clothing.DefaultModels.f or Clothing.DefaultModels.m
  return {
    model = model,
    components = {
      [0] = { drawable = 0, texture = 0 },
      [1] = { drawable = 0, texture = 0 },
      [2] = { drawable = 0, texture = 0 },
      [3] = { drawable = 15, texture = 0 },
      [4] = { drawable = sex == 'f' and 14 or 21, texture = 0 },
      [5] = { drawable = 0, texture = 0 },
      [6] = { drawable = sex == 'f' and 35 or 34, texture = 0 },
      [7] = { drawable = 0, texture = 0 },
      [8] = { drawable = 15, texture = 0 },
      [9] = { drawable = 0, texture = 0 },
      [10] = { drawable = 0, texture = 0 },
      [11] = { drawable = 15, texture = 0 },
    },
    props = {
      [0] = { drawable = -1, texture = 0 },
      [1] = { drawable = -1, texture = 0 },
      [2] = { drawable = -1, texture = 0 },
      [6] = { drawable = -1, texture = 0 },
      [7] = { drawable = -1, texture = 0 },
    },
  }
end

--[[
  Les presets utilisent des drawables vanilla GTA V pour mp_m_freemode_01 / mp_f_freemode_01.
  Avec sl-dlc activé, certains indices peuvent décaler.
  Utilise /clothing_dump en jeu pour voir tes drawables actuels et les copier ici
  pour créer tes propres tenues.
]]

Clothing.Presets = {
  {
    id = 'civil_casual_m',
    label = 'Civil casual',
    sex = 'm',
    price = 350,
    components = {
      [1] = { drawable = 0, texture = 0 },
      [3] = { drawable = 0, texture = 0 },
      [4] = { drawable = 1, texture = 0 },
      [6] = { drawable = 1, texture = 0 },
      [7] = { drawable = 0, texture = 0 },
      [8] = { drawable = 0, texture = 0 },
      [9] = { drawable = 0, texture = 0 },
      [11] = { drawable = 15, texture = 0 },
    },
    props = {
      [0] = { drawable = -1, texture = 0 }, [1] = { drawable = -1, texture = 0 },
    },
  },
  {
    id = 'business_m',
    label = 'Costume sombre',
    sex = 'm',
    price = 750,
    components = {
      [1] = { drawable = 0, texture = 0 },
      [3] = { drawable = 4, texture = 0 },
      [4] = { drawable = 24, texture = 0 },
      [6] = { drawable = 12, texture = 0 },
      [7] = { drawable = 9, texture = 0 },
      [8] = { drawable = 38, texture = 0 },
      [9] = { drawable = 0, texture = 0 },
      [11] = { drawable = 32, texture = 0 },
    },
    props = {
      [0] = { drawable = -1, texture = 0 }, [1] = { drawable = -1, texture = 0 },
    },
  },
  {
    id = 'sport_m',
    label = 'Sport',
    sex = 'm',
    price = 280,
    components = {
      [1] = { drawable = 0, texture = 0 },
      [3] = { drawable = 1, texture = 0 },
      [4] = { drawable = 39, texture = 0 },
      [6] = { drawable = 49, texture = 1 },
      [7] = { drawable = 0, texture = 0 },
      [8] = { drawable = 15, texture = 0 },
      [9] = { drawable = 0, texture = 0 },
      [11] = { drawable = 86, texture = 0 },
    },
    props = {
      [0] = { drawable = -1, texture = 0 }, [1] = { drawable = -1, texture = 0 },
    },
  },
  {
    id = 'tactical_m',
    label = 'Tactique',
    sex = 'm',
    price = 850,
    components = {
      [1] = { drawable = 0, texture = 0 },
      [3] = { drawable = 13, texture = 0 },
      [4] = { drawable = 73, texture = 0 },
      [6] = { drawable = 24, texture = 0 },
      [7] = { drawable = 0, texture = 0 },
      [8] = { drawable = 31, texture = 0 },
      [9] = { drawable = 13, texture = 0 },
      [11] = { drawable = 49, texture = 0 },
    },
    props = {
      [0] = { drawable = -1, texture = 0 }, [1] = { drawable = -1, texture = 0 },
    },
  },
  {
    id = 'street_m',
    label = 'Style rue',
    sex = 'm',
    price = 420,
    components = {
      [1] = { drawable = 0, texture = 0 },
      [3] = { drawable = 4, texture = 0 },
      [4] = { drawable = 4, texture = 0 },
      [6] = { drawable = 1, texture = 5 },
      [7] = { drawable = 0, texture = 0 },
      [8] = { drawable = 15, texture = 0 },
      [9] = { drawable = 0, texture = 0 },
      [11] = { drawable = 31, texture = 0 },
    },
    props = {
      [0] = { drawable = 60, texture = 0 }, [1] = { drawable = -1, texture = 0 },
    },
  },
  {
    id = 'beach_m',
    label = 'Plage',
    sex = 'm',
    price = 200,
    components = {
      [1] = { drawable = 0, texture = 0 },
      [3] = { drawable = 0, texture = 0 },
      [4] = { drawable = 14, texture = 0 },
      [6] = { drawable = 6, texture = 0 },
      [7] = { drawable = 0, texture = 0 },
      [8] = { drawable = 15, texture = 0 },
      [9] = { drawable = 0, texture = 0 },
      [11] = { drawable = 15, texture = 0 },
    },
    props = {
      [0] = { drawable = -1, texture = 0 }, [1] = { drawable = 5, texture = 0 },
    },
  },
  {
    id = 'civil_casual_f',
    label = 'Civil casual',
    sex = 'f',
    price = 350,
    components = {
      [1] = { drawable = 0, texture = 0 },
      [3] = { drawable = 4, texture = 0 },
      [4] = { drawable = 15, texture = 0 },
      [6] = { drawable = 35, texture = 0 },
      [7] = { drawable = 0, texture = 0 },
      [8] = { drawable = 14, texture = 0 },
      [9] = { drawable = 0, texture = 0 },
      [11] = { drawable = 15, texture = 0 },
    },
    props = {
      [0] = { drawable = -1, texture = 0 }, [1] = { drawable = -1, texture = 0 },
    },
  },
  {
    id = 'business_f',
    label = 'Costume',
    sex = 'f',
    price = 750,
    components = {
      [1] = { drawable = 0, texture = 0 },
      [3] = { drawable = 4, texture = 0 },
      [4] = { drawable = 10, texture = 0 },
      [6] = { drawable = 24, texture = 0 },
      [7] = { drawable = 0, texture = 0 },
      [8] = { drawable = 36, texture = 0 },
      [9] = { drawable = 0, texture = 0 },
      [11] = { drawable = 25, texture = 0 },
    },
    props = {
      [0] = { drawable = -1, texture = 0 }, [1] = { drawable = -1, texture = 0 },
    },
  },
}
