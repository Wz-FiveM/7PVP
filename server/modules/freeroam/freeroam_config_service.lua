---Réglages du Freeroam modifiables en jeu (panneau admin F10, onglet « Freeroam ») :
---  véhicules : vote de la course poursuite, menu Freeroam (Tab), convoi du CVC, moto du 1VS1 Bike ;
---  positions : PNJ des modes de jeu (et tableau du classement), départs de la course poursuite,
---              points de départ des équipes du CVC dans chaque arène, des deux joueurs des 1VS1,
---              points d'apparition du Gungame.
---Les changements s'appliquent tout de suite et sont enregistrés en base (pvp_freeroam_settings) :
---ils remplacent les fichiers de config/ au démarrage. « Valeurs par défaut » revient au fichier.
---Chaque réglage passe par une valeur « simple » (tables et nombres, sans vecteurs) : c'est elle
---qui est validée, enregistrée en base, envoyée au panneau et aux clients.
---@class FreeroamConfigServiceModule
local FreeroamConfigService = PVP.define('FreeroamConfigService')
local AdminService = PVP.use('AdminService')
local ChaseService = PVP.use('ChaseService')
local FreeroamPositions = PVP.use('FreeroamPositions')
local Callback = PVP.use('Callback')
local DiscordService = PVP.use('DiscordService')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')

FreeroamConfigService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_freeroam_settings (
    name VARCHAR(32) NOT NULL,
    data LONGTEXT NOT NULL,
    updated_by VARCHAR(64) NOT NULL DEFAULT '',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

-- Sortes de réglages : méthodes de lecture, d'écriture et de validation de la valeur simple
FreeroamConfigService.KINDS = {
    vehicles = { get = 'getPath', set = 'setPath', validate = 'validateVehicles' }, -- { model, label (, category) }[]
    model = { get = 'getPath', set = 'setPath', validate = 'model' }, -- un modèle de véhicule
    points = { get = 'getPoints', set = 'setPoints', validate = 'validatePoints' }, -- { x, y, z, w }[]
    pair = { get = 'getPoints', set = 'setPoints', validate = 'validatePair' }, -- exactement deux { x, y, z, w }
    arenas = { get = 'getArenas', set = 'setArenas', validate = 'validateArenas' }, -- { label, spawns }[]
    places = { get = 'getPlaces', set = 'setPlaces', validate = 'validatePlaces' }, -- { key, label, coords }[]
}

-- Réglages modifiables, dans l'ordre du panneau.
--  group    : section du panneau ('vehicles' ou 'positions')
--  path     : emplacement dans Config (Config[path[1]][path[2]]), pour les sortes qui en ont besoin
--  category : chaque véhicule a une catégorie (onglets du menu Freeroam)
--  sync     : lu par les clients (renvoyé à tous à chaque changement)
FreeroamConfigService.SETTINGS = {
    {
        name = 'chaseVehicles',
        group = 'vehicles',
        kind = 'vehicles',
        label = 'Course poursuite',
        hint = 'Véhicules proposés au vote avant chaque partie (image : web/public/items/<modèle>.png).',
        path = { 'Chase', 'vehicles' },
    },
    {
        name = 'menuVehicles',
        group = 'vehicles',
        kind = 'vehicles',
        label = 'Menu Freeroam',
        hint = 'Véhicules gratuits du menu (Tab), rangés par catégorie.',
        path = { 'Freeroam', 'vehicles' },
        category = true,
        sync = true,
    },
    {
        name = 'cvcVehicle',
        group = 'vehicles',
        kind = 'model',
        label = 'CVC',
        hint = 'Véhicule du convoi de chaque équipe.',
        path = { 'Cvc', 'vehicle' },
    },
    {
        name = 'bikeVehicle',
        group = 'vehicles',
        kind = 'model',
        label = '1VS1 Bike',
        hint = 'Moto des deux joueurs, recréée à chaque manche.',
        path = { 'Bike', 'vehicle' },
    },
    {
        name = 'places',
        group = 'positions',
        kind = 'places',
        label = 'PNJ et tableau',
        hint = 'PNJ des modes de jeu et tableau du classement. Place-toi à l\'endroit voulu : le PNJ (ou l\'écran) regardera dans la même direction que toi. Les PNJ doivent rester dans la zone safe.',
        sync = true,
    },
    {
        name = 'chaseStarts',
        group = 'positions',
        kind = 'points',
        label = 'Départs course poursuite',
        hint = 'Un départ est tiré au sort à chaque manche : le voleur part ici, dans ta direction, le policier juste derrière. Choisis une route droite, en ville.',
        path = { 'Chase', 'starts' },
    },
    {
        name = 'cvcSpawns',
        group = 'positions',
        kind = 'arenas',
        label = 'Spawns CVC',
        hint = 'Départ de chaque équipe dans chaque arène : les véhicules sont alignés derrière ce point, tournés vers le centre de l\'arène.',
    },
    {
        name = 'gunfightSpawns',
        group = 'positions',
        kind = 'pair',
        label = 'Spawns 1VS1 GunFight',
        hint = 'Départ de chaque joueur (ils échangent de côté à chaque manche), dans ta direction : place-les face à face. La zone de combat est un cercle autour du milieu des deux points.',
        path = { 'Gunfight', 'spawns' },
    },
    {
        name = 'bikeSpawns',
        group = 'positions',
        kind = 'pair',
        label = 'Spawns 1VS1 Bike',
        hint = 'Départ de chaque moto (les joueurs échangent de côté à chaque manche), dans ta direction : place-les loin l\'un de l\'autre. La zone de combat est un cercle autour du milieu des deux points.',
        path = { 'Bike', 'spawns' },
    },
    {
        name = 'gungameSpawns',
        group = 'positions',
        kind = 'points',
        label = 'Spawns Gungame',
        hint = 'Points d\'apparition des joueurs, dans ta direction : on réapparaît sur celui le plus loin des autres. Répartis-les tout autour de l\'arène ; la zone de combat est un cercle autour de leur milieu.',
        path = { 'Gungame', 'spawns' },
    },
}

FreeroamConfigService.MAX_VEHICLES = 40
FreeroamConfigService.MAX_POINTS = 30
FreeroamConfigService.MAX_MODEL = 32
FreeroamConfigService.MAX_LABEL = 40
FreeroamConfigService.MAX_COORD = 10000.0 -- la carte tient dans ±10 km
FreeroamConfigService.DEFAULT_CATEGORY = 'Autres'

---@type table<string, any> valeurs simples des fichiers de config au démarrage (« valeurs par défaut »)
FreeroamConfigService.defaults = {}
---@type table<string, boolean> réglages modifiés depuis le panneau
FreeroamConfigService.modified = {}

function FreeroamConfigService.init()
    for _, setting in ipairs(FreeroamConfigService.SETTINGS) do
        FreeroamConfigService.defaults[setting.name] = FreeroamConfigService.copy(FreeroamConfigService.get(setting))
    end

    Callback.register(Events.callbacks.adminFreeroam, FreeroamConfigService.getCallback)
    Callback.register(Events.callbacks.adminFreeroamSave, FreeroamConfigService.saveCallback)
    Callback.register(Events.callbacks.adminFreeroamReset, FreeroamConfigService.resetCallback)

    -- Les clients lisent certains réglages dans leur config (menu Freeroam, PNJ) : on leur envoie ceux modifiés
    AddEventHandler(Events.internal.playerLoaded, function(playerSource)
        FreeroamConfigService.sendSynced(playerSource)
    end)

    CreateThread(FreeroamConfigService.load)
end

---Applique ce qui a été enregistré depuis le panneau.
function FreeroamConfigService.load()
    MySQL.query.await(FreeroamConfigService.SCHEMA)
    local rows = MySQL.query.await('SELECT name, data FROM pvp_freeroam_settings') or {}
    for _, row in ipairs(rows) do
        local setting = FreeroamConfigService.find(row.name)
        local ok, data = pcall(json.decode, row.data)
        local clean = setting and ok and FreeroamConfigService.validate(setting, data)
        if clean then
            FreeroamConfigService.modified[setting.name] = true
            FreeroamConfigService.set(setting, clean)
        end
    end
    if #rows > 0 then Logger.info('[freeroam] %d réglage(s) chargé(s) depuis la base', #rows) end
end

-- ---------------------------------------------------------------------------
-- Réglages
-- ---------------------------------------------------------------------------

---@param value any
---@return any copie profonde (tables et nombres)
function FreeroamConfigService.copy(value)
    return json.decode(json.encode({ value }))[1]
end

---@param name any
---@return table|nil
function FreeroamConfigService.find(name)
    for _, setting in ipairs(FreeroamConfigService.SETTINGS) do
        if setting.name == name then return setting end
    end
    return nil
end

---@param setting table
---@return any valeur simple actuelle
function FreeroamConfigService.get(setting)
    return FreeroamConfigService[FreeroamConfigService.KINDS[setting.kind].get](setting)
end

---@param setting table
---@param value any valeur simple déjà validée
function FreeroamConfigService.set(setting, value)
    FreeroamConfigService[FreeroamConfigService.KINDS[setting.kind].set](setting, value)
    if setting.sync then FreeroamConfigService.sendSynced(-1, setting) end
end

---@param setting table
---@param data any
---@return any valeur simple propre, ou nil si les données sont inutilisables
function FreeroamConfigService.validate(setting, data)
    return FreeroamConfigService[FreeroamConfigService.KINDS[setting.kind].validate](data, setting)
end

---Réglages lus par les clients, seulement s'ils ont été modifiés.
---@param target integer joueur, -1 = tout le monde
---@param only? table un seul réglage
function FreeroamConfigService.sendSynced(target, only)
    for _, setting in ipairs(FreeroamConfigService.SETTINGS) do
        if setting.sync and (not only or only == setting) and FreeroamConfigService.modified[setting.name] then
            TriggerClientEvent(Events.client.freeroamSettings, target, setting.name, FreeroamConfigService.get(setting))
        end
    end
end

-- Config[path] tel quel (véhicules, modèle) ------------------------------------------------

function FreeroamConfigService.getPath(setting)
    return Config[setting.path[1]][setting.path[2]]
end

function FreeroamConfigService.setPath(setting, value)
    Config[setting.path[1]][setting.path[2]] = value
end

-- Positions ------------------------------------------------------------------------------

---@param coords vector3|vector4
---@return { x: number, y: number, z: number, w: number }
function FreeroamConfigService.toPoint(coords)
    return { x = coords.x, y = coords.y, z = coords.z, w = coords.w or 0.0 }
end

---@param point table { x, y, z, w }
---@return vector4
function FreeroamConfigService.toVector(point)
    return vector4(point.x, point.y, point.z, point.w)
end

---Liste de vector4 dans Config[path] (départs de la course poursuite).
function FreeroamConfigService.getPoints(setting)
    local list = {}
    for _, coords in ipairs(FreeroamConfigService.getPath(setting)) do
        list[#list + 1] = FreeroamConfigService.toPoint(coords)
    end
    return list
end

function FreeroamConfigService.setPoints(setting, value)
    local list = {}
    for _, point in ipairs(value) do list[#list + 1] = FreeroamConfigService.toVector(point) end
    FreeroamConfigService.setPath(setting, list)
end

---Départs des deux équipes dans chaque arène du CVC.
function FreeroamConfigService.getArenas()
    local list = {}
    for _, arena in ipairs(Config.Cvc.arenas) do
        list[#list + 1] = {
            label = arena.label,
            spawns = { FreeroamConfigService.toPoint(arena.spawns[1]), FreeroamConfigService.toPoint(arena.spawns[2]) },
        }
    end
    return list
end

function FreeroamConfigService.setArenas(_, value)
    for index, arena in ipairs(Config.Cvc.arenas) do
        local spawns = value[index].spawns
        arena.spawns = {
            vector3(spawns[1].x, spawns[1].y, spawns[1].z),
            vector3(spawns[2].x, spawns[2].y, spawns[2].z),
        }
    end
end

---PNJ des modes de jeu et tableau du classement (voir FreeroamPositions).
function FreeroamConfigService.getPlaces()
    local list = {}
    for _, place in ipairs(FreeroamPositions.list()) do
        list[#list + 1] = { key = place.key, label = place.label, coords = FreeroamConfigService.toPoint(place.coords) }
    end
    return list
end

function FreeroamConfigService.setPlaces(_, value)
    for _, place in ipairs(value) do
        FreeroamPositions.set(place.key, FreeroamConfigService.toVector(place.coords))
    end
end

-- ---------------------------------------------------------------------------
-- Validation (l'existence d'un modèle est vérifiée par le client de l'admin, voir Admin.checkModels)
-- ---------------------------------------------------------------------------

---@param model any
---@return string|nil nom de modèle propre (minuscules, lettres, chiffres et _)
function FreeroamConfigService.model(model)
    if type(model) ~= 'string' then return nil end
    model = model:lower()
    if #model == 0 or #model > FreeroamConfigService.MAX_MODEL or model:find('[^%w_]') then return nil end
    return model
end

---@param text any
---@param fallback string
---@return string texte sans caractères de contrôle, coupé à MAX_LABEL caractères
function FreeroamConfigService.text(text, fallback)
    if type(text) ~= 'string' then return fallback end
    text = text:gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' or not utf8.len(text) then return fallback end
    if utf8.len(text) > FreeroamConfigService.MAX_LABEL then
        text = text:sub(1, utf8.offset(text, FreeroamConfigService.MAX_LABEL + 1) - 1)
    end
    return text
end

---@param data any
---@param setting table
---@return table[]|nil
function FreeroamConfigService.validateVehicles(data, setting)
    if type(data) ~= 'table' then return nil end
    local clean, seen = {}, {}
    for _, vehicle in ipairs(data) do
        local model = type(vehicle) == 'table' and FreeroamConfigService.model(vehicle.model)
        if not model then return nil end
        if not seen[model] then
            seen[model] = true
            local entry = { model = model, label = FreeroamConfigService.text(vehicle.label, model) }
            if setting.category then
                entry.category = FreeroamConfigService.text(vehicle.category, FreeroamConfigService.DEFAULT_CATEGORY)
            end
            clean[#clean + 1] = entry
        end
    end
    if #clean == 0 or #clean > FreeroamConfigService.MAX_VEHICLES then return nil end
    return clean
end

---@param value any
---@param max number
---@return number|nil nombre fini, arrondi au centième, dans [-max, max]
function FreeroamConfigService.number(value, max)
    value = tonumber(value)
    if not value or value ~= value or math.abs(value) > max then return nil end
    return math.floor(value * 100 + 0.5) / 100
end

---@param point any { x, y, z, w }
---@return table|nil
function FreeroamConfigService.point(point)
    if type(point) ~= 'table' then return nil end
    local max = FreeroamConfigService.MAX_COORD
    local x, y = FreeroamConfigService.number(point.x, max), FreeroamConfigService.number(point.y, max)
    local z = FreeroamConfigService.number(point.z, 3000.0)
    local w = FreeroamConfigService.number(point.w or 0, 100000.0)
    if not x or not y or not z or not w then return nil end
    return { x = x, y = y, z = z, w = w % 360.0 }
end

---@param data any
---@return table[]|nil
function FreeroamConfigService.validatePoints(data)
    if type(data) ~= 'table' then return nil end
    local clean = {}
    for _, point in ipairs(data) do
        local coords = FreeroamConfigService.point(point)
        if not coords then return nil end
        clean[#clean + 1] = coords
    end
    if #clean == 0 or #clean > FreeroamConfigService.MAX_POINTS then return nil end
    return clean
end

---Les deux départs du 1VS1 GunFight.
---@param data any
---@return table[]|nil
function FreeroamConfigService.validatePair(data)
    local clean = FreeroamConfigService.validatePoints(data)
    if not clean or #clean ~= 2 then return nil end
    return clean
end

---Une entrée par arène de config/cvc.lua (les arènes elles-mêmes ne changent pas), deux départs chacune.
---@param data any
---@return table[]|nil
function FreeroamConfigService.validateArenas(data)
    if type(data) ~= 'table' or #data ~= #Config.Cvc.arenas then return nil end
    local clean = {}
    for index, arena in ipairs(Config.Cvc.arenas) do
        local spawns = type(data[index]) == 'table' and data[index].spawns
        local first = type(spawns) == 'table' and FreeroamConfigService.point(spawns[1])
        local second = type(spawns) == 'table' and FreeroamConfigService.point(spawns[2])
        if not first or not second then return nil end
        clean[index] = { label = arena.label, spawns = { first, second } }
    end
    return clean
end

---Seulement les emplacements connus (FreeroamPositions.list) ; ceux qui manquent ne bougent pas.
---@param data any
---@return table[]|nil
function FreeroamConfigService.validatePlaces(data)
    if type(data) ~= 'table' then return nil end
    local known = {}
    for _, place in ipairs(FreeroamPositions.list()) do known[place.key] = place.label end
    local clean = {}
    for _, place in ipairs(data) do
        local key = type(place) == 'table' and place.key
        local coords = known[key] and FreeroamConfigService.point(place.coords)
        if coords then
            clean[#clean + 1] = { key = key, label = known[key], coords = coords }
            known[key] = nil
        end
    end
    if #clean == 0 then return nil end
    return clean
end

-- ---------------------------------------------------------------------------
-- Panneau admin
-- ---------------------------------------------------------------------------

---@param source integer
---@return boolean
function FreeroamConfigService.allowed(source)
    if AdminService.isAdmin(source) then return true end
    DiscordService.adminDenied(source)
    return false
end

---Tout ce que l'onglet affiche : réglages et courses poursuite en cours.
---@param source integer
function FreeroamConfigService.getCallback(source)
    if not FreeroamConfigService.allowed(source) then return { ok = false, message = 'Accès refusé.' } end

    local settings = {}
    for _, setting in ipairs(FreeroamConfigService.SETTINGS) do
        settings[#settings + 1] = {
            name = setting.name,
            group = setting.group,
            kind = setting.kind,
            label = setting.label,
            hint = setting.hint,
            category = setting.category == true,
            value = FreeroamConfigService.get(setting),
            modified = FreeroamConfigService.modified[setting.name] == true,
        }
    end
    return { ok = true, settings = settings, chases = ChaseService.describeMatches(), chaseQueue = #ChaseService.queue }
end

---@param source integer
---@param name any
---@param data any
function FreeroamConfigService.saveCallback(source, name, data)
    if not FreeroamConfigService.allowed(source) then return { ok = false, message = 'Accès refusé.' } end
    local setting = FreeroamConfigService.find(name)
    if not setting then return { ok = false, message = 'Réglage inconnu.' } end
    local clean = FreeroamConfigService.validate(setting, data)
    if not clean then
        return { ok = false, message = setting.kind == 'model' and 'Modèle invalide.' or 'Données invalides (liste vide ou valeur incorrecte).' }
    end

    FreeroamConfigService.modified[setting.name] = true
    FreeroamConfigService.set(setting, clean)
    MySQL.insert(
        'INSERT INTO pvp_freeroam_settings (name, data, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), updated_by = VALUES(updated_by)',
        { setting.name, json.encode(clean), GetPlayerName(source) or '' }
    )
    local detail = type(clean) == 'table' and ('%d élément(s)'):format(#clean) or clean
    FreeroamConfigService.log(source, ('« %s » : %s'):format(setting.label, detail))
    return { ok = true, message = ('« %s » enregistré.'):format(setting.label) }
end

---@param source integer
---@param name any
function FreeroamConfigService.resetCallback(source, name)
    if not FreeroamConfigService.allowed(source) then return { ok = false, message = 'Accès refusé.' } end
    local setting = FreeroamConfigService.find(name)
    if not setting then return { ok = false, message = 'Réglage inconnu.' } end

    -- Encore « modifié » pendant l'envoi : les clients reçoivent la valeur par défaut
    FreeroamConfigService.set(setting, FreeroamConfigService.copy(FreeroamConfigService.defaults[setting.name]))
    FreeroamConfigService.modified[setting.name] = nil
    MySQL.update('DELETE FROM pvp_freeroam_settings WHERE name = ?', { setting.name })
    FreeroamConfigService.log(source, ('« %s » remis par défaut'):format(setting.label))
    return { ok = true, message = ('« %s » remis par défaut.'):format(setting.label) }
end

---@param source integer
---@param message string
function FreeroamConfigService.log(source, message)
    Logger.info('[admin] %s : freeroam, %s', GetPlayerName(source), message)
    DiscordService.adminAction(source, 'freeroamConfig', nil, {}, message)
end
