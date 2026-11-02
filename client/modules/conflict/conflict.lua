---Zones de conflit côté client : repères sur la carte, mur rouge autour de la zone et,
---quand on est dedans, kill leader, ses kills et compteur en bas au milieu de l'écran.
---@class ConflictModule
local Conflict = PVP.define('Conflict')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

-- Le mur se dessine jusqu'à cette distance du bord de la zone
Conflict.DRAW_MARGIN = 200.0

---@type table|false état reçu du serveur
Conflict.zone = false
Conflict.endsAt = 0 -- GetGameTimer() de la fin du compteur
---@type { area: integer, icon: integer, coords: vector3, radius: number }|nil
Conflict.blips = nil
Conflict.ground = nil -- hauteur du sol trouvée
Conflict.inside = false

function Conflict.init()
    RegisterNetEvent(Events.client.conflictState, function(data)
        Conflict.zone = type(data) == 'table' and data or false
        Conflict.endsAt = Conflict.zone and GetGameTimer() + Conflict.zone.endsIn * 1000 or 0
        Conflict.sendHud()
    end)
    CreateThread(Conflict.loop)
end

function Conflict.loop()
    while true do
        local needsFrame = false
        local zone = Conflict.zone
        if zone and State.inPvp() then
            Conflict.showBlips(zone)
            local distance = #(GetEntityCoords(PlayerPedId()).xy - zone.coords.xy)
            if distance < zone.radius + Conflict.DRAW_MARGIN then
                needsFrame = true
                Conflict.drawWall(zone)
            end
            Conflict.setInside(distance <= zone.radius)
        else
            Conflict.removeBlips()
            Conflict.setInside(false)
        end
        Wait(needsFrame and 0 or 500)
    end
end

---@param inside boolean
function Conflict.setInside(inside)
    if inside == Conflict.inside then return end
    Conflict.inside = inside
    Conflict.sendHud()
end

---@param zone table
function Conflict.showBlips(zone)
    local blips = Conflict.blips
    -- Autre zone, ou zone déplacée par un admin : repères et hauteur du sol à refaire
    if blips and blips.coords == zone.coords and blips.radius == zone.radius then return end
    Conflict.removeBlips()

    local settings = Config.ConflictZones.blip
    local area = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
    SetBlipColour(area, settings.color)
    SetBlipAlpha(area, 130)
    local icon = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
    SetBlipSprite(icon, settings.sprite)
    SetBlipColour(icon, settings.color)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Locale.t('Zone de conflit : %s', Locale.t(zone.label)))
    EndTextCommandSetBlipName(icon)
    Conflict.blips = { area = area, icon = icon, coords = zone.coords, radius = zone.radius }
end

function Conflict.removeBlips()
    if not Conflict.blips then return end
    RemoveBlip(Conflict.blips.area)
    RemoveBlip(Conflict.blips.icon)
    Conflict.blips = nil
    Conflict.ground = nil
end

---Mur rouge recalé sur la hauteur du terrain.
---@param zone table
function Conflict.drawWall(zone)
    if not Conflict.ground then
        local found, ground = GetGroundZFor_3dCoord(zone.coords.x, zone.coords.y, zone.coords.z + 50.0, false)
        if found then Conflict.ground = ground end
    end
    local z = Conflict.ground or zone.coords.z
    DrawMarker(1, zone.coords.x, zone.coords.y, z - 1.0, 0, 0, 0, 0, 0, 0, zone.radius * 2, zone.radius * 2, Config.ConflictZones.wallHeight,
        255, 40, 30, 70, false, false, 2, false, nil, nil, false)
end

---Le bandeau n'existe que dans la zone.
function Conflict.sendHud()
    local zone = Conflict.zone
    if not zone or not Conflict.inside then
        return Nui.send('conflict', { conflict = false })
    end
    Nui.send('conflict', {
        conflict = {
            endsIn = math.max(0, math.ceil((Conflict.endsAt - GetGameTimer()) / 1000)),
            leader = zone.leader,
        },
    })
end
