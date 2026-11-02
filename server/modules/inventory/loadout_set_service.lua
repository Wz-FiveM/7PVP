---Sets d'équipement : le joueur enregistre le contenu de son sac et, chez le banquier, le ressort
---des coffres en un clic. Un set ne garde que des quantités : il ne crée jamais d'objet.
---@class LoadoutSetServiceModule
local LoadoutSetService = PVP.define('LoadoutSetService')
local InventoryObject = PVP.use('InventoryObject')
local InventoryService = PVP.use('InventoryService')
local PlayerRepository = PVP.use('PlayerRepository')
local SafeNpcs = PVP.use('SafeNpcs')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

function LoadoutSetService.init()
    Callback.register(Events.callbacks.loadoutSetSave, LoadoutSetService.save)
    Callback.register(Events.callbacks.loadoutSetApply, LoadoutSetService.apply)
    Callback.register(Events.callbacks.loadoutSetClear, LoadoutSetService.clear)
end

---Toujours Config.LoadoutSets.slots emplacements : `false` pour un emplacement vide.
---@param raw any valeur de la colonne loadout_sets
---@return (table<string, integer>|false)[]
function LoadoutSetService.decode(raw)
    local ok, data = pcall(json.decode, raw or '')
    data = ok and type(data) == 'table' and data or {}
    local sets = {}
    for slot = 1, Config.LoadoutSets.slots do
        local items = InventoryObject.sanitize(data[slot])
        sets[slot] = next(items) ~= nil and items or false
    end
    return sets
end

---@param slot any
---@return integer|nil
function LoadoutSetService.validSlot(slot)
    slot = math.floor(tonumber(slot) or 0)
    return slot >= 1 and slot <= Config.LoadoutSets.slots and slot or nil
end

---Enregistre le sac tel qu'il est, sans l'argent.
---@param source integer
---@param slot any
---@return { ok: boolean, message?: string }
function LoadoutSetService.save(source, slot)
    local player = InventoryService.getActivePlayer(source)
    slot = LoadoutSetService.validSlot(slot)
    if not player or not slot then return { ok = false } end

    local items = {}
    for name, count in pairs(player.inventory.bag) do
        if not Items.isType(name, 'money') then items[name] = count end
    end
    if next(items) == nil then return { ok = false, message = Locale.t('Ton sac est vide : rien à enregistrer.') } end

    player.loadoutSets[slot] = items
    player:sync()
    return { ok = true, message = Locale.t('Set %d enregistré.', slot) }
end

---@param source integer
---@param slot any
---@return { ok: boolean, message?: string }
function LoadoutSetService.clear(source, slot)
    local player = InventoryService.getActivePlayer(source)
    slot = LoadoutSetService.validSlot(slot)
    if not player or not slot then return { ok = false } end

    player.loadoutSets[slot] = false
    player:sync()
    return { ok = true, message = Locale.t('Set %d effacé.', slot) }
end

---Sort des coffres ce qui manque au joueur pour atteindre le set : ce qu'il porte déjà compte,
---y compris dans le conteneur protégé. Le sac plein ou un coffre vide laissent le set incomplet.
---@param source integer
---@param slot any
---@return { ok: boolean, message?: string }
function LoadoutSetService.apply(source, slot)
    local player = InventoryService.getActivePlayer(source)
    slot = LoadoutSetService.validSlot(slot)
    if not player or not slot then return { ok = false } end
    if not InventoryService.isAtBanker(player) then
        return { ok = false, message = Locale.t('%s : %s', Locale.t('Sets d\'équipement'), SafeNpcs.hint('stash')) }
    end

    local set = player.loadoutSets[slot]
    if not set then return { ok = false, message = Locale.t('Ce set est vide.') } end

    local inventory, moved, missing = player.inventory, 0, {}
    for name, wanted in pairs(set) do
        local needed = wanted - inventory:count(name)
        for _, stash in ipairs(inventory:openStashes()) do
            if needed <= 0 then break end
            local count = math.min(needed, inventory:countIn(stash, name), inventory:maxFit('bag', name))
            if count > 0 and inventory:move(stash, 'bag', name, count) then
                moved, needed = moved + count, needed - count
            end
        end
        if needed > 0 then missing[name] = needed end
    end

    if moved > 0 then
        PlayerRepository.save(player)
        player:sync()
    end
    if next(missing) ~= nil then
        return { ok = moved > 0, message = Locale.t('Set incomplet, il manque : %s', Items.describeText(missing)) }
    end
    return { ok = true, message = moved > 0 and Locale.t('Set %d sorti du coffre.', slot) or Locale.t('Tu portes déjà tout ce set.') }
end
