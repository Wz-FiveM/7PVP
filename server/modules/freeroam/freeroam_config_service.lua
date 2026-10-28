---Véhicules du Freeroam modifiables en jeu (panneau admin F10, onglet « Freeroam ») : véhicules
---proposés au vote de la course poursuite, véhicules du menu Freeroam (Tab) et véhicule du convoi CVC.
---Les changements s'appliquent tout de suite et sont enregistrés en base (pvp_freeroam_settings) :
---ils remplacent config/chase.lua, config/freeroam.lua et config/cvc.lua au démarrage.
---« Valeurs par défaut » revient au fichier.
---@class FreeroamConfigServiceModule
local FreeroamConfigService = PVP.define('FreeroamConfigService')
local AdminService = PVP.use('AdminService')
local ChaseService = PVP.use('ChaseService')
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

-- Réglages modifiables, dans l'ordre du panneau.
--  path     : emplacement dans Config (Config[path[1]][path[2]])
--  list     : liste de véhicules { model, label (, category) } ; sinon un seul modèle
--  category : chaque véhicule a une catégorie (onglets du menu Freeroam)
--  sync     : lu par les clients (renvoyé à tous à chaque changement)
FreeroamConfigService.SETTINGS = {
    {
        name = 'chaseVehicles',
        label = 'Course poursuite',
        hint = 'Véhicules proposés au vote avant chaque partie (image : web/public/items/<modèle>.png).',
        path = { 'Chase', 'vehicles' },
        list = true,
    },
    {
        name = 'menuVehicles',
        label = 'Menu Freeroam',
        hint = 'Véhicules gratuits du menu (Tab), rangés par catégorie.',
        path = { 'Freeroam', 'vehicles' },
        list = true,
        category = true,
        sync = true,
    },
    {
        name = 'cvcVehicle',
        label = 'CVC',
        hint = 'Véhicule du convoi de chaque équipe.',
        path = { 'Cvc', 'vehicle' },
    },
}

FreeroamConfigService.MAX_VEHICLES = 40
FreeroamConfigService.MAX_MODEL = 32
FreeroamConfigService.MAX_LABEL = 40
FreeroamConfigService.DEFAULT_CATEGORY = 'Autres'

---@type table<string, any> valeurs des fichiers de config au démarrage (« valeurs par défaut »)
FreeroamConfigService.defaults = {}
---@type table<string, boolean> réglages modifiés depuis le panneau
FreeroamConfigService.modified = {}

function FreeroamConfigService.init()
    for _, setting in ipairs(FreeroamConfigService.SETTINGS) do
        FreeroamConfigService.defaults[setting.name] = json.decode(json.encode({ FreeroamConfigService.get(setting) }))[1]
    end

    Callback.register(Events.callbacks.adminFreeroam, FreeroamConfigService.getCallback)
    Callback.register(Events.callbacks.adminFreeroamSave, FreeroamConfigService.saveCallback)
    Callback.register(Events.callbacks.adminFreeroamReset, FreeroamConfigService.resetCallback)

    -- Les clients lisent la liste du menu Freeroam dans leur config : on leur envoie la version modifiée
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
            FreeroamConfigService.set(setting, clean)
            FreeroamConfigService.modified[setting.name] = true
        end
    end
    if #rows > 0 then
        Logger.info('[freeroam] %d réglage(s) chargé(s) depuis la base', #rows)
        FreeroamConfigService.sendSynced(-1)
    end
end

-- ---------------------------------------------------------------------------
-- Réglages
-- ---------------------------------------------------------------------------

---@param name any
---@return table|nil
function FreeroamConfigService.find(name)
    for _, setting in ipairs(FreeroamConfigService.SETTINGS) do
        if setting.name == name then return setting end
    end
    return nil
end

---@param setting table
---@return any
function FreeroamConfigService.get(setting)
    return Config[setting.path[1]][setting.path[2]]
end

---@param setting table
---@param value any
function FreeroamConfigService.set(setting, value)
    Config[setting.path[1]][setting.path[2]] = value
    if setting.sync then FreeroamConfigService.sendSynced(-1) end
end

---Réglages lus par les clients (liste du menu Freeroam), seulement s'ils ont été modifiés.
---@param target integer joueur, -1 = tout le monde
function FreeroamConfigService.sendSynced(target)
    if FreeroamConfigService.modified.menuVehicles then
        TriggerClientEvent(Events.client.freeroamVehicles, target, Config.Freeroam.vehicles)
    end
end

-- ---------------------------------------------------------------------------
-- Validation (l'existence du modèle est vérifiée par le client de l'admin, voir Admin.checkModels)
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

---Valeur propre, ou nil si les données sont inutilisables (liste vide, modèle invalide...).
---@param setting table
---@param data any
---@return any
function FreeroamConfigService.validate(setting, data)
    if not setting.list then return FreeroamConfigService.model(data) end
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
            label = setting.label,
            hint = setting.hint,
            kind = setting.list and 'list' or 'model',
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
        return { ok = false, message = setting.list and 'Liste invalide (au moins un véhicule, modèles valides).' or 'Modèle invalide.' }
    end

    FreeroamConfigService.modified[setting.name] = true
    FreeroamConfigService.set(setting, clean)
    MySQL.insert(
        'INSERT INTO pvp_freeroam_settings (name, data, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), updated_by = VALUES(updated_by)',
        { setting.name, json.encode(clean), GetPlayerName(source) or '' }
    )
    local detail = setting.list and ('%d véhicule(s)'):format(#clean) or clean
    FreeroamConfigService.log(source, ('véhicules « %s » : %s'):format(setting.label, detail))
    return { ok = true, message = ('Véhicules « %s » enregistrés.'):format(setting.label) }
end

---@param source integer
---@param name any
function FreeroamConfigService.resetCallback(source, name)
    if not FreeroamConfigService.allowed(source) then return { ok = false, message = 'Accès refusé.' } end
    local setting = FreeroamConfigService.find(name)
    if not setting then return { ok = false, message = 'Réglage inconnu.' } end

    -- Encore « modifié » pendant l'envoi : les clients reçoivent la liste par défaut
    FreeroamConfigService.set(setting, json.decode(json.encode({ FreeroamConfigService.defaults[setting.name] }))[1])
    FreeroamConfigService.modified[setting.name] = nil
    MySQL.update('DELETE FROM pvp_freeroam_settings WHERE name = ?', { setting.name })
    FreeroamConfigService.log(source, ('véhicules « %s » remis par défaut'):format(setting.label))
    return { ok = true, message = ('Véhicules « %s » remis par défaut.'):format(setting.label) }
end

---@param source integer
---@param message string
function FreeroamConfigService.log(source, message)
    Logger.info('[admin] %s : freeroam, %s', GetPlayerName(source), message)
    DiscordService.adminAction(source, 'freeroamConfig', nil, {}, message)
end
