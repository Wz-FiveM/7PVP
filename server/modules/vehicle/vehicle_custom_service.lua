---Custom des véhicules (Config.VehicleCustom) : une par joueur et par modèle, gardée en base.
---Le client affiche l'essai ; le serveur vérifie qu'on est au volant de son véhicule, chez le mécanicien,
---et nettoie ce qu'il reçoit. VehicleService la joint à chaque sortie du modèle.
---@class VehicleCustomServiceModule
local VehicleCustomService = PVP.define('VehicleCustomService')
local PlayerService = PVP.use('PlayerService')
local VehicleService = PVP.use('VehicleService')
local SafeNpcs = PVP.use('SafeNpcs')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

VehicleCustomService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_vehicle_customs (
    identifier VARCHAR(64) NOT NULL,
    model VARCHAR(32) NOT NULL,
    data TEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, model)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

-- Champs entiers d'une custom : bornes de GTA
VehicleCustomService.INT_FIELDS = {
    primary = { 0, 160 },
    secondary = { 0, 160 },
    pearl = { 0, 160 },
    wheelColor = { 0, 160 },
    tint = { -1, 6 },
    plate = { 0, 5 },
    livery = { -1, 64 },
    wheelType = { -1, 12 },
    xenonColor = { 0, 255 },
}
VehicleCustomService.MAX_MOD_INDEX = 255

---@type table<string, table<string, table>> identifiant du joueur -> modèle -> custom
VehicleCustomService.saved = {}
---@type table<string, boolean> pièces autorisées (type de modification GTA, en texte)
VehicleCustomService.allowedMods = {}

function VehicleCustomService.init()
    for _, mod in ipairs(Config.VehicleCustom.mods) do
        if mod.tab ~= 'performance' or Config.VehicleCustom.performance then
            VehicleCustomService.allowedMods[tostring(mod.id)] = true
        end
    end

    Callback.register(Events.callbacks.vehicleCustomOpen, VehicleCustomService.openCallback)
    Callback.register(Events.callbacks.vehicleCustomSave, VehicleCustomService.saveCallback)

    AddEventHandler(Events.internal.playerLoaded, function(playerSource)
        VehicleCustomService.loadPlayer(playerSource)
    end)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        local player = PlayerService.get(playerSource)
        if player then VehicleCustomService.saved[player.identifier] = nil end
    end)

    MySQL.ready(VehicleCustomService.load)
end

function VehicleCustomService.load()
    MySQL.query.await(VehicleCustomService.SCHEMA)
    -- Joueurs arrivés avant la fin du chargement (redémarrage de la ressource)
    for _, player in pairs(PlayerService.all()) do
        VehicleCustomService.loadPlayer(player.source)
    end
end

---@param source integer
function VehicleCustomService.loadPlayer(source)
    local player = PlayerService.get(source)
    if not player then return end
    local identifier = player.identifier
    MySQL.query('SELECT model, data FROM pvp_vehicle_customs WHERE identifier = ?', { identifier }, function(rows)
        local customs = {}
        for _, row in ipairs(rows or {}) do
            local ok, data = pcall(json.decode, row.data)
            local clean = ok and VehicleCustomService.sanitize(data)
            if clean then customs[row.model] = clean end
        end
        VehicleCustomService.saved[identifier] = customs
    end)
end

---@param player PvpPlayer
---@param model string
---@return table|nil custom du joueur pour ce modèle
function VehicleCustomService.get(player, model)
    local customs = VehicleCustomService.saved[player.identifier]
    return customs and customs[model] or nil
end

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------

---@param value any
---@param min integer
---@param max integer
---@return integer|nil entier dans [min, max]
function VehicleCustomService.int(value, min, max)
    value = tonumber(value)
    if not value or value ~= math.floor(value) or value < min or value > max then return nil end
    return math.floor(value)
end

---Ne garde que ce qu'une custom peut contenir, dans les bornes de GTA. Sert aussi à la lecture en base :
---passer Config.VehicleCustom.performance à false retire les performances déjà enregistrées.
---@param data any
---@return table|nil
function VehicleCustomService.sanitize(data)
    if type(data) ~= 'table' then return nil end
    local clean = { mods = {} }
    for field, range in pairs(VehicleCustomService.INT_FIELDS) do
        clean[field] = VehicleCustomService.int(data[field], range[1], range[2])
    end
    clean.neon = data.neon == true
    clean.xenon = data.xenon == true
    clean.turbo = Config.VehicleCustom.performance and data.turbo == true
    if type(data.neonColor) == 'string' and data.neonColor:match('^#%x%x%x%x%x%x$') then
        clean.neonColor = data.neonColor
    end
    if type(data.mods) == 'table' then
        for id, index in pairs(data.mods) do
            local key = tostring(id)
            local value = VehicleCustomService.allowedMods[key] and VehicleCustomService.int(index, -1, VehicleCustomService.MAX_MOD_INDEX)
            -- -1 : pièce d'origine, comme un véhicule neuf
            if value and value >= 0 then clean.mods[key] = value end
        end
    end
    return clean
end

-- ---------------------------------------------------------------------------
-- Chez le mécanicien
-- ---------------------------------------------------------------------------

---@param source integer
---@return string|nil modèle du véhicule à customiser, table|nil refus { ok = false, message }
function VehicleCustomService.check(source)
    local player = PlayerService.get(source)
    if not player or player.dead then return nil, { ok = false } end
    if player.mode ~= 'pvp' then
        return nil, { ok = false, message = Locale.t('Véhicules disponibles en mode PvP.') }
    end
    local ped = player:getPed()
    local entity = GetVehiclePedIsIn(ped, false)
    if entity == 0 or GetPedInVehicleSeat(entity, -1) ~= ped then
        return nil, { ok = false, message = Locale.t('Mets-toi au volant de ton véhicule.') }
    end
    if not SafeNpcs.isNear(player:getCoords(), Config.VehicleCustom.role, Config.VehicleCustom.serverDistance) then
        return nil, { ok = false, message = SafeNpcs.hint(Config.VehicleCustom.role) }
    end
    if VehicleService.ownerOf(entity) ~= source then
        return nil, { ok = false, message = Locale.t('Ce véhicule n\'est pas à toi : range-le pour le récupérer (K), puis ressors-le.') }
    end
    return Items.get(VehicleService.active[source].item).model
end

---@param source integer
---@return { ok: boolean, message?: string, label?: string }
function VehicleCustomService.openCallback(source)
    local model, refusal = VehicleCustomService.check(source)
    if not model then return refusal end
    return { ok = true, label = Items.label(VehicleService.active[source].item) }
end

---@param source integer
---@param data any
---@return { ok: boolean, message?: string }
function VehicleCustomService.saveCallback(source, data)
    local model, refusal = VehicleCustomService.check(source)
    if not model then return refusal end
    local clean = VehicleCustomService.sanitize(data)
    if not clean then return { ok = false, message = Locale.t('Données invalides.') } end

    local player = PlayerService.get(source)
    local customs = VehicleCustomService.saved[player.identifier] or {}
    VehicleCustomService.saved[player.identifier] = customs
    customs[model] = clean
    MySQL.insert(
        'INSERT INTO pvp_vehicle_customs (identifier, model, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
        { player.identifier, model, json.encode(clean) }
    )
    return {
        ok = true,
        message = Locale.t('Custom enregistrée : toutes tes prochaines %s seront comme ça.', Locale.t(Items.label(VehicleService.active[source].item))),
    }
end
