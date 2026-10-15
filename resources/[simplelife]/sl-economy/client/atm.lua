-- client/atm.lua
-- Gestion des zones ATM + banques et ouverture de la NUI banque grunge.
-- NE TOUCHE PAS a : balances, persistence, exports, callbacks serveur existants.

local nuiOpen = false

-- ===========================================================================
-- NUI callbacks (fermeture + actions delegues au serveur via lib.callback)
-- ===========================================================================

-- Fermeture via bouton X ou Echap
RegisterNUICallback('atm:close', function(_, cb)
  if not nuiOpen then cb({}) return end
  nuiOpen = false
  SetNuiFocus(false, false)
  cb({})
end)

-- Depot
RegisterNUICallback('atm:deposit', function(data, cb)
  local amount = math.floor(tonumber(data.amount) or 0)
  if amount <= 0 then cb({ ok = false, error = 'montant invalide' }) return end
  local res = lib.callback.await('sl-economy:atm:deposit', false, amount)
  cb(res or { ok = false, error = 'no response' })
end)

-- Retrait
RegisterNUICallback('atm:withdraw', function(data, cb)
  local amount = math.floor(tonumber(data.amount) or 0)
  if amount <= 0 then cb({ ok = false, error = 'montant invalide' }) return end
  local res = lib.callback.await('sl-economy:atm:withdraw', false, amount)
  cb(res or { ok = false, error = 'no response' })
end)

-- Virement (par numero de telephone ou citizenId)
RegisterNUICallback('atm:transfer', function(data, cb)
  local number = tostring(data.number or ''):gsub('%s+', '')
  local amount = math.floor(tonumber(data.amount) or 0)
  local reason = tostring(data.reason or ''):sub(1, 64)
  if number == '' then cb({ ok = false, error = 'numero requis' }) return end
  if amount <= 0  then cb({ ok = false, error = 'montant invalide' }) return end
  local res = lib.callback.await('sl-economy:transferByNumber', false, number, amount, reason)
  cb(res or { ok = false, error = 'no response' })
end)

-- Historique
RegisterNUICallback('atm:transactions', function(data, cb)
  local limit = math.min(math.max(tonumber(data.limit) or 50, 1), 100)
  local rows = lib.callback.await('sl-economy:transactions', false, limit)
  cb(rows or {})
end)

-- ===========================================================================
-- Ouverture de la NUI banque
-- ===========================================================================
local function openAtmNUI()
  local balances = lib.callback.await('sl-economy:getBalances', false)
  print('[sl-economy/client] ATM NUI open, balances: ' .. (balances and json.encode(balances) or 'nil'))

  if not balances or (balances.cash == 0 and balances.bank == 0 and balances.crypto == 0) then
    balances = ClientEconomy and ClientEconomy.balances or { cash = 0, bank = 0, crypto = 0 }
  end

  nuiOpen = true
  SetNuiFocus(true, true)
  SendNUIMessage({
    action   = 'open',
    balances = {
      cash   = balances.cash   or 0,
      bank   = balances.bank   or 0,
      crypto = balances.crypto or 0,
    },
  })
end

-- Ecoute l'event bus pour rafraichir les soldes si la NUI est ouverte
RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  if not nuiOpen then return end
  if event == 'sl:economy:moneyChanged' then
    local balances = lib.callback.await('sl-economy:getBalances', false)
    if not balances then return end
    SendNUIMessage({
      action   = 'balances',
      balances = {
        cash   = balances.cash   or 0,
        bank   = balances.bank   or 0,
        crypto = balances.crypto or 0,
      },
    })
  end
end)

-- ===========================================================================
-- Interactions : sl-interact (visee libre + touche E)
--
-- 2 types de points :
--   ATMs  (Economy.ATM.locations)        -> NUI
--   Banques (Economy.Bank.locations)     -> NUI
-- ===========================================================================
CreateThread(function()
  local registered = 0

  if Economy.ATM and Economy.ATM.locations then
    for _, loc in ipairs(Economy.ATM.locations) do
      exports['sl-interact']:AddZone({
        coords   = vec3(loc.x, loc.y, loc.z),
        radius   = 1.6,
        label    = 'Utiliser le distributeur',
        key      = 'E',
        onSelect = function() openAtmNUI() end,
      })
      registered = registered + 1
    end
  end

  if Economy.Bank and Economy.Bank.locations then
    for _, loc in ipairs(Economy.Bank.locations) do
      exports['sl-interact']:AddZone({
        coords   = vec3(loc.x, loc.y, loc.z),
        radius   = 2.2,
        label    = 'Entrer dans la banque',
        key      = 'E',
        onSelect = function() openAtmNUI() end,
      })
      registered = registered + 1
    end
  end

  print(('[sl-economy/client] %d zones d\'interaction enregistrees (ATM + banques)'):format(registered))
end)

-- ===========================================================================
-- Blips
-- ===========================================================================
CreateThread(function()
  if Economy.Bank and Economy.Bank.locations then
    for _, loc in ipairs(Economy.Bank.locations) do
      local blip = AddBlipForCoord(loc.x, loc.y, loc.z)
      SetBlipSprite(blip, Economy.Bank.blip.sprite)
      SetBlipColour(blip, Economy.Bank.blip.color)
      SetBlipScale(blip, Economy.Bank.blip.scale)
      SetBlipAsShortRange(blip, true)
      BeginTextCommandSetBlipName('STRING')
      AddTextComponentSubstringPlayerName(Economy.Bank.blip.name)
      EndTextCommandSetBlipName(blip)
    end
    print('[sl-economy/client] created ' .. #Economy.Bank.locations .. ' bank blips')
  end

  if Economy.ATM and Economy.ATM.showBlips and Economy.ATM.locations then
    for _, loc in ipairs(Economy.ATM.locations) do
      local blip = AddBlipForCoord(loc.x, loc.y, loc.z)
      SetBlipSprite(blip, Economy.ATM.blip.sprite)
      SetBlipColour(blip, Economy.ATM.blip.color)
      SetBlipScale(blip, Economy.ATM.blip.scale)
      SetBlipAsShortRange(blip, true)
      SetBlipDisplay(blip, 4)
      BeginTextCommandSetBlipName('STRING')
      AddTextComponentSubstringPlayerName(Economy.ATM.blip.name)
      EndTextCommandSetBlipName(blip)
    end
    print('[sl-economy/client] created ' .. #Economy.ATM.locations .. ' ATM blips')
  end
end)
