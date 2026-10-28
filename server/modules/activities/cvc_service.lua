---CVC (Config.Cvc) : file d'attente, deux équipes équilibrées, manches en convoi avec une seule vie.
---Le serveur décide de tout (équipes, vivants, fin de manche, tirs alliés) ; les clients créent
---les véhicules (le conducteur crée le sien et renvoie son net id aux passagers) et affichent l'état.
---@class CvcMatch
---@field id integer
---@field bucket integer
---@field teams integer[][] joueurs de chaque équipe (1 et 2)
---@field teamOf table<integer, integer> joueur -> équipe
---@field scores integer[] manches gagnées par équipe
---@field round integer
---@field phase 'countdown'|'running'|'pause'|'ended'
---@field dead table<integer, boolean> morts de la manche en cours
---@field vehicles table<integer, integer> net id par véhicule de la manche ([équipe * 100 + numéro])
---@field crews table<integer, integer[]> joueurs par véhicule (même clé), conducteur en premier
---@field endAt integer|nil

---@class CvcServiceModule
local CvcService = PVP.define('CvcService')
local ActivityService = PVP.use('ActivityService')
local PlayerService = PVP.use('PlayerService')
local ModeRegistry = PVP.use('ModeRegistry')
local Utils = PVP.use('Utils')
local Zones = PVP.use('Zones')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')

CvcService.ID = 'cvc'
CvcService.CHECK_INTERVAL = 500
CvcService.VEHICLE_SPACING = 9.0

---@type integer[] joueurs en attente
CvcService.queue = {}
---@type integer|nil GetGameTimer() du lancement prévu de la prochaine partie
CvcService.startAt = nil
---@type table<integer, CvcMatch>
CvcService.matches = {}
---@type table<integer, integer> joueur -> partie
CvcService.playerMatch = {}
CvcService.nextId = 0

function CvcService.init()
    ActivityService.register(CvcService.ID, CvcService.toggleQueue)

    RegisterNetEvent(Events.server.cvcVehicle, function(key, netId)
        CvcService.onVehicle(source, key, netId)
    end)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        CvcService.leave(playerSource)
    end)
end

-- ---------------------------------------------------------------------------
-- File d'attente
-- ---------------------------------------------------------------------------

---PNJ du CVC : rejoint la file, ou la quitte si on y est déjà.
---@param player PvpPlayer
---@return boolean, string
function CvcService.toggleQueue(player)
    local source = player.source
    if CvcService.playerMatch[source] then return false, 'Tu es déjà dans une partie de CVC.' end

    for index, queued in ipairs(CvcService.queue) do
        if queued == source then
            table.remove(CvcService.queue, index)
            TriggerClientEvent(Events.client.cvcQueue, source, false)
            CvcService.updateQueue()
            return true, 'Tu as quitté la file du CVC.'
        end
    end

    CvcService.queue[#CvcService.queue + 1] = source
    CvcService.updateQueue()
    return true, 'Tu rejoins la file du CVC. Reparle à l\'organisateur pour la quitter.'
end

---Compte à rebours dès qu'il y a assez de joueurs ; partie lancée tout de suite si c'est plein.
function CvcService.updateQueue()
    local count = #CvcService.queue
    if count < Config.Cvc.minPlayers then
        CvcService.startAt = nil
    elseif count >= Config.Cvc.maxPlayers then
        CvcService.launch()
        return
    elseif not CvcService.startAt then
        CvcService.startAt = GetGameTimer() + Config.Cvc.queueDelay * 1000
        local planned = CvcService.startAt
        SetTimeout(Config.Cvc.queueDelay * 1000, function()
            if CvcService.startAt == planned then CvcService.launch() end
        end)
    end

    local startIn = CvcService.startAt and math.ceil((CvcService.startAt - GetGameTimer()) / 1000) or nil
    for _, source in ipairs(CvcService.queue) do
        TriggerClientEvent(Events.client.cvcQueue, source, {
            count = count, needed = Config.Cvc.minPlayers, max = Config.Cvc.maxPlayers, startIn = startIn,
        })
    end
end

function CvcService.launch()
    CvcService.startAt = nil
    if #CvcService.queue < Config.Cvc.minPlayers then return CvcService.updateQueue() end
    local players = {}
    while #CvcService.queue > 0 and #players < Config.Cvc.maxPlayers do
        players[#players + 1] = table.remove(CvcService.queue, 1)
    end
    CvcService.startMatch(players)
    CvcService.updateQueue()
end

---Déconnexion ou départ du Freeroam : sort de la file, ou quitte son équipe.
---@param source integer
function CvcService.leave(source)
    for index, queued in ipairs(CvcService.queue) do
        if queued == source then
            table.remove(CvcService.queue, index)
            CvcService.updateQueue()
            return
        end
    end

    local match = CvcService.matches[CvcService.playerMatch[source]]
    if not match or match.phase == 'ended' then return end
    local team = match.teamOf[source]
    CvcService.playerMatch[source] = nil
    match.teamOf[source] = nil
    for index, member in ipairs(match.teams[team]) do
        if member == source then table.remove(match.teams[team], index) break end
    end
    if #match.teams[team] == 0 then
        CvcService.endMatch(match, 3 - team, ('L\'équipe %s a abandonné : victoire par forfait.'):format(Config.Cvc.teams[team].label))
    end
end

-- ---------------------------------------------------------------------------
-- Partie
-- ---------------------------------------------------------------------------

---Deux équipes équilibrées, tirées au sort.
---@param players integer[]
function CvcService.startMatch(players)
    CvcService.nextId = CvcService.nextId + 1
    local match = {
        id = CvcService.nextId,
        bucket = Config.Cvc.bucketBase + CvcService.nextId,
        teams = { {}, {} },
        teamOf = {},
        scores = { 0, 0 },
        round = 0,
        phase = 'pause',
        dead = {},
        vehicles = {},
        crews = {},
    }
    CvcService.matches[match.id] = match
    SetRoutingBucketPopulationEnabled(match.bucket, false)

    for i = #players, 2, -1 do
        local j = math.random(i)
        players[i], players[j] = players[j], players[i]
    end
    for index, source in ipairs(players) do
        local team = index % 2 == 1 and 1 or 2
        match.teams[team][#match.teams[team] + 1] = source
        match.teamOf[source] = team
        CvcService.playerMatch[source] = match.id
        SetPlayerRoutingBucket(source, match.bucket)
        TriggerClientEvent(Events.client.cvcQueue, source, false)
    end
    Logger.info('[cvc] partie n°%d : %d contre %d', match.id, #match.teams[1], #match.teams[2])
    CvcService.startRound(match)
end

---@param from vector3
---@param to vector3
---@return number cap GTA (degrés) pour regarder de `from` vers `to`
function CvcService.headingTo(from, to)
    return (math.deg(math.atan(-(to.x - from.x), to.y - from.y)) + 360.0) % 360.0
end

---Nouvelle manche : zone au hasard, convoi de chaque équipe tourné vers le centre.
---@param match CvcMatch
function CvcService.startRound(match)
    if match.phase == 'ended' then return end
    match.round = match.round + 1
    match.phase = 'countdown'
    match.dead = {}
    match.vehicles = {}
    match.crews = {}
    local arena = Utils.pick(Config.Cvc.arenas)

    for team = 1, 2 do
        local start = arena.spawns[team]
        local heading = CvcService.headingTo(start, arena.center)
        local radians = math.rad(heading)
        local back = vector3(math.sin(radians), -math.cos(radians), 0.0)
        local members = match.teams[team]
        local seats = math.max(1, Config.Cvc.seatsPerVehicle)

        for index, source in ipairs(members) do
            local vehicleNumber = math.ceil(index / seats)
            local seat = (index - 1) % seats - 1 -- -1 conducteur, 0 passager avant, puis arrière
            local key = team * 100 + vehicleNumber
            match.crews[key] = match.crews[key] or {}
            table.insert(match.crews[key], source)
            local position = start + back * (CvcService.VEHICLE_SPACING * (vehicleNumber - 1))

            TriggerClientEvent(Events.client.cvcRound, source, {
                round = match.round,
                team = Config.Cvc.teams[team],
                arena = { label = arena.label, center = arena.center, radius = arena.radius },
                spawn = vector4(position.x, position.y, position.z, heading),
                vehicleKey = key,
                seat = seat,
                model = Config.Cvc.vehicle,
                kit = Config.Cvc.kit,
                countdown = Config.Cvc.countdown,
                roundTime = Config.Cvc.roundTime,
                outsideDamage = Config.Cvc.outsideDamage,
                roundsToWin = Config.Cvc.roundsToWin,
                scores = { us = match.scores[team], them = match.scores[3 - team] },
            })
        end
    end

    SetTimeout(Config.Cvc.countdown * 1000, function()
        if match.phase ~= 'countdown' then return end
        match.phase = 'running'
        match.endAt = GetGameTimer() + Config.Cvc.roundTime * 1000
        CreateThread(function()
            CvcService.runRound(match)
        end)
    end)
end

---Le conducteur a créé le véhicule : son net id part aux passagers.
---@param source integer
---@param key any
---@param netId any
function CvcService.onVehicle(source, key, netId)
    local match = CvcService.matches[CvcService.playerMatch[source]]
    key, netId = tonumber(key), tonumber(netId)
    if not match or not key or not netId or not match.crews[key] or match.crews[key][1] ~= source then return end
    match.vehicles[key] = netId
    for index, member in ipairs(match.crews[key]) do
        if index > 1 then TriggerClientEvent(Events.client.cvcVehicle, member, netId) end
    end
end

---@param match CvcMatch
function CvcService.runRound(match)
    while match.phase == 'running' do
        Wait(CvcService.CHECK_INTERVAL)
        if match.phase ~= 'running' then return end
        CvcService.check(match)
    end
end

---@param match CvcMatch
---@param team integer
---@return integer joueurs encore en vie
function CvcService.aliveCount(match, team)
    local count = 0
    for _, source in ipairs(match.teams[team]) do
        if not match.dead[source] then count = count + 1 end
    end
    return count
end

---@param match CvcMatch
function CvcService.check(match)
    for team = 1, 2 do
        for _, source in ipairs(match.teams[team]) do
            local ped = GetPlayerPed(source)
            if not match.dead[source] and (ped == 0 or GetEntityHealth(ped) <= 0) then match.dead[source] = true end
        end
    end

    local alive = { CvcService.aliveCount(match, 1), CvcService.aliveCount(match, 2) }
    if alive[1] == 0 or alive[2] == 0 then
        if alive[1] == alive[2] then return CvcService.endRound(match, nil, 'Les deux équipes sont tombées.') end
        local winner = alive[1] > 0 and 1 or 2
        return CvcService.endRound(match, winner, ('L\'équipe %s a éliminé tous ses adversaires.'):format(Config.Cvc.teams[winner].label))
    end

    local now = GetGameTimer()
    if now >= match.endAt then
        if alive[1] == alive[2] then return CvcService.endRound(match, nil, 'Temps écoulé : autant de survivants des deux côtés.') end
        local winner = alive[1] > alive[2] and 1 or 2
        return CvcService.endRound(match, winner, ('Temps écoulé : l\'équipe %s a plus de survivants.'):format(Config.Cvc.teams[winner].label))
    end

    local remaining = math.max(0, math.ceil((match.endAt - now) / 1000))
    for team = 1, 2 do
        local mates = {}
        for _, source in ipairs(match.teams[team]) do
            mates[#mates + 1] = {
                id = source,
                name = GetPlayerName(source) or '?',
                alive = not match.dead[source],
                coords = GetEntityCoords(GetPlayerPed(source)),
            }
        end
        local state = { remaining = remaining, alive = { us = alive[team], them = alive[3 - team] }, mates = mates }
        for _, source in ipairs(match.teams[team]) do
            TriggerClientEvent(Events.client.cvcState, source, state)
        end
    end
end

---@param match CvcMatch
---@param winner integer|nil nil = manche nulle
---@param reason string
function CvcService.endRound(match, winner, reason)
    if match.phase ~= 'running' then return end
    match.phase = 'pause'
    if winner then match.scores[winner] = match.scores[winner] + 1 end
    CvcService.deleteVehicles(match)

    for team = 1, 2 do
        for _, source in ipairs(match.teams[team]) do
            TriggerClientEvent(Events.client.cvcRoundEnd, source, {
                result = winner == nil and 'draw' or (winner == team and 'won' or 'lost'),
                reason = reason,
                round = match.round,
                scores = { us = match.scores[team], them = match.scores[3 - team] },
            })
        end
    end

    SetTimeout(Config.Cvc.roundPause * 1000, function()
        if match.phase ~= 'pause' then return end
        for team = 1, 2 do
            if match.scores[team] >= Config.Cvc.roundsToWin then
                return CvcService.endMatch(match, team, nil)
            end
        end
        CvcService.startRound(match)
    end)
end

---@param match CvcMatch
function CvcService.deleteVehicles(match)
    for _, netId in pairs(match.vehicles) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    match.vehicles = {}
end

---Fin de partie : retour dans la zone safe du Freeroam.
---@param match CvcMatch
---@param winner integer|nil
---@param reason string|nil
function CvcService.endMatch(match, winner, reason)
    if match.phase == 'ended' then return end
    match.phase = 'ended'
    CvcService.matches[match.id] = nil
    CvcService.deleteVehicles(match)

    local freeroam = ModeRegistry.getConfig('freeroam')
    for team = 1, 2 do
        for _, source in ipairs(match.teams[team]) do
            CvcService.playerMatch[source] = nil
            if PlayerService.get(source) then
                if freeroam then SetPlayerRoutingBucket(source, freeroam.bucket) end
                TriggerClientEvent(Events.client.cvcEnd, source, {
                    result = winner == nil and 'draw' or (winner == team and 'won' or 'lost'),
                    reason = reason,
                    scores = { us = match.scores[team], them = match.scores[3 - team] },
                    spawn = Zones.randomSpawn('freeroam'),
                })
            end
        end
    end
    Logger.info('[cvc] partie n°%d terminée (%d - %d)', match.id, match.scores[1], match.scores[2])
end

---Tirs entre deux joueurs : nil si ce n'est pas une affaire du CVC, sinon autorisé ou non
---(pas de tir allié, pas de tir avant le départ).
---@param attacker integer
---@param victim integer
---@return boolean|nil
function CvcService.damageAllowed(attacker, victim)
    local matchId = CvcService.playerMatch[attacker]
    if not matchId or CvcService.playerMatch[victim] ~= matchId then return nil end
    local match = CvcService.matches[matchId]
    if not match or match.phase ~= 'running' then return false end
    return match.teamOf[attacker] ~= match.teamOf[victim]
end
