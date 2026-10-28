---Véhicules en objets (config/vehicles.lua) : utiliser l'objet fait apparaître le véhicule,
---le ranger (assis dedans, K) rend l'objet à celui qui range. Un seul véhicule sorti par joueur.
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

---@type table<integer, { item: string, netId: integer|nil, checking: boolean|nil }> véhicule sorti (ou en cours de création) par joueur
VehicleService.active = {}
---@type table<integer, integer> véhicule sorti d'un menu (Freeroam, admin) par joueur : net id
VehicleService.menu = {}
-- State bag (non répliqué) posé sur ces véhicules : source du joueur qui l'a sorti
VehicleService.MENU_STATE = '7pvp:menuVehicle'
-- ms laissées au serveur pour connaître le véhicule créé par le client (l'événement arrive souvent avant)
VehicleService.SPAWN_TIMEOUT = 3000
-- State bag posé sur les véhicules sortis d'un objet (nom de l'objet) : le client affiche l'aide K
VehicleService.ITEM_STATE = '7pvp:vehicleItem'

function VehicleService.init()
    Callback.register(Events.callbacks.vehicleStore, VehicleService.storeCallback)

    RegisterNetEvent(Events.server.vehicleSpawned, function(name, netId)
        VehicleService.onSpawned(source, name, netId)
    end)
    RegisterNetEvent(Events.server.menuVehicle, function(netId)
        VehicleService.onMenuVehicle(source, netId)
    end)

    -- Déconnexion (avant la sauvegarde) : le véhicule rentre dans l'inventaire
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        local player = PlayerService.get(playerSource)
        if player then VehicleService.release(player) end
        VehicleService.deleteMenuVehicle(playerSource)
    end)
end

---Véhicule sorti d'un menu (Freeroam, admin) : un seul par joueur, le précédent est supprimé.
---Supprimé par le serveur : le client ne peut plus le faire une fois le véhicule loin de lui
---(hors de portée après une téléportation) ou passé à un autre joueur.
---@param source integer
---@param netId any net id du nouveau véhicule, nil pour seulement supprimer le précédent
function VehicleService.onMenuVehicle(source, netId)
    if not PlayerService.get(source) then return end
    if netId == nil then return VehicleService.deleteMenuVehicle(source) end

    local entity = VehicleService.waitEntity(netId)
    -- Seulement un véhicule créé par ce joueur : on ne lui laisse pas supprimer celui d'un autre
    if not entity or GetEntityType(entity) ~= 2 or NetworkGetEntityOwner(entity) ~= source then return end
    VehicleService.deleteMenuVehicle(source)
    VehicleService.menu[source] = tonumber(netId)
    Entity(entity).state:set(VehicleService.MENU_STATE, source, false)
end

---@param source integer
function VehicleService.deleteMenuVehicle(source)
    local netId = VehicleService.menu[source]
    VehicleService.menu[source] = nil
    if not netId then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    -- Le net id a pu resservir à une autre entité si le véhicule a disparu entre-temps
    if entity ~= 0 and DoesEntityExist(entity) and Entity(entity).state[VehicleService.MENU_STATE] == source then
        DeleteEntity(entity)
    end
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
    if player:isInSafeZone() then
        return { ok = false, message = 'Impossible de sortir un véhicule en zone safe : sors de la zone.' }
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
    if not player or not pending or pending.netId or pending.checking or pending.item ~= name then return end

    pending.checking = true
    local entity = VehicleService.waitEntity(netId)
    pending.checking = nil
    -- Joueur parti ou véhicule déjà rangé pendant l'attente (l'objet a été rendu par release)
    if VehicleService.active[source] ~= pending or not PlayerService.get(source) then
        if entity then DeleteEntity(entity) end
        return
    end

    local item = Items.get(name)
    if not entity or GetEntityModel(entity) ~= GetHashKey(item.model) then
        if entity then DeleteEntity(entity) end
        VehicleService.active[source] = nil
        player.inventory:unreserve(name)
        VehicleService.refund(player, name)
        TriggerClientEvent(Events.client.vehicleReleased, source)
        player:notify('Le véhicule n\'a pas pu apparaître : objet rendu.', 'error')
        return player:sync()
    end
    pending.netId = tonumber(netId)
    Entity(entity).state:set(VehicleService.ITEM_STATE, name, true)
end

---Attend que le serveur connaisse l'entité créée par le client.
---@param netId any
---@return integer|nil entité, nil si elle n'est pas apparue à temps
function VehicleService.waitEntity(netId)
    netId = tonumber(netId)
    if not netId or netId == 0 then return nil end
    local timeout = GetGameTimer() + VehicleService.SPAWN_TIMEOUT
    while true do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity ~= 0 and DoesEntityExist(entity) then return entity end
        if GetGameTimer() > timeout then return nil end
        Wait(100)
    end
end

---Range le véhicule dans lequel le joueur est assis (touche K). N'importe quel véhicule sorti
---d'un objet, le sien ou celui d'un autre : l'objet va à celui qui range, le propriétaire est prévenu.
---@param source integer
function VehicleService.storeCallback(source)
    local player = PlayerService.get(source)
    if not player or player.dead then return { ok = false } end
    if player.mode ~= 'pvp' then
        return { ok = false, message = 'Véhicules disponibles en mode PvP.' }
    end
    local ped = player:getPed()
    local entity = GetVehiclePedIsIn(ped, false)
    if entity == 0 then
        return { ok = false, message = 'Monte dans le véhicule pour le ranger.' }
    end
    local ownerSource = VehicleService.ownerOf(entity)
    local owner = ownerSource and PlayerService.get(ownerSource)
    if not owner then
        -- Marque restée sur un véhicule que le serveur ne suit plus : l'aide K disparaît
        Entity(entity).state:set(VehicleService.ITEM_STATE, nil, true)
        return { ok = false, message = 'Ce véhicule ne vient pas d\'un objet : il ne se range pas.' }
    end
    if VehicleService.isDestroyed(entity) then
        return { ok = false, message = 'Ce véhicule est détruit.' }
    end
    if #GetEntityVelocity(entity) * 3.6 >= Config.VehicleOptions.storeMaxSpeed then
        return { ok = false, message = ('Arrête le véhicule pour le ranger (moins de %d km/h).'):format(Config.VehicleOptions.storeMaxSpeed) }
    end
    if VehicleService.hasOtherOccupant(entity, ped) then
        return { ok = false, message = 'Quelqu\'un est encore à bord.' }
    end

    local label = Items.label(VehicleService.active[ownerSource].item)
    VehicleService.release(owner, player)
    player:sync()
    if ownerSource == source then
        return { ok = true, message = ('%s rangé'):format(label) }
    end
    owner:sync()
    owner:notify(('%s a rangé ton véhicule (%s) : il l\'a récupéré.'):format(player.name, label), 'error')
    TriggerClientEvent(Events.client.vehicleReleased, ownerSource)
    return { ok = true, message = ('%s récupéré'):format(label) }
end

---Range le véhicule sorti du joueur : supprimé du monde, objet rendu s'il est intact.
---@param player PvpPlayer propriétaire du véhicule
---@param recipient PvpPlayer|nil qui reçoit l'objet (le propriétaire par défaut)
function VehicleService.release(player, recipient)
    local current = VehicleService.active[player.source]
    if not current then return end
    VehicleService.active[player.source] = nil
    player.inventory:unreserve(current.item)
    recipient = recipient or player
    -- Pas encore apparu : l'objet est rendu (onSpawned supprimera le véhicule s'il arrive ensuite)
    if not current.netId then return VehicleService.refund(recipient, current.item) end

    local entity = NetworkGetEntityFromNetworkId(current.netId)
    if entity == 0 or not DoesEntityExist(entity) then return end
    if not VehicleService.isDestroyed(entity) then
        VehicleService.refund(recipient, current.item)
    end
    DeleteEntity(entity)
end

---@param entity integer
---@return integer|nil source du joueur qui a sorti ce véhicule
function VehicleService.ownerOf(entity)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    for source, current in pairs(VehicleService.active) do
        if current.netId == netId then return source end
    end
    return nil
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
