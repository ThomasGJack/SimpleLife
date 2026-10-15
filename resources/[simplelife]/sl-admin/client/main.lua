print('[sl-admin/client] main.lua loaded')

-- ===========================================================================
-- sl-admin v0.2 : NUI custom grunge GTA V (remplace ox_lib context)
--
-- Le menu s'ouvre via /sladmin (chat ou keybind F7). Côté serveur, la commande
-- check les ACEs admin puis trigger 'sl-admin:open' vers le client.
-- ===========================================================================

local uiOpen = false
local hasFocus = false

local function setFocus(state)
  hasFocus = state
  SetNuiFocus(state, state)
  SetNuiFocusKeepInput(false)
end

local function notify(msg, kind)
  -- toast in-NUI si le panel admin est ouvert (toujours visible),
  -- ox_lib sinon (visible normalement)
  if uiOpen then
    SendNUIMessage({ action = 'toast', text = msg, kind = kind or 'inform', duration = 3000 })
  else
    lib.notify({ description = msg, type = kind or 'inform', duration = 3000 })
  end
end

local function fmtVec3(v) return ('%.2f, %.2f, %.2f'):format(v.x, v.y, v.z) end

-- ===========================================================================
-- Collecteurs d'info debug (envoyés à la NUI)
-- ===========================================================================
local function collectDebugData()
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local heading = GetEntityHeading(ped)
  local vehicle = GetVehiclePedIsIn(ped, false)
  local vmodel = (vehicle ~= 0) and GetEntityModel(vehicle) or 0
  local vplate = (vehicle ~= 0) and GetVehicleNumberPlateText(vehicle) or '—'

  local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
  local zoneName   = GetNameOfZone(coords.x, coords.y, coords.z)
  local streetName = GetStreetNameFromHashKey(streetHash)

  return {
    coords  = ('%.2f, %.2f, %.2f · h=%.0f'):format(coords.x, coords.y, coords.z, heading),
    zone    = ('%s · %s'):format(zoneName or '—', streetName or '—'),
    vehicle = vehicle ~= 0 and ('model=%d · plate=%s'):format(vmodel, vplate) or 'Aucun',
    time    = ('%02d:%02d · %s'):format(GetClockHours(), GetClockMinutes(), GetPrevWeatherTypeHashName() or ''),
  }
end

-- ===========================================================================
-- Ouverture / fermeture NUI
-- ===========================================================================
local function openAdmin()
  if uiOpen then return end
  uiOpen = true
  setFocus(true)
  SendNUIMessage({
    action = 'open',
    data = { debug = collectDebugData() },
  })
end

local function closeAdmin()
  if not uiOpen then return end
  uiOpen = false
  setFocus(false)
  SendNUIMessage({ action = 'close' })
end

-- ===========================================================================
-- NUI callbacks
-- ===========================================================================
RegisterNUICallback('close', function(_, cb)
  closeAdmin()
  cb({ ok = true })
end)

RegisterNUICallback('refreshDebug', function(_, cb)
  SendNUIMessage({ action = 'updateDebug', debug = collectDebugData() })
  cb({ ok = true })
end)

RegisterNUICallback('refreshOnline', function(_, cb)
  local players = lib.callback.await('sl-admin:getPlayers', false)
  SendNUIMessage({ action = 'updateOnline', players = players or {} })
  cb({ ok = true })
end)

-- Debug actions
RegisterNUICallback('copyCoords', function(_, cb)
  local ped = PlayerPedId()
  local c = GetEntityCoords(ped); local h = GetEntityHeading(ped)
  local s = ('vec4(%.3f, %.3f, %.3f, %.1f)'):format(c.x, c.y, c.z, h)
  print(('[sl-admin] %s'):format(s))
  notify('Copié dans la console F8 : ' .. s, 'inform')
  cb({ ok = true })
end)

RegisterNUICallback('aimedEntity', function(_, cb)
  local hit, entity = GetEntityPlayerIsFreeAimingAt(PlayerId())
  if not hit then
    notify('Vise une entité avec ton arme (clic droit).', 'error')
    cb({ ok = false }); return
  end
  local model = GetEntityModel(entity)
  local pos = GetEntityCoords(entity)
  local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or 0
  local info = ('entity=%d · model=%d · netId=%d · @ %s'):format(entity, model, netId, fmtVec3(pos))
  print('[sl-admin] aimed → ' .. info)
  notify(info, 'inform')
  cb({ ok = true })
end)

RegisterNUICallback('tpWaypoint', function(_, cb)
  local wp = GetFirstBlipInfoId(8)
  if not DoesBlipExist(wp) then
    notify('Pas de waypoint placé.', 'error')
    cb({ ok = false }); return
  end
  local pos = GetBlipInfoIdCoord(wp)
  local ped = PlayerPedId()
  SetEntityCoords(ped, pos.x, pos.y, pos.z + 1.0, false, false, false, false)
  notify(('TP → %s'):format(fmtVec3(pos)), 'success')
  cb({ ok = true })
end)

RegisterNUICallback('healSelf', function(_, cb)
  local ped = PlayerPedId()
  SetEntityHealth(ped, GetEntityMaxHealth(ped))
  SetPedArmour(ped, 100)
  notify('PV + armure max', 'success')
  cb({ ok = true })
end)

-- Player tab actions (self)
RegisterNUICallback('giveMoneySelf', function(data, cb)
  TriggerServerEvent('sl-admin:giveMoney', GetPlayerServerId(PlayerId()), data.account, tonumber(data.amount) or 0)
  notify(('Demande +%s %s envoyée.'):format(data.amount, data.account), 'inform')
  cb({ ok = true })
end)

RegisterNUICallback('refillHungerSelf', function(_, cb)
  TriggerServerEvent('sl-admin:refillHunger', GetPlayerServerId(PlayerId()))
  cb({ ok = true })
end)

RegisterNUICallback('giveItemSelf', function(data, cb)
  TriggerServerEvent('sl-admin:giveItem', GetPlayerServerId(PlayerId()), data.item, tonumber(data.qty) or 1)
  cb({ ok = true })
end)

-- Online tab actions (target = other player)
RegisterNUICallback('tpToPlayer', function(data, cb)
  local pid = GetPlayerFromServerId(tonumber(data.target) or -1)
  if pid == -1 then notify('Joueur hors-scope.', 'error'); cb({ ok = false }); return end
  local ped = GetPlayerPed(pid)
  if not ped or ped == 0 then notify('Ped introuvable.', 'error'); cb({ ok = false }); return end
  local pos = GetEntityCoords(ped)
  SetEntityCoords(PlayerPedId(), pos.x, pos.y, pos.z + 0.5, false, false, false, false)
  notify(('TP vers joueur [%d]'):format(data.target), 'success')
  cb({ ok = true })
end)

RegisterNUICallback('giveMoney', function(data, cb)
  TriggerServerEvent('sl-admin:giveMoney', tonumber(data.target), data.account, tonumber(data.amount) or 0)
  cb({ ok = true })
end)

RegisterNUICallback('refillHunger', function(data, cb)
  TriggerServerEvent('sl-admin:refillHunger', tonumber(data.target))
  cb({ ok = true })
end)

RegisterNUICallback('heal', function(data, cb)
  -- pas d'event server pour heal target encore : on log juste ; les autres modules
  -- pourraient ajouter un sl-admin:heal côté server avec teleport + SetEntityHealth.
  notify('Heal target → impl. partielle (utilise via TP).', 'inform')
  cb({ ok = true })
end)

RegisterNUICallback('giveItem', function(data, cb)
  TriggerServerEvent('sl-admin:giveItem', tonumber(data.target), data.item, tonumber(data.qty) or 1)
  cb({ ok = true })
end)

-- NoClip
RegisterNUICallback('toggleNoclip', function(_, cb)
  ToggleNoClip()
  cb({ ok = true })
end)

-- ===========================================================================
-- NoClip implementation
-- ===========================================================================
local noclipOn = false
function ToggleNoClip()
  noclipOn = not noclipOn
  local ped = PlayerPedId()
  if noclipOn then
    SetEntityInvincible(ped, true)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, false)
    notify('NoClip ON · ZQSD + espace/ctrl, shift = x3', 'inform')
    CreateThread(function()
      while noclipOn do
        Wait(0)
        local p = PlayerPedId()
        SetEntityInvincible(p, true)
        SetEntityCollision(p, false, false)
        SetEntityVisible(p, true, false)
        local cam = GetGameplayCamRot(2)
        local rx = math.rad(cam.x); local rz = math.rad(cam.z)
        local fwd = vector3(-math.sin(rz)*math.cos(rx), math.cos(rz)*math.cos(rx), math.sin(rx))
        local right = vector3(math.cos(rz), math.sin(rz), 0)
        local pos = GetEntityCoords(p)
        local mult = IsControlPressed(0, 21) and 3.0 or 1.0
        local dx, dy, dz = 0.0, 0.0, 0.0
        if IsControlPressed(0, 32) then dx = dx + fwd.x; dy = dy + fwd.y; dz = dz + fwd.z end
        if IsControlPressed(0, 33) then dx = dx - fwd.x; dy = dy - fwd.y; dz = dz - fwd.z end
        if IsControlPressed(0, 34) then dx = dx - right.x; dy = dy - right.y end
        if IsControlPressed(0, 35) then dx = dx + right.x; dy = dy + right.y end
        if IsControlPressed(0, 22) then dz = dz + 1.0 end
        if IsControlPressed(0, 36) then dz = dz - 1.0 end
        if dx ~= 0.0 or dy ~= 0.0 or dz ~= 0.0 then
          SetEntityCoordsNoOffset(p, pos.x + dx*mult, pos.y + dy*mult, pos.z + dz*mult, false, false, false)
        end
      end
      local p = PlayerPedId()
      SetEntityInvincible(p, false)
      SetEntityCollision(p, true, true)
    end)
  else
    notify('NoClip OFF', 'inform')
  end
end

-- ===========================================================================
-- Events
-- ===========================================================================
RegisterNetEvent('sl-admin:open', openAdmin)

RegisterNetEvent('sl-admin:applyTp', function(coords)
  if not coords then return end
  local ped = PlayerPedId()
  SetEntityCoords(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, false, false, false, false)
  notify(('TP → %s'):format(fmtVec3(coords)), 'success')
end)

-- ===========================================================================
-- Client commands : sladmin + myace
-- ===========================================================================
RegisterCommand('sladmin', function()
  TriggerServerEvent('sl-admin:requestOpen')
end, false)

RegisterCommand('myace', function()
  TriggerServerEvent('sl-admin:requestAceDump')
end, false)

RegisterNetEvent('sl-admin:aceDump', function(payload)
  print('========= ACE PERMISSIONS =========')
  for k, v in pairs(payload or {}) do print(('  %-22s = %s'):format(tostring(k), tostring(v))) end
  print('===================================')
  notify(('isAdmin = %s · F8 console pour détails'):format(tostring((payload or {}).isAdmin)), 'inform')
end)

-- Cleanup
AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() and hasFocus then setFocus(false) end
end)
