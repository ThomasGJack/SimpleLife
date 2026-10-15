print('[sl-core/client] world.lua loaded')

local DISPATCH_SERVICES = {
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
}

local function isDisabled(key)
  return not (Config.EnableVanilla and Config.EnableVanilla[key])
end

CreateThread(function()
  while not NetworkIsSessionStarted() do Wait(500) end

  if isDisabled('wantedLevel') then
    SetMaxWantedLevel(0)
    SetPlayerWantedLevel(PlayerId(), 0, false)
    SetPlayerWantedLevelNow(PlayerId(), false)
    ClearPlayerWantedLevel(PlayerId())
    print('[sl-core/client] vanilla wanted level disabled')
  end

  if isDisabled('emergencyDispatch') then
    for _, id in ipairs(DISPATCH_SERVICES) do
      EnableDispatchService(id, false)
    end
    print('[sl-core/client] vanilla emergency dispatch disabled')
  end

  if isDisabled('randomCops') then
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)
    print('[sl-core/client] vanilla random cops disabled')
  end
end)

if isDisabled('wantedLevel') then
  CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    while true do
      Wait(2000)
      local pid = PlayerId()
      if GetPlayerWantedLevel(pid) > 0 then
        SetPlayerWantedLevel(pid, 0, false)
        SetPlayerWantedLevelNow(pid, false)
        ClearPlayerWantedLevel(pid)
      end
    end
  end)
end

if isDisabled('randomCops') or isDisabled('emergencyDispatch') then
  CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    while true do
      Wait(10000)
      if isDisabled('randomCops') then
        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)
      end
      if isDisabled('emergencyDispatch') then
        for _, id in ipairs(DISPATCH_SERVICES) do
          EnableDispatchService(id, false)
        end
      end
    end
  end)
end

if isDisabled('ambientSpawns') then
  CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    while true do
      Wait(0)
      SetVehicleDensityMultiplierThisFrame(0.0)
      SetPedDensityMultiplierThisFrame(0.0)
      SetRandomVehicleDensityMultiplierThisFrame(0.0)
      SetParkedVehicleDensityMultiplierThisFrame(0.0)
      SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
    end
  end)
end

if isDisabled('scenarioPeds') then
  CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    SetScenarioGroupsBlocked()
  end)
end
