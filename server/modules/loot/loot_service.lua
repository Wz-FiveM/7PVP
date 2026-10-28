---Butin au sol : sacs (morts de joueurs, objets jetés) ou corps de zombies à fouiller.
---Un butin lié à un corps (`netId`) supprime ce corps quand il est vidé ou qu'il expire.
---@class LootBag
---@field coords vector3
---@field items table<string, integer>
---@field expires integer
---@field netId integer|nil corps du zombie qui porte le butin (pas de sac affiché)
---@field model string|nil modèle 3D à la place du sac (ex : caisse de largage)
---@field label string|nil texte de l'action (ex : « Fouiller le largage »)
---@field kind string|nil 'airdrop' pour un largage (contrats)
---@field lootedBy table<integer, boolean> joueurs ayant déjà pris quelque chose (contrats)

---@class LootDropOptions
---@field netId integer|nil
---@field model string|nil
---@field label string|nil
---@field lifetime integer|nil secondes (défaut : Config.LootLifetime)
---@field kind string|nil

---@class LootServiceModule
local LootService = PVP.define('LootService')
local PlayerService = PVP.use('PlayerService')
local Items = PVP.use('Items')
local Utils = PVP.use('Utils')
local ContractService = PVP.use('ContractService')
local Events = PVP.use('Events')

---@type table<integer, LootBag>
LootService.bags = {}
LootService.nextId = 0

function LootService.init()
    RegisterNetEvent(Events.server.lootPickup, function(id)
        LootService.pickup(source, id)
    end)

    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
            LootService.clearAll()
        end
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

---Plusieurs tirages de la même table, additionnés.
---@param tableName string
---@param rolls integer
---@return table<string, integer>
function LootService.rollMany(tableName, rolls)
    local items = {}
    for _ = 1, math.max(1, rolls) do
        for name, count in pairs(LootService.roll(tableName)) do
            items[name] = (items[name] or 0) + count
        end
    end
    return items
end

---@param coords vector3
---@param items table<string, integer>
---@param options? integer|LootDropOptions netId du corps qui porte le butin (zombie), ou options
---@return integer|nil id du butin, nil s'il était vide
function LootService.drop(coords, items, options)
    if type(options) ~= 'table' then options = { netId = options } end
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
        expires = os.time() + (options.lifetime or Config.LootLifetime),
        netId = options.netId,
        model = options.model,
        label = options.label,
        kind = options.kind,
        lootedBy = {},
    }
    TriggerClientEvent(Events.client.lootAdd, -1, id, LootService.describe(LootService.bags[id]))
    return id
end

---@param id integer
function LootService.remove(id)
    local bag = LootService.bags[id]
    if not bag then return end
    LootService.bags[id] = nil
    TriggerClientEvent(Events.client.lootRemove, -1, id)

    -- Corps fouillé ou expiré : il disparaît avec son butin
    local entity = LootService.getEntity(bag)
    if entity then DeleteEntity(entity) end
end

---Ce que les clients reçoivent d'un butin (pas son contenu).
---@param bag LootBag
---@return table
function LootService.describe(bag)
    return { coords = bag.coords, netId = bag.netId, model = bag.model, label = bag.label }
end

---@param bag LootBag
---@return integer|nil entité du corps qui porte le butin, si elle existe encore
function LootService.getEntity(bag)
    if not bag.netId then return nil end
    local entity = NetworkGetEntityFromNetworkId(bag.netId)
    if entity ~= 0 and DoesEntityExist(entity) then return entity end
    return nil
end

---Position actuelle du butin : le corps a pu glisser ou être poussé depuis sa mort.
---@param bag LootBag
---@return vector3
function LootService.getCoords(bag)
    local entity = LootService.getEntity(bag)
    return entity and GetEntityCoords(entity) or bag.coords
end

---Supprime tous les sacs au sol (action admin).
---@return integer nombre de sacs supprimés
function LootService.clearAll()
    local count = 0
    for id in pairs(LootService.bags) do
        LootService.remove(id)
        count = count + 1
    end
    return count
end

---@param source integer
function LootService.syncTo(source)
    local list = {}
    for id, bag in pairs(LootService.bags) do
        local entry = LootService.describe(bag)
        entry.id = id
        list[#list + 1] = entry
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

---Contrats : un corps ou un largage compte une fois par joueur.
---@param player PvpPlayer
---@param bag LootBag
function LootService.trackLooting(player, bag)
    if bag.lootedBy[player.source] then return end
    bag.lootedBy[player.source] = true
    if bag.netId then ContractService.track(player, 'lootCorpse', 1) end
    if bag.kind == 'airdrop' then ContractService.track(player, 'lootAirdrop', 1) end
end

-- Écart de hauteur toléré : la hauteur du sol des points de largage est approximative
LootService.REACH_HEIGHT = 25.0

---@param playerCoords vector3
---@param lootCoords vector3
---@return boolean
function LootService.isInReach(playerCoords, lootCoords)
    local flat = #(playerCoords.xy - lootCoords.xy)
    return flat <= Config.LootPickupDistance + 3.0 and math.abs(playerCoords.z - lootCoords.z) <= LootService.REACH_HEIGHT
end

---Ramasse ce qui rentre dans le sac du joueur ; le reste reste au sol.
---@param source integer
---@param id integer
function LootService.pickup(source, id)
    local player = PlayerService.get(source)
    local bag = LootService.bags[id]
    if not player or player.dead or not bag then return end
    if not LootService.isInReach(player:getCoords(), LootService.getCoords(bag)) then return end

    local taken = {}
    for name, count in pairs(bag.items) do
        local added = player:giveItem(name, count)
        if added > 0 then taken[name] = added end
        bag.items[name] = count > added and count - added or nil
    end

    if next(taken) == nil then
        return player:notify('Ton sac est plein.', 'error')
    end
    LootService.trackLooting(player, bag)

    if next(bag.items) == nil then
        LootService.remove(id)
        player:notify('Butin : ' .. Items.describe(taken), 'success')
    else
        local where = bag.netId and 'sur le corps' or 'au sol'
        player:notify(('Butin : %s (sac plein, il reste des objets %s)'):format(Items.describe(taken), where), 'info')
    end
    player:sync()
end
