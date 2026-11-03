---Poids des objets (Config.Items[...].weight).
---Ils se modifient en jeu (panneau admin F10, onglet « Poids ») : ils s'appliquent tout de suite aux
---sacs, coffres et achats, et ceux qui diffèrent de la valeur par défaut sont enregistrés en base
---(pvp_item_weights). Un sac devenu trop lourd garde ses objets : il ne peut seulement plus rien recevoir.
---@class WeightServiceModule
local WeightService = PVP.define('WeightService')
local AdminService = PVP.use('AdminService')
local DiscordService = PVP.use('DiscordService')
local CaseConfigService = PVP.use('CaseConfigService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

WeightService.MAX_WEIGHT = 100.0 -- kg par unité, accepté dans le panneau
WeightService.LOG_LIMIT = 5 -- poids cités dans le journal d'une modification

WeightService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_item_weights (
    item VARCHAR(64) NOT NULL,
    weight DECIMAL(8,3) NOT NULL,
    updated_by VARCHAR(64) NOT NULL DEFAULT '',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (item)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

---@type table<string, number> objet -> poids de la config (relevé avant toute modification)
WeightService.defaults = {}

function WeightService.init()
    Callback.register(Events.callbacks.adminWeights, WeightService.getCallback)
    Callback.register(Events.callbacks.adminWeightsSave, WeightService.saveCallback)
    Callback.register(Events.callbacks.adminWeightsReset, WeightService.resetCallback)

    AddEventHandler(Events.internal.playerLoaded, function(playerSource)
        WeightService.sendWeights(playerSource)
    end)

    CreateThread(WeightService.load)
end

---Applique ce qui a été enregistré depuis le panneau, une fois les caisses du panneau créées (ce sont des objets).
function WeightService.load()
    MySQL.query.await(WeightService.SCHEMA)
    CaseConfigService.awaitLoaded()
    local rows = MySQL.query.await('SELECT item, weight FROM pvp_item_weights') or {}
    local applied = 0
    for _, row in ipairs(rows) do
        local weight = WeightService.validWeight(row.item, row.weight)
        if weight then
            WeightService.set(row.item, weight)
            applied = applied + 1
        end
    end
    if applied > 0 then
        Logger.info('[poids] %d poids chargé(s) depuis la base', applied)
        WeightService.sendWeights(-1)
    end
end

---@param name string
---@return number poids de la config
function WeightService.defaultOf(name)
    if WeightService.defaults[name] == nil then WeightService.defaults[name] = Config.Items[name].weight end
    return WeightService.defaults[name]
end

---@param name string
---@param weight number
function WeightService.set(name, weight)
    WeightService.defaultOf(name)
    Config.Items[name].weight = weight
end

---@param name any
---@param value any
---@return number|nil poids borné au gramme, nil pour un objet inconnu, l'argent ou une valeur invalide
function WeightService.validWeight(name, value)
    if not Items.exists(name) or name == 'money' then return nil end
    local weight = tonumber(value)
    if not weight or weight ~= weight or weight < 0 then return nil end
    return math.floor(math.min(WeightService.MAX_WEIGHT, weight) * 1000 + 0.5) / 1000
end

---@param target integer joueur, -1 = tout le monde
function WeightService.sendWeights(target)
    local weights = {}
    for name, item in pairs(Config.Items) do weights[name] = item.weight end
    TriggerClientEvent(Events.client.itemWeights, target, weights)
end

-- ---------------------------------------------------------------------------
-- Panneau admin
-- ---------------------------------------------------------------------------

---@param source integer
---@return boolean
function WeightService.allowed(source)
    if AdminService.isAdmin(source) then return true end
    DiscordService.adminDenied(source)
    return false
end

---Tous les objets sauf l'argent, avec leur poids actuel et celui de la config.
---@param source integer
function WeightService.getCallback(source)
    if not WeightService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end

    local items = {}
    for name, item in pairs(Config.Items) do
        if name ~= 'money' then
            items[#items + 1] = {
                name = name,
                label = item.label,
                type = item.type,
                weight = item.weight,
                default = WeightService.defaultOf(name),
            }
        end
    end
    table.sort(items, function(a, b) return a.label < b.label end)
    return { ok = true, items = items, maxWeight = WeightService.MAX_WEIGHT }
end

---@param source integer
---@param data any objet -> poids en kg
function WeightService.saveCallback(source, data)
    if not WeightService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end
    if type(data) ~= 'table' then return { ok = false, message = Locale.t('Données invalides.') } end

    local changes = {}
    for name, value in pairs(data) do
        local weight = WeightService.validWeight(name, value)
        if weight and weight ~= Config.Items[name].weight then
            changes[#changes + 1] = ('%s %g → %g kg'):format(Items.label(name), Config.Items[name].weight, weight)
            WeightService.set(name, weight)
            WeightService.store(source, name, weight)
        end
    end
    if #changes == 0 then return { ok = false, message = Locale.t('Aucun poids à enregistrer.') } end

    WeightService.sendWeights(-1)
    table.sort(changes)
    local shown = table.concat(changes, ', ', 1, math.min(#changes, WeightService.LOG_LIMIT))
    WeightService.log(source, ('%d poids : %s'):format(#changes, shown))
    return { ok = true, message = Locale.t('Poids enregistrés : %d', #changes) }
end

---@param source integer
function WeightService.resetCallback(source)
    if not WeightService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end

    for name, weight in pairs(WeightService.defaults) do
        if Config.Items[name] then Config.Items[name].weight = weight end
    end
    MySQL.update('DELETE FROM pvp_item_weights')
    WeightService.sendWeights(-1)
    WeightService.log(source, 'tous les poids remis par défaut')
    return { ok = true, message = Locale.t('Poids remis par défaut.') }
end

---@param source integer
---@param name string
---@param weight number
function WeightService.store(source, name, weight)
    if weight == WeightService.defaultOf(name) then
        MySQL.update('DELETE FROM pvp_item_weights WHERE item = ?', { name })
        return
    end
    MySQL.insert(
        'INSERT INTO pvp_item_weights (item, weight, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE weight = VALUES(weight), updated_by = VALUES(updated_by)',
        { name, weight, GetPlayerName(source) or '' }
    )
end

---@param source integer
---@param message string
function WeightService.log(source, message)
    Logger.info('[admin] %s : poids, %s', GetPlayerName(source), message)
    DiscordService.adminAction(source, 'weightConfig', nil, {}, message)
end
