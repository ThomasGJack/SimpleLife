-- ============================================================
-- sl-death : configuration partagee serveur + client
-- ============================================================
Death = Death or {}

-- Duree avant respawn force (secondes depuis le passage en downed)
Death.DeathTimerSec = 300

-- Intervalle de drain du timer par bleedLevel (secondes retires par tick de saignement)
-- bleedLevel 0 = pas de drain supplementaire (timer normal)
-- bleedLevel 1 = -1s/tick   bleedLevel 2 = -3s/tick   bleedLevel 3 = -6s/tick
Death.BleedDrainPerLevel = { [0] = 0, [1] = 1, [2] = 3, [3] = 6 }

-- Intervalle du tick de saignement cote client (ms)
Death.BleedTickMs = 5000

-- HP GTA a partir duquel on considere le ped comme downed (<=)
-- GTA HP : 200 = plein,  100 = quasi mort (seuil non-mortel pris en charge)
Death.DownedThreshold = 100

-- HP auquel on fixe le ped en etat downed (empêche la mort GTA)
Death.DownedHP = 101

-- HP accordes au respawn hopital (pourcentage de 200 = max GTA)
-- 50% = 100 pts
Death.RespawnHPPercent = 50

-- Frais d hospitalisation (option: nil = gratuit)
-- Utilise sl-economy:RemoveMoney(src, 'cash', montant, raison)
Death.HospitalFee = 1500
Death.HospitalFeeAccount = 'cash'   -- 'cash' | 'bank'

-- Coords respawn hopital Pillbox
Death.HospitalCoords = { x = 341.0, y = -1397.3, z = 32.5 }

-- Fade out/in duree (ms)
Death.FadeMs = 1500

-- Delai entre fadeOut et teleport (ms)
Death.FadeOutWaitMs = 1200

-- Controles desactives en etat downed (sauf camera / chat)
-- voir https://docs.fivem.net/docs/game-references/controls/
Death.DisabledControls = {
  32,  -- INPUT_MOVE_UP_DOWN
  31,  -- INPUT_MOVE_LEFT_RIGHT
  22,  -- INPUT_JUMP
  44,  -- INPUT_ATTACK  (tirer)
  25,  -- INPUT_AIM
  21,  -- INPUT_SPRINT
  38,  -- INPUT_ENTER (monter en voiture)
  68,  -- INPUT_VEH_HANDBRAKE
  75,  -- INPUT_VEH_EXIT
}

-- Scenario d animation au sol (ou ragdoll si non disponible)
Death.DownedAnimDict = 'dead'
Death.DownedAnimName = 'dead_a'
-- Fallback si le dict n est pas dispo : SetPedToRagdoll
Death.RagdollFallback = true

-- Label prompt affiche en bas de l ecran en etat downed
Death.DownedPromptText = 'Vous etes a terre... (~r~' .. tostring(Death.DeathTimerSec) .. 's~w~)'
