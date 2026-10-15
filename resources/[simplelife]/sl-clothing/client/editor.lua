EditorCam = nil
EditorActive = false
local working = nil
local original = nil
local camAngle = 180.0
local camDist = 2.4
local camHeight = 0.3
local camAuto = true
local camThread = nil

local function deepCopy(t)
  if type(t) ~= 'table' then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = deepCopy(v) end
  return r
end

local function updateCam()
  if not EditorCam then return end
  local ped = PlayerPedId()
  local pcoords = GetEntityCoords(ped)
  local rad = math.rad(camAngle)
  local cx = pcoords.x + math.sin(rad) * camDist
  local cy = pcoords.y - math.cos(rad) * camDist

  -- Lateral offset: shift cam to the LEFT (perpendicular to view) so ped appears on the RIGHT side of the screen
  local lateralOffset = -0.9
  cx = cx + math.cos(rad) * lateralOffset
  cy = cy + math.sin(rad) * lateralOffset

  SetCamCoord(EditorCam, cx, cy, pcoords.z + camHeight)
  PointCamAtEntity(EditorCam, ped, 0.0, 0.0, 0.2, true)
end

local function setupEditorCam()
  local ped = PlayerPedId()
  EditorCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
  SetCamFov(EditorCam, 38.0)
  updateCam()
  RenderScriptCams(true, true, 600, true, true)

  if camThread then return end
  camThread = true
  CreateThread(function()
    while EditorActive do
      Wait(20)
      if camAuto then
        camAngle = (camAngle + 0.4) % 360
      end
      updateCam()
    end
    camThread = nil
  end)
end

local function teardownEditorCam()
  if EditorCam then
    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(EditorCam, true)
    EditorCam = nil
  end
end

local function getSex()
  local appearance = exports['sl-clothing']:GetAppearance()
  if appearance and appearance.model then
    return appearance.model:find('mp_f_') and 'f' or 'm'
  end
  return 'm'
end

local function enumerateDrawables()
  local ped = PlayerPedId()
  local model = GetEntityModel(ped)
  local sex = GetClothingSex()
  print(('[sl-clothing] enumerateDrawables: ped model=%s sex=%s'):format(tostring(model), sex))
  local out = { components = {}, props = {} }

  for _, c in ipairs(Clothing.Components) do
    local nbDraw = GetNumberOfPedDrawableVariations(ped, c.id)
    print(('[sl-clothing] component %d (%s): nbDraw=%d'):format(c.id, c.label, nbDraw))
    if nbDraw <= 0 then nbDraw = 250 end
    local drawables = {}
    for d = 0, nbDraw - 1 do
      local valid = IsPedComponentVariationValid(ped, c.id, d, 0)
      local texMax = GetNumberOfPedTextureVariations(ped, c.id, d) - 1
      if texMax < 0 then texMax = 0 end
      local item = {
        drawable = d,
        textures = texMax,
        valid = valid,
      }
      if c.id == 11 then
        local best = GetBestTorsoFor(sex, d, 0)
        item.compatible = best ~= nil
        if best then item.bestTorso = best end
      end
      table.insert(drawables, item)
    end
    out.components[tostring(c.id)] = drawables
    Wait(0)
  end

  for _, p in ipairs(Clothing.Props) do
    local nbDraw = GetNumberOfPedPropDrawableVariations(ped, p.id)
    print(('[sl-clothing] prop %d (%s): nbDraw=%d'):format(p.id, p.label, nbDraw))
    if nbDraw <= 0 then nbDraw = 100 end
    local drawables = {}
    table.insert(drawables, { drawable = -1, textures = 0, valid = true })
    for d = 0, nbDraw - 1 do
      local texMax = GetNumberOfPedPropTextureVariations(ped, p.id, d) - 1
      if texMax < 0 then texMax = 0 end
      table.insert(drawables, {
        drawable = d,
        textures = texMax,
        valid = true,
      })
    end
    out.props[tostring(p.id)] = drawables
    Wait(0)
  end

  return out
end

LastAutoTorso = LastAutoTorso or nil

local function applyPreview(kind, id, drawable, texture)
  local ped = PlayerPedId()
  if kind == 'component' then
    SetPedComponentVariation(ped, id, drawable or 0, texture or 0, 0)
    if id == 11 then
      local sex = GetClothingSex()
      local best = GetBestTorsoFor(sex, drawable or 0, texture or 0)
      if best then
        SetPedComponentVariation(ped, 3, best.drawable, best.texture, 0)
        LastAutoTorso = { drawable = best.drawable, texture = best.texture }
        SendNUIMessage({
          action = 'autoApplied',
          component = 3,
          drawable = best.drawable,
          texture = best.texture,
          compatible = true,
        })
      else
        LastAutoTorso = nil
        SendNUIMessage({
          action = 'autoApplied',
          component = 3,
          compatible = false,
        })
      end
    end
  else
    if drawable == nil or drawable == -1 then
      ClearPedProp(ped, id)
    else
      SetPedPropIndex(ped, id, drawable, texture or 0, true)
    end
  end
end

local function commitCart(changes)
  if not changes or #changes == 0 then
    lib.notify({ type = 'info', title = 'Magasin', description = 'Aucune modification' })
    return true
  end
  print('[sl-clothing] commitCart sending ' .. #changes .. ' changes')
  local res = lib.callback.await('sl-clothing:purchase', false, { changes = changes })
  if not res or not res.ok then
    lib.notify({ type = 'error', title = 'Achat refusé', description = res and res.error or 'unknown' })
    print('[sl-clothing] purchase REFUSED: ' .. (res and res.error or 'unknown'))
    return false
  end
  print(('[sl-clothing] purchase OK: -%d $ (%s)'):format(res.price, res.account or '?'))
  lib.notify({
    type = 'success',
    title = 'Achat validé',
    description = ('-%d $ (%s)'):format(res.price, res.account or '?'),
  })
  return true
end

local function cancelEdit()
  if original then
    exports['sl-clothing']:ApplyAppearance(original)
  end
end

local function endShop()
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  teardownEditorCam()
  EditorActive = false
  working = nil
  original = nil
end

local function presetsForSex(sex)
  local out = {}
  for _, p in ipairs(Clothing.Presets or {}) do
    if not p.sex or p.sex == sex then
      table.insert(out, {
        id = p.id,
        label = p.label,
        price = p.price,
        components = p.components,
        props = p.props,
      })
    end
  end
  return out
end

function StartShop()
  if EditorActive then return end

  local current = exports['sl-clothing']:GetAppearance()
  if not current then
    current = lib.callback.await('sl-clothing:getAppearance', false)
  end
  if not current then
    lib.notify({ type = 'error', title = 'Apparence', description = 'Apparence non chargée' })
    return
  end

  EditorActive = true
  original = deepCopy(current)
  working = deepCopy(current)
  setupEditorCam()

  local sex = getSex()
  local enumerated = enumerateDrawables()

  local categories = {}
  for _, c in ipairs(Clothing.Components) do
    table.insert(categories, { kind = 'component', id = c.id, key = c.key or ('c' .. c.id), label = c.label, price = c.price })
  end
  for _, p in ipairs(Clothing.Props) do
    table.insert(categories, { kind = 'prop', id = p.id, key = p.key or ('p' .. p.id), label = p.label, price = p.price })
  end

  SendNUIMessage({
    action = 'open',
    appearance = working,
    categories = categories,
    components = Clothing.Components,
    props = Clothing.Props,
    drawables = enumerated,
    presets = presetsForSex(sex),
    camRotating = camAuto,
  })
  SetNuiFocus(true, true)
end

RegisterNUICallback('preview', function(data, cb)
  applyPreview(data.kind, data.id, data.drawable, data.texture)
  cb({ ok = true })
end)

RegisterNUICallback('applyPreset', function(data, cb)
  print('[sl-clothing] applyPreset callback received')
  if (not data.components or next(data.components) == nil) and (not data.props or next(data.props) == nil) then
    print('[sl-clothing] preset is empty')
    cb({ ok = false }); return
  end
  local count = 0
  for id, v in pairs(data.components or {}) do
    local cid = tonumber(id)
    if cid and v.drawable ~= nil then
      print(('[sl-clothing] preset apply component id=%d drawable=%d texture=%d'):format(cid, v.drawable, v.texture or 0))
      applyPreview('component', cid, v.drawable, v.texture)
      count = count + 1
    end
  end
  for id, v in pairs(data.props or {}) do
    local pid = tonumber(id)
    if pid then
      print(('[sl-clothing] preset apply prop id=%d drawable=%s texture=%d'):format(pid, tostring(v.drawable), v.texture or 0))
      applyPreview('prop', pid, v.drawable, v.texture)
      count = count + 1
    end
  end
  print(('[sl-clothing] preset applied: %d changes'):format(count))
  cb({ ok = true })
end)

RegisterNUICallback('camRotate', function(data, cb)
  camAuto = data.active and true or false
  cb({ ok = true })
end)

RegisterNUICallback('camZoom', function(data, cb)
  camDist = math.min(5.0, math.max(1.2, camDist + (tonumber(data.delta) or 0)))
  cb({ ok = true })
end)

RegisterNUICallback('cancel', function(_, cb)
  cancelEdit()
  endShop()
  cb({ ok = true })
end)

RegisterNUICallback('validate', function(data, cb)
  local changes = data.changes or {}
  local autoTorsoChange = nil
  for _, ch in ipairs(changes) do
    if ch.kind == 'component' and ch.id == 11 and ch.autoTorso and ch.autoTorso.drawable then
      autoTorsoChange = {
        kind = 'component',
        id = 3,
        drawable = ch.autoTorso.drawable,
        texture = ch.autoTorso.texture or 0,
        price = 0,
        label = 'Bras auto-ajusté',
      }
      break
    end
  end
  if autoTorsoChange then table.insert(changes, autoTorsoChange) end
  local ok = commitCart(changes)
  if ok == false then cancelEdit() end
  endShop()
  cb({ ok = true })
end)
