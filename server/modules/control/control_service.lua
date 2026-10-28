---Zones de contrôle : un camp (un groupe, ou un joueur seul) capture une zone en y restant
---sans adversaire, puis la zone lui rapporte de l'argent régulièrement.
---@class ControlZoneState
---@field def table entrée de Config.ControlZones.zones
---@field owner string|nil camp propriétaire ('g:<groupe>' ou 'p:<server id>')
---@field ownerLabel string|nil
---@field capturer string|nil camp en train de capturer
---@field progress number 0 à 1
---@field contested boolean
---@field paidAt integer GetGameTimer() du dernier versement

---@class ControlServiceModule
local ControlService = PVP.define('ControlService')
local PlayerService = PVP.use('PlayerService')
local GroupService = PVP.use('GroupService')
local ChatService = PVP.use('ChatService')
local Events = PVP.use('Events')

ControlService.TICK = 1000

---@type ControlZoneState[]
ControlService.zones = {}
ControlService.lastSent = ''

function ControlService.init()
    for _, def in ipairs(Config.ControlZones.zones) do
        ControlService.zones[#ControlService.zones + 1] = {
            def = def, owner = nil, ownerLabel = nil, capturer = nil, progress = 0, contested = false, paidAt = 0,
        }
    end
    RegisterNetEvent(Events.server.ready, function()
        TriggerClientEvent(Events.client.controlZones, source, ControlService.describe())
    end)
    CreateThread(ControlService.loop)
end

function ControlService.loop()
    while true do
        Wait(ControlService.TICK)
        for _, zone in ipairs(ControlService.zones) do
            ControlService.tick(zone)
        end
        ControlService.broadcast(false)
    end
end

---@param player PvpPlayer
---@return string camp du joueur : son groupe s'il en a un, sinon lui seul
function ControlService.teamOf(player)
    local group = GroupService.getGroupOf(player.source)
    return group and ('g:' .. group.id) or ('p:' .. player.source)
end

---@param team string
---@param player PvpPlayer un joueur du camp
---@return string
function ControlService.teamLabel(team, player)
    local group = GroupService.getGroupOf(player.source)
    if team:sub(1, 2) == 'g:' and group then
        local leader = PlayerService.get(group.leader)
        return ('Groupe de %s'):format(leader and leader.name or player.name)
    end
    return player.name
end

---Camps présents dans le cercle (joueurs PvP vivants).
---@param zone ControlZoneState
---@return table<string, PvpPlayer> camp -> un de ses joueurs
function ControlService.teamsInside(zone)
    local teams = {}
    for _, player in pairs(PlayerService.all()) do
        if player.mode == 'pvp' and not player.dead and #(player:getCoords() - zone.def.coords) <= zone.def.radius then
            teams[ControlService.teamOf(player)] = player
        end
    end
    return teams
end

---@param zone ControlZoneState
function ControlService.tick(zone)
    local teams = ControlService.teamsInside(zone)
    local count, team, member = 0, nil, nil
    for key, player in pairs(teams) do
        count = count + 1
        team, member = key, player
    end

    zone.contested = count > 1
    if count == 1 and team ~= zone.owner then
        ControlService.advance(zone, team, member)
    elseif count == 0 and zone.capturer and zone.progress > 0 then
        -- Personne : la capture entamée retombe lentement
        zone.progress = math.max(0, zone.progress - ControlService.step(zone) / 2)
        if zone.progress == 0 then zone.capturer = nil end
    end

    ControlService.payIncome(zone)
end

---@param zone ControlZoneState
---@return number progression par tick (plus lent si la zone appartient à quelqu'un)
function ControlService.step(zone)
    local seconds = Config.ControlZones.captureTime * (zone.owner and 2 or 1)
    return ControlService.TICK / 1000 / seconds
end

---@param zone ControlZoneState
---@param team string
---@param member PvpPlayer
function ControlService.advance(zone, team, member)
    if zone.capturer ~= team then
        -- Un autre camp avait commencé : sa progression doit d'abord retomber
        if zone.progress > 0 and zone.capturer then
            zone.progress = math.max(0, zone.progress - ControlService.step(zone))
            if zone.progress > 0 then return end
        end
        zone.capturer = team
    end

    zone.progress = math.min(1, zone.progress + ControlService.step(zone))
    if zone.progress >= 1 then
        zone.owner = team
        zone.ownerLabel = ControlService.teamLabel(team, member)
        zone.capturer = nil
        zone.progress = 0
        zone.paidAt = GetGameTimer()
        ChatService.announce('pvp', ('%s a pris le contrôle de : %s'):format(zone.ownerLabel, zone.def.label))
    end
end

---Versement régulier à tous les joueurs PvP connectés du camp propriétaire.
---@param zone ControlZoneState
function ControlService.payIncome(zone)
    if not zone.owner or GetGameTimer() - zone.paidAt < Config.ControlZones.incomeInterval * 1000 then return end
    zone.paidAt = GetGameTimer()
    for _, player in pairs(PlayerService.all()) do
        if player.mode == 'pvp' and ControlService.teamOf(player) == zone.owner then
            player:addMoney(zone.def.income)
            player:notify(('%s : +$%d'):format(zone.def.label, zone.def.income), 'success')
            player:sync()
        end
    end
end

---@return table[]
function ControlService.describe()
    local list = {}
    for _, zone in ipairs(ControlService.zones) do
        list[#list + 1] = {
            id = zone.def.id,
            label = zone.def.label,
            coords = zone.def.coords,
            radius = zone.def.radius,
            owner = zone.owner or false,
            ownerLabel = zone.ownerLabel or false,
            capturer = zone.capturer or false,
            progress = math.floor(zone.progress * 100),
            contested = zone.contested,
        }
    end
    return list
end

---Envoie l'état des zones à tous, seulement s'il a changé.
---@param force boolean
function ControlService.broadcast(force)
    local list = ControlService.describe()
    local key = json.encode(list)
    if not force and key == ControlService.lastSent then return end
    ControlService.lastSent = key
    TriggerClientEvent(Events.client.controlZones, -1, list)
end
