CreateThread(function()
  if not Clothing.Shops then return end
  for _, shop in ipairs(Clothing.Shops) do
    local blip = AddBlipForCoord(shop.x, shop.y, shop.z)
    SetBlipSprite(blip, Clothing.Blip.sprite)
    SetBlipColour(blip, Clothing.Blip.color)
    SetBlipScale(blip, Clothing.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(shop.label or Clothing.Blip.name)
    EndTextCommandSetBlipName(blip)
  end
  print('[sl-clothing/client] created ' .. #Clothing.Shops .. ' shop blips')
end)

-- ===========================================================================
-- Interactions : sl-interact (visée libre + touche E)
-- Les magasins de fringues sont des ZONES (pas de PNJ pour ce module).
-- ===========================================================================
CreateThread(function()
  if not Clothing.Shops then return end
  for _, shop in ipairs(Clothing.Shops) do
    exports['sl-interact']:AddZone({
      coords   = vec3(shop.x, shop.y, shop.z),
      radius   = 2.5,
      label    = ('Ouvrir le magasin — %s'):format(shop.label or 'Vêtements'),
      key      = 'E',
      onSelect = function() StartShop() end,
    })
  end
  print('[sl-clothing/client] interact zones enregistrées sur ' .. #Clothing.Shops .. ' shops')
end)

RegisterCommand('wardrobe', function() StartShop() end, false)
RegisterCommand('cloth',    function() StartShop() end, false)
