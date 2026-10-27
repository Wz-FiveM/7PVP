---Actions d'inventaire demandées par le client : utiliser, déplacer, jeter, raccourcis.
---@class InventoryServiceModule
local InventoryService = PVP.define('InventoryService')
local PlayerService = PVP.use('PlayerService')
local LootService = PVP.use('LootService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Events = PVP.use('Events')

function InventoryService.init()
    Callback.register(Events.callbacks.useItem, InventoryService.use)
    Callback.register(Events.callbacks.moveItem, InventoryService.move)
    Callback.register(Events.callbacks.dropItem, InventoryService.drop)
    Callback.register(Events.callbacks.setShortcut, InventoryService.setShortcut)
end

---@param source integer
---@return PvpPlayer|nil
function InventoryService.getActivePlayer(source)
    local player = PlayerService.get(source)
    if not player or player.dead then return nil end
    return player
end

---@param source integer
---@param name string
---@return { ok: boolean, message?: string }
function InventoryService.use(source, name)
    local player = InventoryService.getActivePlayer(source)
    if not player or not Items.isType(name, 'consumable') then
        return { ok = false, message = 'Cet objet ne s\'utilise pas.' }
    end
    if not player:removeItem(name, 1) then
        return { ok = false, message = 'Tu n\'as plus cet objet.' }
    end

    -- La vie et l'armure du ped sont gérées par le client
    TriggerClientEvent(Events.client.applyItem, source, name)
    player:sync()
    return { ok = true, message = ('%s utilisé'):format(Items.label(name)) }
end

---@param source integer
---@param data { item: string, from: string, to: string, count: integer }
---@return { ok: boolean, message?: string }
function InventoryService.move(source, data)
    local player = InventoryService.getActivePlayer(source)
    if not player or type(data) ~= 'table' then return { ok = false } end

    local ok, message = player.inventory:move(data.from, data.to, data.item, data.count)
    if ok then player:sync() end
    return { ok = ok, message = message }
end

---Jette des objets au sol, dans un sac de butin.
---@param source integer
---@param data { item: string, container: string, count: integer }
---@return { ok: boolean, message?: string }
function InventoryService.drop(source, data)
    local player = InventoryService.getActivePlayer(source)
    if not player or type(data) ~= 'table' then return { ok = false } end

    local removed = player.inventory:removeFrom(data.container, data.item, data.count)
    if removed <= 0 then
        return { ok = false, message = 'Quantité invalide.' }
    end

    LootService.drop(player:getCoords(), { [data.item] = removed })
    player:sync()
    return { ok = true, message = ('Jeté : %s'):format(Items.describe({ [data.item] = removed })) }
end

---@param source integer
---@param slot integer
---@param name string|nil nil pour vider l'emplacement
---@return { ok: boolean }
function InventoryService.setShortcut(source, slot, name)
    local player = PlayerService.get(source)
    if not player or not player.inventory:setShortcut(slot, name) then return { ok = false } end
    player:sync()
    return { ok = true }
end
