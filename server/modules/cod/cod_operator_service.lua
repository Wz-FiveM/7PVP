---Personnages du mode Call of Duty (config/cod_operators.lua) : accessibles avec le VIP, ou achetés pour toujours
---en points boutique. Les achats ont leur table : un paiement ne dépend pas de la sauvegarde du profil.
---Le choix reste enregistré si le VIP expire : le joueur le retrouve en le renouvelant.
---@class CodOperatorServiceModule
local CodOperatorService = PVP.define('CodOperatorService')
local CodProfileService = PVP.use('CodProfileService')
local ShopPointsService = PVP.use('ShopPointsService')
local PlayerService = PVP.use('PlayerService')
local VipService = PVP.use('VipService')
local Events = PVP.use('Events')
local Logger = PVP.use('Logger')
local Locale = PVP.use('Locale')

CodOperatorService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_cod_operators_owned (
    identifier VARCHAR(64) NOT NULL,
    operator_id VARCHAR(32) NOT NULL,
    price INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, operator_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

---@type table<string, table> entrées de Config.CodOperators.list par id
CodOperatorService.byId = {}
---@type table<integer, boolean> joueurs dont un paiement attend la base
CodOperatorService.buying = {}

function CodOperatorService.init()
    for _, entry in ipairs(Config.CodOperators.list) do CodOperatorService.byId[entry.id] = entry end
    MySQL.ready(function()
        MySQL.query.await(CodOperatorService.SCHEMA)
    end)
    AddEventHandler(Events.internal.vipChanged, function(identifier)
        CodOperatorService.onVipChanged(identifier)
    end)
end

---@param identifier string
---@return table<string, boolean>
function CodOperatorService.loadOwned(identifier)
    local rows = MySQL.query.await('SELECT operator_id FROM pvp_cod_operators_owned WHERE identifier = ?', { identifier }) or {}
    local owned = {}
    for _, row in ipairs(rows) do owned[row.operator_id] = true end
    return owned
end

---@param profile CodProfile
---@param entry table
---@return boolean
function CodOperatorService.canUse(profile, entry)
    return profile.owned[entry.id] == true or VipService.isActive(profile.identifier)
end

---@param profile CodProfile
---@return table|nil personnage porté, nil pour celui du joueur
function CodOperatorService.current(profile)
    local entry = CodOperatorService.byId[profile.operator]
    return entry and CodOperatorService.canUse(profile, entry) and entry or nil
end

---@param source integer
---@return string|false modèle porté, vu par les autres joueurs
function CodOperatorService.modelOf(source)
    local profile = CodProfileService.profiles[source]
    local entry = profile and CodOperatorService.current(profile)
    return entry and entry.model or false
end

---Champs du profil envoyé à l'interface.
---@param profile CodProfile
---@return { operator: string|false, operatorModel: string|false, ownedOperators: string[], vipDays: integer }
function CodOperatorService.describe(profile)
    local entry = CodOperatorService.current(profile)
    local owned = {}
    for id in pairs(profile.owned) do owned[#owned + 1] = id end
    return {
        operator = entry and entry.id or false,
        operatorModel = entry and entry.model or false,
        ownedOperators = owned,
        vipDays = VipService.daysLeft(profile.identifier),
    }
end

---@param source integer
---@param id any id du personnage, nil pour reprendre celui du joueur
---@return { ok: boolean, message?: string, profile?: table }
function CodOperatorService.select(source, id)
    local profile = CodProfileService.profiles[source]
    if not profile then return { ok = false } end
    if id ~= nil then
        local entry = type(id) == 'string' and CodOperatorService.byId[id]
        if not entry then return { ok = false } end
        if not CodOperatorService.canUse(profile, entry) then
            return { ok = false, message = Locale.t('Ce personnage demande le VIP ou un achat en %s.', Locale.t(Config.ShopPoints.label:lower())) }
        end
    end
    profile.operator = id or false
    CodProfileService.save(profile)
    return { ok = true, profile = CodProfileService.describe(profile) }
end

---Achat pour toujours : le personnage est équipé aussitôt.
---@param source integer
---@param id any
---@return { ok: boolean, message?: string, profile?: table }
function CodOperatorService.buy(source, id)
    local profile = CodProfileService.profiles[source]
    local player = PlayerService.get(source)
    local entry = type(id) == 'string' and CodOperatorService.byId[id]
    if not profile or not player or not entry then return { ok = false } end
    if profile.owned[id] then return { ok = false, message = Locale.t('Tu possèdes déjà ce personnage.') } end
    if CodOperatorService.buying[source] then return { ok = false } end

    -- Réservé pendant l'attente de la base : une 2e demande ne peut pas payer en même temps
    CodOperatorService.buying[source] = true
    local paid = ShopPointsService.spend(player, entry.price, 'cod_operator:' .. id)
    if not paid then
        CodOperatorService.buying[source] = nil
        player:sync() -- solde relu en base : l'affichage était peut-être en retard
        return { ok = false, message = Locale.t('Pas assez de %s.', Locale.t(Config.ShopPoints.label:lower())) }
    end

    local saved, changed = pcall(MySQL.update.await,
        'INSERT IGNORE INTO pvp_cod_operators_owned (identifier, operator_id, price) VALUES (?, ?, ?)',
        { player.identifier, id, entry.price })
    CodOperatorService.buying[source] = nil
    if not saved or (changed or 0) == 0 then
        ShopPointsService.credit(player.identifier, entry.price, 'refund:cod_operator:' .. id)
        return { ok = false, message = Locale.t('Achat impossible : tes points ont été rendus.') }
    end

    Logger.info('[cod] %s achète le personnage %s (%d points)', player.name, id, entry.price)
    -- Déconnecté pendant le paiement : l'achat est en base, il le retrouvera
    if CodProfileService.profiles[source] ~= profile then return { ok = false } end
    profile.owned[id] = true
    profile.operator = id
    CodProfileService.save(profile)
    player:sync()
    return { ok = true, message = Locale.t('Personnage acheté : %s', entry.label), profile = CodProfileService.describe(profile) }
end

---VIP ajouté ou retiré pendant que le joueur est dans le mode.
---@param identifier string
function CodOperatorService.onVipChanged(identifier)
    for source, profile in pairs(CodProfileService.profiles) do
        if profile.identifier == identifier then
            TriggerClientEvent(Events.client.codProfile, source, CodProfileService.describe(profile))
        end
    end
end
