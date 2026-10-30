---Statut VIP (config/vip.lua) : crédité par Tebex ou un admin, à durée limitée.
---La base fait foi : `VipService.expiry` n'en garde qu'une copie pour les joueurs connectés.
---@class VipServiceModule
local VipService = PVP.define('VipService')
local PlayerService = PVP.use('PlayerService')
local AdminService = PVP.use('AdminService')
local DiscordService = PVP.use('DiscordService')
local Events = PVP.use('Events')
local Logger = PVP.use('Logger')
local Locale = PVP.use('Locale')

VipService.DAY = 86400
VipService.SCHEMAS = {
    [[CREATE TABLE IF NOT EXISTS pvp_vip (
        identifier VARCHAR(64) NOT NULL,
        expires_at BIGINT NOT NULL,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS pvp_vip_log (
        id INT NOT NULL AUTO_INCREMENT,
        identifier VARCHAR(64) NOT NULL,
        days INT NOT NULL,
        reason VARCHAR(64) NOT NULL,
        reference VARCHAR(128) NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_reference (reference),
        KEY idx_identifier (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

---@type table<string, integer> licence -> os.time() de fin, joueurs connectés
VipService.expiry = {}

function VipService.init()
    MySQL.ready(function()
        for _, query in ipairs(VipService.SCHEMAS) do MySQL.query.await(query) end
    end)
    AddEventHandler(Events.internal.playerUnloading, function(source)
        local player = PlayerService.get(source)
        if player then VipService.expiry[player.identifier] = nil end
    end)

    -- Commandes console (Tebex) et admins en jeu, via la permission command.<nom>
    RegisterCommand('addvip', function(source, args)
        VipService.commandAdd(source, args)
    end, true)
    RegisterCommand('removevip', function(source, args)
        VipService.commandRemove(source, args)
    end, true)
    RegisterCommand('vip', function(source, args)
        VipService.commandShow(source, args[1])
    end, true)
end

---Lu au chargement du joueur.
---@param identifier string
function VipService.load(identifier)
    VipService.expiry[identifier] = VipService.read(identifier)
end

---@param identifier string
---@return integer os.time() de fin, 0 sans VIP
function VipService.read(identifier)
    return MySQL.scalar.await('SELECT expires_at FROM pvp_vip WHERE identifier = ?', { identifier }) or 0
end

---@param identifier string joueur connecté
---@return boolean
function VipService.isActive(identifier)
    return (VipService.expiry[identifier] or 0) > os.time()
end

---@param identifier string joueur connecté
---@return integer jours restants, entamés compris ; 0 sans VIP
function VipService.daysLeft(identifier)
    local left = (VipService.expiry[identifier] or 0) - os.time()
    return left > 0 and math.ceil(left / VipService.DAY) or 0
end

---La copie d'un joueur connecté suit la base, et les modules concernés sont prévenus.
---@param identifier string
function VipService.refresh(identifier)
    if VipService.expiry[identifier] == nil then return end
    VipService.expiry[identifier] = VipService.read(identifier)
    TriggerEvent(Events.internal.vipChanged, identifier)
end

---@param days any
---@return integer|nil nombre de jours entier strictement positif
function VipService.parseDays(days)
    days = math.tointeger(tonumber(days))
    if not days or days <= 0 or days > Config.Vip.maxDays then return nil end
    return days
end

---Ajoute des jours, à la suite de ceux qui restent, même à une licence hors ligne.
---@param identifier string
---@param days any
---@param reason string ex : 'tebex', 'admin'
---@param reference? string référence unique (transaction Tebex) : un doublon n'est pas crédité
---@return 'ok'|'duplicate'|'invalid'|'error'
function VipService.add(identifier, days, reason, reference)
    days = VipService.parseDays(days)
    if not days then return 'invalid' end
    if reference and VipService.hasReference(reference) then return 'duplicate' end

    local now, seconds = os.time(), days * VipService.DAY
    -- Avec une référence déjà utilisée, la clé unique fait échouer la transaction entière
    local done = MySQL.transaction.await({
        {
            query = 'INSERT INTO pvp_vip_log (identifier, days, reason, reference) VALUES (?, ?, ?, ?)',
            values = { identifier, days, reason, reference },
        },
        {
            query = [[INSERT INTO pvp_vip (identifier, expires_at) VALUES (?, ?)
                      ON DUPLICATE KEY UPDATE expires_at = GREATEST(expires_at, ?) + ?]],
            values = { identifier, now + seconds, now, seconds },
        },
    })
    if done ~= true then
        return (reference and VipService.hasReference(reference)) and 'duplicate' or 'error'
    end

    Logger.info('[vip] %s : +%d jours (%s%s)', identifier, days, reason, reference and (', réf. ' .. reference) or '')
    VipService.refresh(identifier)
    return 'ok'
end

---@param reference string
---@return boolean
function VipService.hasReference(reference)
    return MySQL.scalar.await('SELECT 1 FROM pvp_vip_log WHERE reference = ?', { reference }) ~= nil
end

---@param identifier string
---@param reason string
---@return boolean false si le joueur n'était pas VIP
function VipService.remove(identifier, reason)
    local changed = MySQL.update.await('DELETE FROM pvp_vip WHERE identifier = ?', { identifier })
    if (changed or 0) == 0 then return false end
    Logger.info('[vip] %s : retiré (%s)', identifier, reason)
    VipService.refresh(identifier)
    return true
end

-- ---------------------------------------------------------------------------
-- Commandes
-- ---------------------------------------------------------------------------

---@param source integer 0 = console
---@return string
function VipService.reasonOf(source)
    return source == 0 and 'console' or ('admin:' .. (GetPlayerName(source) or source))
end

---addvip <id | license:xxxx> <jours> [référence]
---@param source integer
---@param args string[]
function VipService.commandAdd(source, args)
    local identifier, name = AdminService.resolveTarget(args[1])
    local days = VipService.parseDays(args[2])
    if not identifier or not days then
        return AdminService.reply(source, Locale.t('Usage : %s <id du joueur | license:xxxx> <jours> [référence]', 'addvip'))
    end

    local label = name or identifier
    local reference = args[3]
    local status = VipService.add(identifier, days, VipService.reasonOf(source), reference)
    if status == 'duplicate' then
        return AdminService.reply(source, Locale.t('Référence %s déjà créditée : ignorée.', reference))
    elseif status ~= 'ok' then
        Logger.error('[vip] addvip %s %d a échoué (%s)', label, days, status)
        return AdminService.reply(source, Locale.t('Échec de l\'ajout du VIP (voir la console).'))
    end
    DiscordService.vip(source, label, days, reference)
    AdminService.reply(source, Locale.t('%s : +%d jours de VIP.', label, days))
end

---removevip <id | license:xxxx>
---@param source integer
---@param args string[]
function VipService.commandRemove(source, args)
    local identifier, name = AdminService.resolveTarget(args[1])
    if not identifier then
        return AdminService.reply(source, Locale.t('Usage : %s <id du joueur | license:xxxx>', 'removevip'))
    end

    local label = name or identifier
    if not VipService.remove(identifier, VipService.reasonOf(source)) then
        return AdminService.reply(source, Locale.t('%s n\'est pas VIP.', label))
    end
    DiscordService.vip(source, label, 0)
    AdminService.reply(source, Locale.t('%s : VIP retiré.', label))
end

---vip <id | license:xxxx>
---@param source integer
---@param arg string|nil
function VipService.commandShow(source, arg)
    local identifier, name = AdminService.resolveTarget(arg)
    if not identifier then
        return AdminService.reply(source, Locale.t('Usage : %s <id du joueur | license:xxxx>', 'vip'))
    end

    local label = name or identifier
    local expires = VipService.read(identifier)
    if expires <= os.time() then
        return AdminService.reply(source, Locale.t('%s n\'est pas VIP.', label))
    end
    AdminService.reply(source, Locale.t('%s : VIP jusqu\'au %s.', label, os.date('%d/%m/%Y', expires)))
end
