print('[sl-clothing/client] main.lua loaded')

ClientClothing = ClientClothing or { appearance = nil }

BestTorso = BestTorso or { m = nil, f = nil }

CreateThread(function()
  local maleContent = LoadResourceFile(GetCurrentResourceName(), 'data/besttorso_male.json')
  local femaleContent = LoadResourceFile(GetCurrentResourceName(), 'data/besttorso_female.json')
  if maleContent then
    local ok, decoded = pcall(json.decode, maleContent)
    if ok then BestTorso.m = decoded; print('[sl-clothing/client] BestTorso male loaded') end
  end
  if femaleContent then
    local ok, decoded = pcall(json.decode, femaleContent)
    if ok then BestTorso.f = decoded; print('[sl-clothing/client] BestTorso female loaded') end
  end
end)

function GetBestTorsoFor(sex, topDrawable, topTexture)
  local data = BestTorso[sex or 'm']
  if not data then return nil end
  local byDraw = data[tostring(topDrawable)]
  if not byDraw then return nil end
  local entry = byDraw[tostring(topTexture or 0)]
  if not entry then return nil end
  if entry.BestTorsoDrawable == nil or entry.BestTorsoDrawable < 0 then return nil end
  return { drawable = entry.BestTorsoDrawable, texture = entry.BestTorsoTexture or 0 }
end

function GetClothingSex()
  if ClientClothing.appearance and ClientClothing.appearance.model then
    return ClientClothing.appearance.model:find('mp_f_') and 'f' or 'm'
  end
  local m = GetEntityModel(PlayerPedId())
  return m == `mp_f_freemode_01` and 'f' or 'm'
end

local function loadModel(modelHash)
  if not IsModelValid(modelHash) then
    print('[sl-clothing/client] model invalid: ' .. tostring(modelHash))
    return false
  end
  if not IsModelInCdimage(modelHash) then
    print('[sl-clothing/client] model not in cdimage: ' .. tostring(modelHash))
    return false
  end
  RequestModel(modelHash)
  local t = 0
  while not HasModelLoaded(modelHash) and t < 200 do
    Wait(50); t = t + 1
  end
  if not HasModelLoaded(modelHash) then
    print('[sl-clothing/client] model load TIMEOUT: ' .. tostring(modelHash))
    return false
  end
  print('[sl-clothing/client] model loaded after ' .. t .. ' tries: ' .. tostring(modelHash))
  return true
end

function ApplyAppearance(appearance)
  if not appearance then return end
  local ped = PlayerPedId()
  local model = appearance.model or 'mp_m_freemode_01'
  local hash = type(model) == 'string' and joaat(model) or model
  local currentModel = GetEntityModel(ped)

  print(('[sl-clothing/client] ApplyAppearance: target model=%s (hash=%s), current=%s, match=%s'):format(
    tostring(model), tostring(hash), tostring(currentModel), tostring(currentModel == hash)))

  if currentModel ~= hash then
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local health = GetEntityHealth(ped)
    if loadModel(hash) then
      SetPlayerModel(PlayerId(), hash)
      SetModelAsNoLongerNeeded(hash)
      Wait(100)
      ped = PlayerPedId()
      print(('[sl-clothing/client] new ped model after SetPlayerModel: %s'):format(tostring(GetEntityModel(ped))))
      SetPedDefaultComponentVariation(ped)
      SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
      SetEntityHeading(ped, heading)
      if health > 100 then SetEntityHealth(ped, health) end
      FreezeEntityPosition(ped, false)
      SetEntityVisible(ped, true, false)
      SetEntityInvincible(ped, false)
      SetPlayerInvincible(PlayerId(), false)
      pcall(NetworkResurrectLocalPlayer, coords.x, coords.y, coords.z, heading, true, false)
      ClearPedTasksImmediately(ped)
    else
      print('[sl-clothing/client] ERROR: model load failed, keeping current ped')
    end
  end

  for id, c in pairs(appearance.components or {}) do
    local cid = tonumber(id)
    if cid and c.drawable then
      SetPedComponentVariation(ped, cid, c.drawable, c.texture or 0, 0)
    end
  end

  for id, p in pairs(appearance.props or {}) do
    local pid = tonumber(id)
    if pid then
      if not p.drawable or p.drawable == -1 then
        ClearPedProp(ped, pid)
      else
        SetPedPropIndex(ped, pid, p.drawable, p.texture or 0, true)
      end
    end
  end

  FreezeEntityPosition(ped, false)
  SetEntityVisible(ped, true, false)
  ClientClothing.appearance = appearance
end

local function isSpawned()
  local state = exports['sl-core']:GetState()
  return state and state.spawned == true
end

AddEventHandler('sl:clothing:apply', function(appearance)
  CreateThread(function()
    local maxWait = 30
    local tries = 0
    while not isSpawned() and tries < maxWait do
      Wait(200)
      tries = tries + 1
    end
    Wait(100)
    ApplyAppearance(appearance)
    print('[sl-clothing/client] appearance applied')
  end)
end)

exports('GetAppearance', function() return ClientClothing.appearance end)
exports('ApplyAppearance', ApplyAppearance)

RegisterCommand('clothing_dump', function()
  local ped = PlayerPedId()
  local model = GetEntityModel(ped)
  print('=== CLOTHING DUMP for ped model ' .. model .. ' ===')
  print('Components:')
  print('  components = {')
  for _, id in ipairs({0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}) do
    local drawable = GetPedDrawableVariation(ped, id)
    local texture = GetPedTextureVariation(ped, id)
    print(('    [%d] = { drawable = %d, texture = %d },'):format(id, drawable, texture))
  end
  print('  },')
  print('Props:')
  print('  props = {')
  for _, id in ipairs({0, 1, 2, 6, 7}) do
    local drawable = GetPedPropIndex(ped, id)
    local texture = GetPedPropTextureIndex(ped, id)
    print(('    [%d] = { drawable = %d, texture = %d },'):format(id, drawable, texture))
  end
  print('  },')
  print('=== Copy-paste this into Clothing.Presets to make your own outfit ===')
end, false)

RegisterCommand('clothing_apply_raw', function(_, args)
  if #args < 3 then
    print('Usage: clothing_apply_raw <component_id> <drawable> <texture>')
    return
  end
  local cid = tonumber(args[1])
  local drawable = tonumber(args[2])
  local texture = tonumber(args[3])
  SetPedComponentVariation(PlayerPedId(), cid, drawable, texture, 0)
  print(('[sl-clothing] applied component %d = drawable %d, texture %d'):format(cid, drawable, texture))
end, false)
