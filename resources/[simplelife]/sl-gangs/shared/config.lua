-- ===========================================================================
-- sl-gangs / shared/config.lua
-- ===========================================================================

Gangs = Gangs or {}

-- Grades : index 0 = recrue, 4 = boss
Gangs.Grades = {
  [0] = { label = 'Recrue',     canInvite = false, canKick = false, canPromote = false },
  [1] = { label = 'Membre',     canInvite = false, canKick = false, canPromote = false },
  [2] = { label = 'Officier',   canInvite = true,  canKick = true,  canPromote = false },
  [3] = { label = 'Lieutenant', canInvite = true,  canKick = true,  canPromote = true  },
  [4] = { label = 'Boss',       canInvite = true,  canKick = true,  canPromote = true  },
}

Gangs.MaxGrade      = 4
Gangs.BossGrade     = 4

-- Territoires : liste des zones de capture
-- chaque zone a un centre (vec3) et un rayon (metres)
-- Ces zones sont seedees dans sl_gang_territories au boot si absentes
Gangs.Territories = {
  { zone = 'forum_drive',    label = 'Forum Drive',    coords = vector3(92.4,   -1960.2, 20.6),  radius = 80.0  },
  { zone = 'davis_grove',    label = 'Davis Grove',    coords = vector3(116.1,  -1736.4, 29.4),  radius = 70.0  },
  { zone = 'innocence_blvd', label = 'Innocence Blvd', coords = vector3(278.6,  -1935.6, 24.2),  radius = 75.0  },
  { zone = 'chamberlain',    label = 'Chamberlain',    coords = vector3(-6.4,   -1548.3, 29.0),  radius = 80.0  },
  { zone = 'strawberry',     label = 'Strawberry',     coords = vector3(-390.0, -1568.0, 29.0),  radius = 85.0  },
  { zone = 'little_seoul',   label = 'Little Seoul',   coords = vector3(-574.9, -710.2,  33.2),  radius = 90.0  },
  { zone = 'elysian_island', label = 'Elysian Island', coords = vector3(354.0,  -2475.7, 6.0),   radius = 100.0 },
  { zone = 'mirror_park',    label = 'Mirror Park',    coords = vector3(1200.0, -1413.0, 35.2),  radius = 80.0  },
}

-- Influence : tick (secondes) pour incrementer l'influence d'une zone
-- Chaque membre present dans la zone ajoute InfluencePerMember par tick
Gangs.InfluenceTick        = 30       -- secondes entre chaque verification de presence
Gangs.InfluencePerMember   = 2        -- influence gagnee par membre present dans la zone
Gangs.InfluenceToCapture   = 100      -- seuil pour capturer une zone
Gangs.InfluenceDecayPerTick = 1       -- perte passive par tick si le gang n'est pas present

-- Blips GTA V : couleur par defaut si le gang n'a pas de couleur reconnue
Gangs.DefaultBlipColor     = 1  -- rouge (couleur blip GTA)

-- Mapping couleur gang (nom CSS/hex) -> indice blip GTA V
-- https://docs.fivem.net/docs/game-references/blips/#blip-colors
Gangs.ColorToBlip = {
  red     = 1,
  blue    = 3,
  green   = 2,
  yellow  = 5,
  purple  = 27,
  orange  = 17,
  pink    = 8,
  white   = 4,
  black   = 0,
  cyan    = 43,
}

-- Blip sprite pour les territoires
Gangs.TerritoryBlipSprite  = 534   -- zone / cercle
Gangs.TerritoryBlipScale   = 1.0

-- Rayon de detection pour le tick influence (metres, <= zone.radius)
-- Si un membre se trouve dans ce rayon il compte comme "present"
Gangs.PresenceRadius       = 60.0
