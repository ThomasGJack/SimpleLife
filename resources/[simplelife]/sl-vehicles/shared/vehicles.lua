-- =============================================================================
-- sl-vehicles / shared/vehicles.lua
-- Catalogue ~40 vehicules GTA V vanilla, 6 categories
-- =============================================================================

Vehicles = Vehicles or {}

Vehicles.Catalog = {
  -- =========================================================================
  -- COMPACT
  -- =========================================================================
  { model = 'blista',     label = 'Blista',          category = 'compact',  price = 11500  },
  { model = 'panto',      label = 'Panto',            category = 'compact',  price = 10000  },
  { model = 'dilettante', label = 'Dilettante',       category = 'compact',  price = 13000  },
  { model = 'prairie',    label = 'Prairie',          category = 'compact',  price = 9500   },
  { model = 'issi2',      label = 'Issi Classic',     category = 'compact',  price = 12000  },
  { model = 'brioso',     label = 'Brioso R/A',       category = 'compact',  price = 14500  },

  -- =========================================================================
  -- SEDAN
  -- =========================================================================
  { model = 'asea',       label = 'Asea',             category = 'sedan',    price = 18000  },
  { model = 'premier',    label = 'Premier',           category = 'sedan',    price = 20000  },
  { model = 'primo',      label = 'Primo',             category = 'sedan',    price = 16000  },
  { model = 'stanier',    label = 'Stanier',           category = 'sedan',    price = 19000  },
  { model = 'washington', label = 'Washington',        category = 'sedan',    price = 22000  },
  { model = 'tailgater',  label = 'Tailgater',         category = 'sedan',    price = 32000  },

  -- =========================================================================
  -- SPORT
  -- =========================================================================
  { model = 'comet2',     label = 'Comet',             category = 'sport',    price = 75000  },
  { model = 'banshee',    label = 'Banshee',           category = 'sport',    price = 90000  },
  { model = 'elegy',      label = 'Elegy RH8',         category = 'sport',    price = 0      },
  { model = 'jester',     label = 'Jester',            category = 'sport',    price = 80000  },
  { model = 'feltzer2',   label = 'Feltzer',           category = 'sport',    price = 68000  },
  { model = 'sultan',     label = 'Sultan',            category = 'sport',    price = 62000  },

  -- =========================================================================
  -- SUV
  -- =========================================================================
  { model = 'baller',     label = 'Baller',            category = 'suv',      price = 40000  },
  { model = 'granger',    label = 'Granger',           category = 'suv',      price = 36000  },
  { model = 'dubsta',     label = 'Dubsta',            category = 'suv',      price = 45000  },
  { model = 'rocoto',     label = 'Rocoto',            category = 'suv',      price = 38000  },
  { model = 'xls',        label = 'XLS',               category = 'suv',      price = 55000  },
  { model = 'cavalcade',  label = 'Cavalcade',         category = 'suv',      price = 42000  },

  -- =========================================================================
  -- MOTO
  -- =========================================================================
  { model = 'akuma',      label = 'Akuma',             category = 'moto',     price = 9000   },
  { model = 'bati',       label = 'Bati 801',          category = 'moto',     price = 15000  },
  { model = 'sanchez',    label = 'Sanchez',           category = 'moto',     price = 7500   },
  { model = 'pcj',        label = 'PCJ 600',           category = 'moto',     price = 11000  },
  { model = 'nemesis',    label = 'Nemesis',           category = 'moto',     price = 12000  },
  { model = 'vader',      label = 'Vader',             category = 'moto',     price = 8500   },

  -- =========================================================================
  -- UTILITY
  -- =========================================================================
  { model = 'bison',      label = 'Bison',             category = 'utility',  price = 28000  },
  { model = 'burrito',    label = 'Burrito',           category = 'utility',  price = 24000  },
  { model = 'rumpo',      label = 'Rumpo',             category = 'utility',  price = 26000  },
  { model = 'mule',       label = 'Mule',              category = 'utility',  price = 35000  },
  { model = 'speedo',     label = 'Speedo',            category = 'utility',  price = 22000  },
  { model = 'pony',       label = 'Pony',              category = 'utility',  price = 20000  },
}

-- Lookup par modele
function Vehicles.GetByModel(model)
  for _, v in ipairs(Vehicles.Catalog) do
    if v.model == model then return v end
  end
  return nil
end

-- Retourne la liste par categorie
function Vehicles.GetByCategory(cat)
  local out = {}
  for _, v in ipairs(Vehicles.Catalog) do
    if v.category == cat then out[#out+1] = v end
  end
  return out
end
