print('[sl-curator/client] main.lua loaded')

local CuratorActive = false
local CamHandle = nil
local CamAngle = 180.0
local CamDist = 3.8
local CamHeight = 0.9
local CamLookOffset = -0.3
local OriginalAppearance = nil
local CurrentOutfit = nil
local CurrentHash = nil
local CurrentPhase = 'p1'
local CurrentMode = 'normal'
local CurrentSex = 'm'
local SessionDedup = {}
local History = {}

local function getSex()
  local ok, appearance = pcall(function() return exports['sl-clothing']:GetAppearance() end)
  if ok and appearance and appearance.model then
    return appearance.model:find('mp_f_') and 'f' or 'm'
  end
  return 'm'
end

local function setupCam()
  if CamHandle then return end
  CamHandle = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
  SetCamFov(CamHandle, 50.0)
  RenderScriptCams(true, true, 600, true, true)
  CreateThread(function()
    while CuratorActive do
      Wait(16)
      local rad = math.rad(CamAngle)
      local pcoords = GetEntityCoords(PlayerPedId())
      local cx = pcoords.x + math.sin(rad) * CamDist
      local cy = pcoords.y - math.cos(rad) * CamDist
      local lateralOffset = -0.6
      cx = cx + math.cos(rad) * lateralOffset
      cy = cy + math.sin(rad) * lateralOffset
      SetCamCoord(CamHandle, cx, cy, pcoords.z + CamHeight)
      PointCamAtEntity(CamHandle, PlayerPedId(), 0.0, 0.0, CamLookOffset, true)
    end
  end)
end

local function teardownCam()
  if CamHandle then
    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(CamHandle, true)
    CamHandle = nil
  end
end

local function applyOutfit(outfit)
  local ped = PlayerPedId()
  for key, v in pairs(outfit) do
    local kind, idStr = key:match('([^:]+):(%d+)')
    local id = tonumber(idStr)
    if kind == 'component' then
      SetPedComponentVariation(ped, id, v.drawable or 0, v.texture or 0, 0)
    elseif kind == 'prop' then
      if not v.drawable or v.drawable < 0 then
        ClearPedProp(ped, id)
      else
        SetPedPropIndex(ped, id, v.drawable, v.texture or 0, true)
      end
    end
  end
end

local function buildEnumData()
  local ped = PlayerPedId()
  local out = { component = {}, prop = {} }
  local componentIds = { 3, 4, 6, 7, 8, 9, 10, 11 }
  for _, id in ipairs(componentIds) do
    local nb = GetNumberOfPedDrawableVariations(ped, id)
    if nb <= 0 then nb = 100 end
    local list = {}
    for d = 0, nb - 1 do
      local valid = IsPedComponentVariationValid(ped, id, d, 0)
      table.insert(list, { drawable = d, valid = valid })
    end
    out.component[tostring(id)] = list
  end
  return out
end

local function getDedupList()
  local list = {}
  for h in pairs(SessionDedup) do table.insert(list, h) end
  return list
end

local function fetchNext(phaseOverride, modeOverride)
  local phase = phaseOverride or CurrentPhase
  local mode = modeOverride or CurrentMode
  local res = lib.callback.await('sl-curator:next', false, {
    phase = phase,
    mode = mode,
    excludeHashes = getDedupList(),
  })
  if not res or not res.ok then
    SendNUIMessage({ action = 'error', error = res and res.error or 'no outfit', phase = phase, mode = mode })
    return
  end
  CurrentOutfit = res.outfit
  CurrentHash = res.hash
  CurrentSex = res.sex
  CurrentPhase = res.phase
  CurrentMode = res.mode or 'normal'
  if mode == 'normal' then
    SessionDedup[res.hash] = true
    if #SessionDedup > (Curator.SessionDedupSize or 200) then
      local oldest = next(SessionDedup)
      if oldest then SessionDedup[oldest] = nil end
    end
  end
  applyOutfit(res.outfit)
  SendNUIMessage({
    action = 'show',
    outfit = res.outfit,
    phase = res.phase,
    mode = CurrentMode,
    isReview = res.isReview == true,
    phaseLabel = res.phaseLabel,
    phaseTitle = res.phaseTitle,
    phaseDesc = res.phaseDesc,
    slots = res.slots,
    extraSlot = res.extraSlot,
    stats = res.stats,
    canBack = #History > 0,
  })
end

local function voteYes()
  if not CurrentOutfit or not CurrentHash then return end
  local res
  if CurrentMode == 'review' then
    res = lib.callback.await('sl-curator:confirmReview', false, {
      hash = CurrentHash, sex = CurrentSex, phase = CurrentPhase,
    })
  else
    table.insert(History, { hash = CurrentHash, outfit = CurrentOutfit, phase = CurrentPhase })
    if #History > 15 then table.remove(History, 1) end
    res = lib.callback.await('sl-curator:voteYes', false, {
      hash = CurrentHash, outfit = CurrentOutfit, sex = CurrentSex, phase = CurrentPhase,
    })
  end
  if res and res.ok then
    SendNUIMessage({ action = 'stats', stats = res.stats })
  end
  fetchNext()
end

local function voteNo()
  if CurrentMode ~= 'review' then return end
  if not CurrentHash then return end
  local res = lib.callback.await('sl-curator:rejectReview', false, {
    hash = CurrentHash, sex = CurrentSex, phase = CurrentPhase,
  })
  if res and res.ok then
    SendNUIMessage({ action = 'stats', stats = res.stats })
  end
  fetchNext()
end

local function next_()
  fetchNext()
end

local function setMode(mode)
  if mode ~= 'normal' and mode ~= 'review' then return end
  CurrentMode = mode
  fetchNext(nil, mode)
end

local function setPhase(phase)
  if not Curator.Phases[phase] then return end
  lib.callback.await('sl-curator:setPhase', false, phase)
  CurrentPhase = phase
  fetchNext(phase)
end

local function back()
  if #History == 0 then return end
  local last = table.remove(History)
  lib.callback.await('sl-curator:undo', false, {
    hash = last.hash, sex = CurrentSex, phase = last.phase,
  })
  SessionDedup[last.hash] = nil
  CurrentOutfit = last.outfit
  CurrentHash = last.hash
  CurrentPhase = last.phase
  applyOutfit(last.outfit)
  local phaseConf = Curator.Phases[last.phase]
  SendNUIMessage({
    action = 'show',
    outfit = last.outfit,
    phase = last.phase,
    phaseLabel = phaseConf.label,
    phaseTitle = phaseConf.title,
    phaseDesc = phaseConf.desc,
    slots = phaseConf.testSlots,
    extraSlot = phaseConf.extraSlot and (phaseConf.extraSlot.kind .. ':' .. phaseConf.extraSlot.id) or nil,
    canBack = #History > 0,
    isBack = true,
  })
end

local function start()
  if CuratorActive then return end
  local appearance = exports['sl-clothing']:GetAppearance()
  if not appearance then
    appearance = lib.callback.await('sl-clothing:getAppearance', false)
  end
  if not appearance then
    lib.notify({ type = 'error', title = 'Curator', description = 'Pas d\'apparence' })
    return
  end
  OriginalAppearance = appearance

  CuratorActive = true
  SessionDedup = {}
  History = {}
  setupCam()

  local enumData = buildEnumData()
  lib.callback.await('sl-curator:setEnum', false, enumData)
  Wait(200)

  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'init', phases = {
    { id = 'p1', label = 'Phase 1', title = 'Trio haut' },
    { id = 'p2', label = 'Phase 2', title = '+ Gilet' },
    { id = 'p3', label = 'Phase 3', title = '+ Chaîne' },
    { id = 'p4', label = 'Phase 4', title = 'Bas' },
  }})
  fetchNext()
end

local function stop()
  CuratorActive = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  teardownCam()
  if OriginalAppearance then
    exports['sl-clothing']:ApplyAppearance(OriginalAppearance)
    OriginalAppearance = nil
  end
  pcall(function() lib.callback.await('sl-curator:leave', false) end)
end

RegisterNUICallback('voteYes', function(_, cb) voteYes(); cb({ ok = true }) end)
RegisterNUICallback('voteNo', function(_, cb) voteNo(); cb({ ok = true }) end)
RegisterNUICallback('next', function(_, cb) next_(); cb({ ok = true }) end)
RegisterNUICallback('back', function(_, cb) back(); cb({ ok = true }) end)
RegisterNUICallback('setPhase', function(data, cb) setPhase(data.phase); cb({ ok = true }) end)
RegisterNUICallback('setMode', function(data, cb) setMode(data.mode); cb({ ok = true }) end)
RegisterNUICallback('close', function(_, cb) stop(); cb({ ok = true }) end)
RegisterNUICallback('rotate', function(data, cb)
  local delta = tonumber(data.delta) or 0
  CamAngle = (CamAngle + delta) % 360
  if CamAngle < 0 then CamAngle = CamAngle + 360 end
  cb({ ok = true })
end)
RegisterNUICallback('zoom', function(data, cb)
  local delta = tonumber(data.delta) or 0
  CamDist = math.min(6.0, math.max(2.0, CamDist + delta))
  cb({ ok = true })
end)

RegisterCommand('curator', function() start() end, false)
RegisterCommand('curator_stop', function() stop() end, false)
RegisterCommand('curator_dump', function(_, args)
  local phase = args[1]
  local res = lib.callback.await('sl-curator:dumpPresets', false, phase)
  if not res or not res.ok then print('dump failed'); return end
  print(('[sl-curator] %d outfits validated:'):format(res.count))
  for i, p in ipairs(res.presets) do
    print(('-- Preset #%d (sex=%s, phase=%s) --'):format(i, p.sex, p.phase or '?'))
    for k, v in pairs(p.outfit) do
      print(('  %s = drawable %d'):format(k, v.drawable or 0))
    end
  end
end, false)
