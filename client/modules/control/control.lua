---Zones de contrôle côté client : repères sur la carte (couleur selon le propriétaire),
---cercle au sol et barre de capture dans le HUD quand on est dedans.
---@class ControlModule
local Control = PVP.define('Control')
local State = PVP.use('State')
local Group = PVP.use('Group')
local Nui = PVP.use('Nui')
local Events = PVP.use('Events')

Control.DRAW_DISTANCE = 150.0

---@type table[] état reçu du serveur
Control.zones = {}
---@type table<string, { area: integer, icon: integer }> id -> repères
Control.blips = {}
Control.ground = {} -- id -> hauteur du sol trouvée
Control.insideId = false

function Control.init()
    RegisterNetEvent(Events.client.controlZones, function(list)
        Control.zones = type(list) == 'table' and list or {}
        Control.refreshBlips()
        Control.sendHud()
    end)
    CreateThread(Control.loop)
end

---@return string camp du joueur local (même format que le serveur)
function Control.myTeam()
    if Group.data then return 'g:' .. Group.data.id end
    return 'p:' .. GetPlayerServerId(PlayerId())
end

---@param zone table
---@return integer couleur du repère
function Control.colorOf(zone)
    local colors = Config.ControlZones.blip
    if not zone.owner then return colors.neutral end
    return zone.owner == Control.myTeam() and colors.mine or colors.enemy
end

function Control.refreshBlips()
    for _, zone in ipairs(Control.zones) do
        local blips = Control.blips[zone.id]
        if not blips then
            local area = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
            SetBlipAlpha(area, 110)
            local icon = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
            SetBlipSprite(icon, Config.ControlZones.blip.sprite)
            SetBlipAsShortRange(icon, true)
            blips = { area = area, icon = icon }
            Control.blips[zone.id] = blips
        end
        local color = Control.colorOf(zone)
        SetBlipColour(blips.area, color)
        SetBlipColour(blips.icon, color)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(zone.ownerLabel and ('%s (%s)'):format(zone.label, zone.ownerLabel) or zone.label)
        EndTextCommandSetBlipName(blips.icon)
    end
end

function Control.loop()
    while true do
        local needsFrame = false
        if State.inPvp() then
            local pos = GetEntityCoords(PlayerPedId())
            local inside = false
            for _, zone in ipairs(Control.zones) do
                local dist = #(pos.xy - zone.coords.xy)
                if dist < Control.DRAW_DISTANCE then
                    needsFrame = true
                    Control.drawCircle(zone)
                end
                if dist <= zone.radius then inside = zone.id end
            end
            if inside ~= Control.insideId then
                Control.insideId = inside
                Control.sendHud()
            end
        elseif Control.insideId then
            Control.insideId = false
            Control.sendHud()
        end
        Wait(needsFrame and 0 or 500)
    end
end

---Cercle au sol, recalé sur la hauteur du terrain.
---@param zone table
function Control.drawCircle(zone)
    if not Control.ground[zone.id] then
        local found, ground = GetGroundZFor_3dCoord(zone.coords.x, zone.coords.y, zone.coords.z + 50.0, false)
        if found then Control.ground[zone.id] = ground end
    end
    local z = Control.ground[zone.id] or zone.coords.z
    local r, g, b = 160, 160, 160
    if zone.owner then
        if zone.owner == Control.myTeam() then r, g, b = 181, 242, 61 else r, g, b = 255, 107, 26 end
    end
    DrawMarker(1, zone.coords.x, zone.coords.y, z - 1.0, 0, 0, 0, 0, 0, 0, zone.radius * 2, zone.radius * 2, 1.5,
        r, g, b, 60, false, false, 2, false, nil, nil, false)
end

---Zone où se trouve le joueur, avec l'état de la capture (le HUD affiche la barre).
function Control.sendHud()
    local current = false
    for _, zone in ipairs(Control.zones) do
        if zone.id == Control.insideId then
            local team = Control.myTeam()
            current = {
                label = zone.label,
                ownerLabel = zone.ownerLabel,
                mine = zone.owner == team,
                capturing = zone.capturer == team,
                enemyCapturing = zone.capturer ~= false and zone.capturer ~= team,
                progress = zone.progress,
                contested = zone.contested,
            }
        end
    end
    Nui.send('controlZone', { zone = current })
end
