Hunger = Hunger or {}

-- ===========================================================================
-- Stats persistées (faim + soif). Stamina vit côté client uniquement.
-- ===========================================================================
Hunger.MaxValue   = 100
Hunger.StartValue = 100   -- valeur initiale au 1er spawn d'un perso

-- Rythme de décrément :
--   - Faim : -1 / 6 min  (~10h pour atteindre 0)
--   - Soif : -1 / 4 min  (~6h40 pour atteindre 0)
Hunger.HungerIntervalSec = 6 * 60
Hunger.ThirstIntervalSec = 4 * 60

-- Fréquence du tick serveur (regroupe les décrémentations).
Hunger.ServerTickSec = 30

-- Fréquence à laquelle on persiste si dirty (réduit les writes DB).
Hunger.SaveIntervalSec = 120

-- ===========================================================================
-- Stamina (client-only, non persistée)
-- ===========================================================================
Hunger.StaminaMax        = 100
Hunger.StaminaDrainPerSec = 1.6     -- baisse en sprint
Hunger.StaminaRegenPerSec = 3.0     -- regen quand au repos
Hunger.StaminaDrainBoost  = 1.5     -- multiplicateur drain si faim<30 ou soif<30

-- Si faim ou soif est sous ce seuil → sprint complètement désactivé
Hunger.SprintLockThreshold = 10

-- ===========================================================================
-- Conséquences à zéro : dégâts + ralentissement
-- ===========================================================================
Hunger.DamageIntervalSec = 30   -- -1 PV toutes les Xs si une stat est à 0
Hunger.DamagePerTick     = 1

-- ===========================================================================
-- Alertes notifications (seuils en pourcent)
-- Tableau ordonné DÉCROISSANT, première traversée descendante = alerte.
-- ===========================================================================
Hunger.AlertThresholds = { 20, 0 }

-- Couleurs (passées au CSS via variables JS)
Hunger.HUDColors = {
  green  = '#4ade80',  -- > 60 %
  yellow = '#fbbf24',  -- 30-60 %
  orange = '#fb923c',  -- 10-30 %
  red    = '#ef4444',  -- < 10 %
}

-- ===========================================================================
-- Helpers
-- ===========================================================================
function Hunger.ColorFor(pct)
  if pct >= 60 then return Hunger.HUDColors.green end
  if pct >= 30 then return Hunger.HUDColors.yellow end
  if pct >= 10 then return Hunger.HUDColors.orange end
  return Hunger.HUDColors.red
end
