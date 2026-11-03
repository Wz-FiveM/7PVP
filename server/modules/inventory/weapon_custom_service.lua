---Custom des armes (Config.WeaponCustom) : une par joueur et par modèle d'arme, gardée en base.
---L'essai se fait côté client sur un modèle local ; le serveur vérifie qu'on est chez le customiseur,
---qu'on porte l'arme, et nettoie ce qu'il reçoit. Le client reçoit ses customs à la connexion et les
---pose sur les armes de son personnage (voir Loadout.apply).
---Les accessoires se débloquent en tuant des zombies avec l'arme (Config.WeaponCustom.unlocks) : un
---compteur par joueur et par modèle, écrit en base par lots.
---@class WeaponCustomServiceModule
local WeaponCustomService = PVP.define('WeaponCustomService')
local PlayerService = PVP.use('PlayerService')
local SafeNpcs = PVP.use('SafeNpcs')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Items = PVP.use('Items')
local Locale = PVP.use('Locale')
local Logger = PVP.use('Logger')
local Utils = PVP.use('Utils')

WeaponCustomService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_weapon_customs (
    identifier VARCHAR(64) NOT NULL,
    weapon VARCHAR(64) NOT NULL,
    data TEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, weapon)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

WeaponCustomService.KILLS_SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_weapon_kills (
    identifier VARCHAR(64) NOT NULL,
    weapon VARCHAR(64) NOT NULL,
    kills INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (identifier, weapon)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

-- Dernière teinte des armes Mk II
WeaponCustomService.MAX_TINT = 31
-- Les zombies tués partent en base toutes les 30 s (et à la déconnexion)
WeaponCustomService.FLUSH_INTERVAL = 30000

---@type table<string, table<string, { tint: integer, finish: string|nil, attachments: string[] }>> identifiant du joueur -> arme -> custom
WeaponCustomService.saved = {}
---@type table<string, table<string, integer>> identifiant du joueur -> arme -> zombies tués avec
WeaponCustomService.kills = {}
---@type table<string, table<string, integer>> zombies tués pas encore écrits en base
WeaponCustomService.pending = {}
---@type table<string, integer> accessoire -> zombies à tuer pour le débloquer
WeaponCustomService.thresholds = {}
---@type table<integer, string> hash d'arme non signé -> objet de l'arme
WeaponCustomService.byHash = {}

function WeaponCustomService.init()
    for _, unlock in ipairs(Config.WeaponCustom.unlocks) do
        WeaponCustomService.thresholds[unlock.attachment] = unlock.kills
    end
    for name, item in pairs(Config.Items) do
        if item.type == 'weapon' then WeaponCustomService.byHash[GetHashKey(item.weapon) & 0xFFFFFFFF] = name end
    end

    Callback.register(Events.callbacks.weaponCustomOpen, WeaponCustomService.openCallback)
    Callback.register(Events.callbacks.weaponCustomSave, WeaponCustomService.saveCallback)

    AddEventHandler(Events.internal.playerLoaded, function(playerSource)
        WeaponCustomService.loadPlayer(playerSource)
        local player = PlayerService.get(playerSource)
        if player then WeaponCustomService.refundLegacy(player) end
    end)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        local player = PlayerService.get(playerSource)
        if not player then return end
        WeaponCustomService.flush(player.identifier)
        WeaponCustomService.saved[player.identifier] = nil
        WeaponCustomService.kills[player.identifier] = nil
    end)
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then WeaponCustomService.flushAll() end
    end)

    MySQL.ready(WeaponCustomService.load)
    CreateThread(WeaponCustomService.flushLoop)
end

function WeaponCustomService.load()
    MySQL.query.await(WeaponCustomService.SCHEMA)
    MySQL.query.await(WeaponCustomService.KILLS_SCHEMA)
    -- Joueurs arrivés avant la fin du chargement (redémarrage de la ressource)
    for _, player in pairs(PlayerService.all()) do
        WeaponCustomService.loadPlayer(player.source)
    end
end

---@param source integer
function WeaponCustomService.loadPlayer(source)
    local player = PlayerService.get(source)
    if not player then return end
    local identifier = player.identifier
    MySQL.query('SELECT weapon, data FROM pvp_weapon_customs WHERE identifier = ?', { identifier }, function(rows)
        local customs = {}
        for _, row in ipairs(rows or {}) do
            local ok, data = pcall(json.decode, row.data)
            local clean = ok and WeaponCustomService.sanitize(row.weapon, data)
            if clean then customs[row.weapon] = clean end
        end
        WeaponCustomService.saved[identifier] = customs
        if PlayerService.get(source) then TriggerClientEvent(Events.client.weaponCustoms, source, customs) end
    end)
    MySQL.query('SELECT weapon, kills FROM pvp_weapon_kills WHERE identifier = ?', { identifier }, function(rows)
        local kills = {}
        for _, row in ipairs(rows or {}) do kills[row.weapon] = tonumber(row.kills) or 0 end
        -- Zombies tués pendant la lecture : pas encore en base, déjà comptés ici
        for weapon, count in pairs(WeaponCustomService.pending[identifier] or {}) do
            kills[weapon] = (kills[weapon] or 0) + count
        end
        if PlayerService.get(source) then WeaponCustomService.kills[identifier] = kills end
    end)
end

---Nettoie une custom. Les accessoires doivent aller sur l'arme ; leur palier n'est vérifié qu'à l'enregistrement
---(un compteur ne baisse jamais).
---@param weapon any objet de l'arme
---@param data any
---@return { tint: integer, finish: string|nil, attachments: string[] }|nil
function WeaponCustomService.sanitize(weapon, data)
    local item = type(weapon) == 'string' and Config.Items[weapon]
    if not item or item.type ~= 'weapon' or type(data) ~= 'table' then return nil end
    local tint = tonumber(data.tint) or 0
    if tint ~= math.floor(tint) or tint < 0 or tint > WeaponCustomService.MAX_TINT then return nil end
    local clean = { tint = math.floor(tint), attachments = {} }
    for _, finish in ipairs(Config.WeaponCustom.finishes[weapon] or {}) do
        if finish.component == data.finish then clean.finish = finish.component end
    end
    local wanted = {}
    for _, attachment in ipairs(type(data.attachments) == 'table' and data.attachments or {}) do
        if type(attachment) == 'string' then wanted[attachment] = true end
    end
    for _, unlock in ipairs(Config.WeaponCustom.unlocks) do
        local compatible = Config.Attachments[unlock.attachment]
        if wanted[unlock.attachment] and compatible and compatible[weapon] then
            clean.attachments[#clean.attachments + 1] = unlock.attachment
        end
    end
    return clean
end

---@param identifier string
---@param weapon string
---@return integer zombies tués avec ce modèle
function WeaponCustomService.killsOf(identifier, weapon)
    local kills = WeaponCustomService.kills[identifier]
    return kills and kills[weapon] or 0
end

---@param identifier string
---@param weapon string
---@param attachment string
---@return boolean
function WeaponCustomService.isUnlocked(identifier, weapon, attachment)
    local threshold = WeaponCustomService.thresholds[attachment]
    return threshold ~= nil and WeaponCustomService.killsOf(identifier, weapon) >= threshold
end

-- ---------------------------------------------------------------------------
-- Zombies tués
-- ---------------------------------------------------------------------------

---Zombie tué par ce joueur (CombatService.rewardNpcKill) : compte pour l'arme qu'il tient.
---@param killer PvpPlayer
function WeaponCustomService.onZombieKill(killer)
    local ped = GetPlayerPed(killer.source)
    if ped == 0 then return end
    local weapon = WeaponCustomService.byHash[GetSelectedPedWeapon(ped) & 0xFFFFFFFF]
    if not weapon then return end

    local identifier = killer.identifier
    local pending = WeaponCustomService.pending[identifier] or {}
    WeaponCustomService.pending[identifier] = pending
    pending[weapon] = (pending[weapon] or 0) + 1

    local kills = WeaponCustomService.kills[identifier]
    if not kills then return end
    local count = (kills[weapon] or 0) + 1
    kills[weapon] = count
    for _, unlock in ipairs(Config.WeaponCustom.unlocks) do
        local compatible = Config.Attachments[unlock.attachment]
        if unlock.kills == count and compatible and compatible[weapon] then
            killer:notify(Locale.t('Accessoire débloqué sur %s : %s. À poser chez le customiseur.',
                Locale.t(Items.label(weapon)), Locale.t(Items.label(unlock.attachment))), 'success')
        end
    end
end

function WeaponCustomService.flushLoop()
    while true do
        Wait(WeaponCustomService.FLUSH_INTERVAL)
        WeaponCustomService.flushAll()
    end
end

function WeaponCustomService.flushAll()
    for identifier in pairs(WeaponCustomService.pending) do
        WeaponCustomService.flush(identifier)
    end
end

---@param identifier string
function WeaponCustomService.flush(identifier)
    local pending = WeaponCustomService.pending[identifier]
    WeaponCustomService.pending[identifier] = nil
    for weapon, count in pairs(pending or {}) do
        MySQL.insert(
            'INSERT INTO pvp_weapon_kills (identifier, weapon, kills) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE kills = kills + VALUES(kills)',
            { identifier, weapon, count }
        )
    end
end

-- ---------------------------------------------------------------------------
-- Anciens accessoires en objets
-- ---------------------------------------------------------------------------

---Rachète les accessoires du temps où c'étaient des objets : sac, conteneur protégé, coffres et ceux fixés
---sur une arme. L'argent va dans le coffre 1, qu'on ne perd pas à la mort.
---@param player PvpPlayer
function WeaponCustomService.refundLegacy(player)
    local inventory = player.inventory
    local refund = Config.WeaponCustom.refund
    local total, refunded = 0, {}
    for _, list in pairs(inventory.legacyAttachments) do
        for attachment in pairs(list) do
            refunded[attachment] = (refunded[attachment] or 0) + 1
        end
    end
    inventory.legacyAttachments = {}
    for id in pairs(Config.Containers) do
        for name, count in pairs(Utils.shallowCopy(inventory[id])) do
            if Items.isType(name, 'attachment') then
                inventory:removeFrom(id, name, count)
                refunded[name] = (refunded[name] or 0) + count
            end
        end
    end
    for attachment, count in pairs(refunded) do
        total = total + count * (refund[attachment] or 0)
    end
    if next(refunded) == nil then return end

    if total > 0 then inventory:add('stash', 'money', total) end
    inventory:pruneShortcuts()
    Logger.info('[custom arme] %s : accessoires rachetés (%s) pour $%d', player.name, Items.describe(refunded), total)
    player:notify(Locale.t('Les accessoires se débloquent maintenant en tuant des zombies : les tiens ont été rachetés $%d, versés dans ton coffre.', total), 'info')
end

-- ---------------------------------------------------------------------------
-- Menu du customiseur
-- ---------------------------------------------------------------------------

---@param source integer
---@return PvpPlayer|nil joueur, table|nil refus { ok = false, message }
function WeaponCustomService.check(source)
    local player = PlayerService.get(source)
    if not player or player.dead then return nil, { ok = false } end
    if player.mode ~= 'pvp' then
        return nil, { ok = false, message = Locale.t('Disponible en mode PvP.') }
    end
    if not SafeNpcs.isNear(player:getCoords(), Config.WeaponCustom.role) then
        return nil, { ok = false, message = SafeNpcs.hint(Config.WeaponCustom.role) }
    end
    return player
end

---@param source integer
---@return { ok: boolean, message?: string, kills?: table<string, integer> }
function WeaponCustomService.openCallback(source)
    local player, refusal = WeaponCustomService.check(source)
    if not player then return refusal end
    return { ok = true, kills = WeaponCustomService.kills[player.identifier] or {} }
end

---Enregistre les armes modifiées dans le menu. Tout ou rien : une arme refusée n'en enregistre aucune.
---@param source integer
---@param data any arme -> { tint, finish, attachments }
---@return { ok: boolean, message?: string }
function WeaponCustomService.saveCallback(source, data)
    local player, refusal = WeaponCustomService.check(source)
    if not player then return refusal end
    if type(data) ~= 'table' then return { ok = false, message = Locale.t('Données invalides.') } end

    local clean = {}
    for weapon, custom in pairs(data) do
        clean[weapon] = WeaponCustomService.sanitize(weapon, custom)
        if not clean[weapon] then return { ok = false, message = Locale.t('Données invalides.') } end
        if player.inventory:countIn('bag', weapon) <= 0 then
            return { ok = false, message = Locale.t('Tu ne portes plus cette arme.') }
        end
        for _, attachment in ipairs(clean[weapon].attachments) do
            if not WeaponCustomService.isUnlocked(player.identifier, weapon, attachment) then
                return { ok = false, message = Locale.t('Accessoire pas encore débloqué sur cette arme.') }
            end
        end
    end

    local customs = WeaponCustomService.saved[player.identifier] or {}
    WeaponCustomService.saved[player.identifier] = customs
    for weapon, custom in pairs(clean) do
        customs[weapon] = custom
        MySQL.insert(
            'INSERT INTO pvp_weapon_customs (identifier, weapon, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
            { player.identifier, weapon, json.encode(custom) }
        )
    end
    TriggerClientEvent(Events.client.weaponCustoms, source, customs)
    return { ok = true, message = Locale.t('Custom enregistrée : tes prochaines armes de ce modèle seront comme ça.') }
end
