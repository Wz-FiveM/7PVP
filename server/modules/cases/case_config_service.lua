---Caisses modifiables en jeu (panneau admin F10, onglet « Caisses ») : création, nom, prix, niveau,
---récompenses et chances, retrait de la page. Une ligne de pvp_cases par caisse créée, modifiée ou
---retirée ; les caisses de config/cases.lua sans ligne restent telles que dans le fichier.
---Une caisse retirée n'est plus vendue ni ouverte en points, mais celles déjà possédées s'ouvrent
---encore : elle n'est jamais effacée, pour ne pas faire disparaître l'objet des inventaires.
---@class CaseConfigServiceModule
local CaseConfigService = PVP.define('CaseConfigService')
local CaseService = PVP.use('CaseService')
local AdminService = PVP.use('AdminService')
local ResaleService = PVP.use('ResaleService')
local DiscordService = PVP.use('DiscordService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Utils = PVP.use('Utils')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CaseConfigService.MAX_CASES = 30
CaseConfigService.MAX_REWARDS = 30
CaseConfigService.MAX_LABEL = 40
CaseConfigService.MAX_DESCRIPTION = 160
CaseConfigService.MAX_POINTS = 100000
CaseConfigService.MAX_LEVEL = 100
CaseConfigService.MAX_COUNT = 1000
CaseConfigService.MAX_MONEY = 1000000
CaseConfigService.MIN_WEIGHT = 0.01
CaseConfigService.MAX_WEIGHT = 10000
-- Attente maximale du chargement avant de lire un inventaire ou une table de butin
CaseConfigService.LOAD_TIMEOUT = 10000

CaseConfigService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_cases (
    id VARCHAR(64) NOT NULL,
    data TEXT NULL,
    removed TINYINT(1) NOT NULL DEFAULT 0,
    updated_by VARCHAR(64) NOT NULL DEFAULT '',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

---@type table<string, table> caisses de config/cases.lua, telles que dans le fichier
CaseConfigService.originals = {}
---@type string[] toutes les caisses dans l'ordre de la page, retirées comprises
CaseConfigService.order = {}
for _, case in ipairs(Config.Cases) do
    CaseConfigService.originals[case.id] = {
        label = case.label,
        description = case.description,
        price = case.price,
        points = case.points,
        level = case.level,
        rewards = case.rewards,
    }
    CaseConfigService.order[#CaseConfigService.order + 1] = case.id
end
---@type table<string, boolean> caisses de config/cases.lua modifiées depuis le panneau
CaseConfigService.modified = {}
CaseConfigService.loaded = false

function CaseConfigService.init()
    Callback.register(Events.callbacks.adminCases, CaseConfigService.getCallback)
    Callback.register(Events.callbacks.adminCaseSave, CaseConfigService.saveCallback)
    Callback.register(Events.callbacks.adminCaseRemove, CaseConfigService.removeCallback)
    Callback.register(Events.callbacks.adminCaseReset, CaseConfigService.resetCallback)

    -- Les clients lisent les caisses dans leur config (page Caisses, inventaire)
    AddEventHandler(Events.internal.playerLoaded, function(playerSource)
        CaseConfigService.send(playerSource)
    end)

    CreateThread(CaseConfigService.load)
end

---Applique ce qui a été enregistré depuis le panneau.
function CaseConfigService.load()
    MySQL.query.await(CaseConfigService.SCHEMA)
    local rows = MySQL.query.await('SELECT id, data, removed FROM pvp_cases ORDER BY created_at, id') or {}
    for _, row in ipairs(rows) do
        local fields
        if row.data then
            local ok, data = pcall(json.decode, row.data)
            fields = ok and CaseConfigService.clean(data) or nil
        end
        if fields and CaseConfigService.validId(row.id) then
            CaseConfigService.apply(row.id, fields)
        end
        local case = CaseService.byId[row.id]
        if case then case.removed = row.removed == 1 or row.removed == true end
    end
    CaseConfigService.rebuild()
    CaseConfigService.loaded = true
    if #rows > 0 then
        Logger.info('[caisses] %d caisse(s) chargée(s) depuis la base', #rows)
        CaseConfigService.send(-1)
    end
end

---Les caisses créées sont des objets : à attendre avant de lire un inventaire ou une table de butin,
---qui oublieraient un objet inconnu.
function CaseConfigService.awaitLoaded()
    local deadline = GetGameTimer() + CaseConfigService.LOAD_TIMEOUT
    while not CaseConfigService.loaded and GetGameTimer() < deadline do Wait(50) end
end

---@param id any
---@return boolean
function CaseConfigService.validId(id)
    return type(id) == 'string' and #id <= 64 and id:find('^case_[%w_]+$') ~= nil
end

---Crée la caisse si elle n'existe pas, sinon remplace son contenu.
---@param id string
---@param fields table champs propres (CaseConfigService.clean)
---@return table caisse
function CaseConfigService.apply(id, fields)
    local case = CaseService.byId[id]
    if not case then
        case = { id = id }
        CaseConfigService.order[#CaseConfigService.order + 1] = id
    end
    if CaseConfigService.originals[id] then CaseConfigService.modified[id] = true end
    case.label, case.description = fields.label, fields.description
    case.price, case.points, case.level = fields.price, fields.points, fields.level
    case.rewards = fields.rewards
    CaseService.prepare(case)
    return case
end

---Config.Cases (la page) = les caisses non retirées, dans l'ordre. Même table : les modules la relisent.
function CaseConfigService.rebuild()
    for index = #Config.Cases, 1, -1 do Config.Cases[index] = nil end
    for _, id in ipairs(CaseConfigService.order) do
        local case = CaseService.byId[id]
        if case and not case.removed then Config.Cases[#Config.Cases + 1] = case end
    end
end

---@param target integer joueur, -1 = tout le monde
function CaseConfigService.send(target)
    local items = {}
    for id in pairs(CaseService.byId) do items[id] = Config.Items[id] end
    TriggerClientEvent(Events.client.cases, target, Config.Cases, items)
end

---Caisses changées : les joueurs voient la page à jour, le receleur suit les nouveaux prix.
function CaseConfigService.applied()
    CaseConfigService.rebuild()
    ResaleService.refreshDefaults()
    CaseConfigService.send(-1)
end

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------

---@param text any
---@param max integer
---@return string texte sans retours à la ligne, coupé à `max` caractères ('' si invalide)
function CaseConfigService.text(text, max)
    if type(text) ~= 'string' then return '' end
    text = text:gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if not utf8.len(text) then return '' end
    if utf8.len(text) > max then text = text:sub(1, utf8.offset(text, max + 1) - 1) end
    return text
end

---@param value any
---@param max integer
---@return integer|nil nil si absent ou nul (pas en vente)
function CaseConfigService.optional(value, max)
    local number = Utils.toCount(value)
    if number < 1 then return nil end
    return math.min(max, number)
end

---@param reward any { item, count, weight, rarity }
---@return table|nil
function CaseConfigService.cleanReward(reward)
    if type(reward) ~= 'table' or type(reward.item) ~= 'string' then return nil end
    local item = Items.get(reward.item)
    if not item or item.type == 'attachment' then return nil end
    if type(reward.rarity) ~= 'string' or not Config.CaseRarities[reward.rarity] then return nil end

    local weight = tonumber(reward.weight)
    if not weight or weight ~= weight then return nil end
    weight = math.floor(math.max(CaseConfigService.MIN_WEIGHT, math.min(CaseConfigService.MAX_WEIGHT, weight)) * 100 + 0.5) / 100

    local max = reward.item == 'money' and CaseConfigService.MAX_MONEY or CaseConfigService.MAX_COUNT
    local range = type(reward.count) == 'table' and reward.count or { reward.count or 1, reward.count or 1 }
    local low = math.max(1, math.min(max, Utils.toCount(range[1])))
    local high = math.max(low, math.min(max, Utils.toCount(range[2])))
    local count = low ~= high and { low, high } or (low > 1 and low or nil)

    return { item = reward.item, count = count, weight = weight, rarity = reward.rarity }
end

---@param data any { label, description, price, points, level, rewards }
---@return table|nil champs propres
---@return string|table|nil message d'erreur à traduire (Locale.t)
function CaseConfigService.clean(data)
    if type(data) ~= 'table' then return nil, Locale.t('Données invalides.') end
    local fields = {
        label = CaseConfigService.text(data.label, CaseConfigService.MAX_LABEL),
        description = CaseConfigService.text(data.description, CaseConfigService.MAX_DESCRIPTION),
        price = CaseConfigService.optional(data.price, Config.ShopMaxPrice),
        points = CaseConfigService.optional(data.points, CaseConfigService.MAX_POINTS),
        level = math.max(1, math.min(CaseConfigService.MAX_LEVEL, Utils.toCount(data.level))),
        rewards = {},
    }
    if fields.label == '' then return nil, Locale.t('Donne un nom à la caisse.') end
    if fields.description == '' then fields.description = nil end
    if fields.level == 1 then fields.level = nil end

    local rewards = type(data.rewards) == 'table' and data.rewards or {}
    if #rewards == 0 then return nil, Locale.t('Ajoute au moins une récompense.') end
    if #rewards > CaseConfigService.MAX_REWARDS then
        return nil, Locale.t('Trop de récompenses (%d au maximum).', CaseConfigService.MAX_REWARDS)
    end
    for index, reward in ipairs(rewards) do
        local clean = CaseConfigService.cleanReward(reward)
        if not clean then return nil, Locale.t('Récompense n°%d invalide.', index) end
        fields.rewards[index] = clean
    end
    return fields
end

---@return string id libre d'une nouvelle caisse (c'est aussi le nom de l'objet)
function CaseConfigService.newId()
    local id = 'case_' .. os.time()
    while CaseService.byId[id] or Config.Items[id] do id = id .. 'x' end
    return id
end

-- ---------------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------------

---Enregistre l'état d'une caisse : une caisse d'origine non modifiée et affichée n'a pas de ligne.
---@param source integer
---@param case table
function CaseConfigService.store(source, case)
    local custom = CaseConfigService.originals[case.id] == nil
    local data
    if custom or CaseConfigService.modified[case.id] then
        data = json.encode({
            label = case.label,
            description = case.description,
            price = case.price,
            points = case.points,
            level = case.level,
            rewards = case.rewards,
        })
    end
    if not data and not case.removed then
        MySQL.update('DELETE FROM pvp_cases WHERE id = ?', { case.id })
        return
    end
    MySQL.insert(
        'INSERT INTO pvp_cases (id, data, removed, updated_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), removed = VALUES(removed), updated_by = VALUES(updated_by)',
        { case.id, data, case.removed and 1 or 0, GetPlayerName(source) or '' }
    )
end

-- ---------------------------------------------------------------------------
-- Panneau admin
-- ---------------------------------------------------------------------------

---@param source integer
---@return boolean
function CaseConfigService.allowed(source)
    if AdminService.isAdmin(source) then return true end
    DiscordService.adminDenied(source)
    return false
end

---Toutes les caisses (retirées comprises) et les objets qu'elles peuvent donner.
---@param source integer
function CaseConfigService.getCallback(source)
    if not CaseConfigService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end

    local cases = {}
    for _, id in ipairs(CaseConfigService.order) do
        local case = CaseService.byId[id]
        cases[#cases + 1] = {
            id = id,
            label = case.label,
            description = case.description,
            price = case.price,
            points = case.points,
            level = case.level,
            rewards = case.rewards,
            removed = case.removed == true,
            custom = CaseConfigService.originals[id] == nil,
            modified = CaseConfigService.modified[id] == true,
        }
    end

    local items = {}
    for name, item in pairs(Config.Items) do
        if item.type ~= 'attachment' then items[#items + 1] = { name = name, label = item.label, type = item.type } end
    end
    table.sort(items, function(a, b) return a.label < b.label end)

    return {
        ok = true,
        cases = cases,
        items = items,
        limits = {
            maxCases = CaseConfigService.MAX_CASES,
            maxRewards = CaseConfigService.MAX_REWARDS,
            maxPrice = Config.ShopMaxPrice,
            maxPoints = CaseConfigService.MAX_POINTS,
            maxLevel = CaseConfigService.MAX_LEVEL,
            maxCount = CaseConfigService.MAX_COUNT,
            maxMoney = CaseConfigService.MAX_MONEY,
        },
    }
end

---Crée une caisse (sans `id`) ou modifie une caisse existante.
---@param source integer
---@param data any { id?, label, description, price, points, level, rewards }
function CaseConfigService.saveCallback(source, data)
    if not CaseConfigService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end
    if type(data) ~= 'table' then return { ok = false, message = Locale.t('Données invalides.') } end
    if data.id ~= nil and not CaseService.byId[data.id] then
        return { ok = false, message = Locale.t('Caisse inconnue.') }
    end
    if data.id == nil and #CaseConfigService.order >= CaseConfigService.MAX_CASES then
        return { ok = false, message = Locale.t('Trop de caisses (%d au maximum).', CaseConfigService.MAX_CASES) }
    end

    local fields, err = CaseConfigService.clean(data)
    if not fields then return { ok = false, message = err } end

    local created = data.id == nil
    local case = CaseConfigService.apply(created and CaseConfigService.newId() or data.id, fields)
    CaseConfigService.store(source, case)
    CaseConfigService.applied()
    CaseConfigService.log(source, ('caisse « %s » %s'):format(case.label, created and 'créée' or 'modifiée'))
    return {
        ok = true,
        id = case.id,
        message = created and Locale.t('Caisse « %s » créée.', case.label) or Locale.t('Caisse « %s » enregistrée.', case.label),
    }
end

---Retire une caisse de la page (plus vendue ni ouverte en points) ou l'y remet.
---@param source integer
---@param id any
---@param removed any
function CaseConfigService.removeCallback(source, id, removed)
    if not CaseConfigService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end
    local case = CaseService.byId[id]
    if not case then return { ok = false, message = Locale.t('Caisse inconnue.') } end

    case.removed = removed == true
    CaseConfigService.store(source, case)
    CaseConfigService.applied()
    CaseConfigService.log(source, ('caisse « %s » %s'):format(case.label, case.removed and 'retirée' or 'remise'))
    return {
        ok = true,
        message = case.removed and Locale.t('Caisse « %s » retirée.', case.label) or Locale.t('Caisse « %s » remise.', case.label),
    }
end

---Remet une caisse de config/cases.lua telle que dans le fichier, et sur la page.
---@param source integer
---@param id any
function CaseConfigService.resetCallback(source, id)
    if not CaseConfigService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end
    local original = type(id) == 'string' and CaseConfigService.originals[id]
    if not original then return { ok = false, message = Locale.t('Caisse inconnue.') } end

    local case = CaseService.byId[id]
    case.label, case.description = original.label, original.description
    case.price, case.points, case.level = original.price, original.points, original.level
    case.rewards = original.rewards
    case.removed = nil
    CaseService.prepare(case)
    CaseConfigService.modified[id] = nil
    MySQL.update('DELETE FROM pvp_cases WHERE id = ?', { id })
    CaseConfigService.applied()
    CaseConfigService.log(source, ('caisse « %s » remise par défaut'):format(case.label))
    return { ok = true, message = Locale.t('Caisse « %s » remise par défaut.', case.label) }
end

---@param source integer
---@param message string
function CaseConfigService.log(source, message)
    Logger.info('[admin] %s : caisses, %s', GetPlayerName(source), message)
    DiscordService.adminAction(source, 'casesConfig', nil, {}, message)
end
