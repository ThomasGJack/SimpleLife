print('[sl-death/client] main.lua loaded')

-- ============================================================
-- Etat local (miroir du cache serveur)
-- ============================================================
local state      = 'alive'   -- 'alive' | 'downed' | 'dead'
local bleedLevel = 0
local timerRemaining = Death.DeathTimerSec or 300

-- Flags de controle des threads
local isMonitoring  = false
local isShowingHud  = false
local downedAnimLoaded = false

-- ============================================================
-- Helpers
-- ============================================================
local function clamp(v, mn, mx)
  if v < mn then return mn end
  if v > mx then return mx end
  return v
end

local function getPed()
  return PlayerPedId()
end

-- Verifier que le ped existe et est valide
local function pedValid()
  local ped = getPed()
  return ped and ped ~= 0 and DoesEntityExist(ped)
end

-- ============================================================
-- Disabling des controles en etat downed
-- ============================================================
local function disableDownedControls()
  for _, ctrl in ipairs(Death.DisabledControls or {}) do
    DisableControlAction(0, ctrl, true)
  end
end

-- ============================================================
-- Animation au sol
-- Essaye le scenario dead, sinon ragdoll
-- ============================================================
local function playDownedAnim(ped)
  if not downedAnimLoaded then
    local dict = Death.DownedAnimDict or 'dead'
    if not HasAnimDictLoaded(dict) then
      RequestAnimDict(dict)
      local tries = 0
      while not HasAnimDictLoaded(dict) and tries < 40 do
        Wait(100)
        tries = tries + 1
      end
    end
    downedAnimLoaded = HasAnimDictLoaded(Death.DownedAnimDict or 'dead')
  end

  if downedAnimLoaded then
    TaskPlayAnim(
      ped,
      Death.DownedAnimDict or 'dead',
      Death.DownedAnimName or 'dead_a',
      1.0, 1.0, -1,
      1,    -- flag 1 = loop
      0, false, false, false
    )
  elseif Death.RagdollFallback then
    SetPedToRagdoll(ped, 3000, 3000, 0, false, false, false)
  end
end

-- Stoppe l anim en cours
local function stopDownedAnim(ped)
  ClearPedTasks(ped)
end

-- ============================================================
-- Thread de surveillance HP (monitoring state = 'alive')
-- Detects passage sous le seuil HP -> envoie au serveur
-- ============================================================
local function startMonitoring()
  if isMonitoring then return end
  isMonitoring = true
  CreateThread(function()
    while state == 'alive' do
      Wait(250)
      if not pedValid() then Wait(500); goto continue end
      local ped = getPed()
      local hp  = GetEntityHealth(ped)
      -- HP <= seuil et joueur vivant GTA -> on passe downed
      if hp <= (Death.DownedThreshold or 100) and not IsEntityDead(ped) then
        -- Fixer HP a la valeur non-mortelle
        SetEntityHealth(ped, Death.DownedHP or 101)
        -- Signaler au serveur
        state = 'downed'   -- optimistic local
        TriggerServerEvent('sl:death:clientDowned')
        break
      end
      -- Si GTA tue le ped quand meme (edge case), reforcer
      if IsEntityDead(ped) and state == 'alive' then
        NetworkResurrectLocalPlayer(
          GetEntityCoords(ped),
          GetEntityHeading(ped),
          true, true
        )
        SetEntityHealth(ped, Death.DownedHP or 101)
        state = 'downed'
        TriggerServerEvent('sl:death:clientDowned')
        break
      end
      ::continue::
    end
    isMonitoring = false
  end)
end

-- ============================================================
-- Thread downed : desactive les controles, maintient l anim,
-- gere le timer de mort
-- ============================================================
local function startDownedLoop()
  if isShowingHud then return end
  isShowingHud = true
  timerRemaining = Death.DeathTimerSec or 300

  CreateThread(function()
    -- Lancer l anim initiale
    local ped = getPed()
    if pedValid() then
      playDownedAnim(ped)
    end

    -- Notification
    lib.notify({
      description = 'Vous etes a terre...',
      type        = 'error',
      duration    = 5000,
    })

    while state == 'downed' do
      Wait(0)

      if not pedValid() then Wait(500); goto cont end
      ped = getPed()

      -- Bloquer les controles
      disableDownedControls()

      -- Empecher la mort GTA
      if GetEntityHealth(ped) <= (Death.DownedThreshold or 100) then
        SetEntityHealth(ped, Death.DownedHP or 101)
      end

      -- Maintenir l anim si elle s est arretee
      if not IsEntityPlayingAnim(ped,
        Death.DownedAnimDict or 'dead',
        Death.DownedAnimName or 'dead_a', 3) then
        if downedAnimLoaded then
          TaskPlayAnim(
            ped,
            Death.DownedAnimDict or 'dead',
            Death.DownedAnimName or 'dead_a',
            1.0, 1.0, -1, 1, 0, false, false, false
          )
        end
      end

      -- Afficher prompt (DrawText2d via ox_lib si disponible, sinon DrawText custom)
      -- On utilise BeginTextCommandDisplayText pour rester propre
      if timerRemaining > 0 then
        SetTextFont(4)
        SetTextScale(0.4, 0.4)
        SetTextColour(220, 50, 50, 220)
        SetTextDropShadow()
        SetTextEntry('STRING')
        AddTextComponentString(('Vous etes a terre... %ds'):format(math.floor(timerRemaining)))
        DrawText(0.5, 0.92)
      end

      ::cont::
    end

    isShowingHud = false
  end)
end

-- ============================================================
-- Fade out / fade in utilitaire
-- ============================================================
local function fadeOut(ms)
  DoScreenFadeOut(ms or Death.FadeMs or 1500)
  Wait((ms or Death.FadeMs or 1500) + 200)
end

local function fadeIn(ms)
  DoScreenFadeIn(ms or Death.FadeMs or 1500)
end

-- ============================================================
-- Logique de respawn cote client
-- ============================================================
local function doRespawn(coords, fee)
  local ped = getPed()
  if not pedValid() then return end

  -- Stopper l anim
  stopDownedAnim(ped)

  -- Fade out
  fadeOut()

  -- TP a l hopital
  local x = (coords and coords.x) or Death.HospitalCoords.x
  local y = (coords and coords.y) or Death.HospitalCoords.y
  local z = (coords and coords.z) or Death.HospitalCoords.z

  SetEntityCoords(ped, x, y, z, false, false, false, true)

  -- Remettre HP a 50%
  local maxHp    = 200
  local targetHp = math.floor(maxHp * (Death.RespawnHPPercent / 100.0))
  SetEntityHealth(ped, targetHp)

  -- Ressuciter si mort GTA
  NetworkResurrectLocalPlayer(
    vector3(x, y, z),
    GetEntityHeading(ped),
    true, true
  )
  SetEntityHealth(ped, targetHp)

  -- Effacer les blessures visuelles
  ClearPedBloodDamage(ped)
  ClearPedLastWeaponDamage(ped)

  -- Fade in
  Wait(200)
  fadeIn()

  -- ACK serveur
  TriggerServerEvent('sl:death:clientRespawnDone')

  -- Mettre a jour l etat local
  state      = 'alive'
  bleedLevel = 0

  lib.notify({
    description = ('Vous avez ete hospitalise.%s'):format(
      fee and fee > 0 and (' Frais : $' .. tostring(fee)) or ''),
    type        = 'inform',
    duration    = 6000,
  })

  -- Relancer la surveillance HP
  startMonitoring()
end

-- ============================================================
-- Logique de revive (par medecin ou admin)
-- ============================================================
local function doRevive(by)
  local ped = getPed()
  if not pedValid() then return end

  -- Stopper l anim
  stopDownedAnim(ped)

  -- Ressuciter si le ped GTA est reellement mort (edge case)
  if IsEntityDead(ped) then
    NetworkResurrectLocalPlayer(
      GetEntityCoords(ped),
      GetEntityHeading(ped),
      true, true
    )
  end

  -- Remettre HP plein
  SetEntityHealth(ped, 200)
  ClearPedBloodDamage(ped)
  ClearPedLastWeaponDamage(ped)

  state      = 'alive'
  bleedLevel = 0

  lib.notify({
    description = 'Vous avez ete revive.',
    type        = 'success',
    duration    = 5000,
  })

  -- Relancer la surveillance
  startMonitoring()
end

-- ============================================================
-- Bus events (serveur -> client via sl:bus:dispatch)
-- ============================================================
RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  if not event then return end

  -- Joueur tombe
  if event == 'sl:death:downed' then
    state = 'downed'
    startDownedLoop()

  -- Force downed (Kill)
  elseif event == 'sl:death:forceDowned' then
    local ped = getPed()
    if pedValid() then
      SetEntityHealth(ped, Death.DownedHP or 101)
    end
    state = 'downed'
    TriggerServerEvent('sl:death:clientDowned')

  -- Revive par medecin/admin
  elseif event == 'sl:death:doRevive' then
    state = 'alive'
    doRevive(payload and payload.by)

  -- Respawn hopital
  elseif event == 'sl:death:doRespawn' then
    state = 'dead'
    CreateThread(function()
      doRespawn(payload and payload.coords, payload and payload.fee)
    end)

  -- Mise a jour du timer (tick serveur)
  elseif event == 'sl:death:timerTick' then
    if payload then
      timerRemaining = tonumber(payload.remaining) or timerRemaining
      bleedLevel     = tonumber(payload.bleed)     or bleedLevel
    end

  -- Bleed change
  elseif event == 'sl:death:bleedChanged' then
    if payload then
      bleedLevel = tonumber(payload.level) or bleedLevel
    end

  -- Respawn confirme
  elseif event == 'sl:death:respawned' then
    state      = 'alive'
    bleedLevel = 0
  end
end)

-- ============================================================
-- Initialisation au character selected
-- ============================================================
AddEventHandler('sl:core:characterSelected', function()
  state      = 'alive'
  bleedLevel = 0
  timerRemaining = Death.DeathTimerSec or 300
  downedAnimLoaded = false

  -- Petit delai pour s assurer que le ped est spawn
  CreateThread(function()
    Wait(1500)
    -- Fetch etat initial depuis le serveur (cas reconnexion, etc.)
    local res = lib.callback.await('sl-death:getState', false)
    if res then
      state      = res.state or 'alive'
      bleedLevel = res.bleed or 0
    end

    if state == 'downed' then
      startDownedLoop()
    else
      startMonitoring()
    end
  end)
end)

-- ============================================================
-- Cleanup / reinit au resource stop (hot reload dev)
-- ============================================================
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  -- Restaurer les controles / etat si le module est stoppe en cours de jeu
  local ped = pedValid() and getPed() or nil
  if ped and state == 'downed' then
    stopDownedAnim(ped)
    SetEntityHealth(ped, 200)
  end
  state         = 'alive'
  isMonitoring  = false
  isShowingHud  = false
end)
