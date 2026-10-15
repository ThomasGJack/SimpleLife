print('[sl-shops/client] main.lua loaded')

-- ===========================================================================
-- État NUI
-- ===========================================================================
local uiOpen = false
local hasFocus = false
local currentShop = nil

local function setFocus(state)
  hasFocus = state
  SetNuiFocus(state, state)
  SetNuiFocusKeepInput(false)
end

local function closeShop()
  if not uiOpen then return end
  uiOpen = false
  currentShop = nil
  setFocus(false)
  SendNUIMessage({ action = 'close' })
end

local function openShop(shopKey)
  if uiOpen then return end
  local catalog = lib.callback.await('sl-shops:getCatalog', false, shopKey)
  if not catalog then
    lib.notify({ description = 'Catalogue indisponible.', type = 'error' })
    return
  end
  uiOpen = true
  currentShop = shopKey
  setFocus(true)
  SendNUIMessage({ action = 'open', catalog = catalog })
end

-- ===========================================================================
-- Spawn PNJ + sl-interact (visée libre + E) + blips
-- ===========================================================================

local spawnedPeds = {}
local spawnedBlips = {}

local function loadModel(model)
  if not IsModelInCdimage(model) then
    print(('[sl-shops] model NOT IN CDIMAGE : %s'):format(tostring(model)))
    return false
  end
  if not IsModelAPed(model) then
    print(('[sl-shops] model is NOT A PED : %s'):format(tostring(model)))
    return false
  end
  RequestModel(model)
  local deadline = GetGameTimer() + 6000
  while not HasModelLoaded(model) and GetGameTimer() < deadline do
    Wait(20)
  end
  return HasModelLoaded(model)
end

local function createPed(shopKey, shop, spawn)
  local model = GetHashKey(shop.pedModel)
  if not loadModel(model) then
    print(('[sl-shops] %s : failed to load ped model: %s'):format(shopKey, tostring(shop.pedModel)))
    return nil
  end
  -- spawn.z est censé être la hauteur du SOL → on passe la hauteur exacte,
  -- pas spawn.z-1 (sinon le ped peut tomber sous la map sur certaines positions).
  local ped = CreatePed(4, model, spawn.x + 0.0, spawn.y + 0.0, spawn.z + 0.0, spawn.h + 0.0, false, true)
  if ped == 0 or not DoesEntityExist(ped) then
    print(('[sl-shops] %s : CreatePed failed @ %.2f,%.2f,%.2f'):format(shopKey, spawn.x, spawn.y, spawn.z))
    SetModelAsNoLongerNeeded(model)
    return nil
  end
  SetEntityInvincible(ped, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  FreezeEntityPosition(ped, true)
  SetPedDiesWhenInjured(ped, false)
  SetPedCanRagdoll(ped, false)
  SetPedFleeAttributes(ped, 0, false)
  SetPedDefaultComponentVariation(ped)
  SetModelAsNoLongerNeeded(model)
  print(('[sl-shops] %s : ped spawned (model=%s) @ %.2f,%.2f,%.2f h=%.0f'):format(
    shopKey, shop.pedModel, spawn.x, spawn.y, spawn.z, spawn.h))
  return ped
end

local function createBlip(shop, spawn)
  if not shop.blip then return nil end
  local blip = AddBlipForCoord(spawn.x + 0.0, spawn.y + 0.0, spawn.z + 0.0)
  SetBlipSprite(blip, shop.blip.sprite or 52)
  SetBlipColour(blip, shop.blip.color or 2)
  SetBlipScale(blip, shop.blip.scale or 0.7)
  SetBlipAsShortRange(blip, true)
  BeginTextCommandSetBlipName('STRING')
  AddTextComponentString(shop.blip.label or shop.label or 'Shop')
  EndTextCommandSetBlipName(blip)
  return blip
end

local function setupShop(shopKey, shop)
  for _, spawn in ipairs(shop.spawns or {}) do
    -- PNJ
    local ped = createPed(shopKey, shop, spawn)
    if ped then
      spawnedPeds[#spawnedPeds+1] = ped
      -- sl-interact : visée libre + touche E
      exports['sl-interact']:AddEntity(ped, {
        label    = ('Acheter — %s'):format(shop.label),
        key      = 'E',
        distance = Shops.OpenDistance or 3.0,
        onSelect = function() openShop(shopKey) end,
      })
    end
    -- Blip
    local blip = createBlip(shop, spawn)
    if blip then spawnedBlips[#spawnedBlips+1] = blip end
  end
end

CreateThread(function()
  -- Attend le spawn du joueur avant de spawner les PNJ
  while not NetworkIsSessionStarted() do Wait(500) end
  Wait(2000)
  for key, shop in pairs(Shops.List) do
    setupShop(key, shop)
  end
  print(('[sl-shops/client] %d shops setup'):format((function() local n=0 for _ in pairs(Shops.List) do n=n+1 end return n end)()))
end)

-- Cleanup au resource stop
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  for _, ped in ipairs(spawnedPeds) do
    if DoesEntityExist(ped) then
      pcall(function() exports['sl-interact']:RemoveEntity(ped) end)
      DeleteEntity(ped)
    end
  end
  for _, blip in ipairs(spawnedBlips) do
    if DoesBlipExist(blip) then RemoveBlip(blip) end
  end
  if hasFocus then setFocus(false) end
end)

-- ===========================================================================
-- NUI callbacks
-- ===========================================================================
RegisterNUICallback('close', function(_, cb)
  closeShop()
  cb({ ok = true })
end)

RegisterNUICallback('purchase', function(data, cb)
  if not currentShop or not data or not data.item then
    cb({ ok = false, error = 'invalide' })
    return
  end
  local qty = tonumber(data.qty) or 1
  local res = lib.callback.await('sl-shops:purchase', false, currentShop, data.item, qty)
  cb(res or { ok = false, error = 'rpc failed' })
end)

-- ESC pour fermer
CreateThread(function()
  while true do
    if uiOpen then
      if IsControlJustReleased(0, 322) or IsControlJustReleased(0, 200) then
        closeShop()
      end
      Wait(0)
    else
      Wait(300)
    end
  end
end)
