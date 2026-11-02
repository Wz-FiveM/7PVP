---Custom des armes (Config.WeaponCustom) : une par joueur et par modèle d'arme, gardée en base.
---L'essai se fait côté client sur un modèle local ; le serveur vérifie qu'on est chez le customiseur,
---qu'on porte l'arme, et nettoie ce qu'il reçoit. Le client reçoit ses customs à la connexion et les
---pose sur les armes de son personnage (voir Loadout.apply).
---@class WeaponCustomServiceModule
local WeaponCustomService = PVP.define('WeaponCustomService')
local PlayerService = PVP.use('PlayerService')
local SafeNpcs = PVP.use('SafeNpcs')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

WeaponCustomService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_weapon_customs (
    identifier VARCHAR(64) NOT NULL,
    weapon VARCHAR(64) NOT NULL,
    data TEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, weapon)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

-- Dernière teinte des armes Mk II
WeaponCustomService.MAX_TINT = 31

---@type table<string, table<string, { tint: integer, finish: string|nil }>> identifiant du joueur -> arme -> custom
WeaponCustomService.saved = {}

function WeaponCustomService.init()
    Callback.register(Events.callbacks.weaponCustomOpen, WeaponCustomService.openCallback)
    Callback.register(Events.callbacks.weaponCustomSave, WeaponCustomService.saveCallback)

    AddEventHandler(Events.internal.playerLoaded, function(playerSource)
        WeaponCustomService.loadPlayer(playerSource)
    end)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        local player = PlayerService.get(playerSource)
        if player then WeaponCustomService.saved[player.identifier] = nil end
    end)

    MySQL.ready(WeaponCustomService.load)
end

function WeaponCustomService.load()
    MySQL.query.await(WeaponCustomService.SCHEMA)
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
end

---@param weapon any objet de l'arme
---@param data any
---@return { tint: integer, finish: string|nil }|nil
function WeaponCustomService.sanitize(weapon, data)
    local item = type(weapon) == 'string' and Config.Items[weapon]
    if not item or item.type ~= 'weapon' or type(data) ~= 'table' then return nil end
    local tint = tonumber(data.tint) or 0
    if tint ~= math.floor(tint) or tint < 0 or tint > WeaponCustomService.MAX_TINT then return nil end
    local clean = { tint = math.floor(tint) }
    for _, finish in ipairs(Config.WeaponCustom.finishes[weapon] or {}) do
        if finish.component == data.finish then clean.finish = finish.component end
    end
    return clean
end

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
---@return { ok: boolean, message?: string }
function WeaponCustomService.openCallback(source)
    local player, refusal = WeaponCustomService.check(source)
    if not player then return refusal end
    return { ok = true }
end

---Enregistre les armes modifiées dans le menu. Tout ou rien : une arme refusée n'en enregistre aucune.
---@param source integer
---@param data any arme -> { tint, finish }
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
