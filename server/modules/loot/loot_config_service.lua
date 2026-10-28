---Tables de butin modifiables en jeu (panneau admin F10, onglet « Butin ») : argent, objets,
---quantités et chances de chaque table de Config.LootTables, et table utilisée par chaque zone PvE.
---Les changements s'appliquent tout de suite et sont enregistrés en base (pvp_loot_tables) :
---ils remplacent config/loot.lua au démarrage. « Valeurs par défaut » revient au fichier.
---@class LootConfigServiceModule
local LootConfigService = PVP.define('LootConfigService')
local AdminService = PVP.use('AdminService')
local Items = PVP.use('Items')
local Callback = PVP.use('Callback')
local DiscordService = PVP.use('DiscordService')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')

LootConfigService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_loot_tables (
    name VARCHAR(32) NOT NULL,
    data LONGTEXT NOT NULL,
    updated_by VARCHAR(64) NOT NULL DEFAULT '',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

-- Ligne qui garde la table de butin choisie pour chaque zone PvE
LootConfigService.ZONES_ROW = '_zones'

-- Noms affichés dans le panneau
LootConfigService.LABELS = {
    gang = 'Zombies — zones communes',
    military = 'Zombies — zones militaires',
    airdrop = 'Largages',
}

LootConfigService.MAX_DROPS = 60
LootConfigService.MAX_COUNT = 100000
LootConfigService.MAX_MONEY = 1000000

---@type table<string, table> tables de config/loot.lua au démarrage (« valeurs par défaut »)
LootConfigService.defaults = {}
---@type table<string, string> table de chaque zone PvE dans config/zones.lua
LootConfigService.defaultZones = {}
---@type table<string, boolean> tables modifiées depuis le panneau
LootConfigService.modified = {}

function LootConfigService.init()
    LootConfigService.defaults = json.decode(json.encode(Config.LootTables))
    for _, zone in ipairs(Config.Zones) do
        if zone.npc then LootConfigService.defaultZones[zone.id] = zone.npc.loot end
    end

    Callback.register(Events.callbacks.adminLoot, LootConfigService.getCallback)
    Callback.register(Events.callbacks.adminLootSave, LootConfigService.saveCallback)
    Callback.register(Events.callbacks.adminLootReset, LootConfigService.resetCallback)
    Callback.register(Events.callbacks.adminLootZones, LootConfigService.zonesCallback)

    CreateThread(LootConfigService.load)
end

---Applique ce qui a été enregistré depuis le panneau.
function LootConfigService.load()
    MySQL.query.await(LootConfigService.SCHEMA)
    local rows = MySQL.query.await('SELECT name, data FROM pvp_loot_tables') or {}
    for _, row in ipairs(rows) do
        local ok, data = pcall(json.decode, row.data)
        if ok and type(data) == 'table' then
            if row.name == LootConfigService.ZONES_ROW then
                LootConfigService.applyZones(data)
            elseif Config.LootTables[row.name] then
                local clean = LootConfigService.validate(data)
                if clean then
                    Config.LootTables[row.name] = clean
                    LootConfigService.modified[row.name] = true
                end
            end
        end
    end
    if #rows > 0 then Logger.info('[butin] %d réglage(s) chargé(s) depuis la base', #rows) end
end

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------

---@param value any
---@param max number
---@return integer|nil
function LootConfigService.integer(value, max)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return math.max(0, math.min(max, math.floor(value)))
end

---@param range any { min, max }
---@param max number
---@param minimum integer
---@return integer[]|nil
function LootConfigService.range(range, max, minimum)
    if type(range) ~= 'table' then return nil end
    local low, high = LootConfigService.integer(range[1], max), LootConfigService.integer(range[2], max)
    if not low or not high then return nil end
    low = math.max(minimum, low)
    return { low, math.max(low, high) }
end

---Table propre (objets connus, nombres bornés), ou nil si les données sont inutilisables.
---@param data any
---@return table|nil
function LootConfigService.validate(data)
    if type(data) ~= 'table' or type(data.drops) ~= 'table' then return nil end
    local clean = { drops = {} }
    if data.money then
        clean.money = LootConfigService.range(data.money, LootConfigService.MAX_MONEY, 0)
    end
    for _, drop in ipairs(data.drops) do
        if #clean.drops >= LootConfigService.MAX_DROPS then break end
        local chance = tonumber(type(drop) == 'table' and drop.chance)
        local count = type(drop) == 'table' and LootConfigService.range(drop.count, LootConfigService.MAX_COUNT, 1)
        if type(drop.item) == 'string' and Items.exists(drop.item) and drop.item ~= 'money' and count and chance then
            -- Chance au dixième de pour cent près, entre 0,1 et 100
            chance = math.max(0.1, math.min(100, math.floor(chance * 10 + 0.5) / 10))
            clean.drops[#clean.drops + 1] = { item = drop.item, count = count, chance = chance }
        end
    end
    return clean
end

---@param data table<string, string> zone -> table
function LootConfigService.applyZones(data)
    for _, zone in ipairs(Config.Zones) do
        local loot = data[zone.id]
        if zone.npc and type(loot) == 'string' and Config.LootTables[loot] then
            zone.npc.loot = loot
        end
    end
end

-- ---------------------------------------------------------------------------
-- Panneau admin
-- ---------------------------------------------------------------------------

---@param source integer
---@return boolean
function LootConfigService.allowed(source)
    if AdminService.isAdmin(source) then return true end
    DiscordService.adminDenied(source)
    return false
end

---@param name string
---@return string[] zones (ou largages) qui utilisent la table
function LootConfigService.usedBy(name)
    local list = {}
    for _, zone in ipairs(Config.Zones) do
        if zone.npc and zone.npc.loot == name then list[#list + 1] = zone.label end
    end
    if Config.Airdrops.loot == name then list[#list + 1] = 'Largages aériens' end
    return list
end

---Tout ce que le panneau affiche : tables, zones PvE et liste des objets.
---@param source integer
function LootConfigService.getCallback(source)
    if not LootConfigService.allowed(source) then return { ok = false, message = 'Accès refusé.' } end

    local tables = {}
    for name, lootTable in pairs(Config.LootTables) do
        tables[#tables + 1] = {
            name = name,
            label = LootConfigService.LABELS[name] or name,
            money = lootTable.money or false,
            drops = lootTable.drops,
            usedBy = LootConfigService.usedBy(name),
            modified = LootConfigService.modified[name] == true,
        }
    end
    table.sort(tables, function(a, b) return a.label < b.label end)

    local zones = {}
    for _, zone in ipairs(Config.Zones) do
        if zone.npc then zones[#zones + 1] = { id = zone.id, label = zone.label, loot = zone.npc.loot } end
    end

    local items = {}
    for name, item in pairs(Config.Items) do
        if name ~= 'money' then items[#items + 1] = { name = name, label = item.label, type = item.type } end
    end
    table.sort(items, function(a, b) return a.label < b.label end)

    return { ok = true, tables = tables, zones = zones, items = items }
end

---@param source integer
---@param name any
---@param data any
function LootConfigService.saveCallback(source, name, data)
    if not LootConfigService.allowed(source) then return { ok = false, message = 'Accès refusé.' } end
    if type(name) ~= 'string' or not Config.LootTables[name] then
        return { ok = false, message = 'Table inconnue.' }
    end
    local clean = LootConfigService.validate(data)
    if not clean then return { ok = false, message = 'Données invalides.' } end

    Config.LootTables[name] = clean
    LootConfigService.modified[name] = true
    LootConfigService.store(source, name, clean)
    local label = LootConfigService.LABELS[name] or name
    LootConfigService.log(source, ('table « %s » : %d objet(s)'):format(label, #clean.drops))
    return { ok = true, message = ('Butin « %s » enregistré.'):format(label) }
end

---@param source integer
---@param name any
function LootConfigService.resetCallback(source, name)
    if not LootConfigService.allowed(source) then return { ok = false, message = 'Accès refusé.' } end
    if type(name) ~= 'string' or not LootConfigService.defaults[name] then
        return { ok = false, message = 'Table inconnue.' }
    end

    Config.LootTables[name] = json.decode(json.encode(LootConfigService.defaults[name]))
    LootConfigService.modified[name] = nil
    MySQL.update('DELETE FROM pvp_loot_tables WHERE name = ?', { name })
    local label = LootConfigService.LABELS[name] or name
    LootConfigService.log(source, ('table « %s » remise par défaut'):format(label))
    return { ok = true, message = ('Butin « %s » remis par défaut.'):format(label) }
end

---@param source integer
---@param data any zone -> table
function LootConfigService.zonesCallback(source, data)
    if not LootConfigService.allowed(source) then return { ok = false, message = 'Accès refusé.' } end
    if type(data) ~= 'table' then return { ok = false } end

    LootConfigService.applyZones(data)
    local saved = {}
    for _, zone in ipairs(Config.Zones) do
        if zone.npc then saved[zone.id] = zone.npc.loot end
    end
    LootConfigService.store(source, LootConfigService.ZONES_ROW, saved)
    LootConfigService.log(source, 'butin des zones PvE modifié')
    return { ok = true, message = 'Butin des zones enregistré.' }
end

---@param source integer
---@param name string
---@param data table
function LootConfigService.store(source, name, data)
    MySQL.insert(
        'INSERT INTO pvp_loot_tables (name, data, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), updated_by = VALUES(updated_by)',
        { name, json.encode(data), GetPlayerName(source) or '' }
    )
end

---@param source integer
---@param message string
function LootConfigService.log(source, message)
    Logger.info('[admin] %s : butin, %s', GetPlayerName(source), message)
    DiscordService.adminAction(source, 'lootConfig', nil, {}, message)
end
