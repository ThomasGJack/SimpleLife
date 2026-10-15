print('[sl-dlc/client] main.lua loaded')

local loadedIpls   = {}
local loadedCount  = 0
local failedCount  = 0
local removedCount = 0

-- ===========================================================================
-- Charge un IPL avec retry et logs
-- ===========================================================================
local function loadIpl(name)
  if loadedIpls[name] then return true end
  if not IsIplActive(name) then
    RequestIpl(name)
    -- petite pause pour laisser le moteur le streamer
    local deadline = GetGameTimer() + 250
    while not IsIplActive(name) and GetGameTimer() < deadline do Wait(20) end
  end
  if IsIplActive(name) then
    loadedIpls[name] = true
    loadedCount = loadedCount + 1
    return true
  end
  failedCount = failedCount + 1
  return false
end

local function removeIpl(name)
  if IsIplActive(name) then
    RemoveIpl(name)
    removedCount = removedCount + 1
  end
end

-- ===========================================================================
-- Cayo Perico : Island Hopper
--
-- L'île n'est pas un IPL ordinaire — il faut activer le "Heist Island" via
-- la native SetIslandHopperEnabled. Sans ça, l'île est invisible/inaccessible
-- même si les IPLs h4_islandx_* sont actifs.
-- ===========================================================================
local function enableCayoPerico()
  if SetIslandHopperEnabled then
    pcall(SetIslandHopperEnabled, 'HeistIsland', true)
    print('[sl-dlc/client] Cayo Perico (HeistIsland) enabled')
    return true
  end
  print('[sl-dlc/client] WARN : SetIslandHopperEnabled native indisponible')
  return false
end

-- ===========================================================================
-- Active la map MP DLC complète
-- ===========================================================================
local function enableMpDlcMaps()
  pcall(LoadMpDlcMaps)
  pcall(OnEnteringMpMaps)
  if SetMpDlcMapsEnabled then pcall(SetMpDlcMapsEnabled, true) end
  -- Stunt rampe (Doomsday Heist) — souvent oubliée
  if SetScenarioTypeEnabled then
    pcall(SetScenarioTypeEnabled, 'WORLD_HUMAN_PROSTITUTE_LOW_CLASS', false)
  end
end

-- ===========================================================================
-- Boot
-- ===========================================================================
CreateThread(function()
  while not NetworkIsSessionStarted() do Wait(500) end
  Wait(2000)

  if DLC.EnableMpDlcMaps then
    print('[sl-dlc/client] enabling MP DLC maps...')
    local ok, err = pcall(enableMpDlcMaps)
    if ok then
      print('[sl-dlc/client] MP DLC maps enabled')
    else
      print('[sl-dlc/client] LoadMpDlcMaps failed: ' .. tostring(err))
    end
  end

  -- Cayo Perico (island hopper natif)
  -- Si DÉSACTIVÉ (cas par défaut), on force aussi l'arrêt pour nettoyer si la
  -- session précédente l'avait activée (utile après /restart sl-dlc).
  if DLC.EnableIslandHopper then
    enableCayoPerico()
  else
    if SetIslandHopperEnabled then
      pcall(SetIslandHopperEnabled, 'HeistIsland', false)
    end
    print('[sl-dlc/client] Cayo Perico DISABLED (Los Santos reste pleinement chargée)')
  end

  -- Charge tous les IPLs configurés
  if DLC.IPLs and #DLC.IPLs > 0 then
    print(('[sl-dlc/client] loading %d IPLs...'):format(#DLC.IPLs))
    for _, name in ipairs(DLC.IPLs) do
      local ok = loadIpl(name)
      if DLC.LogProgress and not ok then
        print(('[sl-dlc/client] IPL skipped (inactive after request): %s'):format(name))
      end
    end
    print(('[sl-dlc/client] IPLs done : %d active, %d skipped'):format(loadedCount, failedCount))
  end

  -- Désactive ceux qu'on veut retirer (clean-up vanilla)
  if DLC.IPLsToRemove and #DLC.IPLsToRemove > 0 then
    for _, name in ipairs(DLC.IPLsToRemove) do removeIpl(name) end
    print(('[sl-dlc/client] removed %d IPLs (cleanup)'):format(removedCount))
  end

  print('[sl-dlc/client] DLC loader complete')
end)

-- ===========================================================================
-- Commands debug
-- ===========================================================================
RegisterCommand('sl_dlc_status', function()
  print('====== SL-DLC STATUS ======')
  print('LoadMpDlcMaps      : ' .. tostring(DLC.EnableMpDlcMaps))
  print('Cayo Perico hopper : ' .. tostring(DLC.EnableIslandHopper))
  print('IPLs configurés    : ' .. (#DLC.IPLs or 0))
  print('IPLs actifs        : ' .. loadedCount)
  print('IPLs skippés       : ' .. failedCount)
  print('IPLs retirés       : ' .. removedCount)
  print('===========================')
end, false)

RegisterCommand('sl_dlc_reload', function()
  loadedIpls = {}; loadedCount = 0; failedCount = 0; removedCount = 0
  CreateThread(function()
    enableMpDlcMaps()
    if DLC.EnableIslandHopper then enableCayoPerico() end
    for _, name in ipairs(DLC.IPLs or {}) do loadIpl(name) end
    for _, name in ipairs(DLC.IPLsToRemove or {}) do removeIpl(name) end
    print(('[sl-dlc/client] reload done : %d actifs, %d skippés'):format(loadedCount, failedCount))
  end)
end, false)

RegisterCommand('sl_dlc_test_model', function(_, args)
  local model = args[1]
  if not model then
    print('Usage : /sl_dlc_test_model <model_name>')
    print('Try : terbyte, dinghy5, avenger, valkyrie, savage, manchez3, comet6')
    return
  end
  local hash = joaat(model)
  if not IsModelValid(hash)     then print('[sl-dlc] INVALID model: '   .. model); return end
  if not IsModelInCdimage(hash) then print('[sl-dlc] NOT in cdimage: '  .. model); return end
  RequestModel(hash)
  local t = 0
  while not HasModelLoaded(hash) and t < 50 do Wait(100); t = t + 1 end
  if HasModelLoaded(hash) then
    print('[sl-dlc] model AVAILABLE : ' .. model .. ' (hash=' .. hash .. ')')
    SetModelAsNoLongerNeeded(hash)
  else
    print('[sl-dlc] model load TIMEOUT : ' .. model)
  end
end, false)

-- ===========================================================================
-- /cayo_on et /cayo_off : toggle dynamique de Cayo Perico
--
-- Permanent enable casse Los Santos sur la plupart des builds. La bonne pratique
-- est d'activer l'île UNIQUEMENT quand on veut s'y rendre, puis de la couper
-- en revenant. Ces commandes le font proprement.
-- ===========================================================================

local cayoIPLs = {
  'h4_islandx',
  'h4_islandxmissions',
  'h4_islandx_ext',
  'h4_islandx_props',
  'h4_islandx_terrain',
  'h4_beach_party_2',
  'h4_mph4_pi_int',
  'h4_mph4_kos_carpark',
  'h4_islandx_lod_blockers',
  'h4_islandx_lod',
}

local islandActive = false

RegisterCommand('cayo_on', function()
  if islandActive then
    print('[sl-dlc] Cayo déjà activée — annule avec /cayo_off avant')
    return
  end
  if SetIslandHopperEnabled then
    pcall(SetIslandHopperEnabled, 'HeistIsland', true)
  end
  for _, name in ipairs(cayoIPLs) do
    if not IsIplActive(name) then RequestIpl(name) end
  end
  islandActive = true
  print('[sl-dlc] ✅ Cayo Perico ACTIVÉE — Los Santos peut disparaître. Use /cayo_off au retour.')
end, false)

RegisterCommand('cayo_off', function()
  if SetIslandHopperEnabled then
    pcall(SetIslandHopperEnabled, 'HeistIsland', false)
  end
  for _, name in ipairs(cayoIPLs) do
    if IsIplActive(name) then RemoveIpl(name) end
  end
  islandActive = false
  print('[sl-dlc] ✅ Cayo Perico DÉSACTIVÉE — Los Santos redevient pleinement chargée.')
end, false)

-- /sl_dlc_tp_cayo : TP sur Cayo Perico + auto-activation
RegisterCommand('sl_dlc_tp_cayo', function()
  if not islandActive then ExecuteCommand('cayo_on'); Wait(800) end
  local coords = vec3(4840.0, -5174.0, 2.0)   -- plage de la villa Cayo Perico
  local ped = PlayerPedId()
  SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
  print(('[sl-dlc] TP vers Cayo Perico @ %.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z))
end, false)

-- /sl_dlc_tp_ls : retour Los Santos + auto-désactivation Cayo
RegisterCommand('sl_dlc_tp_ls', function()
  if islandActive then ExecuteCommand('cayo_off'); Wait(800) end
  local coords = vec3(-250.74, -1868.92, 27.75)   -- spawn par défaut Pillbox
  local ped = PlayerPedId()
  SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
  print(('[sl-dlc] TP vers Los Santos @ %.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z))
end, false)
