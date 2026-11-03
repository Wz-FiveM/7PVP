---Coffre de crew : un conteneur commun aux membres, chez le banquier (Config.Crews.stash).
---Son contenu part aux membres avec le crew (CrewService.serialize). Chaque opération est écrite
---tout de suite en base, avec l'inventaire du joueur : un arrêt du serveur ne peut ni perdre ni doubler un objet.
---@class CrewStashEntry
---@field name string joueur
---@field item string
---@field count integer
---@field taken boolean retrait (sinon dépôt)
---@field at integer os.time()

---@class CrewStash
---@field items table<string, integer>
---@field log CrewStashEntry[] du plus récent au plus ancien

---@class CrewStashServiceModule
local CrewStashService = PVP.define('CrewStashService')
local CrewService = PVP.use('CrewService')
local CrewRepository = PVP.use('CrewRepository')
local CrewBonusService = PVP.use('CrewBonusService')
local InventoryObject = PVP.use('InventoryObject')
local InventoryService = PVP.use('InventoryService')
local PlayerRepository = PVP.use('PlayerRepository')
local SafeNpcs = PVP.use('SafeNpcs')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Utils = PVP.use('Utils')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')
local Logger = PVP.use('Logger')

-- Ce que le joueur porte : seuls conteneurs d'où l'on dépose et où l'on retire
CrewStashService.CARRIED = { bag = true, protected = true }

---@type table<string, CrewStash> label -> coffre
CrewStashService.stashes = {}

function CrewStashService.init()
    Callback.register(Events.callbacks.crewStashPut, CrewStashService.put)
    Callback.register(Events.callbacks.crewStashTake, CrewStashService.take)
end

---Coffres gardés en base : appelé par CrewService au chargement des crews.
---@param rows { crew_tag: string, items: string, log: string }[]
function CrewStashService.restore(rows)
    for _, row in ipairs(rows) do
        local okItems, items = pcall(json.decode, row.items)
        local okLog, log = pcall(json.decode, row.log)
        CrewStashService.stashes[row.crew_tag] = {
            items = InventoryObject.sanitize(okItems and items or nil),
            log = okLog and type(log) == 'table' and log or {},
        }
    end
end

---@param tag string
---@return CrewStash
function CrewStashService.get(tag)
    local stash = CrewStashService.stashes[tag]
    if not stash then
        stash = { items = {}, log = {} }
        CrewStashService.stashes[tag] = stash
    end
    return stash
end

---@param tag string
---@return boolean
function CrewStashService.isEmpty(tag)
    return next(CrewStashService.get(tag).items) == nil
end

---Crew dissous (la base est nettoyée par CrewRepository.delete).
---@param tag string
function CrewStashService.remove(tag)
    if not CrewStashService.isEmpty(tag) then
        Logger.info('[crew] coffre de [%s] perdu : %s', tag, Items.describe(CrewStashService.get(tag).items))
    end
    CrewStashService.stashes[tag] = nil
end

---Ajoute ou retire de l'argent sans joueur (guerre, tournoi). Le montant retiré doit avoir été vérifié.
---@param tag string
---@param amount integer négatif pour un retrait
---@param label string motif affiché dans le journal, traduit par l'interface
function CrewStashService.moveMoney(tag, amount, label)
    local stash = CrewStashService.get(tag)
    local left = math.max(0, (stash.items.money or 0) + amount)
    stash.items.money = left > 0 and left or nil
    CrewStashService.record(tag, stash, label, 'money', math.abs(amount), amount < 0)
    Logger.info('[crew] coffre de [%s] : %+d $', tag, amount)
end

---Dépose des objets sans joueur (armurerie du crew). La place doit avoir été vérifiée (maxFit).
---@param tag string
---@param item string
---@param count integer
---@param label string motif affiché dans le journal, traduit par l'interface
function CrewStashService.addItem(tag, item, count, label)
    local stash = CrewStashService.get(tag)
    stash.items[item] = (stash.items[item] or 0) + count
    CrewStashService.record(tag, stash, label, item, count, false)
    Logger.info('[crew] coffre de [%s] : %s (%s)', tag, Items.describe({ [item] = count }), label)
end

---@param tag string
---@param stash CrewStash
---@param name string joueur ou motif
---@param item string
---@param count integer
---@param taken boolean
function CrewStashService.record(tag, stash, name, item, count, taken)
    table.insert(stash.log, 1, { name = name, item = item, count = count, taken = taken, at = os.time() })
    while #stash.log > Config.Crews.stash.logSize do table.remove(stash.log) end
    CrewRepository.saveStash(tag, json.encode(stash.items), json.encode(stash.log))
end

---@param source integer
---@return PvpPlayer|nil, PvpCrew|nil, table|nil raison du refus (Locale.t)
function CrewStashService.access(source)
    local player = InventoryService.getActivePlayer(source)
    if not player then return nil end
    local crew = CrewService.crewOf(source)
    if not crew then return nil, nil, Locale.t('Tu n\'es dans aucun crew.') end
    if not InventoryService.isAtBanker(player) then
        return nil, nil, Locale.t('%s : %s', Locale.t('Coffre du crew'), SafeNpcs.hint('stash'))
    end
    return player, crew
end

---@param tag string
---@param name string
---@return number unités de cet objet qui tiennent encore dans le coffre (agrandissements compris)
function CrewStashService.maxFit(tag, name)
    local weight = Items.get(name).weight
    if weight <= 0 then return math.huge end
    local free = CrewBonusService.stashCapacity(tag) - Items.weightOf(CrewStashService.get(tag).items)
    return math.max(0, math.floor((free + 1e-6) / weight))
end

---Dépose des objets portés. Les accessoires d'une arme restent à son propriétaire, comme à l'échange.
---@param source integer
---@param data any { item, count, from }
---@return { ok: boolean, message?: string }
function CrewStashService.put(source, data)
    local player, crew, denied = CrewStashService.access(source)
    if not player or type(data) ~= 'table' then return { ok = false, message = denied } end

    local item, count = data.item, Utils.toCount(data.count)
    if not CrewStashService.CARRIED[data.from] or not Items.exists(item) or count <= 0 then return { ok = false } end
    if Config.Crews.stash.blocked[item] then return { ok = false, message = Locale.t('Cet objet ne va pas dans le coffre du crew.') } end
    if player.inventory:countIn(data.from, item) < count then return { ok = false, message = Locale.t('Quantité invalide.') } end

    local stash = CrewStashService.get(crew.tag)
    if CrewStashService.maxFit(crew.tag, item) < count then
        return { ok = false, message = Locale.t('Pas assez de place dans : %s.', Locale.t('Coffre du crew')) }
    end

    player.inventory:removeFrom(data.from, item, count)
    stash.items[item] = (stash.items[item] or 0) + count
    CrewStashService.commit(crew, player, stash, item, count, false)
    return { ok = true }
end

---Retire des objets : autant que le conteneur choisi peut en recevoir.
---@param source integer
---@param data any { item, count, to }
---@return { ok: boolean, message?: string }
function CrewStashService.take(source, data)
    local player, crew, denied = CrewStashService.access(source)
    if not player or type(data) ~= 'table' then return { ok = false, message = denied } end

    local item, count = data.item, Utils.toCount(data.count)
    if not CrewStashService.CARRIED[data.to] or not Items.exists(item) or count <= 0 then return { ok = false } end

    local stash = CrewStashService.get(crew.tag)
    if (stash.items[item] or 0) < count then return { ok = false, message = Locale.t('Quantité invalide.') } end

    local added = player:giveItem(item, count, data.to)
    if added <= 0 then
        return { ok = false, message = Locale.t('Pas assez de place dans : %s.', Locale.t(Config.Containers[data.to].label)) }
    end

    local left = stash.items[item] - added
    stash.items[item] = left > 0 and left or nil
    CrewStashService.commit(crew, player, stash, item, added, true)
    return { ok = true }
end

---@param crew PvpCrew
---@param player PvpPlayer
---@param stash CrewStash
---@param item string
---@param count integer
---@param taken boolean
function CrewStashService.commit(crew, player, stash, item, count, taken)
    CrewStashService.record(crew.tag, stash, player.name, item, count, taken)
    PlayerRepository.save(player)
    player:sync()
    CrewService.sync(crew)
    Logger.info('[crew] %s %s [%s] : %s', player.name, taken and 'retire de' or 'dépose dans', crew.tag, Items.describe({ [item] = count }))
end
