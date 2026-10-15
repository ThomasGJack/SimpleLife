print('[sl-curator/server] main.lua loaded')

local SL = exports['sl-core']
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
    deps = { 'sl-core@^0.1', 'sl-clothing@^0.1' },
  })
end

AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryReady() do Wait(200) end
  registerSelf()
end)

AddEventHandler('playerDropped', function()
  local src = source
  if CuratorEnum and CuratorEnum[src] then CuratorEnum[src] = nil end
end)
