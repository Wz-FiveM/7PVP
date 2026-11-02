---Zones de contrôle : un camp (un groupe, ou un joueur seul) capture une zone en y restant
---sans adversaire, puis la zone lui rapporte de l'argent régulièrement.
---Territoires (def.crew) : même principe, mais seul un crew capture, et le propriétaire reste en base.
---@class ControlZoneState
---@field def table entrée de Config.ControlZones.zones
---@field owner string|nil camp propriétaire ('g:<groupe>', 'p:<server id>' ou 'c:<label du crew>')
---@field ownerLabel string|nil
---@field capturer string|nil camp en train de capturer
---@field progress number 0 à 1
---@field contested boolean
---@field paidAt integer GetGameTimer() du dernier versement
---@field protectedUntil integer os.time() de la fin de la protection d'un territoire
---@field alertedAt integer|nil GetGameTimer() de la dernière alerte au crew propriétaire

---@class ControlServiceModule
local ControlService = PVP.define('ControlService')
local PlayerService = PVP.use('PlayerService')
local GroupService = PVP.use('GroupService')
local CrewService = PVP.use('CrewService')
local CrewRepository = PVP.use('CrewRepository')
local ChatService = PVP.use('ChatService')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

ControlService.TICK = 1000
ControlService.CREW_PREFIX = 'c:'

---@type ControlZoneState[]
ControlService.zones = {}
ControlService.lastSent = ''

function ControlService.init()
    for _, def in ipairs(Config.ControlZones.zones) do
        ControlService.zones[#ControlService.zones + 1] = {
            def = def, owner = nil, ownerLabel = nil, capturer = nil, progress = 0, contested = false, paidAt = 0,
            protectedUntil = 0, alertedAt = nil,
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
---@param zone ControlZoneState
---@return string camp du joueur dans cette zone : son crew sur un territoire, sinon son groupe, sinon lui seul
function ControlService.teamOf(player, zone)
    if zone.def.crew then
        local tag = CrewService.tagOf(player.identifier)
        return tag and (ControlService.CREW_PREFIX .. tag) or ('p:' .. player.source)
    end
    local group = GroupService.getGroupOf(player.source)
    return group and ('g:' .. group.id) or ('p:' .. player.source)
end

---@param team string
---@param player PvpPlayer un joueur du camp
---@return string|table nom du joueur, ou message à traduire (Locale.t) pour un groupe
function ControlService.teamLabel(team, player)
    if team:sub(1, 2) == ControlService.CREW_PREFIX then
        return ControlService.crewLabel(team:sub(3))
    end
    local group = GroupService.getGroupOf(player.source)
    if team:sub(1, 2) == 'g:' and group then
        local leader = PlayerService.get(group.leader)
        return Locale.t('Groupe de %s', leader and leader:displayName() or player:displayName())
    end
    return player:displayName()
end

---@param tag string
---@return string « [MGZ] Magazine »
function ControlService.crewLabel(tag)
    local crew = CrewService.crews[tag]
    return crew and ('[%s] %s'):format(tag, crew.name) or ('[%s]'):format(tag)
end

---Camps présents dans le cercle (joueurs PvP vivants).
---@param zone ControlZoneState
---@return table<string, PvpPlayer> camp -> un de ses joueurs
function ControlService.teamsInside(zone)
    local teams = {}
    for _, player in pairs(PlayerService.all()) do
        if player.mode == 'pvp' and not player.dead and #(player:getCoords().xy - zone.def.coords.xy) <= zone.def.radius then
            teams[ControlService.teamOf(player, zone)] = player
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
    if count == 1 and team ~= zone.owner and ControlService.canCapture(zone, team) then
        ControlService.advance(zone, team, member)
    elseif count <= 1 and zone.capturer and zone.progress > 0 then
        -- Personne, ou seulement un camp qui ne peut pas capturer : la capture entamée retombe lentement
        zone.progress = math.max(0, zone.progress - ControlService.step(zone) / 2)
        if zone.progress == 0 then zone.capturer = nil end
    end

    ControlService.payIncome(zone)
end

---@param zone ControlZoneState
---@param team string
---@return boolean
function ControlService.canCapture(zone, team)
    if not zone.def.crew then return true end
    if team:sub(1, 2) ~= ControlService.CREW_PREFIX or os.time() < zone.protectedUntil then return false end
    return ControlService.territoriesOf(team) < Config.ControlZones.territories.maxPerCrew
end

---@param team string
---@return integer territoires tenus par ce camp
function ControlService.territoriesOf(team)
    local count = 0
    for _, zone in ipairs(ControlService.zones) do
        if zone.def.crew and zone.owner == team then count = count + 1 end
    end
    return count
end

---@param zone ControlZoneState
---@return number progression par tick (plus lent si la zone appartient à quelqu'un)
function ControlService.step(zone)
    local settings = zone.def.crew and Config.ControlZones.territories or Config.ControlZones
    local seconds = settings.captureTime * (zone.owner and 2 or 1)
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
        ControlService.alertOwner(zone)
    end

    zone.progress = math.min(1, zone.progress + ControlService.step(zone))
    if zone.progress >= 1 then
        local previous = zone.owner
        zone.owner = team
        zone.ownerLabel = ControlService.teamLabel(team, member)
        zone.capturer = nil
        zone.progress = 0
        zone.paidAt = GetGameTimer()
        if zone.def.crew then
            ControlService.onTerritoryTaken(zone, previous)
        else
            ChatService.announce('pvp', Locale.t('%s a pris le contrôle de : %s', zone.ownerLabel, Locale.t(zone.def.label)))
        end
    end
end

---Prévient le crew propriétaire qu'on attaque son territoire.
---@param zone ControlZoneState
function ControlService.alertOwner(zone)
    if not zone.def.crew or not zone.owner then return end
    local now = GetGameTimer()
    if zone.alertedAt and now - zone.alertedAt < Config.ControlZones.territories.alertDelay * 1000 then return end
    zone.alertedAt = now

    local crew = CrewService.crews[zone.owner:sub(3)]
    if crew then CrewService.notifyMembers(crew, Locale.t('Ton territoire est attaqué : %s !', Locale.t(zone.def.label))) end
end

---@param zone ControlZoneState
---@param previous string|nil ancien propriétaire
function ControlService.onTerritoryTaken(zone, previous)
    zone.protectedUntil = os.time() + Config.ControlZones.territories.protection
    zone.alertedAt = nil
    CrewRepository.setTerritory(zone.def.id, zone.owner:sub(3), zone.protectedUntil)

    local label = Locale.t(zone.def.label)
    ChatService.announce('pvp', Locale.t('%s prend le territoire : %s', zone.ownerLabel, label))
    local crew = previous and CrewService.crews[previous:sub(3)]
    if crew then CrewService.notifyMembers(crew, Locale.t('Ton crew a perdu le territoire : %s', label)) end
end

---Territoires gardés en base : appelé par CrewService une fois les crews chargés.
---@param rows { zone_id: string, crew_tag: string, protected_until: integer }[]
function ControlService.restoreTerritories(rows)
    local byId = {}
    for _, zone in ipairs(ControlService.zones) do
        if zone.def.crew then byId[zone.def.id] = zone end
    end
    for _, row in ipairs(rows) do
        local zone = byId[row.zone_id]
        if zone and CrewService.crews[row.crew_tag] then
            zone.owner = ControlService.CREW_PREFIX .. row.crew_tag
            zone.ownerLabel = ControlService.crewLabel(row.crew_tag)
            zone.protectedUntil = row.protected_until
            zone.paidAt = GetGameTimer()
        end
    end
    ControlService.broadcast(true)
end

---Crew dissous : ses territoires redeviennent libres (la base est nettoyée par CrewRepository.delete).
---@param tag string
function ControlService.releaseCrew(tag)
    local team = ControlService.CREW_PREFIX .. tag
    for _, zone in ipairs(ControlService.zones) do
        if zone.capturer == team then
            zone.capturer = nil
            zone.progress = 0
        end
        if zone.owner == team then
            zone.owner = nil
            zone.ownerLabel = nil
            zone.protectedUntil = 0
            zone.alertedAt = nil
        end
    end
    ControlService.broadcast(true)
end

---Versement régulier à tous les joueurs PvP connectés du camp propriétaire.
---@param zone ControlZoneState
function ControlService.payIncome(zone)
    local interval = zone.def.crew and Config.ControlZones.territories.incomeInterval or Config.ControlZones.incomeInterval
    if not zone.owner or GetGameTimer() - zone.paidAt < interval * 1000 then return end
    zone.paidAt = GetGameTimer()
    for _, player in pairs(PlayerService.all()) do
        if player.mode == 'pvp' and ControlService.teamOf(player, zone) == zone.owner then
            player:addMoney(zone.def.income)
            player:notify(Locale.t('%s : +$%d', Locale.t(zone.def.label), zone.def.income), 'success')
            player:sync()
        end
    end
end

---@return table[]
function ControlService.describe()
    local list = {}
    local now = os.time()
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
            crew = zone.def.crew == true,
            income = zone.def.income,
            protected = now < zone.protectedUntil,
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
