---Zones de contrôle côté client : repères sur la carte (couleur selon le propriétaire),
---cercle au sol et barre de capture dans le HUD quand on est dedans.
---Territoires (zone.crew) : le camp du joueur est son crew, et le menu Crew en affiche la liste.
---@class ControlModule
local Control = PVP.define('Control')
local State = PVP.use('State')
local Group = PVP.use('Group')
local Crew = PVP.use('Crew')
local Nui = PVP.use('Nui')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Control.DRAW_DISTANCE = 150.0

---@type table[] état reçu du serveur
Control.zones = {}
---@type table<string, { area: integer, icon: integer }> id -> repères
Control.blips = {}
Control.ground = {} -- id -> hauteur du sol trouvée
Control.insideId = false
Control.lastTerritories = ''

function Control.init()
    RegisterNetEvent(Events.client.controlZones, function(list)
        Control.zones = type(list) == 'table' and list or {}
        Control.refresh()
    end)
    CreateThread(Control.loop)
end

---État reçu, ou crew du joueur qui change (voir Crew.onSync) : le camp peut ne plus être le même.
function Control.refresh()
    Control.refreshBlips()
    Control.sendHud()
    Control.sendTerritories()
end

---@param zone table
---@return string camp du joueur local dans cette zone (même format que le serveur)
function Control.myTeam(zone)
    if zone.crew then
        if Crew.data then return 'c:' .. Crew.data.tag end
    elseif Group.data then
        return 'g:' .. Group.data.id
    end
    return 'p:' .. GetPlayerServerId(PlayerId())
end

---@param zone table
---@return integer couleur du repère
function Control.colorOf(zone)
    local colors = Config.ControlZones.blip
    if not zone.owner then return colors.neutral end
    return zone.owner == Control.myTeam(zone) and colors.mine or colors.enemy
end

---@return table[] territoires pour le menu Crew
function Control.territoryList()
    local list = {}
    for _, zone in ipairs(Control.zones) do
        if zone.crew then
            list[#list + 1] = {
                id = zone.id,
                label = zone.label,
                ownerLabel = zone.ownerLabel,
                mine = zone.owner == Control.myTeam(zone),
                income = zone.income,
            }
        end
    end
    return list
end

---Le menu n'a besoin que des propriétaires : rien à envoyer pendant une capture.
function Control.sendTerritories()
    local list = Control.territoryList()
    local key = json.encode(list)
    if key == Control.lastTerritories then return end
    Control.lastTerritories = key
    Nui.send('territories', { territories = list })
end

---@param zone table territoire
---@return boolean le crew du joueur est au maximum et ne tient pas déjà ce territoire
function Control.atTerritoryLimit(zone)
    local team = Control.myTeam(zone)
    if not Crew.data or zone.owner == team then return false end
    local count = 0
    for _, other in ipairs(Control.zones) do
        if other.crew and other.owner == team then count = count + 1 end
    end
    return count >= Config.ControlZones.territories.maxPerCrew
end

function Control.refreshBlips()
    for _, zone in ipairs(Control.zones) do
        local blips = Control.blips[zone.id]
        -- Zone déplacée par un admin : repères et hauteur du sol à refaire
        if blips and (blips.coords ~= zone.coords or blips.radius ~= zone.radius) then
            RemoveBlip(blips.area)
            RemoveBlip(blips.icon)
            Control.ground[zone.id] = nil
            blips = nil
        end
        if not blips then
            local area = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
            SetBlipAlpha(area, 110)
            local icon = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
            SetBlipSprite(icon, zone.crew and Config.ControlZones.territories.sprite or Config.ControlZones.blip.sprite)
            SetBlipAsShortRange(icon, true)
            blips = { area = area, icon = icon, coords = zone.coords, radius = zone.radius }
            Control.blips[zone.id] = blips
        end
        local color = Control.colorOf(zone)
        SetBlipColour(blips.area, color)
        SetBlipColour(blips.icon, color)
        local label = zone.crew and Locale.t('Territoire : %s', Locale.t(zone.label)) or Locale.t(zone.label)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(zone.ownerLabel and ('%s (%s)'):format(label, Locale.resolve(zone.ownerLabel)) or label)
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
        if zone.owner == Control.myTeam(zone) then r, g, b = 181, 242, 61 else r, g, b = 255, 107, 26 end
    end
    DrawMarker(1, zone.coords.x, zone.coords.y, z - 1.0, 0, 0, 0, 0, 0, 0, zone.radius * 2, zone.radius * 2, 1.5,
        r, g, b, 60, false, false, 2, false, nil, nil, false)
end

---Zone où se trouve le joueur, avec l'état de la capture (le HUD affiche la barre).
function Control.sendHud()
    local current = false
    for _, zone in ipairs(Control.zones) do
        if zone.id == Control.insideId then
            local team = Control.myTeam(zone)
            current = {
                label = zone.label,
                ownerLabel = zone.ownerLabel,
                mine = zone.owner == team,
                capturing = zone.capturer == team,
                enemyCapturing = zone.capturer ~= false and zone.capturer ~= team,
                progress = zone.progress,
                contested = zone.contested,
                territory = zone.crew,
                protected = zone.protected,
                noCrew = zone.crew and not Crew.data,
                atLimit = zone.crew and Control.atTerritoryLimit(zone),
            }
        end
    end
    Nui.send('controlZone', { zone = current })
end
