-- ===========================================================================
-- sl-ems — configuration partagee client + serveur
-- ===========================================================================

EMS = EMS or {}

-- Duree en ms du soin selon le type
EMS.ReviveTime    = 8000   -- ms, barre de progression revive
EMS.HealTime      = 5000   -- ms, barre de progression soin

-- XP medical par action (via sl-skills, pcall)
EMS.XP = {
  revive = 40,
  heal   = 10,
  bill   = 5,
}

-- Distance max pour interagir avec un joueur (revive, soin)
EMS.InteractDistance = 3.5

-- Sante restored par HealTarget sans montant explicite
EMS.DefaultHealAmount = 50

-- Sante max GTA (ped health va de 0 a 200, 100 = pleine vie hors armure)
EMS.MaxHealth = 200
EMS.MinHealth = 100   -- minimum rendu par heal (correspond a 0 hp affiches en jeu)

-- Items consommables EMS et leur effet (montant HP rendu)
EMS.HealItems = {
  bandage    = 15,
  medkit     = 50,
  painkillers = 20,
  suture_kit  = 35,
  oxygen_mask = 25,
}

-- Coords hopital Pillbox (destination transport brancard)
EMS.HospitalCoords = vector3(341.0, -1397.3, 32.5)

-- Cooldown entre deux revives sur la meme cible (secondes)
EMS.ReviveCooldown = 30

-- Montant par defaut propose pour la facture
EMS.DefaultBillAmount = 500

-- Montant max autorise pour une facture
EMS.MaxBillAmount = 10000

-- Anim CPR / soins
EMS.Anims = {
  revive = { dict = 'mini@cpr',     clip = 'cpr_pumpchest',  duration = 8000, flag = 1 },
  heal   = { dict = 'amb@medic@standing@tendtowounded@base', clip = 'base', duration = 5000, flag = 1 },
}

-- Tableau zones du corps pour le diagnostic
EMS.BodyZones = {
  { id = 'head',    label = 'Tete'         },
  { id = 'torso',   label = 'Torse'        },
  { id = 'larm',    label = 'Bras gauche'  },
  { id = 'rarm',    label = 'Bras droit'   },
  { id = 'lleg',    label = 'Jambe gauche' },
  { id = 'rleg',    label = 'Jambe droite' },
}

-- Seuils HP -> gravite blessure
EMS.InjurySeverity = {
  { threshold = 180, label = 'Aucune',    color = '#4ade80' },
  { threshold = 140, label = 'Legere',    color = '#ffb000' },
  { threshold =  90, label = 'Moderee',   color = '#ff7a18' },
  { threshold =   0, label = 'Grave',     color = '#c8362d' },
}

-- Job requis pour facturer
EMS.JobName = 'ambulance'
