---Affichage et ramassage du butin : sacs au sol, ou corps de zombies à fouiller.
---@class ClientLootBag
---@field coords vector3
---@field object integer|nil
---@field netId integer|nil corps qui porte le butin (aucun sac n'est créé)
---@field model integer modèle du sac ou de la caisse
---@field label string|nil texte de l'action

---@class LootModule
local Loot = PVP.define('Loot')
local State = PVP.use('State')
local Events = PVP.use('Events')

Loot.STREAM_DISTANCE = 60.0
Loot.DRAW_DISTANCE = 15.0
Loot.CONTROL_PICKUP = 38 -- E

---@type table<integer, ClientLootBag>
Loot.bags = {}
Loot.model = 0

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
    SetEntityCollision(bag.object, false, false)
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

---@param text string
function Loot.showHelp(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
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

    if dist < Config.LootPickupDistance and State.isAlive() then
        Loot.showHelp('~INPUT_CONTEXT~ ' .. (bag.label or (bag.netId and 'Fouiller le corps' or 'Ramasser le butin')))
        if IsControlJustReleased(0, Loot.CONTROL_PICKUP) then
            TriggerServerEvent(Events.server.lootPickup, id)
        end
    end
    return true
end
