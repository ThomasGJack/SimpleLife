print('[sl-vehicles/server] commands.lua loaded')

-- =============================================================================
-- sl-vehicles / server/commands.lua
-- Commandes admin + debug
-- =============================================================================

-- /givevehicle [plate] [model] : donne un vehicule a un joueur
RegisterCommand('givevehicle', function(source, args, rawCmd)
  -- admin check
  if source ~= 0 and not IsPlayerAceAllowed(source, 'sl.admin') then
    if source > 0 then TriggerClientEvent('ox_lib:notify', source, { description = 'Acces refuse.', type = 'error' }) end
    return
  end

  local targetSrc = tonumber(args[1])
  local model     = args[2]
  if not targetSrc or not model then
    if source == 0 then print('Usage: givevehicle <src> <model>') end
    if source > 0 then TriggerClientEvent('ox_lib:notify', source, { description = 'Usage: /givevehicle <src> <model>', type = 'error' }) end
    return
  end

  if not GetPlayerName(targetSrc) then
    if source > 0 then TriggerClientEvent('ox_lib:notify', source, { description = 'Joueur introuvable.', type = 'error' }) end
    return
  end

  local plate = RegisterOwnership(targetSrc, nil, model, nil)
  if not plate then
    local msg = 'Erreur lors de la creation du vehicule.'
    if source == 0 then print(msg) end
    if source > 0 then TriggerClientEvent('ox_lib:notify', source, { description = msg, type = 'error' }) end
    return
  end

  -- Donne la cle
  pcall(function()
    exports['sl-inventory']:AddItem(targetSrc, 'cle_voiture', 1, { plate = plate }, 'givevehicle_admin')
  end)

  TriggerClientEvent('ox_lib:notify', targetSrc, {
    description = ('Vehicule %s recu ! Plaque : %s'):format(model, plate),
    type = 'success',
  })

  local msg2 = ('[sl-vehicles] givevehicle: src=%d model=%s plate=%s by admin=%d'):format(targetSrc, model, plate, source)
  print(msg2)
  if source > 0 then TriggerClientEvent('ox_lib:notify', source, { description = 'Vehicule donne : ' .. plate, type = 'success' }) end
end, false)

-- /delvehicle [plate] : supprime un vehicule de la DB
RegisterCommand('delvehicle', function(source, args, rawCmd)
  if source ~= 0 and not IsPlayerAceAllowed(source, 'sl.admin') then
    if source > 0 then TriggerClientEvent('ox_lib:notify', source, { description = 'Acces refuse.', type = 'error' }) end
    return
  end

  local plate = args[1]
  if not plate then
    if source == 0 then print('Usage: delvehicle <plate>') end
    if source > 0 then TriggerClientEvent('ox_lib:notify', source, { description = 'Usage: /delvehicle <plate>', type = 'error' }) end
    return
  end

  local aff = SL:DB().update('DELETE FROM sl_vehicles WHERE plate = ?', { plate })
  VehicleCache[plate] = nil

  local msg = ('[sl-vehicles] delvehicle: plate=%s affected=%s'):format(plate, tostring(aff))
  print(msg)
  if source > 0 then TriggerClientEvent('ox_lib:notify', source, { description = 'Vehicule supprime : ' .. plate, type = 'success' }) end
end, false)

-- /listvehicles [src] : liste les vehicules d'un joueur
RegisterCommand('listvehicles', function(source, args, rawCmd)
  if source ~= 0 and not IsPlayerAceAllowed(source, 'sl.admin') then
    if source > 0 then TriggerClientEvent('ox_lib:notify', source, { description = 'Acces refuse.', type = 'error' }) end
    return
  end

  local targetSrc = tonumber(args[1]) or source
  local list = ListOwned(targetSrc)
  if source == 0 then
    print(('[sl-vehicles] listvehicles src=%d count=%d'):format(targetSrc, #list))
    for _, v in ipairs(list) do
      print(('  plate=%s model=%s state=%s fuel=%s'):format(v.plate, v.model, v.state, tostring(v.fuel)))
    end
  end
  if source > 0 then
    local desc = ('Vehicules de %d : %d'):format(targetSrc, #list)
    TriggerClientEvent('ox_lib:notify', source, { description = desc, type = 'inform' })
  end
end, false)

-- /setfuel [plate] [n] : modifie le fuel en DB
RegisterCommand('setfuel', function(source, args, rawCmd)
  if source ~= 0 and not IsPlayerAceAllowed(source, 'sl.admin') then
    if source > 0 then TriggerClientEvent('ox_lib:notify', source, { description = 'Acces refuse.', type = 'error' }) end
    return
  end

  local plate = args[1]
  local n     = tonumber(args[2])
  if not plate or not n then
    if source == 0 then print('Usage: setfuel <plate> <0-100>') end
    if source > 0 then TriggerClientEvent('ox_lib:notify', source, { description = 'Usage: /setfuel <plate> <0-100>', type = 'error' }) end
    return
  end

  SetVehicleFuel(plate, n)
  local msg = ('[sl-vehicles] setfuel plate=%s fuel=%d'):format(plate, n)
  print(msg)
  if source > 0 then TriggerClientEvent('ox_lib:notify', source, { description = msg, type = 'success' }) end
end, false)
