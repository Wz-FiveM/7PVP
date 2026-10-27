---@class ZoneInfo
---@field id string|nil
---@field label string
---@field type 'safe'|'pve'|'pvp'

---@class ZonesModule
local Zones = PVP.define('Zones')

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

---@param zoneType 'safe'|'pve'
---@return table[]
function Zones.byType(zoneType)
    local list = {}
    for _, zone in ipairs(Config.Zones) do
        if zone.type == zoneType then list[#list + 1] = zone end
    end
    return list
end

---Zone qui contient `coords` (les zones safe sont prioritaires), nil = PvP libre.
---@param coords vector3
function Zones.getAt(coords)
    local found
    for _, zone in ipairs(Config.Zones) do
        if #(coords.xy - zone.coords.xy) <= zone.radius then
            if zone.type == 'safe' then return zone end
            found = found or zone
        end
    end
    return found
end

---@param coords vector3
---@return boolean
function Zones.isSafe(coords)
    local zone = Zones.getAt(coords)
    return zone ~= nil and zone.type == 'safe'
end

---@return vector4
function Zones.randomSpawn()
    local spawns = {}
    for _, zone in ipairs(Zones.byType('safe')) do
        for _, spawn in ipairs(zone.spawns or {}) do
            spawns[#spawns + 1] = spawn
        end
    end
    return spawns[math.random(#spawns)]
end

---Version sérialisable d'une zone (pour le NUI et l'API)
---@return ZoneInfo
function Zones.toInfo(zone)
    if not zone then
        return { label = 'Zone PvP', type = 'pvp' }
    end
    return { id = zone.id, label = zone.label, type = zone.type }
end
