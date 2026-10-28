---Actions d'inventaire demandées par le client : utiliser, déplacer, jeter, raccourcis.
---@class InventoryServiceModule
local InventoryService = PVP.define('InventoryService')
local PlayerService = PVP.use('PlayerService')
local LootService = PVP.use('LootService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local SafeNpcs = PVP.use('SafeNpcs')
local VehicleService = PVP.use('VehicleService')
local Events = PVP.use('Events')

function InventoryService.init()
    Callback.register(Events.callbacks.useItem, InventoryService.use)
    Callback.register(Events.callbacks.moveItem, InventoryService.move)
    Callback.register(Events.callbacks.dropItem, InventoryService.drop)
    Callback.register(Events.callbacks.setShortcut, InventoryService.setShortcut)
    Callback.register(Events.callbacks.attachment, InventoryService.attachment)
end

---@param source integer
---@return PvpPlayer|nil
function InventoryService.getActivePlayer(source)
    local player = PlayerService.get(source)
    if not player or player.dead then return nil end
    return player
end

---Le coffre (conteneur `safeOnly`) ne s'ouvre qu'à côté du banquier de la zone safe.
---@param player PvpPlayer
---@param ... string conteneurs touchés par l'action
---@return boolean ok, string|nil message
function InventoryService.canAccess(player, ...)
    for _, id in ipairs({ ... }) do
        local container = Config.Containers[id]
        if container and container.safeOnly and not SafeNpcs.isNear(player:getCoords(), 'stash', Config.SafeNpcs.useDistance + 2.0) then
            return false, ('%s : %s'):format(container.label, SafeNpcs.hint('stash'))
        end
    end
    return true
end

---@param source integer
---@param name string
---@return { ok: boolean, message?: string }
function InventoryService.use(source, name)
    local player = InventoryService.getActivePlayer(source)
    if player and Items.isType(name, 'vehicle') then
        return VehicleService.deploy(player, name)
    end
    if not player or not Items.isType(name, 'consumable') then
        return { ok = false, message = 'Cet objet ne s\'utilise pas.' }
    end
    if Items.get(name).repair and not InventoryService.vehicleToRepair(source) then
        return { ok = false, message = 'Monte dans un véhicule ou reste à côté pour le réparer.' }
    end
    if not player:removeItem(name, 1) then
        return { ok = false, message = 'Tu n\'as plus cet objet.' }
    end

    -- La vie et l'armure du ped sont gérées par le client
    TriggerClientEvent(Events.client.applyItem, source, name)
    player:sync()
    return { ok = true, message = ('%s utilisé'):format(Items.label(name)) }
end

InventoryService.REPAIR_DISTANCE = 5.0

---Véhicule que le kit de réparation peut réparer : celui où est le joueur, sinon son dernier
---véhicule s'il est juste à côté.
---@param source integer
---@return integer|nil
function InventoryService.vehicleToRepair(source)
    local ped = GetPlayerPed(source)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then return vehicle end
    vehicle = GetVehiclePedIsIn(ped, true)
    if vehicle ~= 0 and #(GetEntityCoords(vehicle) - GetEntityCoords(ped)) <= InventoryService.REPAIR_DISTANCE then
        return vehicle
    end
    return nil
end

---@param source integer
---@param data { item: string, from: string, to: string, count: integer }
---@return { ok: boolean, message?: string }
function InventoryService.move(source, data)
    local player = InventoryService.getActivePlayer(source)
    if not player or type(data) ~= 'table' then return { ok = false } end

    local allowed, denied = InventoryService.canAccess(player, data.from, data.to)
    if not allowed then return { ok = false, message = denied } end

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

    local allowed, denied = InventoryService.canAccess(player, data.container)
    if not allowed then return { ok = false, message = denied } end

    local removed = player.inventory:removeFrom(data.container, data.item, data.count)
    if removed <= 0 then
        return { ok = false, message = 'Quantité invalide.' }
    end

    local dropped = { [data.item] = removed }
    for attachment, count in pairs(player.inventory:releaseAttachments(data.item)) do
        dropped[attachment] = (dropped[attachment] or 0) + count
    end
    LootService.drop(player:getCoords(), dropped)
    player:sync()
    return { ok = true, message = ('Jeté : %s'):format(Items.describe({ [data.item] = removed })) }
end

---Fixe ou retire un accessoire sur une arme.
---@param source integer
---@param data { weapon: string, attachment: string, attach: boolean }
---@return { ok: boolean, message?: string }
function InventoryService.attachment(source, data)
    local player = InventoryService.getActivePlayer(source)
    if not player or type(data) ~= 'table' then return { ok = false } end

    local inventory = player.inventory
    local ok, message
    if data.attach == true then
        ok, message = inventory:attach(data.weapon, data.attachment)
    else
        ok, message = inventory:detach(data.weapon, data.attachment)
    end
    if not ok then return { ok = false, message = message } end

    player:sync()
    local verb = data.attach == true and 'fixé sur' or 'retiré de'
    return { ok = true, message = ('%s %s : %s'):format(Items.label(data.attachment), verb, Items.label(data.weapon)) }
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
