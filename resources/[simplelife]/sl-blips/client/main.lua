print('[sl-blips/client] main.lua loaded')

local created = {}

local function createAll()
  for _, b in ipairs(Blips.List or {}) do
    local cat = b.category or 'misc'
    if Blips.Enabled[cat] ~= false then
      local blip = AddBlipForCoord(b.x + 0.0, b.y + 0.0, b.z + 0.0)
      SetBlipSprite(blip, b.sprite or 1)
      SetBlipColour(blip, b.color or 0)
      SetBlipScale(blip, b.scale or 0.8)
      SetBlipAsShortRange(blip, b.shortRange ~= false)
      SetBlipDisplay(blip, 4)
      BeginTextCommandSetBlipName('STRING')
      AddTextComponentSubstringPlayerName(b.label or 'Point')
      EndTextCommandSetBlipName(blip)
      created[#created + 1] = blip
    end
  end
  print(('[sl-blips] %d blips créés'):format(#created))
end

local function removeAll()
  for _, blip in ipairs(created) do
    if DoesBlipExist(blip) then RemoveBlip(blip) end
  end
  created = {}
end

CreateThread(function()
  while not NetworkIsSessionStarted() do Wait(500) end
  Wait(1500)
  createAll()
end)

-- Recrée proprement au restart de la ressource
AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then removeAll() end
end)

-- Commande pour basculer une catégorie (debug)
RegisterCommand('blips', function(_, args)
  local cat = args[1]
  if not cat or Blips.Enabled[cat] == nil then
    print('[sl-blips] catégories : ' .. (function()
      local t = {} for k in pairs(Blips.Enabled) do t[#t+1] = k end return table.concat(t, ', ')
    end)())
    return
  end
  Blips.Enabled[cat] = not Blips.Enabled[cat]
  removeAll()
  createAll()
  lib = lib or {}
  TriggerEvent('chat:addMessage', { args = { 'sl-blips', ('%s -> %s'):format(cat, tostring(Blips.Enabled[cat])) } })
end, false)
