print('[sl-hud/client] main.lua loaded')

local hudVisible = false
local nuiReady = false
local lastSent = { cash = -1, bank = -1, crypto = -1, hp = -1, name = '', cid = '', jobName = '', jobGrade = -1, onDuty = nil }

local function push(payload)
  SendNUIMessage(payload)
end

local function showHud()
  hudVisible = true
  push({ action = 'show' })
end

local function hideHud()
  hudVisible = false
  push({ action = 'hide' })
end

CreateThread(function()
  Wait(500)
  nuiReady = true
  print('[sl-hud/client] NUI ready')
end)

local function formatMoney(n)
  n = math.floor(tonumber(n) or 0)
  local sign = n < 0 and '-' or ''
  local abs = math.abs(n)
  local str = tostring(abs)
  local formatted = str:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ +', '')
  return sign .. formatted
end

local function getBalances()
  local ok, b = pcall(function() return exports['sl-economy']:GetClientBalances() end)
  if ok and type(b) == 'table' then return b end
  return { cash = 0, bank = 0, crypto = 0 }
end

local function getIdentity()
  local ok, state = pcall(function() return exports['sl-core']:GetState() end)
  if not ok or not state then return nil, nil end
  local data = state.data or {}
  local identity = data.identity or {}
  local name = (identity.firstName and identity.lastName)
    and (identity.firstName .. ' ' .. identity.lastName)
    or 'Inconnu'
  return state.citizenId or '—', name
end

local function pushIdentity()
  local cid, name = getIdentity()
  if (cid or '—') ~= lastSent.cid or (name or '') ~= lastSent.name then
    push({ action = 'identity', citizenId = cid or '—', name = name or 'Inconnu' })
    lastSent.cid = cid or '—'
    lastSent.name = name or ''
  end
end

local function getJob()
  local ok, job = pcall(function() return exports['sl-jobs']:GetClientJob() end)
  if ok and type(job) == 'table' then return job end
  return nil
end

local function pushJob(force)
  local j = getJob()
  if not j then return end
  if force
    or j.name ~= lastSent.jobName
    or j.grade ~= lastSent.jobGrade
    or j.onDuty ~= lastSent.onDuty
  then
    push({
      action = 'job',
      name = j.name,
      grade = j.grade,
      onDuty = j.onDuty == true,
      label = j.label or j.name,
      gradeLabel = j.gradeLabel or '—',
    })
    lastSent.jobName = j.name
    lastSent.jobGrade = j.grade
    lastSent.onDuty = j.onDuty
  end
end

local function pushMoney(force)
  local b = getBalances()
  local cash = math.floor(b.cash or 0)
  local bank = math.floor(b.bank or 0)
  local crypto = math.floor(b.crypto or 0)
  if force or cash ~= lastSent.cash or bank ~= lastSent.bank or crypto ~= lastSent.crypto then
    push({
      action = 'money',
      cash = formatMoney(cash),
      bank = formatMoney(bank),
      crypto = formatMoney(crypto),
    })
    lastSent.cash = cash
    lastSent.bank = bank
    lastSent.crypto = crypto
  end
end

local function pushHealth()
  local ped = PlayerPedId()
  if not ped or ped == 0 or not DoesEntityExist(ped) then return end
  local hp = GetEntityHealth(ped) - 100
  if hp < 0 then hp = 0 end
  local maxHp = GetEntityMaxHealth(ped) - 100
  if maxHp <= 0 then maxHp = 100 end
  local pct = math.floor((hp / maxHp) * 100)
  if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
  if pct ~= lastSent.hp then
    push({ action = 'health', hp = pct })
    lastSent.hp = pct
  end
end

CreateThread(function()
  while not NetworkIsSessionStarted() do Wait(500) end
  while not nuiReady do Wait(100) end
  Wait(500)
  showHud()
  print('[sl-hud/client] HUD initial show')
  while true do
    pushMoney()
    pushHealth()
    pushIdentity()
    pushJob()
    Wait(HUD.RefreshMs or 500)
  end
end)

AddEventHandler('sl:economy:moneyChanged', function(payload)
  if not payload or not payload.account then return end
  pushMoney(true)
  if payload.delta then
    push({ action = 'flash', account = payload.account, delta = payload.delta })
  end
end)

AddEventHandler('sl:economy:hydrated', function()
  pushMoney(true)
end)

AddEventHandler('sl:core:characterSelected', function()
  pushIdentity()
  pushMoney(true)
  pushJob(true)
end)

AddEventHandler('sl:jobs:hydrated', function() pushJob(true) end)
AddEventHandler('sl:jobs:jobChanged', function() pushJob(true) end)
AddEventHandler('sl:jobs:dutyChanged', function() pushJob(true) end)

RegisterCommand('hud', function()
  if hudVisible then hideHud() else showHud() end
end, false)

RegisterCommand('hud_show', function() showHud() end, false)
RegisterCommand('hud_hide', function() hideHud() end, false)

-- ===========================================================================
-- V1 : Carburant (en vehicule) — lit exports['sl-fuel']:GetFuel(netId)
-- ===========================================================================
local lastFuelShown = nil
local lastFuelLevel = -1
CreateThread(function()
  while true do
    Wait(700)
    local ped = PlayerPedId()
    local veh = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    local inVeh = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped
    if inVeh then
      local netId = NetworkGetEntityIsNetworked(veh) and NetworkGetNetworkIdFromEntity(veh) or nil
      local level = 100
      if netId then
        local ok, f = pcall(function() return exports['sl-fuel']:GetFuel(netId) end)
        if ok and type(f) == 'number' then level = f end
      end
      level = math.floor(level + 0.5)
      if lastFuelShown ~= true or level ~= lastFuelLevel then
        push({ action = 'fuel', show = true, level = level })
        lastFuelShown = true
        lastFuelLevel = level
      end
    else
      if lastFuelShown ~= false then
        push({ action = 'fuel', show = false })
        lastFuelShown = false
        lastFuelLevel = -1
      end
    end
  end
end)

-- sl-fuel peut aussi pousser localement
AddEventHandler('sl:fuel:update', function(payload)
  if payload and payload.level then
    push({ action = 'fuel', show = true, level = math.floor(payload.level + 0.5) })
    lastFuelShown = true
    lastFuelLevel = math.floor(payload.level + 0.5)
  end
end)

-- ===========================================================================
-- V1 : Overlay "A TERRE" (sl-death) + indicateur menottes (sl-police)
-- On ecoute a la fois le bus serveur (sl:bus:dispatch) ET les events locaux.
-- ===========================================================================
local function handleDeathEvent(event, payload)
  if event == 'sl:death:downed' then
    push({ action = 'down', down = true })
  elseif event == 'sl:death:revived' then
    push({ action = 'down', down = false })
    push({ action = 'downInfo', bleed = 0, timer = '' })
  elseif event == 'sl:death:respawned' then
    push({ action = 'down', down = false })
    push({ action = 'downInfo', bleed = 0, timer = '' })
  elseif event == 'sl:death:bleedChanged' then
    push({ action = 'downInfo', bleed = payload and payload.level or 0 })
  elseif event == 'sl:death:timer' then
    push({ action = 'downInfo', timer = payload and payload.text or '' })
  elseif event == 'sl:police:cuffed' then
    push({ action = 'cuffs', cuffed = true })
  elseif event == 'sl:police:uncuffed' then
    push({ action = 'cuffs', cuffed = false })
  end
end

RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  handleDeathEvent(event, payload)
end)

-- Events locaux (si sl-death/sl-police emettent cote client directement)
for _, ev in ipairs({
  'sl:death:downed', 'sl:death:revived', 'sl:death:respawned',
  'sl:death:bleedChanged', 'sl:death:timer',
  'sl:police:cuffed', 'sl:police:uncuffed',
}) do
  AddEventHandler(ev, function(payload) handleDeathEvent(ev, payload) end)
end

-- Keymap centralisé dans sl-keybinds (catégorie "SimpleLife" dans Settings)
