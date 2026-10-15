-- ============================================================
-- sl-police / shared/config.lua
-- ============================================================

Police = Police or {}

-- Coordonnees cles (reprises de INTEGRATION.md)
Police.Coords = {
  MRPD        = vec3(441.0, -982.0, 30.7),
  Prison      = vec3(1845.0, 2585.0, 45.0),
  PrisonExit  = vec3(1851.0, 2554.0, 45.7),
}

-- Distance pour menotter le joueur le plus proche
Police.CuffDistance   = 3.0
-- Distance pour escorter (drag)
Police.DragDistance   = 1.2
-- Duree de l'animation de menottage (ms)
Police.CuffAnimMs     = 2500

-- Modele PNJ (optionnel, non utilise en v1 — le cuffing est ped-to-ped)
Police.JobName = 'police'

-- MDT : nombre de resultats max pour la recherche
Police.MDTSearchLimit = 20

-- Blip pour le commissariat sur la carte (cops en service)
Police.MRPDBlip = {
  sprite   = 60,
  color    = 3,
  scale    = 0.9,
  name     = 'Commissariat MRPD',
}

-- Kit metier police (distribue a l'embauche + prise de service)
-- Correspond aux items declares dans sl-inventory/shared/items.lua
Police.JobKit = 'police'    -- => GiveJobKit(src, 'police')

-- Charges predefinies pour le MDT (label -> montant par defaut)
Police.DefaultCharges = {
  ['Attaque avec violence']        = 5000,
  ['Meurtre']                      = 25000,
  ['Tentative de meurtre']         = 15000,
  ['Vol de vehicule']              = 3000,
  ['Braquage']                     = 20000,
  ['Trafic de drogue']             = 10000,
  ['Possession de drogue']         = 2000,
  ['Port illegale d arme']         = 4000,
  ['Fuite de police']              = 3000,
  ['Obstruction a la justice']     = 2500,
  ['Conduite en etat d ivresse']   = 1500,
  ['Depassement de vitesse']       = 800,
  ['Stationnement illegal']        = 300,
  ['Agression verbale']            = 500,
}
