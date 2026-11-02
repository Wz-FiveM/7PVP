---Marchand noir ambulant (Config.BlackMarket) : un PNJ apparaît hors des zones safe, vend quelques lots
---limités puis repart. Le stock est partagé : le premier arrivé se sert. Le PNJ n'existe que sur les
---clients ; le serveur vérifie la distance à chaque achat.
---@class BlackMarketOffer
---@field item string
---@field count integer contenu d'un lot
---@field price integer prix du lot
---@field left integer lots restants

---@class BlackMarketVisit
---@field id integer
---@field coords vector4
---@field endsAt integer os.time()
---@field stock BlackMarketOffer[]

---@class BlackMarketServiceModule
local BlackMarketService = PVP.define('BlackMarketService')
local PlayerService = PVP.use('PlayerService')
local ModeRegistry = PVP.use('ModeRegistry')
local ChatService = PVP.use('ChatService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Utils = PVP.use('Utils')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

BlackMarketService.MODE = 'pvp'

---@type BlackMarketVisit|nil
BlackMarketService.current = nil
BlackMarketService.nextId = 0

function BlackMarketService.init()
    RegisterNetEvent(Events.server.ready, function()
        if BlackMarketService.current then
            TriggerClientEvent(Events.client.blackMarketState, source, BlackMarketService.describe())
        end
    end)
    Callback.register(Events.callbacks.blackMarketList, BlackMarketService.list)
    Callback.register(Events.callbacks.blackMarketBuy, BlackMarketService.buy)
    if Config.BlackMarket.enabled then CreateThread(BlackMarketService.loop) end
end

function BlackMarketService.loop()
    local settings = Config.BlackMarket
    Wait(settings.firstDelay * 1000)
    while true do
        local waited = 0
        if not BlackMarketService.current and ModeRegistry.countPlayers(BlackMarketService.MODE) >= settings.minPlayers then
            BlackMarketService.open()
            waited = settings.duration
        end
        Wait((waited + math.random(settings.interval[1], settings.interval[2])) * 1000)
    end
end

---Lots tirés au hasard, sans doublon.
---@return BlackMarketOffer[]
function BlackMarketService.rollStock()
    local pool = {}
    for _, entry in ipairs(Config.BlackMarket.stock) do pool[#pool + 1] = entry end
    local stock = {}
    for _ = 1, math.min(Config.BlackMarket.offers, #pool) do
        local entry = table.remove(pool, math.random(#pool))
        stock[#stock + 1] = { item = entry.item, count = entry.count, price = entry.price, left = entry.lots }
    end
    return stock
end

---@param coords? vector4 position imposée (admin), sinon un point de la config au hasard
---@return BlackMarketVisit
function BlackMarketService.open(coords)
    BlackMarketService.nextId = BlackMarketService.nextId + 1
    local id = BlackMarketService.nextId
    BlackMarketService.current = {
        id = id,
        coords = coords or Utils.pick(Config.BlackMarket.locations),
        endsAt = os.time() + Config.BlackMarket.duration,
        stock = BlackMarketService.rollStock(),
    }
    TriggerClientEvent(Events.client.blackMarketState, -1, BlackMarketService.describe())
    ChatService.announce('pvp', Locale.t('Un marchand noir est en ville pour %d minutes : suis son repère rouge.', math.floor(Config.BlackMarket.duration / 60)))
    Logger.info('[marchand noir] n°%d arrive (%.0f, %.0f)', id, BlackMarketService.current.coords.x, BlackMarketService.current.coords.y)
    SetTimeout(Config.BlackMarket.duration * 1000, function() BlackMarketService.close(id) end)
    return BlackMarketService.current
end

---@param id integer
function BlackMarketService.close(id)
    local visit = BlackMarketService.current
    if not visit or visit.id ~= id then return end
    BlackMarketService.current = nil
    TriggerClientEvent(Events.client.blackMarketState, -1, false)
    ChatService.announce('pvp', Locale.t('Le marchand noir a plié bagage.'))
end

---Données envoyées aux clients : durée restante plutôt qu'une date (horloges différentes).
---@return table
function BlackMarketService.describe()
    local visit = BlackMarketService.current
    return { id = visit.id, coords = visit.coords, endsIn = visit.endsAt - os.time() }
end

---@param player PvpPlayer
---@return boolean le joueur est assez près du marchand pour acheter
function BlackMarketService.isNear(player)
    local visit = BlackMarketService.current
    if not visit then return false end
    local pos = player:getCoords()
    return #(vector3(pos.x, pos.y, pos.z) - vector3(visit.coords.x, visit.coords.y, visit.coords.z)) <= Config.BlackMarket.useDistance
end

---@param source integer
---@return table pour la page Marchand noir
function BlackMarketService.list(source)
    local player = PlayerService.get(source)
    local visit = BlackMarketService.current
    if not player or not visit then return { open = false, stock = {} } end
    return { open = true, near = BlackMarketService.isNear(player), endsIn = visit.endsAt - os.time(), stock = visit.stock }
end

---@param source integer
---@param index any numéro du lot
---@return { ok: boolean, message?: string }
function BlackMarketService.buy(source, index)
    local player = PlayerService.get(source)
    if not player or player.dead or player.mode ~= BlackMarketService.MODE then
        return { ok = false, message = Locale.t('Achat impossible.') }
    end
    local visit = BlackMarketService.current
    if not visit then return { ok = false, message = Locale.t('Le marchand noir est parti.') } end
    if not BlackMarketService.isNear(player) then return { ok = false, message = Locale.t('Le marchand noir est trop loin.') } end

    local offer = visit.stock[tonumber(index)]
    if not offer then return { ok = false, message = Locale.t('Achat impossible.') } end
    if offer.left <= 0 then return { ok = false, message = Locale.t('Plus aucun lot.') } end
    if player:getMoney() < offer.price then return { ok = false, message = Locale.t('Pas assez d\'argent.') } end
    if player.inventory:maxFit('bag', offer.item) < offer.count then return { ok = false, message = Locale.t('Ton sac est trop lourd.') } end

    offer.left = offer.left - 1
    player:removeMoney(offer.price)
    player:giveItem(offer.item, offer.count)
    player:sync()
    Logger.info('[marchand noir] %s achète %s pour $%d', player.name, Items.describe({ [offer.item] = offer.count }), offer.price)
    return { ok = true, message = Locale.t('Acheté : %s', Items.describeText({ [offer.item] = offer.count })) }
end
