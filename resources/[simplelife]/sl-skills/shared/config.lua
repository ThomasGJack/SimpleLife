Skills = Skills or {}

-- ===========================================================================
-- Liste des competences disponibles
-- ===========================================================================
Skills.List = {
  'driving',
  'strength',
  'shooting',
  'crafting',
  'medical',
  'mechanic',
  'farming',
  'dealing',
}

-- ===========================================================================
-- Labels lisibles pour les notifications et affichage
-- ===========================================================================
Skills.Labels = {
  driving  = 'Conduite',
  strength = 'Force',
  shooting = 'Tir',
  crafting = 'Artisanat',
  medical  = 'Medecine',
  mechanic = 'Mecanique',
  farming  = 'Agriculture',
  dealing  = 'Commerce',
}

-- ===========================================================================
-- Courbe XP -> niveau
--   level = floor(sqrt(xp / XpPerLevelSq)), borne 0-100
--   Exemple : niveau 1 = 100 XP, niveau 10 = 10 000 XP, niveau 50 = 250 000 XP
-- ===========================================================================
Skills.MaxLevel      = 100
Skills.XpPerLevelSq  = 100   -- coefficient K : level = floor(sqrt(xp / K))

-- XP maximum stocke (niveau 100 = 100^2 * K = 1 000 000)
Skills.MaxXP = Skills.MaxLevel * Skills.MaxLevel * Skills.XpPerLevelSq

-- Calcule le niveau a partir des XP (partageable server+client)
function Skills.XpToLevel(xp)
  if not xp or xp <= 0 then return 0 end
  local lv = math.floor(math.sqrt(xp / Skills.XpPerLevelSq))
  if lv > Skills.MaxLevel then lv = Skills.MaxLevel end
  return lv
end

-- XP minimum pour atteindre un niveau donne
function Skills.LevelToXp(level)
  if not level or level <= 0 then return 0 end
  if level > Skills.MaxLevel then level = Skills.MaxLevel end
  return level * level * Skills.XpPerLevelSq
end

-- ===========================================================================
-- Frequence de sauvegarde periodique (secondes)
-- ===========================================================================
Skills.SaveIntervalSec = 120

-- ===========================================================================
-- Bonus passifs (documentation pour les modules consommateurs)
-- Ces valeurs sont indicatives en V1.
-- Un module consommateur lit GetLevel(src, skill) et applique le bonus.
-- ===========================================================================
Skills.Bonuses = {
  -- Conduite : reduit les degats en voiture proportionnellement au niveau
  -- Formula consommatrice : damageMultiplier = 1.0 - (level / 100) * 0.4  (jusqu a -40% a 100)
  driving  = { type = 'damage_reduction_vehicle', maxPct = 0.40 },

  -- Force : augmente les degats au corps a corps
  -- Formula : meleeDmgBonus = (level / 100) * 0.50  (jusqu a +50% a 100)
  strength = { type = 'melee_damage_bonus', maxPct = 0.50 },

  -- Tir : reduit le recul et ameliore la precision
  -- Formula : recoilReduction = (level / 100) * 0.35
  shooting = { type = 'recoil_reduction', maxPct = 0.35 },

  -- Artisanat : augmente les chances de qualite superieure
  -- Formula : craftBonusChance = (level / 100) * 0.30
  crafting = { type = 'craft_quality_bonus', maxPct = 0.30 },

  -- Medecine : augmente l efficacite des soins
  -- Formula : healBonus = (level / 100) * 0.50
  medical  = { type = 'heal_effectiveness', maxPct = 0.50 },

  -- Mecanique : reduit le temps de reparation
  -- Formula : repairSpeedBonus = (level / 100) * 0.40
  mechanic = { type = 'repair_speed', maxPct = 0.40 },

  -- Agriculture : augmente les rendements de recolte
  -- Formula : harvestBonus = (level / 100) * 0.60
  farming  = { type = 'harvest_yield', maxPct = 0.60 },

  -- Commerce : reduit les taxes / augmente les prix de vente
  -- Formula : priceBonus = (level / 100) * 0.25
  dealing  = { type = 'price_bonus', maxPct = 0.25 },
}

-- Helper : retourne le multiplicateur de bonus entre 0.0 et maxPct selon le niveau
function Skills.BonusValue(skill, level)
  local b = Skills.Bonuses[skill]
  if not b then return 0.0 end
  return (level / Skills.MaxLevel) * b.maxPct
end
