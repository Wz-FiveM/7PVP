---Achats à l'armurier (Config.Shop).
---Les prix se modifient en jeu (panneau admin F10, onglet « Boutique ») : ils s'appliquent tout de
---suite et ceux qui diffèrent de la valeur par défaut sont enregistrés en base (pvp_shop_prices).
---@class ShopServiceModule
local ShopService = PVP.define('ShopService')
local PlayerService = PVP.use('PlayerService')
local AdminService = PVP.use('AdminService')
local ResaleService = PVP.use('ResaleService')
local DiscordService = PVP.use('DiscordService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local SafeNpcs = PVP.use('SafeNpcs')
local Utils = PVP.use('Utils')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')
local TutorialService = PVP.use('TutorialService')

-- Prix cités dans le journal d'une modification
ShopService.LOG_LIMIT = 5

ShopService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_shop_prices (
    item VARCHAR(64) NOT NULL,
    price INT UNSIGNED NOT NULL,
    updated_by VARCHAR(64) NOT NULL DEFAULT '',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (item)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

---@type table<string, table> objet -> ligne de Config.Shop (son prix est le prix actuel)
ShopService.entries = {}
---@type table<string, integer> objet -> prix de config/shop.lua
ShopService.defaults = {}

function ShopService.init()
    for _, entry in ipairs(Config.Shop) do
        ShopService.entries[entry.item] = entry
        ShopService.defaults[entry.item] = entry.price
    end

    Callback.register(Events.callbacks.buy, ShopService.buy)
    Callback.register(Events.callbacks.adminShop, ShopService.getCallback)
    Callback.register(Events.callbacks.adminShopSave, ShopService.saveCallback)
    Callback.register(Events.callbacks.adminShopReset, ShopService.resetCallback)

    -- Les clients lisent les prix dans leur config (page Boutique)
    AddEventHandler(Events.internal.playerLoaded, function(playerSource)
        ShopService.sendPrices(playerSource)
    end)

    CreateThread(ShopService.load)
end

---Applique ce qui a été enregistré depuis le panneau, puis charge les prix du receleur : leur valeur
---par défaut dépend de ceux de la boutique.
function ShopService.load()
    MySQL.query.await(ShopService.SCHEMA)
    local rows = MySQL.query.await('SELECT item, price FROM pvp_shop_prices') or {}
    for _, row in ipairs(rows) do
        local price = ShopService.validPrice(row.item, row.price)
        if price then ShopService.entries[row.item].price = price end
    end
    if #rows > 0 then
        Logger.info('[boutique] %d prix chargé(s) depuis la base', #rows)
        ShopService.sendPrices(-1)
    end
    ResaleService.refreshDefaults()
    ResaleService.load()
end

---@param name any
---@param value any
---@return integer|nil prix borné, nil si l'objet n'est pas vendu ou si le prix est nul (rien de gratuit)
function ShopService.validPrice(name, value)
    if type(name) ~= 'string' or not ShopService.entries[name] then return nil end
    local price = Utils.toCount(value)
    if price < 1 then return nil end
    return math.min(Config.ShopMaxPrice, price)
end

---@param target integer joueur, -1 = tout le monde
function ShopService.sendPrices(target)
    local prices = {}
    for name, entry in pairs(ShopService.entries) do prices[name] = entry.price end
    TriggerClientEvent(Events.client.shopPrices, target, prices)
end

---@param source integer
---@param index integer index (1-based) dans Config.Shop
---@param quantity? integer nombre de lots (1 par défaut)
---@return { ok: boolean, message: string }
function ShopService.buy(source, index, quantity)
    local player = PlayerService.get(source)
    local entry = Config.Shop[tonumber(index)]
    local lots = Utils.toCount(quantity or 1)
    if not player or player.dead or not entry or lots < 1 or lots > Config.ShopMaxQuantity then
        return { ok = false, message = Locale.t('Achat impossible.') }
    end
    if not SafeNpcs.isNear(player:getCoords(), 'shop', Config.SafeNpcs.useDistance + 2.0) then
        return { ok = false, message = SafeNpcs.hint('shop') }
    end
    if player:getLevel() < (entry.level or 1) then
        return { ok = false, message = Locale.t('Niveau %d requis.', entry.level) }
    end
    local total, received = entry.price * lots, entry.count * lots
    if player:getMoney() < total then
        return { ok = false, message = Locale.t('Pas assez d\'argent.') }
    end
    if player.inventory:maxFit('bag', entry.item) < received then
        return { ok = false, message = Locale.t('Ton sac est trop lourd.') }
    end

    player:removeMoney(total)
    player:giveItem(entry.item, received)
    player:sync()
    TutorialService.complete(player, 'shop')
    return { ok = true, message = Locale.t('Acheté : %s', Items.describeText({ [entry.item] = received })) }
end

-- ---------------------------------------------------------------------------
-- Panneau admin
-- ---------------------------------------------------------------------------

---@param source integer
---@return boolean
function ShopService.allowed(source)
    if AdminService.isAdmin(source) then return true end
    DiscordService.adminDenied(source)
    return false
end

---Les lignes de la boutique, dans son ordre, avec le prix par défaut et ce que le lot rapporte au receleur.
---@param source integer
function ShopService.getCallback(source)
    if not ShopService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end

    local items = {}
    for _, entry in ipairs(Config.Shop) do
        local item = Config.Items[entry.item]
        items[#items + 1] = {
            name = entry.item,
            label = item.label,
            type = item.type,
            count = entry.count,
            price = entry.price,
            default = ShopService.defaults[entry.item],
            resale = (ResaleService.prices[entry.item] or 0) * entry.count,
            resaleFollows = ResaleService.followsShop(entry.item),
        }
    end
    return { ok = true, items = items, maxPrice = Config.ShopMaxPrice }
end

---@param source integer
---@param data any objet -> prix
function ShopService.saveCallback(source, data)
    if not ShopService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end
    if type(data) ~= 'table' then return { ok = false, message = Locale.t('Données invalides.') } end

    local changes = {}
    for name, value in pairs(data) do
        local price = ShopService.validPrice(name, value)
        if price and price ~= ShopService.entries[name].price then
            changes[#changes + 1] = ('%s $%d → $%d'):format(Items.label(name), ShopService.entries[name].price, price)
            ShopService.entries[name].price = price
            ShopService.store(source, name, price)
        end
    end
    if #changes == 0 then return { ok = false, message = Locale.t('Aucun prix à enregistrer.') } end

    ShopService.applied()
    table.sort(changes)
    local shown = table.concat(changes, ', ', 1, math.min(#changes, ShopService.LOG_LIMIT))
    ShopService.log(source, ('%d prix : %s'):format(#changes, shown))
    return { ok = true, message = Locale.t('Prix de la boutique enregistrés : %d', #changes) }
end

---@param source integer
function ShopService.resetCallback(source)
    if not ShopService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end

    for name, entry in pairs(ShopService.entries) do entry.price = ShopService.defaults[name] end
    MySQL.update('DELETE FROM pvp_shop_prices')
    ShopService.applied()
    ShopService.log(source, 'tous les prix remis par défaut')
    return { ok = true, message = Locale.t('Prix de la boutique remis par défaut.') }
end

---Prix changés : le receleur suit, et les joueurs voient les nouveaux prix sans rouvrir la page.
function ShopService.applied()
    ResaleService.refreshDefaults()
    ShopService.sendPrices(-1)
end

---@param source integer
---@param name string
---@param price integer
function ShopService.store(source, name, price)
    if price == ShopService.defaults[name] then
        MySQL.update('DELETE FROM pvp_shop_prices WHERE item = ?', { name })
        return
    end
    MySQL.insert(
        'INSERT INTO pvp_shop_prices (item, price, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE price = VALUES(price), updated_by = VALUES(updated_by)',
        { name, price, GetPlayerName(source) or '' }
    )
end

---@param source integer
---@param message string
function ShopService.log(source, message)
    Logger.info('[admin] %s : boutique, %s', GetPlayerName(source), message)
    DiscordService.adminAction(source, 'shopConfig', nil, {}, message)
end
