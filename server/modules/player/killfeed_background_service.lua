---Fonds du killfeed en PvP (Config.KillfeedBackgrounds) : achetés pour toujours en points boutique.
---Les achats ont leur table : un paiement ne dépend pas de la sauvegarde du profil.
---Le fond choisi est gardé avec le profil (colonne killfeed_background).
---@class KillfeedBackgroundServiceModule
local KillfeedBackgroundService = PVP.define('KillfeedBackgroundService')
local ShopPointsService = PVP.use('ShopPointsService')
local PlayerService = PVP.use('PlayerService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Logger = PVP.use('Logger')
local Locale = PVP.use('Locale')

KillfeedBackgroundService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_killfeed_backgrounds_owned (
    identifier VARCHAR(64) NOT NULL,
    background_id VARCHAR(16) NOT NULL,
    price INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, background_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

---@type table<string, table> entrées de Config.KillfeedBackgrounds par id
KillfeedBackgroundService.byId = {}

function KillfeedBackgroundService.init()
    for _, entry in ipairs(Config.KillfeedBackgrounds) do KillfeedBackgroundService.byId[entry.id] = entry end
    MySQL.ready(function()
        MySQL.query.await(KillfeedBackgroundService.SCHEMA)
    end)
    Callback.register(Events.callbacks.killfeedBackgroundBuy, KillfeedBackgroundService.buy)
    Callback.register(Events.callbacks.killfeedBackgroundSelect, KillfeedBackgroundService.select)
end

---Achats et choix du joueur, au chargement du profil.
---@param player PvpPlayer
---@param chosen any valeur de la colonne killfeed_background
function KillfeedBackgroundService.load(player, chosen)
    local rows = MySQL.query.await('SELECT background_id FROM pvp_killfeed_backgrounds_owned WHERE identifier = ?', { player.identifier }) or {}
    for _, row in ipairs(rows) do player.killfeedOwned[row.background_id] = true end
    -- Un fond retiré de la config n'est plus affiché : le joueur revient au fond par défaut
    player.killfeedBackground = KillfeedBackgroundService.canUse(player, chosen) and chosen or nil
end

---@param player PvpPlayer
---@param id any
---@return boolean fond connu de la config et acheté par le joueur
function KillfeedBackgroundService.canUse(player, id)
    return KillfeedBackgroundService.byId[id] ~= nil and player.killfeedOwned[id] == true
end

---@param player PvpPlayer
---@return string[] fonds achetés, pour l'interface
function KillfeedBackgroundService.ownedList(player)
    local owned = {}
    for id in pairs(player.killfeedOwned) do owned[#owned + 1] = id end
    return owned
end

---@param source integer
---@param id any id du fond, chaîne vide pour reprendre le fond par défaut
---@return { ok: boolean, message?: string }
function KillfeedBackgroundService.select(source, id)
    local player = PlayerService.get(source)
    if not player or type(id) ~= 'string' then return { ok = false } end

    local chosen = id ~= '' and id or nil
    if chosen and not KillfeedBackgroundService.canUse(player, chosen) then
        return { ok = false, message = Locale.t('Tu ne possèdes pas ce fond.') }
    end
    if player.killfeedBackground == chosen then return { ok = true } end

    player.killfeedBackground = chosen
    player:sync()
    return { ok = true, message = chosen and Locale.t('Fond du killfeed équipé.') or Locale.t('Fond du killfeed retiré.') }
end

---Achat pour toujours : le fond est équipé aussitôt.
---@param source integer
---@param id any
---@return { ok: boolean, message?: string }
function KillfeedBackgroundService.buy(source, id)
    local player = PlayerService.get(source)
    local entry = type(id) == 'string' and KillfeedBackgroundService.byId[id]
    if not player or not entry or player.killfeedBuying then return { ok = false } end
    if player.killfeedOwned[id] then return { ok = false, message = Locale.t('Tu possèdes déjà ce fond.') } end

    -- Réservé pendant l'attente de la base : une 2e demande ne peut pas payer en même temps
    player.killfeedBuying = true
    local paid = ShopPointsService.spend(player, entry.price, 'killfeed_background:' .. id)
    if not paid then
        player.killfeedBuying = false
        player:sync() -- solde relu en base : l'affichage était peut-être en retard
        return { ok = false, message = Locale.t('Pas assez de %s.', Locale.t(Config.ShopPoints.label:lower())) }
    end

    local saved, changed = pcall(MySQL.update.await,
        'INSERT IGNORE INTO pvp_killfeed_backgrounds_owned (identifier, background_id, price) VALUES (?, ?, ?)',
        { player.identifier, id, entry.price })
    player.killfeedBuying = false
    if not saved or (changed or 0) == 0 then
        ShopPointsService.credit(player.identifier, entry.price, 'refund:killfeed_background:' .. id)
        return { ok = false, message = Locale.t('Achat impossible : tes points ont été rendus.') }
    end

    Logger.info('[points] %s achète le fond de killfeed %s (%d points)', player.name, id, entry.price)
    -- Déconnecté pendant le paiement : l'achat est en base, il le retrouvera
    if PlayerService.get(source) ~= player then return { ok = false } end
    player.killfeedOwned[id] = true
    player.killfeedBackground = id
    player:sync()
    return { ok = true, message = Locale.t('Fond du killfeed acheté : %s', Locale.t(entry.label)) }
end
