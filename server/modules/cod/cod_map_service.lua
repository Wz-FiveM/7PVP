---Cartes Call of Duty modifiables en jeu (panneau admin F10, onglet « Positions ») : création, nom,
---lieu, rayon, présence au vote, suppression. Les points de chaque carte sont des réglages de
---FreeroamConfigService ; la liste des cartes tient dans une ligne de pvp_freeroam_settings.
---Une carte n'est proposée au vote que si elle a assez de points (COD_LISTS, `min`).
---@class CodMapServiceModule
local CodMapService = PVP.define('CodMapService')
local FreeroamConfigService = PVP.use('FreeroamConfigService')
local CodService = PVP.use('CodService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CodMapService.ROW = 'codMaps'
CodMapService.MAX_MAPS = 30
CodMapService.MIN_RADIUS = 20.0
CodMapService.MAX_RADIUS = 500.0
-- La base limite le nom d'un réglage à 32 caractères (« cod_<id>_alpha »)
CodMapService.MAX_ID = 22

---@type table<string, table> cartes de config/cod.lua, telles que dans le fichier
CodMapService.originals = {}
for _, map in ipairs(Config.Cod.maps) do
    CodMapService.originals[map.id] = { id = map.id, label = map.label, place = map.place, radius = map.radius }
end
---@type table<string, boolean> cartes de config/cod.lua supprimées depuis le panneau
CodMapService.removed = {}

function CodMapService.init()
    Callback.register(Events.callbacks.adminCodMapSave, CodMapService.saveCallback)
    Callback.register(Events.callbacks.adminCodMapDelete, CodMapService.deleteCallback)
    Callback.register(Events.callbacks.adminCodMapRestore, CodMapService.restoreCallback)
end

---@param map table entrée de Config.Cod.maps
---@return boolean encore dans la liste, proposée au vote et assez de points pour tous les modes
function CodMapService.playable(map)
    if map.enabled == false or CodService.findMap(map.id) ~= map then return false end
    for _, list in ipairs(FreeroamConfigService.COD_LISTS) do
        local points = Config.CodSpawns[map.id .. '_' .. list.key]
        if not points or #points < list.min then return false end
    end
    return true
end

---@return table[] cartes pour le panneau
---@return table[] cartes d'origine supprimées, qu'on peut remettre
function CodMapService.describe()
    local maps, removed = {}, {}
    for _, map in ipairs(Config.Cod.maps) do
        maps[#maps + 1] = {
            id = map.id,
            label = map.label,
            place = map.place,
            radius = map.radius,
            enabled = map.enabled ~= false,
            custom = CodMapService.originals[map.id] == nil,
        }
    end
    for id in pairs(CodMapService.removed) do
        removed[#removed + 1] = { id = id, label = CodMapService.originals[id].label }
    end
    return maps, removed
end

---@param data any { label, place, radius, enabled }
---@return table|nil champs propres
function CodMapService.clean(data)
    if type(data) ~= 'table' then return nil end
    local label = FreeroamConfigService.text(data.label, '')
    local radius = FreeroamConfigService.number(data.radius, CodMapService.MAX_RADIUS)
    if label == '' or not radius or radius < CodMapService.MIN_RADIUS then return nil end
    return { label = label, place = FreeroamConfigService.text(data.place, ''), radius = radius, enabled = data.enabled ~= false }
end

---@param map table
---@param fields table champs propres
function CodMapService.fill(map, fields)
    map.label, map.place, map.radius, map.enabled = fields.label, fields.place, fields.radius, fields.enabled
end

---@return string id libre d'une nouvelle carte
function CodMapService.newId()
    local id = 'map' .. os.time()
    while CodService.findMap(id) do id = id .. 'x' end
    return id
end

---@param map table entrée de Config.Cod.maps
function CodMapService.remove(map)
    for index, entry in ipairs(Config.Cod.maps) do
        if entry == map then table.remove(Config.Cod.maps, index) break end
    end
    local original = CodMapService.originals[map.id] ~= nil
    if original then CodMapService.removed[map.id] = true end
    FreeroamConfigService.removeCodMap(map, not original)
end

-- ---------------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------------

---Applique ce qui a été enregistré depuis le panneau (voir FreeroamConfigService.load).
---@param raw string JSON { maps, removed }
function CodMapService.apply(raw)
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then return end

    for _, id in ipairs(type(data.removed) == 'table' and data.removed or {}) do
        local map = CodMapService.originals[id] and CodService.findMap(id)
        if map then CodMapService.remove(map) end
    end
    for _, entry in ipairs(type(data.maps) == 'table' and data.maps or {}) do
        local fields = CodMapService.clean(entry)
        local id = type(entry) == 'table' and entry.id
        if fields and type(id) == 'string' and #id <= CodMapService.MAX_ID and not id:find('[^%w_]') and not CodMapService.removed[id] then
            local map = CodService.findMap(id)
            if not map then
                map = { id = id }
                Config.Cod.maps[#Config.Cod.maps + 1] = map
                CodMapService.fill(map, fields)
                FreeroamConfigService.addCodMap(map)
            else
                CodMapService.fill(map, fields)
                FreeroamConfigService.renameCodMap(map)
            end
        end
    end
end

---@param source integer
function CodMapService.save(source)
    local maps, removed = {}, {}
    for _, map in ipairs(Config.Cod.maps) do
        maps[#maps + 1] = { id = map.id, label = map.label, place = map.place, radius = map.radius, enabled = map.enabled ~= false }
    end
    for id in pairs(CodMapService.removed) do removed[#removed + 1] = id end
    MySQL.insert(
        'INSERT INTO pvp_freeroam_settings (name, data, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), updated_by = VALUES(updated_by)',
        { CodMapService.ROW, json.encode({ maps = maps, removed = removed }), GetPlayerName(source) or '' }
    )
    CodService.refreshVotes()
end

-- ---------------------------------------------------------------------------
-- Panneau admin
-- ---------------------------------------------------------------------------

---Crée une carte (sans `id`) ou modifie une carte existante.
---@param source integer
---@param data any { id?, label, place, radius, enabled }
function CodMapService.saveCallback(source, data)
    if not FreeroamConfigService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end
    local fields = CodMapService.clean(data)
    if not fields then
        return { ok = false, message = Locale.t('Nom vide ou rayon incorrect (de %d à %d m).', CodMapService.MIN_RADIUS, CodMapService.MAX_RADIUS) }
    end

    local map
    if data.id ~= nil then
        map = CodService.findMap(data.id)
        if not map then return { ok = false, message = Locale.t('Carte inconnue.') } end
        CodMapService.fill(map, fields)
        FreeroamConfigService.renameCodMap(map)
    else
        if #Config.Cod.maps >= CodMapService.MAX_MAPS then
            return { ok = false, message = Locale.t('Trop de cartes (%d au maximum).', CodMapService.MAX_MAPS) }
        end
        map = { id = CodMapService.newId() }
        CodMapService.fill(map, fields)
        Config.Cod.maps[#Config.Cod.maps + 1] = map
        FreeroamConfigService.addCodMap(map)
    end

    CodMapService.save(source)
    FreeroamConfigService.log(source, ('carte Call of Duty « %s » enregistrée'):format(map.label))
    return { ok = true, id = map.id, message = Locale.t('Carte « %s » enregistrée.', map.label) }
end

---@param source integer
---@param id any
function CodMapService.deleteCallback(source, id)
    if not FreeroamConfigService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end
    local map = CodService.findMap(id)
    if not map then return { ok = false, message = Locale.t('Carte inconnue.') } end

    CodMapService.remove(map)
    CodMapService.save(source)
    FreeroamConfigService.log(source, ('carte Call of Duty « %s » supprimée'):format(map.label))
    return { ok = true, message = Locale.t('Carte « %s » supprimée.', map.label) }
end

---Remet une carte de config/cod.lua supprimée, telle que dans le fichier.
---@param source integer
---@param id any
function CodMapService.restoreCallback(source, id)
    if not FreeroamConfigService.allowed(source) then return { ok = false, message = Locale.t('Accès refusé.') } end
    if not CodMapService.removed[id] then return { ok = false, message = Locale.t('Carte inconnue.') } end

    local original = CodMapService.originals[id]
    local map = { id = id, label = original.label, place = original.place, radius = original.radius }
    CodMapService.removed[id] = nil
    Config.Cod.maps[#Config.Cod.maps + 1] = map
    FreeroamConfigService.addCodMap(map)

    CodMapService.save(source)
    FreeroamConfigService.log(source, ('carte Call of Duty « %s » remise'):format(map.label))
    return { ok = true, id = id, message = Locale.t('Carte « %s » remise.', map.label) }
end
