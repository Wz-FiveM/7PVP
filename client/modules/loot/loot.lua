---Affichage et ramassage des sacs de butin.
---@class ClientLootBag
---@field coords vector3
---@field object integer|nil

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

    RegisterNetEvent(Events.client.lootAdd, function(id, coords)
        Loot.add(id, coords)
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
---@param coords vector3
function Loot.add(id, coords)
    Loot.bags[id] = { coords = coords }
end

---@param id integer
function Loot.remove(id)
    local bag = Loot.bags[id]
    if not bag then return end
    Loot.deleteObject(bag)
    Loot.bags[id] = nil
end

---@param list { id: integer, coords: vector3 }[]
function Loot.sync(list)
    Loot.clear()
    for _, entry in ipairs(list) do
        Loot.add(entry.id, entry.coords)
    end
end

function Loot.clear()
    for _, bag in pairs(Loot.bags) do
        Loot.deleteObject(bag)
    end
    Loot.bags = {}
end

---@param bag ClientLootBag
function Loot.createObject(bag)
    RequestModel(Loot.model)
    local timeout = GetGameTimer() + 2000
    while not HasModelLoaded(Loot.model) and GetGameTimer() < timeout do Wait(0) end

    bag.object = CreateObject(Loot.model, bag.coords.x, bag.coords.y, bag.coords.z, false, false, false)
    PlaceObjectOnGroundProperly(bag.object)
    FreezeEntityPosition(bag.object, true)
    SetEntityCollision(bag.object, false, false)
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
    local dist = #(pos - bag.coords)

    if dist >= Loot.STREAM_DISTANCE then
        if bag.object then Loot.deleteObject(bag) end
        return false
    end

    if not bag.object then Loot.createObject(bag) end
    if dist >= Loot.DRAW_DISTANCE then return false end

    DrawMarker(2, bag.coords.x, bag.coords.y, bag.coords.z + 0.6, 0, 0, 0, 0, 180.0, 0, 0.25, 0.25, 0.25,
        255, 200, 60, 180, true, true, 2, false, nil, nil, false)

    if dist < Config.LootPickupDistance and State.isAlive() then
        Loot.showHelp('~INPUT_CONTEXT~ Ramasser le butin')
        if IsControlJustReleased(0, Loot.CONTROL_PICKUP) then
            TriggerServerEvent(Events.server.lootPickup, id)
        end
    end
    return true
end
