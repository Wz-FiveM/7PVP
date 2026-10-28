---Place de marché entre joueurs (Config.Market) : vente d'objets portés, achat, retrait
---d'annonce et récupération de l'argent des ventes, auprès du commissaire-priseur.
---Les annonces sont gardées en mémoire (source de vérité, modifiée sans attente) et
---recopiées en base ; un objet mis en vente quitte l'inventaire jusqu'à la vente ou au retrait.
---@class MarketListing
---@field id integer
---@field seller string identifiant (license) du vendeur
---@field sellerName string
---@field item string
---@field count integer
---@field price integer prix du lot

---@class MarketServiceModule
local MarketService = PVP.define('MarketService')
local MarketRepository = PVP.use('MarketRepository')
local PlayerService = PVP.use('PlayerService')
local SafeNpcs = PVP.use('SafeNpcs')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')

---@type table<integer, MarketListing>
MarketService.listings = {}
-- Récupérations en cours (évite de payer deux fois le même solde)
MarketService.collecting = {}

function MarketService.init()
    Callback.register(Events.callbacks.marketList, MarketService.list)
    Callback.register(Events.callbacks.marketSell, MarketService.sell)
    Callback.register(Events.callbacks.marketBuy, MarketService.buy)
    Callback.register(Events.callbacks.marketCancel, MarketService.cancel)
    Callback.register(Events.callbacks.marketCollect, MarketService.collect)

    MySQL.ready(function()
        for _, row in ipairs(MarketRepository.loadAll()) do
            MarketService.listings[row.id] = {
                id = row.id, seller = row.seller, sellerName = row.seller_name,
                item = row.item, count = row.count, price = row.price,
            }
        end
        Logger.info('Place de marché : %d annonce(s)', MarketService.count())
    end)
end

---@param seller? string compter seulement les annonces de ce vendeur
---@return integer
function MarketService.count(seller)
    local count = 0
    for _, listing in pairs(MarketService.listings) do
        if not seller or listing.seller == seller then count = count + 1 end
    end
    return count
end

---Joueur vivant à côté du commissaire-priseur.
---@param source integer
---@return PvpPlayer|nil player, string|nil message
function MarketService.getTrader(source)
    local player = PlayerService.get(source)
    if not player or player.dead then return nil, 'Action impossible.' end
    if not SafeNpcs.isNear(player:getCoords(), 'market', Config.SafeNpcs.useDistance + 2.0) then
        return nil, SafeNpcs.hint('market')
    end
    return player
end

---@param identifier string
---@return PvpPlayer|nil joueur connecté avec cette licence
function MarketService.findOnline(identifier)
    for _, player in pairs(PlayerService.all()) do
        if player.identifier == identifier then return player end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Callbacks
-- ---------------------------------------------------------------------------

---Annonces (les plus récentes d'abord) et solde à récupérer.
---@param source integer
---@return table
function MarketService.list(source)
    local player = PlayerService.get(source)
    if not player then return { listings = {}, balance = 0 } end

    local listings = {}
    for _, listing in pairs(MarketService.listings) do
        listings[#listings + 1] = {
            id = listing.id,
            item = listing.item,
            count = listing.count,
            price = listing.price,
            sellerName = listing.sellerName,
            mine = listing.seller == player.identifier,
        }
    end
    table.sort(listings, MarketService.newestFirst)
    return {
        listings = listings,
        balance = MarketRepository.getBalance(player.identifier),
        fee = Config.Market.fee,
        maxListings = Config.Market.maxListings,
    }
end

---@return boolean
function MarketService.newestFirst(a, b)
    return a.id > b.id
end

---Met en vente une quantité d'un objet porté.
---@param source integer
---@param data { container: string, item: string, count: integer, price: integer }
---@return { ok: boolean, message?: string }
function MarketService.sell(source, data)
    local player, denied = MarketService.getTrader(source)
    if not player then return { ok = false, message = denied } end
    if type(data) ~= 'table' then return { ok = false } end

    local item, container = data.item, data.container
    local count = math.floor(tonumber(data.count) or 0)
    local price = math.floor(tonumber(data.price) or 0)
    if not Items.exists(item) or Config.Market.blocked[item] then
        return { ok = false, message = 'Cet objet ne peut pas être vendu.' }
    end
    if container ~= 'bag' and container ~= 'protected' then return { ok = false, message = 'Conteneur invalide.' } end
    if count <= 0 or price <= 0 or price > Config.Market.maxPrice then
        return { ok = false, message = 'Quantité ou prix invalide.' }
    end
    if MarketService.count(player.identifier) >= Config.Market.maxListings then
        return { ok = false, message = ('%d annonces maximum.'):format(Config.Market.maxListings) }
    end
    if player.inventory:countIn(container, item) < count then
        return { ok = false, message = 'Tu n\'as pas cette quantité.' }
    end

    -- L'objet quitte l'inventaire avant l'écriture en base : pas de double vente possible
    player.inventory:removeFrom(container, item, count)
    for attachment, released in pairs(player.inventory:releaseAttachments(item)) do
        player:giveItem(attachment, released)
    end
    player:sync()

    local id = MarketRepository.insert(player.identifier, player.name, item, count, price)
    if not id then
        player:giveItem(item, count, container)
        player:sync()
        return { ok = false, message = 'Erreur de la base de données, objet rendu.' }
    end
    MarketService.listings[id] = {
        id = id, seller = player.identifier, sellerName = player.name, item = item, count = count, price = price,
    }
    Logger.info('[marché] %s met en vente %s pour $%d', player.name, Items.describe({ [item] = count }), price)
    return { ok = true, message = ('Mis en vente : %s pour $%d'):format(Items.describe({ [item] = count }), price) }
end

---@param source integer
---@param id any
---@return { ok: boolean, message?: string }
function MarketService.buy(source, id)
    local player, denied = MarketService.getTrader(source)
    if not player then return { ok = false, message = denied } end

    local listing = MarketService.listings[tonumber(id)]
    if not listing then return { ok = false, message = 'Cette annonce n\'existe plus.' } end
    if listing.seller == player.identifier then return { ok = false, message = 'C\'est ton annonce : retire-la plutôt.' } end
    if player:getMoney() < listing.price then return { ok = false, message = 'Pas assez d\'argent sur toi.' } end
    if player.inventory:maxFit('bag', listing.item) < listing.count then
        return { ok = false, message = 'Ton sac est trop lourd.' }
    end

    MarketService.listings[listing.id] = nil
    player:removeMoney(listing.price)
    player:giveItem(listing.item, listing.count)
    player:sync()
    MarketRepository.delete(listing.id)

    local earned = math.floor(listing.price * (1 - Config.Market.fee))
    MarketRepository.credit(listing.seller, earned)
    local seller = MarketService.findOnline(listing.seller)
    if seller then
        seller:notify(('Vendu : %s à %s (+$%d à récupérer au marché)'):format(
            Items.describe({ [listing.item] = listing.count }), player.name, earned), 'success')
    end
    Logger.info('[marché] %s achète %s à %s pour $%d', player.name,
        Items.describe({ [listing.item] = listing.count }), listing.sellerName, listing.price)
    return { ok = true, message = ('Acheté : %s'):format(Items.describe({ [listing.item] = listing.count })) }
end

---Retire une de ses annonces : les objets reviennent dans le sac.
---@param source integer
---@param id any
---@return { ok: boolean, message?: string }
function MarketService.cancel(source, id)
    local player, denied = MarketService.getTrader(source)
    if not player then return { ok = false, message = denied } end

    local listing = MarketService.listings[tonumber(id)]
    if not listing or listing.seller ~= player.identifier then return { ok = false, message = 'Annonce introuvable.' } end
    if player.inventory:maxFit('bag', listing.item) < listing.count then
        return { ok = false, message = 'Fais de la place dans ton sac.' }
    end

    MarketService.listings[listing.id] = nil
    player:giveItem(listing.item, listing.count)
    player:sync()
    MarketRepository.delete(listing.id)
    return { ok = true, message = 'Annonce retirée, objets rendus.' }
end

---Récupère l'argent des ventes (versé dans le sac).
---@param source integer
---@return { ok: boolean, message?: string }
function MarketService.collect(source)
    local player, denied = MarketService.getTrader(source)
    if not player then return { ok = false, message = denied } end
    if MarketService.collecting[player.identifier] then return { ok = false } end

    MarketService.collecting[player.identifier] = true
    local balance = MarketRepository.getBalance(player.identifier)
    if balance > 0 then
        MarketRepository.debit(player.identifier, balance)
        player:addMoney(balance)
        player:sync()
    end
    MarketService.collecting[player.identifier] = nil

    if balance <= 0 then return { ok = false, message = 'Rien à récupérer.' } end
    return { ok = true, message = ('Ventes récupérées : +$%d'):format(balance) }
end
