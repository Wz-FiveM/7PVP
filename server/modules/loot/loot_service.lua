---Sacs de butin posés au sol (morts de joueurs et de PNJ, objets jetés).
---@class LootBag
---@field coords vector3
---@field items table<string, integer>
---@field expires integer

---@class LootServiceModule
local LootService = PVP.define('LootService')
local PlayerService = PVP.use('PlayerService')
local Items = PVP.use('Items')
local Utils = PVP.use('Utils')
local Events = PVP.use('Events')

---@type table<integer, LootBag>
LootService.bags = {}
LootService.nextId = 0

function LootService.init()
    RegisterNetEvent(Events.server.lootPickup, function(id)
        LootService.pickup(source, id)
    end)

    CreateThread(LootService.expireLoop)
end

---Tire au sort le contenu d'une table de Config.LootTables.
---@param tableName string
---@return table<string, integer>
function LootService.roll(tableName)
    local items = {}
    local lootTable = Config.LootTables[tableName]
    if not lootTable then return items end

    for _, drop in ipairs(lootTable.drops) do
        if math.random(100) <= drop.chance then
            items[drop.item] = (items[drop.item] or 0) + Utils.randomRange(drop.count)
        end
    end
    if lootTable.money then
        items.money = Utils.randomRange(lootTable.money)
    end

    return items
end

---@param coords vector3
---@param items table<string, integer>
---@return integer|nil id du sac, nil s'il était vide
function LootService.drop(coords, items)
    local clean = {}
    for name, count in pairs(items) do
        if Items.exists(name) and count > 0 then clean[name] = count end
    end
    if next(clean) == nil then return nil end

    LootService.nextId = LootService.nextId + 1
    local id = LootService.nextId
    LootService.bags[id] = {
        coords = coords,
        items = clean,
        expires = os.time() + Config.LootLifetime,
    }
    TriggerClientEvent(Events.client.lootAdd, -1, id, coords)
    return id
end

---@param id integer
function LootService.remove(id)
    LootService.bags[id] = nil
    TriggerClientEvent(Events.client.lootRemove, -1, id)
end

---@param source integer
function LootService.syncTo(source)
    local list = {}
    for id, bag in pairs(LootService.bags) do
        list[#list + 1] = { id = id, coords = bag.coords }
    end
    TriggerClientEvent(Events.client.lootSync, source, list)
end

function LootService.expireLoop()
    while true do
        Wait(10000)
        local now = os.time()
        for id, bag in pairs(LootService.bags) do
            if bag.expires <= now then
                LootService.remove(id)
            end
        end
    end
end

---Ramasse ce qui rentre dans le sac du joueur ; le reste reste au sol.
---@param source integer
---@param id integer
function LootService.pickup(source, id)
    local player = PlayerService.get(source)
    local bag = LootService.bags[id]
    if not player or player.dead or not bag then return end
    if #(player:getCoords() - bag.coords) > Config.LootPickupDistance + 3.0 then return end

    local taken = {}
    for name, count in pairs(bag.items) do
        local added = player:giveItem(name, count)
        if added > 0 then taken[name] = added end
        bag.items[name] = count > added and count - added or nil
    end

    if next(taken) == nil then
        return player:notify('Ton sac est plein.', 'error')
    end

    if next(bag.items) == nil then
        LootService.remove(id)
        player:notify('Butin : ' .. Items.describe(taken), 'success')
    else
        player:notify(('Butin : %s (sac plein, il reste des objets)'):format(Items.describe(taken)), 'info')
    end
    player:sync()
end
