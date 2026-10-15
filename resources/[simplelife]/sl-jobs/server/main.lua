print('[sl-jobs/server] main.lua loaded')

local SL = exports['sl-core']
Cache = Cache or {}

local registered = false
local function tryReady()
  local ok, ready = pcall(function() return SL:IsReady() end)
  return ok and ready == true
end
local function registerSelf()
  if registered then return end
  registered = true
  local apiOk, api = pcall(function() return SL:CoreApi() end)
  SL:RegisterModule({
    name = GetCurrentResourceName(),
    version = '0.1.0',
    coreApi = apiOk and api or 1,
    deps = { 'sl-core@^0.1', 'sl-economy@^0.1' },
  })
end
AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryReady() do Wait(200) end
  registerSelf()
end)

local function hydrate(source, payload)
  local data = payload and payload.data or {}
  data.job = data.job or {}
  local name = data.job.name or Jobs.DefaultJob
  local grade = tonumber(data.job.grade) or Jobs.DefaultGrade
  if not Jobs.IsValid(name, grade) then
    name = Jobs.DefaultJob
    grade = Jobs.DefaultGrade
  end
  local onDuty = data.job.onDuty == true
  Cache[source] = {
    characterId = payload.characterId,
    name = name,
    grade = grade,
    onDuty = onDuty,
  }

  local player = SL:GetPlayer(source)
  if player then
    player.data = player.data or {}
    player.data.job = { name = name, grade = grade, onDuty = onDuty }
    player.modified = true
  end

  TriggerClientEvent('sl:bus:dispatch', source, 'sl:jobs:hydrated', {
    name = name,
    grade = grade,
    onDuty = onDuty,
    label = Jobs.GetJob(name) and Jobs.GetJob(name).label or name,
    gradeLabel = Jobs.GetGrade(name, grade) and Jobs.GetGrade(name, grade).label or '?',
  })

  print(('[sl-jobs] hydrated src=%d job=%s grade=%d duty=%s'):format(source, name, grade, tostring(onDuty)))
end

AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source then return end
  hydrate(payload.source, payload)
end)

AddEventHandler('sl:core:playerDropped', function(payload)
  if payload and payload.source then Cache[payload.source] = nil end
end)
