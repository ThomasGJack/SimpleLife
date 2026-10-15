SL = SL or {}
SL.Modules = { registry = {} }

function SL.Modules.Register(spec)
  assert(type(spec) == 'table', 'spec must be table')
  assert(spec.name, 'spec.name required')
  assert(spec.version, 'spec.version required')
  assert(spec.coreApi, 'spec.coreApi required')

  if spec.coreApi ~= SL_CORE_API then
    print(('^1[sl-core] module %s: coreApi mismatch (mod=%s, core=%s) -> refused^0'):format(spec.name, spec.coreApi, SL_CORE_API))
    return false
  end

  if spec.deps then
    for _, dep in ipairs(spec.deps) do
      local depName, depRange = dep:match('^([^@]+)@?(.*)$')
      depName = depName or dep
      if depName ~= 'sl-core' then
        local got = SL.Modules.registry[depName]
        if not got then
          print(('^3[sl-core] module %s: dep %s not yet registered (will continue)^0'):format(spec.name, dep))
        elseif depRange and depRange ~= '' and not SL.Utils.semverSatisfies(got.version, depRange) then
          print(('^1[sl-core] module %s: dep %s requires %s but got %s -> refused^0'):format(spec.name, depName, depRange, got.version))
          return false
        end
      end
    end
  end

  SL.Modules.registry[spec.name] = {
    name = spec.name,
    version = spec.version,
    coreApi = spec.coreApi,
    deps = spec.deps or {},
    loadedAt = os.time(),
  }

  pcall(function()
    SL.DB.query(
      'INSERT INTO sl_modules_registry (name, version, core_api) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE version=VALUES(version), core_api=VALUES(core_api), loaded_at=CURRENT_TIMESTAMP',
      { spec.name, spec.version, spec.coreApi }
    )
  end)

  SL.Bus.Emit('sl:core:moduleRegistered', { name = spec.name, version = spec.version })
  print(('^2[sl-core] module registered: %s v%s (api=%s)^0'):format(spec.name, spec.version, spec.coreApi))
  return true
end

function SL.Modules.Unregister(name)
  SL.Modules.registry[name] = nil
end

function SL.Modules.Get(name)
  return SL.Modules.registry[name]
end

function SL.Modules.List()
  local out = {}
  for _, mod in pairs(SL.Modules.registry) do table.insert(out, mod) end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() and SL.Modules.registry[resource] then
    SL.Modules.Unregister(resource)
    print(('^3[sl-core] module unregistered: %s^0'):format(resource))
  end
end)
