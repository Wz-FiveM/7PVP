---@class ZoneInfo
---@field id string|nil
---@field label string
---@field type 'safe'|'pve'|'pvp'

---Zones de Config.Zones. Chaque zone appartient à un ou plusieurs modes de jeu (`modes`,
---{ 'pvp' } par défaut) : un joueur ne voit et ne subit que les zones de son mode.
---@class ZonesModule
local Zones = PVP.define('Zones')

Zones.DEFAULT_MODES = { 'pvp' }
Zones.index = {}

function Zones.init()
    for _, zone in ipairs(Config.Zones) do
        Zones.index[zone.id] = zone
    end
end

---@param id string|nil
function Zones.byId(id)
    return id and Zones.index[id]
end

---@param zone table
---@param mode string|nil mode de jeu (nil : lobby, aucune zone)
---@return boolean la zone existe dans ce mode
function Zones.inMode(zone, mode)
    if not mode then return false end
    for _, zoneMode in ipairs(zone.modes or Zones.DEFAULT_MODES) do
        if zoneMode == mode then return true end
    end
    return false
end

---@param zoneType 'safe'|'pve'
---@param mode? string défaut : 'pvp'
---@return table[]
function Zones.byType(zoneType, mode)
    local list = {}
    for _, zone in ipairs(Config.Zones) do
        if zone.type == zoneType and Zones.inMode(zone, mode or 'pvp') then list[#list + 1] = zone end
    end
    return list
end

---Zone du mode qui contient `coords` (les zones safe sont prioritaires), nil = hors zone.
---@param coords vector3
---@param mode? string défaut : 'pvp'
function Zones.getAt(coords, mode)
    local found
    for _, zone in ipairs(Config.Zones) do
        if Zones.inMode(zone, mode or 'pvp') and #(coords.xy - zone.coords.xy) <= zone.radius then
            if zone.type == 'safe' then return zone end
            found = found or zone
        end
    end
    return found
end

---@param coords vector3
---@param mode? string défaut : 'pvp'
---@return boolean
function Zones.isSafe(coords, mode)
    local zone = Zones.getAt(coords, mode)
    return zone ~= nil and zone.type == 'safe'
end

---Point d'apparition au hasard dans les zones safe du mode.
---@param mode? string défaut : 'pvp'
---@return vector4|nil
function Zones.randomSpawn(mode)
    local spawns = {}
    for _, zone in ipairs(Zones.byType('safe', mode)) do
        for _, spawn in ipairs(zone.spawns or {}) do
            spawns[#spawns + 1] = spawn
        end
    end
    return spawns[math.random(math.max(#spawns, 1))]
end

---Version sérialisable d'une zone (pour le NUI et l'API)
---@return ZoneInfo
function Zones.toInfo(zone)
    if not zone then
        return { label = 'Zone PvP', type = 'pvp' }
    end
    return { id = zone.id, label = zone.label, type = zone.type }
end
