local SL = exports['sl-core']
local registered = false

local function tryIsReady()
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
    deps = { 'sl-core@^0.1' },
  })
end

AddEventHandler('sl:core:ready', registerSelf)

CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
end)

AddEventHandler('sl:core:playerLoaded', function(payload)
  local src = payload and payload.source
  print(('[sl-identity] received sl:core:playerLoaded for src=%s'):format(tostring(src)))
  if not src then return end
  CreateThread(function()
    Wait(800)
    print(('[sl-identity] triggering openSelector for src=%d'):format(src))
    TriggerClientEvent('sl-identity:openSelector', src)
  end)
end)
