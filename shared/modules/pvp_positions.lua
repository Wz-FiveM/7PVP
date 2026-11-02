---Emplacements du mode PvP déplaçables depuis le panneau admin (onglet « Positions ») :
---zones safe et zones zombies (centre, rayon, points d'apparition), zones de contrôle (centre, rayon)
---et PNJ de service. Partagé : le serveur valide et enregistre (voir FreeroamConfigService),
---le client refait ses repères et ses PNJ.
---@class PvpPositionsModule
local PvpPositions = PVP.define('PvpPositions')
local Zones = PVP.use('Zones')
local FreeroamPositions = PVP.use('FreeroamPositions')

PvpPositions.MODE = 'pvp'
PvpPositions.CONTROL = 'control'
PvpPositions.CONFLICT = 'conflict'
-- Réglage du panneau -> sorte de zones
PvpPositions.ZONE_SETTINGS = {
    pvpSafeZones = 'safe',
    pvpPveZones = 'pve',
    pvpControlZones = PvpPositions.CONTROL,
    pvpConflictZones = PvpPositions.CONFLICT,
}

---PNJ de service des zones du mode, rangés par zone (« Zone · Rôle »).
---@return { key: string, label: string, coords: vector4 }[] coords.w = cap
function PvpPositions.npcs()
    local list = {}
    for _, npc in ipairs(Config.SafeNpcs.npcs) do
        local zone = Zones.byId(npc.zone)
        if zone and Zones.inMode(zone, PvpPositions.MODE) then
            local role = Config.SafeNpcs.roles[npc.role]
            list[#list + 1] = {
                key = FreeroamPositions.npcKey(npc),
                label = zone.label .. ' · ' .. (role and role.label or npc.role),
                coords = npc.coords,
            }
        end
    end
    return list
end

---@param kind string 'safe', 'pve' ou 'control'
---@return table[] zones du mode, modifiées directement par setZones
function PvpPositions.zones(kind)
    if kind == PvpPositions.CONTROL then return Config.ControlZones.zones end
    if kind == PvpPositions.CONFLICT then return Config.ConflictZones.zones end
    return Zones.byType(kind, PvpPositions.MODE)
end

---@param zone table
---@return vector4[]|nil points d'apparition (joueurs en zone safe, zombies en zone PvE), nil : la zone n'en a pas
function PvpPositions.spawnsOf(zone)
    if zone.type == 'pve' then return zone.npc.spawns end
    return zone.spawns
end

---@param kind string 'safe', 'pve' ou 'control'
---@param value { id: string, center: table, radius: number, spawns: table[]|nil }[] valeur validée ; les zones absentes ne bougent pas
function PvpPositions.setZones(kind, value)
    local zones = {}
    for _, zone in ipairs(PvpPositions.zones(kind)) do zones[zone.id] = zone end
    for _, entry in ipairs(value) do
        local zone = zones[entry.id]
        if zone then
            zone.coords = vector3(entry.center.x, entry.center.y, entry.center.z)
            zone.radius = entry.radius + 0.0
            if entry.spawns then PvpPositions.setSpawns(zone, entry.spawns) end
        end
    end
end

---@param zone table
---@param points { x: number, y: number, z: number, w: number }[]
function PvpPositions.setSpawns(zone, points)
    local spawns = {}
    for _, point in ipairs(points) do
        spawns[#spawns + 1] = vector4(point.x, point.y, point.z, point.w)
    end
    if zone.type == 'pve' then zone.npc.spawns = spawns else zone.spawns = spawns end
end
