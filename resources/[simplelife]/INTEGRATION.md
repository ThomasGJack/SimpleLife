# SimpleLife — Contrat d'intégration V1 (À RESPECTER PAR TOUS LES MODULES)

Ce document fige les interfaces partagées. Chaque nouveau module DOIT respecter exactement les noms d'events, d'exports et d'items ci-dessous pour s'assembler au runtime avec les autres.

## Pattern standard d'un module SimpleLife

Référence vivante : lis `sl-hunger/` (server/main.lua, server/api.lua, client/main.lua, sql/) qui est un module complet et propre à copier comme squelette. Lis aussi `sl-inventory/server/api.lua` pour le pattern API+exports+callbacks et `sl-inventory/html/` pour la NUI grunge.

```lua
-- server/main.lua
print('[sl-MODULE/server] main.lua loaded')
local SL = exports['sl-core']
Cache = Cache or {}

local function tryIsReady()
  local ok, ready = pcall(function() return SL:IsReady() end)
  return ok and ready == true
end

local registered = false
local function registerSelf()
  if registered then return end
  registered = true
  local apiOk, api = pcall(function() return SL:CoreApi() end)
  SL:RegisterModule({
    name = GetCurrentResourceName(),
    version = '0.1.0',
    coreApi = apiOk and api or 1,
    deps = { 'sl-core@^0.1' },   -- + autres deps
  })
end
AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function() while not tryIsReady() do Wait(200) end; registerSelf() end)

AddEventHandler('sl:core:characterSelected', function(payload)
  -- payload.source, payload.characterId, payload.citizenId, payload.data, payload.position
  -- charge/crée les données du perso depuis SL:DB(), met en Cache[source]
end)
AddEventHandler('sl:core:playerDropped', function(payload)
  -- persiste si dirty, puis Cache[payload.source] = nil
end)
```

### DB (toujours via sl-core, jamais MySQL direct)
```lua
local db = SL:DB()
local rows = db.query('SELECT ... WHERE x = ?', { x })      -- array
local row  = db.single('SELECT ... WHERE id = ?', { id })   -- 1 ligne ou nil
local n    = db.scalar('SELECT COUNT(*) FROM t')            -- 1 valeur
local id   = db.insert('INSERT ... VALUES (?, ?)', { a, b }) -- insertId
local aff  = db.update('UPDATE ... SET x=? WHERE id=?', {x, id}) -- lignes affectées
```

### Bus (cross-resource)
```lua
-- Serveur émet un event global : TriggerEvent('sl:MODULE:EVENT', payload)
-- Serveur → client : TriggerClientEvent('sl:bus:dispatch', src, 'sl:MODULE:EVENT', payload)
-- Client écoute : RegisterNetEvent('sl:bus:dispatch', function(event, payload) ... end)
```

### Notifications
```lua
-- ox_lib : TriggerClientEvent('ox_lib:notify', src, { description='...', type='success'|'error'|'inform' })
-- ou côté client : lib.notify({ description='...', type='...' })
```

### PIÈGES CONNUS (À ÉVITER ABSOLUMENT)
1. **JSON keys** : pour toute map à clés numériques denses envoyée en NUI/JSON, utilise `tostring(idx)` comme clé. Sinon cjson sérialise en array JS indexé à 0 → décalage.
2. **SQL** : JAMAIS de `;` ni d'apostrophe dans les commentaires `--` des fichiers .sql (le runner sl-core split sur `;` après strip des commentaires ligne — mais reste prudent, écris les commentaires SQL en ASCII sans `;`).
3. **Exports cross-resource** : toujours `exports['sl-core']:Fn()` (bracket), jamais `exports.sl_core`.
4. **NUI fetch** : `https://${GetParentResourceName()}/callback` — utilise GetParentResourceName(), pas le nom en dur.
5. **Migrations** : `sql/index.lua` retourne `{ '001_xxx.sql' }`. Chaque table `CREATE TABLE IF NOT EXISTS sl_MODULE_xxx`. FK vers `sl_characters(id) ON DELETE CASCADE`.

## Style visuel GTA V grunge (palette à réutiliser)
Copie les variables CSS depuis `sl-inventory/html/style.css` (`:root`). Résumé :
```
--bg:#0a0907  --bg-panel:#161310  --bg-panel-2:#1c1611  --bg-slot:#1f1a14
--border:#3a2d1f  --border-h:#5a4730  --gold:#ffb000  --gold-d:#cc7e3a
--money:#4ade80  --red:#c8362d  --text:#e8d9b8  --text-mute:#8a7a5a
Polices Google : Oswald (titres), Roboto Condensed (corps), Roboto Mono (chiffres).
Texture grunge SVG noise inline (voir sl-inventory). PAS de glassmorphism/blur.
```
Toast in-NUI au-dessus de l'overlay quand une fenêtre plein écran est ouverte (pattern sl-inventory `slNotify`).
EXCEPTION : les apps du téléphone (sl-phone) gardent le style iOS dark existant.

## EVENTS BUS PARTAGÉS (producteur → consommateurs)
```
sl:death:downed         {source}                  prod: sl-death      cons: sl-ems, sl-hud, sl-police
sl:death:revived        {source, by}              prod: sl-death      cons: sl-hud, sl-skills
sl:death:respawned      {source}                  prod: sl-death      cons: sl-hud
sl:death:bleedChanged   {source, level}           prod: sl-death      cons: sl-hud
sl:vehicles:spawned     {source, netId, plate}    prod: sl-vehicles   cons: sl-fuel, sl-jobmissions
sl:vehicles:stored      {source, plate}           prod: sl-vehicles
sl:vehicles:keysChanged {source, plate, has}      prod: sl-vehicles
sl:police:cuffed        {target, by}              prod: sl-police     cons: sl-hud
sl:police:uncuffed      {target}                  prod: sl-police     cons: sl-hud
sl:police:jailed        {target, seconds}         prod: sl-police
sl:ems:revivedTarget    {medic, target}           prod: sl-ems        cons: sl-skills
sl:skills:levelUp       {source, skill, level}    prod: sl-skills     cons: sl-hud, sl-phone
sl:gangs:memberChanged  {source, gang, grade}     prod: sl-gangs
sl:gangs:territory      {zone, gang}              prod: sl-gangs
sl:crime:robberyStarted {shop, source, coords}    prod: sl-crime      cons: sl-police
sl:crime:dealCompleted  {source, drug, amount}    prod: sl-crime
sl:jobs:dutyChanged     {source, name, onDuty}    prod: sl-jobs (EXISTE) cons: sl-ems, sl-police, sl-jobmissions
```

## EXPORTS PUBLICS (signatures figées)
```
sl-death      : IsDowned(src)->bool | Revive(src) | Kill(src) | SetBleed(src,lvl) | Respawn(src)
sl-weapons    : GiveWeapon(src,name,ammo) | RemoveWeapon(src,name) | GetEquipped(src) | GiveAmmo(src,ammoType,n)
sl-fuel       : GetFuel(netId)->n | SetFuel(netId,n) | Consume(netId,n)
sl-vehicles   : SpawnOwned(src,plate)->netId | StoreVehicle(plate) | GiveKeys(src,plate) | HasKeys(src,plate)->bool
                | ListOwned(src)->array | RegisterOwnership(src,plate,model,props)->plate | GetFuel(plate)->n | SetFuel(plate,n)
sl-properties : HasAccess(src,propId)->bool | OpenStash(src,propId) | GetOwned(src)->array | EnterProperty(src,propId)
sl-skills     : AddXP(src,skill,amount) | GetXP(src,skill)->n | GetLevel(src,skill)->n | GetAll(src)->table
sl-police     : IsCuffed(src)->bool | Cuff(by,target) | Jail(target,seconds) | AddCharge(citizenId,charge,fine)
sl-ems        : ReviveTarget(medic,target) | HealTarget(medic,target,amount) | GetInjuries(src)->table
sl-gangs      : GetGang(src)->{name,grade}|nil | IsInGang(src,gangName)->bool | GetTerritoryOwner(zone)->gang
```

## EXPORTS EXISTANTS À CONSOMMER (déjà en place, NE PAS recréer)
```
sl-core      : GetPlayer(src) | GetPlayers() | DB() | Bus() | IsReady() | CoreApi() | RegisterModule(spec) | GenCitizenId()
sl-economy   : AddMoney(src,acc,amt,reason) | RemoveMoney(src,acc,amt,reason) | GetMoney(src,acc) | GetBalances(src)
               | Transfer(fromSrc,toSrc,acc,amt,reason) | GetRecentTransactions(src,limit)
sl-inventory : AddItem(src,item,count,metadata,reason) | RemoveItem(src,item,count,metadata,reason) | GetItem(src,item)->n
               | HasItem(src,item,count)->bool | GetItems(src) | CanCarry(src,item,count) | UseItem(src,slot)
               | GiveJobKit(src,jobName) | RemoveJobKit(src,jobName) | GetCatalog()  [client: HasItem(item,n), GetItem(item)]
sl-jobs      : SetJob(src,job,grade) | SetGrade(src,grade) | SetDuty(src,onDuty) | GetJob(src) | GetOnDutyPlayers(jobName)->array
sl-interact  : AddEntity(entity,options)->id | AddZone({coords,radius,label,key,onSelect})->id | Remove(id) | RemoveEntity(entity)
sl-phone     : GetMyNumber(src) | GetCharacterByNumber(num) | SendSMS(src,toNumber,body) | AddContact(src,name,number)
sl-clothing  : GetAppearance(src) | SetAppearance(src,appearance)
```

## sl-interact (système d'œil) — usage type
```lua
exports['sl-interact']:AddEntity(pedHandle, {
  label = 'Acheter — Concession', key = 'E', distance = 3.0,
  onSelect = function() openConcession() end,
})
exports['sl-interact']:AddZone({ coords = vec3(x,y,z), radius = 2.0, label='Garage', key='E', onSelect=fn })
```

## ITEMS INVENTAIRE (déjà ajoutés au catalogue sl-inventory/shared/items.lua)
Catégories : food, drink, tool, weapon, key, license, badge, doc, valuable, misc, ammo, drug, material.
Munitions: ammo_pistol/smg/rifle/shotgun (useEffect type='ammo', ammoType='AMMO_PISTOL'...).
Drogue: weed_seed/bud/packaged, coke_raw/packaged, meth_raw/packaged.
Outils crime: lockpick, advanced_lockpick, drill, thermite.
Matériaux: metal_scrap, plastic, electronics, fabric, rubber, glass, aluminum.
EMS+: painkillers, suture_kit, oxygen_mask.
Mécano: repair_kit, body_kit, tire_repair.
Armes (existent): pistolet, combat_pistol, smg, taser, matraque (weaponHash mappé).
Clés (existent): cle_voiture (metadata {plate=...}), cle_maison (metadata {propId=...}).

## COORDS CLÉS
```
Hôpital respawn Pillbox : vec3(341.0, -1397.3, 32.5)
MRPD commissariat       : vec3(441.0, -982.0, 30.7)
Concession PDM          : vec3(-56.7, -1096.6, 26.4)
Garage public central   : vec3(215.9, -810.0, 30.7)
Prison Bolingbroke      : vec3(1845.0, 2585.0, 45.0)
Station-service (1 ex)  : vec3(265.0, -1261.3, 29.3)
```

## Tables SQL par module (préfixe sl_)
```
sl-vehicles  : sl_vehicles(id, character_id FK, plate UNIQUE, model, props JSON, fuel TINYINT,
               body_health FLOAT, engine_health FLOAT, state ENUM/varchar(garage|out|impound),
               garage VARCHAR, position JSON, created_at)
sl-properties: sl_properties(id, label, type, price INT, owner_character_id FK NULL, enter JSON, ipl VARCHAR, interior JSON)
               sl_property_access(id, property_id FK, character_id FK)
               sl_property_stash(id, property_id, slot, item, count, metadata JSON)
sl-police    : sl_police_records(id, citizen_id, charges JSON, total_fine INT, created_at)
               sl_police_bolos(id, citizen_id, reason, created_by, created_at)
sl-skills    : sl_skills(id, character_id FK, skill VARCHAR, xp INT, UNIQUE(character_id,skill))
sl-gangs     : sl_gangs(id, name UNIQUE, color VARCHAR, boss_citizen_id)
               sl_gang_members(id, gang_id FK, character_id FK, grade INT)
               sl_gang_territories(id, zone VARCHAR UNIQUE, gang_id FK NULL, influence INT)
sl-crime     : sl_crime_cooldowns(id, kind VARCHAR, target VARCHAR, until_ts BIGINT)
sl-phone(new): sl_phone_social_posts(id, character_id, body, image VARCHAR NULL, likes INT, created_at)
               sl_phone_market_listings(id, character_id, title, price INT, body, number VARCHAR, created_at)
               sl_phone_emergency_calls(id, from_number, service VARCHAR, coords JSON, message, created_at)
```
Note: sl-fuel, sl-death, sl-crafting, sl-jobmissions, sl-ems = pas de table (runtime + config), sauf bills EMS si voulu.
