print('[sl-death/server] api.lua loaded')

local SL = exports['sl-core']

-- ============================================================
-- Helpers locaux
-- ============================================================
local function clamp(v, mn, mx)
  if v < mn then return mn end
  if v > mx then return mx end
  return v
end

-- ============================================================
-- IsDowned(src) -> bool
-- ============================================================
local function IsDowned(source)
  local entry = GetEntry(source)
  if not entry then return false end
  return entry.state == 'downed'
end
exports('IsDowned', IsDowned)

-- ============================================================
-- Revive(src) : remet alive, HP plein, annule anims cote client
-- ============================================================
local function Revive(source, by)
  local entry = GetEntry(source)
  if not entry then return false, 'not loaded' end
  if entry.state == 'alive' then return true end   -- deja vivant, pas d erreur

  SetStatePublic(source, 'alive', by)
  -- Demander au client de remettre HP + stop anims via le dispatch
  DispatchClient(source, 'sl:death:doRevive', { source = source, by = by or 0 })
  TriggerClientEvent('ox_lib:notify', source, {
    description = 'Vous avez ete revive.',
    type        = 'success',
  })
  return true
end
exports('Revive', Revive)

-- ============================================================
-- Kill(src) : force downed immediat (ex: execution)
-- ============================================================
local function Kill(source)
  local entry = GetEntry(source)
  if not entry then return false, 'not loaded' end
  SetStatePublic(source, 'downed')
  DispatchClient(source, 'sl:death:forceDowned', { source = source })
  return true
end
exports('Kill', Kill)

-- ============================================================
-- SetBleed(src, level) : 0-3
-- ============================================================
local function SetBleed(source, level)
  return SetBleedInternal(source, level)
end
exports('SetBleed', SetBleed)

-- ============================================================
-- RespawnToHospital(src) : TP Pillbox + frais + etat alive
-- ============================================================
function RespawnToHospital(source)
  local entry = GetEntry(source)
  if not entry then return false, 'not loaded' end

  -- Passer en dead puis alive (pour reset propre de l etat)
  entry.state      = 'dead'
  entry.bleedLevel = 0
  entry.downedAt   = nil

  -- Frais d hospitalisation (soft, on ne bloque pas si insuffisant)
  if Death.HospitalFee and Death.HospitalFee > 0 then
    local ok = pcall(function()
      exports['sl-economy']:RemoveMoney(
        source,
        Death.HospitalFeeAccount or 'cash',
        Death.HospitalFee,
        'Frais hospitalisation Pillbox'
      )
    end)
    if not ok then
      print('[sl-death] WARNING: sl-economy not available, skipping hospital fee for src=' .. tostring(source))
    end
  end

  -- Notif frais
  TriggerClientEvent('ox_lib:notify', source, {
    description = ('Vous avez ete hospitalise. Frais : $%d'):format(Death.HospitalFee or 0),
    type        = 'inform',
  })

  -- Instruction au client : fade + TP + retour alive
  DispatchClient(source, 'sl:death:doRespawn', {
    source = source,
    coords = Death.HospitalCoords,
    fee    = Death.HospitalFee or 0,
  })

  -- Cote serveur on repasse alive apres le delai de fade (on fait confiance au client ACK)
  -- Le client enverra sl:death:clientRespawnDone pour confirmer
  -- En attendant, on laisse l etat a 'dead' pour eviter un double trigger
end

-- Export public Respawn (appele par commandes ou autres modules)
local function Respawn(source)
  return RespawnToHospital(source)
end
exports('Respawn', Respawn)

-- ============================================================
-- ACK client : le client a fini le fade/TP, on repasse alive
-- ============================================================
RegisterNetEvent('sl:death:clientRespawnDone', function()
  local source = source
  local entry  = GetEntry(source)
  if not entry then return end
  entry.state      = 'alive'
  entry.bleedLevel = 0
  entry.downedAt   = nil
  TriggerEvent('sl:death:respawned', { source = source })
  DispatchClient(source, 'sl:death:respawned', { source = source })
  print(('[sl-death] src=%d respawned at hospital'):format(source))
end)

-- ============================================================
-- Callback : etat courant (utilise au boot client si besoin)
-- ============================================================
lib.callback.register('sl-death:getState', function(source)
  local entry = GetEntry(source)
  if not entry then return { state = 'alive', bleed = 0 } end
  return { state = entry.state, bleed = entry.bleedLevel }
end)
