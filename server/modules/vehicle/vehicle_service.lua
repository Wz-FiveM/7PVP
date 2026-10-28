---Véhicules en objets (config/vehicles.lua) : utiliser l'objet fait apparaître le véhicule,
---le ranger rend l'objet. Un seul véhicule sorti par joueur.
---
---Le véhicule est créé par le client du joueur (tous les types de véhicules, place du conducteur),
---avec une autorisation ponctuelle de l'anti-cheat ; le client renvoie ensuite son net id.
---@class VehicleServiceModule
local VehicleService = PVP.define('VehicleService')
local PlayerService = PVP.use('PlayerService')
local CombatTagService = PVP.use('CombatTagService')
local AntiCheatService = PVP.use('AntiCheatService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Events = PVP.use('Events')

---@type table<integer, { item: string, netId: integer|nil }> véhicule sorti (ou en cours de création) par joueur
VehicleService.active = {}

function VehicleService.init()
    Callback.register(Events.callbacks.vehicleStore, VehicleService.storeCallback)

    RegisterNetEvent(Events.server.vehicleSpawned, function(name, netId)
        VehicleService.onSpawned(source, name, netId)
    end)

    -- Déconnexion (avant la sauvegarde) : le véhicule rentre dans l'inventaire
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        local player = PlayerService.get(playerSource)
        if player then VehicleService.release(player) end
    end)
end

---Utilisation d'un objet véhicule (appelé par InventoryService.use).
---@param player PvpPlayer
---@param name string
---@return { ok: boolean, message?: string }
function VehicleService.deploy(player, name)
    local item = Items.get(name)
    local ped = player:getPed()
    if player.mode ~= 'pvp' then
        return { ok = false, message = 'Véhicules disponibles en mode PvP.' }
    end
    if GetVehiclePedIsIn(ped, false) ~= 0 then
        return { ok = false, message = 'Descends d\'abord du véhicule.' }
    end
    if CombatTagService.isTagged(player) then
        return { ok = false, message = ('Tu es en combat : attends %d s.'):format(CombatTagService.remaining(player)) }
    end
    local current = VehicleService.active[player.source]
    if current and not current.netId then
        return { ok = false, message = 'Un véhicule est déjà en train d\'apparaître.' }
    end
    if not player:removeItem(name, 1) then
        return { ok = false, message = 'Tu n\'as plus cet objet.' }
    end

    -- Un seul véhicule sorti : le précédent est rangé s'il est intact
    VehicleService.release(player)

    VehicleService.active[player.source] = { item = name }
    -- Le véhicule est dehors, pas perdu : son raccourci reste en place
    player.inventory:reserve(name)
    AntiCheatService.allowVehicle(player.source, item.model)
    TriggerClientEvent(Events.client.vehicleSpawn, player.source, name, item.model)
    player:sync()
    return { ok = true, message = ('%s sorti'):format(item.label) }
end

---Le client a créé le véhicule (net id), ou n'a pas pu (false) : l'objet est alors rendu.
---@param source integer
---@param name any
---@param netId any
function VehicleService.onSpawned(source, name, netId)
    local player = PlayerService.get(source)
    local pending = VehicleService.active[source]
    if not player or not pending or pending.netId or pending.item ~= name then return end

    local entity = tonumber(netId) and NetworkGetEntityFromNetworkId(netId) or 0
    local item = Items.get(name)
    if entity == 0 or not DoesEntityExist(entity) or GetEntityModel(entity) ~= GetHashKey(item.model) then
        VehicleService.active[source] = nil
        player.inventory:unreserve(name)
        VehicleService.refund(player, name)
        player:notify('Le véhicule n\'a pas pu apparaître : objet rendu.', 'error')
        return player:sync()
    end
    pending.netId = netId
end

---@param source integer
function VehicleService.storeCallback(source)
    local player = PlayerService.get(source)
    if not player or player.dead then return { ok = false } end
    local entity = VehicleService.entityOf(source)
    if not entity then
        return { ok = false, message = 'Tu n\'as pas de véhicule sorti.' }
    end
    if #(GetEntityCoords(entity) - player:getCoords()) > Config.VehicleOptions.storeDistance then
        return { ok = false, message = 'Approche-toi de ton véhicule.' }
    end
    if VehicleService.isDestroyed(entity) then
        return { ok = false, message = 'Ton véhicule est détruit.' }
    end
    if #GetEntityVelocity(entity) * 3.6 >= Config.VehicleOptions.storeMaxSpeed then
        return { ok = false, message = ('Arrête le véhicule pour le ranger (moins de %d km/h).'):format(Config.VehicleOptions.storeMaxSpeed) }
    end
    if VehicleService.hasOtherOccupant(entity, player:getPed()) then
        return { ok = false, message = 'Quelqu\'un est encore à bord.' }
    end

    local name = VehicleService.active[source].item
    VehicleService.release(player)
    player:sync()
    return { ok = true, message = ('%s rangé'):format(Items.label(name)) }
end

---Range le véhicule sorti du joueur : supprimé du monde, objet rendu s'il est intact.
---@param player PvpPlayer
function VehicleService.release(player)
    local current = VehicleService.active[player.source]
    if not current then return end
    VehicleService.active[player.source] = nil
    player.inventory:unreserve(current.item)

    local entity = current.netId and NetworkGetEntityFromNetworkId(current.netId) or 0
    if entity == 0 or not DoesEntityExist(entity) then return end
    if not VehicleService.isDestroyed(entity) then
        VehicleService.refund(player, current.item)
    end
    DeleteEntity(entity)
end

---@param source integer
---@return integer|nil entité du véhicule sorti
function VehicleService.entityOf(source)
    local current = VehicleService.active[source]
    if not current or not current.netId then return nil end
    local entity = NetworkGetEntityFromNetworkId(current.netId)
    if entity == 0 or not DoesEntityExist(entity) then
        VehicleService.active[source] = nil
        local player = PlayerService.get(source)
        if player then player.inventory:unreserve(current.item) end
        return nil
    end
    return entity
end

---@param source integer
---@return integer|nil net id du véhicule sorti (pour le menu ALT)
function VehicleService.netIdOf(source)
    local current = VehicleService.active[source]
    return current and current.netId or nil
end

---@param entity integer
---@return boolean
function VehicleService.isDestroyed(entity)
    return GetEntityHealth(entity) <= 0 or GetVehicleEngineHealth(entity) <= -3999.0
end

---@param entity integer
---@param ped integer
---@return boolean
function VehicleService.hasOtherOccupant(entity, ped)
    for seat = -1, 6 do
        local occupant = GetPedInVehicleSeat(entity, seat)
        if occupant ~= 0 and occupant ~= ped then return true end
    end
    return false
end

---Rend l'objet : dans le sac, sinon le conteneur protégé, sinon le coffre.
---@param player PvpPlayer
---@param name string
function VehicleService.refund(player, name)
    for _, container in ipairs({ 'bag', 'protected', 'stash' }) do
        if player:giveItem(name, 1, container) > 0 then return end
    end
end
