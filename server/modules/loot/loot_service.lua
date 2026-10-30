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
---@field solid boolean|nil objet avec collisions (caisse), sinon on le traverse (sac)
---@field browse boolean|nil s'ouvre comme un inventaire : on prend les objets un par un (largage, butin d'un joueur)
---@field title string|nil nom affiché dans l'inventaire (browse)
---@field lootedBy table<integer, boolean> joueurs ayant déjà pris quelque chose (contrats)
---@field bucket integer bucket de routage où il est tombé (monde PvP ou monde zombies) : seuls ses joueurs le voient

---@class LootDropOptions
---@field netId integer|nil
---@field model string|nil
---@field label string|nil
---@field lifetime integer|nil secondes (défaut : Config.LootLifetime)
---@field kind string|nil
---@field solid boolean|nil
---@field browse boolean|nil
---@field title string|nil
---@field bucket integer|nil bucket de routage (défaut 0, le monde PvP)

---@class LootServiceModule
local LootService = PVP.define('LootService')
local PlayerService = PVP.use('PlayerService')
local Items = PVP.use('Items')
local Utils = PVP.use('Utils')
local ContractService = PVP.use('ContractService')
local AntiCheatService = PVP.use('AntiCheatService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

---@type table<integer, LootBag>
LootService.bags = {}
LootService.nextId = 0
---@type table<integer, table<integer, boolean>> joueurs qui ont un butin « browse » ouvert, par butin
LootService.viewers = {}
-- Conteneurs où l'on peut ranger ce qu'on prend dans un butin
LootService.TAKE_CONTAINERS = { bag = true, protected = true }

function LootService.init()
    RegisterNetEvent(Events.server.lootPickup, function(id)
        if AntiCheatService.allow(source, 'loot') then LootService.pickup(source, id) end
    end)

    -- Butins « browse » (largages) : ouverts comme un inventaire, objets pris un par un
    Callback.register(Events.callbacks.lootOpen, LootService.open)
    Callback.register(Events.callbacks.lootTake, LootService.take)
    RegisterNetEvent(Events.server.lootClose, function(id)
        LootService.closeFor(source, id)
    end)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        for id in pairs(LootService.viewers) do LootService.closeFor(playerSource, id) end
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
        -- Chance en %, décimales permises (0,5 % = une fois sur 200)
        if math.random() * 100 < drop.chance then
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
        solid = options.solid == true,
        browse = options.browse == true,
        title = options.title,
        lootedBy = {},
        bucket = options.bucket or 0,
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
    -- Ceux qui l'avaient ouvert voient l'inventaire du butin se fermer
    for source in pairs(LootService.viewers[id] or {}) do
        TriggerClientEvent(Events.client.lootContents, source, id, false)
    end
    LootService.viewers[id] = nil

    -- Corps fouillé ou expiré : il disparaît avec son butin
    local entity = LootService.getEntity(bag)
    if entity then DeleteEntity(entity) end
end

---Ce que les clients reçoivent d'un butin (pas son contenu).
---@param bag LootBag
---@return table
function LootService.describe(bag)
    return {
        coords = bag.coords, netId = bag.netId, model = bag.model, label = bag.label, solid = bag.solid, browse = bag.browse,
        bucket = bag.bucket,
    }
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

---À portée et dans le même monde (bucket) que le butin.
---@param player PvpPlayer
---@param bag LootBag
---@return boolean
function LootService.canReach(player, bag)
    return GetPlayerRoutingBucket(player.source) == bag.bucket and LootService.isInReach(player:getCoords(), LootService.getCoords(bag))
end

---Ramasse ce qui rentre dans le sac du joueur ; le reste reste au sol.
---@param source integer
---@param id integer
function LootService.pickup(source, id)
    local player = PlayerService.get(source)
    local bag = LootService.bags[id]
    if not player or player.dead or not bag then return end
    if not LootService.canReach(player, bag) then return end

    local taken = {}
    for name, count in pairs(bag.items) do
        local added = player:giveItem(name, count)
        if added > 0 then taken[name] = added end
        bag.items[name] = count > added and count - added or nil
    end

    if next(taken) == nil then
        return player:notify(Locale.t('Ton sac est plein.'), 'error')
    end
    LootService.trackLooting(player, bag)

    if next(bag.items) == nil then
        LootService.remove(id)
        player:notify(Locale.t('Butin : %s', Items.describeText(taken)), 'success')
    else
        local message = bag.netId and Locale.t('Butin : %s (sac plein, il reste des objets sur le corps)', Items.describeText(taken))
            or Locale.t('Butin : %s (sac plein, il reste des objets au sol)', Items.describeText(taken))
        player:notify(message, 'info')
    end
    player:sync()
end

-- ---------------------------------------------------------------------------
-- Butins « browse » (largages, butins de joueurs) : inventaire ouvert, objets pris un par un
-- ---------------------------------------------------------------------------

---Ouvre le butin : son contenu s'affiche à droite de l'inventaire du joueur.
---@param source integer
---@param id any
---@return table { ok, message?, id?, label?, items? }
function LootService.open(source, id)
    id = tonumber(id)
    local player = PlayerService.get(source)
    local bag = id and LootService.bags[id]
    if not player or player.dead or not bag or not bag.browse then
        return { ok = false, message = Locale.t('Ce butin n\'existe plus.') }
    end
    if not LootService.canReach(player, bag) then
        return { ok = false, message = Locale.t('Approche-toi pour fouiller.') }
    end

    LootService.viewers[id] = LootService.viewers[id] or {}
    LootService.viewers[id][source] = true
    return { ok = true, id = id, label = bag.title or Locale.t('Butin'), items = bag.items }
end

---Prend `count` objets du butin et les range dans le sac ou le conteneur protégé (selon la place).
---@param source integer
---@param id any
---@param name any
---@param count any
---@param to any 'bag' | 'protected'
---@return table { ok, message? }
function LootService.take(source, id, name, count, to)
    id, count = tonumber(id), math.floor(tonumber(count) or 0)
    local player = PlayerService.get(source)
    local bag = id and LootService.bags[id]
    if not player or player.dead or not bag or not bag.browse then
        return { ok = false, message = Locale.t('Ce butin n\'existe plus.') }
    end
    if not LootService.TAKE_CONTAINERS[to] or type(name) ~= 'string' or count <= 0 then return { ok = false } end
    if not LootService.canReach(player, bag) then
        return { ok = false, message = Locale.t('Tu es trop loin du butin.') }
    end
    local available = bag.items[name]
    if not available then return { ok = false, message = Locale.t('Quelqu\'un l\'a déjà pris.') } end

    local added = player:giveItem(name, math.min(count, available), to)
    if added <= 0 then
        return { ok = false, message = Locale.t('Pas assez de place : %s', Locale.t(Config.Containers[to].label)) }
    end
    bag.items[name] = available > added and available - added or nil
    LootService.trackLooting(player, bag)
    player:sync()

    if next(bag.items) == nil then
        LootService.remove(id)
    else
        LootService.pushContents(id)
    end
    return { ok = true }
end

---Envoie le contenu à jour à tous ceux qui ont ce butin ouvert.
---@param id integer
function LootService.pushContents(id)
    local bag = LootService.bags[id]
    if not bag then return end
    for source in pairs(LootService.viewers[id] or {}) do
        TriggerClientEvent(Events.client.lootContents, source, id, bag.items)
    end
end

---@param source integer
---@param id any
function LootService.closeFor(source, id)
    local viewers = LootService.viewers[tonumber(id)]
    if viewers then viewers[source] = nil end
end
