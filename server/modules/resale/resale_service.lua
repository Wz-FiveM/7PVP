---Revente au receleur (Config.Resale) : il rachète les objets portés contre de l'argent.
---Les prix se modifient en jeu (panneau admin F10, onglet « Revente ») : ils s'appliquent tout de
---suite et ceux qui diffèrent de la valeur par défaut sont enregistrés en base (pvp_resale_prices).
---@class ResaleServiceModule
local ResaleService = PVP.define('ResaleService')
local PlayerService = PVP.use('PlayerService')
local AdminService = PVP.use('AdminService')
local SafeNpcs = PVP.use('SafeNpcs')
local Callback = PVP.use('Callback')
local DiscordService = PVP.use('DiscordService')
local Items = PVP.use('Items')
local Utils = PVP.use('Utils')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

ResaleService.MODE = 'pvp'
ResaleService.ROLE = 'resale'
-- Prix cités dans le journal d'une modification
ResaleService.LOG_LIMIT = 5

ResaleService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_resale_prices (
    item VARCHAR(64) NOT NULL,
    price INT UNSIGNED NOT NULL,
    updated_by VARCHAR(64) NOT NULL DEFAULT '',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (item)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

---@type table<string, number> objet -> prix d'achat le plus bas par unité (boutique et caisses)
ResaleService.shopPrices = {}
---@type table<string, integer> objet -> prix de revente par défaut (tous les objets sauf l'argent)
ResaleService.defaults = {}
---@type table<string, integer> objet -> prix de revente actuel (0 : pas repris)
ResaleService.prices = {}

function ResaleService.init()
    ResaleService.shopPrices = ResaleService.buildShopPrices()
    ResaleService.defaults = ResaleService.buildDefaults()
    ResaleService.prices = Utils.shallowCopy(ResaleService.defaults)

    Callback.register(Events.callbacks.resaleList, ResaleService.list)
    Callback.register(Events.callbacks.resaleSell, ResaleService.sell)
    Callback.register(Events.callbacks.adminResale, ResaleService.getCallback)
    Callback.register(Events.callbacks.adminResaleSave, ResaleService.saveCallback)
    Callback.register(Events.callbacks.adminResaleReset, ResaleService.resetCallback)

    CreateThread(ResaleService.load)
end

---Applique ce qui a été enregistré depuis le panneau.
function ResaleService.load()
    MySQL.query.await(ResaleService.SCHEMA)
    local rows = MySQL.query.await('SELECT item, price FROM pvp_resale_prices') or {}
    for _, row in ipairs(rows) do
        local price = ResaleService.validPrice(row.item, row.price)
        if price then ResaleService.prices[row.item] = price end
    end
    if #rows > 0 then Logger.info('[revente] %d prix chargé(s) depuis la base', #rows) end
end

---@return table<string, number>
function ResaleService.buildShopPrices()
    local prices = {}
    for _, entry in ipairs(Config.Shop) do
        local unit = entry.price / entry.count
        prices[entry.item] = math.min(prices[entry.item] or unit, unit)
    end
    for _, case in ipairs(Config.Cases) do
        if case.price then prices[case.id] = case.price end
    end
    return prices
end

---@return table<string, integer>
function ResaleService.buildDefaults()
    local defaults = {}
    for name, item in pairs(Config.Items) do
        if name ~= 'money' then
            defaults[name] = Config.Resale.prices[name]
                or ResaleService.fromShop(ResaleService.shopPrices[name])
                or Config.Resale.byType[item.type]
                or 0
        end
    end
    return defaults
end

---@param unit number|nil prix d'achat par unité
---@return integer|nil au moins $1 pour ce qui coûte plus de $1 (munitions), jamais le prix d'achat
function ResaleService.fromShop(unit)
    if not unit then return nil end
    local price = math.floor(unit * Config.Resale.shopRate)
    if price < 1 and unit > 1 then return 1 end
    return price
end

---@param name any
---@param value any
---@return integer|nil prix borné, nil si l'objet n'existe pas (ou n'est pas revendable)
function ResaleService.validPrice(name, value)
    if type(name) ~= 'string' or not ResaleService.defaults[name] then return nil end
    return math.max(0, math.min(Config.Resale.maxPrice, Utils.toCount(value)))
end

-- ---------------------------------------------------------------------------
-- Joueurs
-- ---------------------------------------------------------------------------

---Prix des objets repris.
---@param source integer
---@return { prices: table<string, integer> }
function ResaleService.list(source)
    if not PlayerService.get(source) then return { prices = {} } end
    local prices = {}
    for name, price in pairs(ResaleService.prices) do
        if price > 0 then prices[name] = price end
    end
    return { prices = prices }
end

---Vend une quantité d'un objet porté.
---@param source integer
---@param data { container: string, item: string, count: integer }
---@return { ok: boolean, message?: string }
function ResaleService.sell(source, data)
    local player = PlayerService.get(source)
    if not player or player.dead or player.mode ~= ResaleService.MODE then
        return { ok = false, message = Locale.t('Action impossible.') }
    end
    if not SafeNpcs.isNear(player:getCoords(), ResaleService.ROLE, Config.SafeNpcs.useDistance + 2.0) then
        return { ok = false, message = SafeNpcs.hint(ResaleService.ROLE) }
    end
    if type(data) ~= 'table' then return { ok = false } end

    local item, container = data.item, data.container
    local count = Utils.toCount(data.count)
    local price = ResaleService.prices[item] or 0
    if price <= 0 then return { ok = false, message = Locale.t('Le receleur ne reprend pas cet objet.') } end
    if container ~= 'bag' and container ~= 'protected' then return { ok = false, message = Locale.t('Conteneur invalide.') } end
    if count <= 0 then return { ok = false, message = Locale.t('Quantité invalide.') } end
    if player.inventory:countIn(container, item) < count then
        return { ok = false, message = Locale.t('Tu n\'as pas cette quantité.') }
    end

    local total = price * count
    player.inventory:removeFrom(container, item, count)
    -- Accessoires de l'arme : rendus, ou vendus avec elle s'ils ne rentrent plus dans le sac
    for attachment, released in pairs(player.inventory:releaseAttachments(item)) do
        local overflow = released - player:giveItem(attachment, released)
        total = total + overflow * (ResaleService.prices[attachment] or 0)
    end
    player:addMoney(total)
    player:sync()
    Logger.info('[revente] %s vend %s pour $%d', player.name, Items.describe({ [item] = count }), total)
    return { ok = true, message = Locale.t('Vendu : %s pour $%d', Items.describeText({ [item] = count }), total) }
end

-- ---------------------------------------------------------------------------
-- Panneau admin
-- ---------------------------------------------------------------------------

---@param source integer
---@return boolean
function ResaleService.allowed(source)
    if AdminService.isAdmin(source) then return true end
    DiscordService.adminDenied(source)
    return false
end

---Tous les objets, avec leur prix de revente, sa valeur par défaut et le prix d'achat.
---@param source integer
function ResaleService.getCallback(source)
    if not ResaleService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end

    local items = {}
    for name, price in pairs(ResaleService.prices) do
        local item = Config.Items[name]
        items[#items + 1] = {
            name = name,
            label = item.label,
            type = item.type,
            price = price,
            default = ResaleService.defaults[name],
            shop = ResaleService.shopPrices[name] or false,
        }
    end
    table.sort(items, function(a, b) return a.label < b.label end)
    return { ok = true, items = items, maxPrice = Config.Resale.maxPrice }
end

---@param source integer
---@param data any objet -> prix
function ResaleService.saveCallback(source, data)
    if not ResaleService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end
    if type(data) ~= 'table' then return { ok = false, message = Locale.t('Données invalides.') } end

    local changes = {}
    for name, value in pairs(data) do
        local price = ResaleService.validPrice(name, value)
        if price and price ~= ResaleService.prices[name] then
            changes[#changes + 1] = ('%s $%d → $%d'):format(Items.label(name), ResaleService.prices[name], price)
            ResaleService.prices[name] = price
            ResaleService.store(source, name, price)
        end
    end
    if #changes == 0 then return { ok = false, message = Locale.t('Aucun prix à enregistrer.') } end

    table.sort(changes)
    local shown = table.concat(changes, ', ', 1, math.min(#changes, ResaleService.LOG_LIMIT))
    ResaleService.log(source, ('%d prix : %s'):format(#changes, shown))
    return { ok = true, message = Locale.t('Prix de revente enregistrés : %d', #changes) }
end

---@param source integer
function ResaleService.resetCallback(source)
    if not ResaleService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end

    ResaleService.prices = Utils.shallowCopy(ResaleService.defaults)
    MySQL.update('DELETE FROM pvp_resale_prices')
    ResaleService.log(source, 'tous les prix remis par défaut')
    return { ok = true, message = Locale.t('Prix de revente remis par défaut.') }
end

---@param source integer
---@param name string
---@param price integer
function ResaleService.store(source, name, price)
    if price == ResaleService.defaults[name] then
        MySQL.update('DELETE FROM pvp_resale_prices WHERE item = ?', { name })
        return
    end
    MySQL.insert(
        'INSERT INTO pvp_resale_prices (item, price, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE price = VALUES(price), updated_by = VALUES(updated_by)',
        { name, price, GetPlayerName(source) or '' }
    )
end

---@param source integer
---@param message string
function ResaleService.log(source, message)
    Logger.info('[admin] %s : revente, %s', GetPlayerName(source), message)
    DiscordService.adminAction(source, 'resaleConfig', nil, {}, message)
end
