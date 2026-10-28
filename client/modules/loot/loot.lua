---Affichage et ramassage du butin : sacs au sol, ou corps de zombies à fouiller.
---@class ClientLootBag
---@field coords vector3
---@field object integer|nil
---@field netId integer|nil corps qui porte le butin (aucun sac n'est créé)
---@field model integer modèle du sac ou de la caisse
---@field label string|nil texte de l'action
---@field solid boolean objet avec collisions (caisse de largage)
---@field browse boolean s'ouvre comme un inventaire (largage) au lieu d'être ramassé d'un coup

---@class LootModule
local Loot = PVP.define('Loot')
local State = PVP.use('State')
local HelpNotify = PVP.use('HelpNotify')
local Nui = PVP.use('Nui')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')

Loot.STREAM_DISTANCE = 60.0
Loot.DRAW_DISTANCE = 15.0
Loot.CONTROL_PICKUP = 38 -- E

---@type table<integer, ClientLootBag>
Loot.bags = {}
Loot.model = 0
---@type integer|nil butin « browse » ouvert dans l'inventaire
Loot.openId = nil

function Loot.init()
    Loot.model = GetHashKey(Config.LootModel)

    RegisterNetEvent(Events.client.lootAdd, function(id, info)
        Loot.add(id, info)
    end)
    RegisterNetEvent(Events.client.lootRemove, function(id)
        Loot.remove(id)
    end)
    RegisterNetEvent(Events.client.lootSync, function(list)
        Loot.sync(list)
    end)
    RegisterNetEvent(Events.client.lootContents, function(id, items)
        Loot.onContents(id, items)
    end)
    RegisterNUICallback('lootTake', function(data, cb)
        if type(data) ~= 'table' or not Loot.openId then return cb({ ok = false }) end
        cb(Callback.await(Events.callbacks.lootTake, Loot.openId, data.item, data.count, data.to) or { ok = false })
    end)
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
            Loot.clear()
        end
    end)

    CreateThread(Loot.renderLoop)
end

---@param id integer
---@param info { coords: vector3, netId: integer|nil, model: string|nil, label: string|nil }
function Loot.add(id, info)
    Loot.bags[id] = {
        coords = info.coords,
        netId = info.netId,
        model = info.model and GetHashKey(info.model) or Loot.model,
        label = info.label,
        solid = info.solid == true,
        browse = info.browse == true,
    }
end

---@param id integer
function Loot.remove(id)
    local bag = Loot.bags[id]
    if not bag then return end
    Loot.deleteObject(bag)
    Loot.bags[id] = nil
end

---@param list table[] { id, coords, netId, model, label }
function Loot.sync(list)
    Loot.clear()
    for _, entry in ipairs(list) do
        Loot.add(entry.id, entry)
    end
end

---Position du butin : celle du corps s'il est chargé (il a pu glisser depuis sa mort).
---@param bag ClientLootBag
---@return vector3
function Loot.getCoords(bag)
    if bag.netId and NetworkDoesEntityExistWithNetworkId(bag.netId) then
        local entity = NetworkGetEntityFromNetworkId(bag.netId)
        if DoesEntityExist(entity) then return GetEntityCoords(entity) end
    end
    return bag.coords
end

---Butin représenté par cette entité (sac, caisse, ou corps de zombie qui porte le butin).
---@param entity integer
---@return integer|nil id du butin
function Loot.findByEntity(entity)
    for id, bag in pairs(Loot.bags) do
        if bag.object == entity then return id end
        if bag.netId and NetworkDoesEntityExistWithNetworkId(bag.netId)
            and NetworkGetEntityFromNetworkId(bag.netId) == entity then
            return id
        end
    end
    return nil
end

function Loot.clear()
    for _, bag in pairs(Loot.bags) do
        Loot.deleteObject(bag)
    end
    Loot.bags = {}
end

---@param bag ClientLootBag
function Loot.createObject(bag)
    RequestModel(bag.model)
    local timeout = GetGameTimer() + 2000
    while not HasModelLoaded(bag.model) and GetGameTimer() < timeout do Wait(0) end

    bag.object = CreateObject(bag.model, bag.coords.x, bag.coords.y, bag.coords.z, false, false, false)
    PlaceObjectOnGroundProperly(bag.object)
    FreezeEntityPosition(bag.object, true)
    -- Une caisse bloque les joueurs ; un sac se traverse pour ne pas gêner les combats
    SetEntityCollision(bag.object, bag.solid, bag.solid)
    SetModelAsNoLongerNeeded(bag.model)
    -- Le marqueur suit l'objet posé au sol (la hauteur envoyée peut être approximative)
    bag.coords = GetEntityCoords(bag.object)
end

---@param bag ClientLootBag
function Loot.deleteObject(bag)
    if bag.object and DoesEntityExist(bag.object) then
        DeleteObject(bag.object)
    end
    bag.object = nil
end

function Loot.renderLoop()
    while true do
        local needsFrame = false
        local pos = GetEntityCoords(PlayerPedId())

        for id, bag in pairs(Loot.bags) do
            if Loot.renderBag(id, bag, pos) then
                needsFrame = true
            end
        end

        Wait(needsFrame and 0 or 500)
    end
end

---@param id integer
---@param bag ClientLootBag
---@param pos vector3 position du joueur
---@return boolean true si le sac doit être dessiné à chaque frame
function Loot.renderBag(id, bag, pos)
    local coords = Loot.getCoords(bag)
    local dist = #(pos - coords)

    -- Le butin n'existe que dans le monde PvP
    if not State.inPvp() or dist >= Loot.STREAM_DISTANCE then
        if bag.object then Loot.deleteObject(bag) end
        return false
    end

    -- Un corps de zombie porte lui-même son butin : pas de sac
    if not bag.netId and not bag.object then Loot.createObject(bag) end
    if dist >= Loot.DRAW_DISTANCE then return false end

    DrawMarker(2, coords.x, coords.y, coords.z + (bag.netId and 0.9 or 0.6), 0, 0, 0, 0, 180.0, 0, 0.25, 0.25, 0.25,
        255, 200, 60, 180, true, true, 2, false, nil, nil, false)

    -- On fouille une caisse depuis son bord : portée un peu plus grande
    local reach = bag.solid and Config.LootPickupDistance + 1.0 or Config.LootPickupDistance
    if dist < reach and State.isAlive() then
        HelpNotify.show(HelpNotify.controlKey(Loot.CONTROL_PICKUP),
            bag.label or (bag.netId and 'Fouiller le corps' or 'Ramasser le butin'))
        if IsControlJustReleased(0, Loot.CONTROL_PICKUP) then
            Loot.interact(id)
        end
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Fouille : ramassage direct, ou inventaire pour les butins « browse » (largages)
-- ---------------------------------------------------------------------------

---@param id integer
function Loot.interact(id)
    local bag = Loot.bags[id]
    if not bag then return end
    if not bag.browse then return TriggerServerEvent(Events.server.lootPickup, id) end
    CreateThread(function()
        Loot.openContainer(id)
    end)
end

---Ouvre l'inventaire avec le contenu du butin à droite.
---@param id integer
function Loot.openContainer(id)
    local result = Callback.await(Events.callbacks.lootOpen, id)
    if not result or not result.ok then
        return Nui.notify(result and result.message or 'Butin indisponible.', 'error')
    end
    Loot.openId = id
    Nui.send('lootContainer', { open = true, id = id, label = result.label, items = result.items })
    Nui.setMenu(true, 'inventory')
end

---Contenu mis à jour par le serveur (quelqu'un a pris un objet), false : butin vidé ou disparu.
---@param id integer
---@param items table|false
function Loot.onContents(id, items)
    if id ~= Loot.openId then return end
    if not items then
        Loot.closeContainer()
        return Nui.notify('Le butin est vide.', 'info')
    end
    Nui.send('lootContainer', { open = true, id = id, items = items })
end

---Appelé à la fermeture du menu.
function Loot.closeContainer()
    if not Loot.openId then return end
    TriggerServerEvent(Events.server.lootClose, Loot.openId)
    Loot.openId = nil
    Nui.send('lootContainer', { open = false })
end
