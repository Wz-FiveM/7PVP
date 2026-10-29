---1VS1 GunFight (Config.Gunfight) : file d'attente, duel au pistolet en manches à une seule vie.
---Le serveur décide de tout (vivants, fin de manche, tirs autorisés) ; les clients placent le joueur,
---donnent l'arme et affichent l'état.
---@class GunfightMatch
---@field id integer
---@field bucket integer
---@field players integer[] les deux joueurs (départ 1 et 2)
---@field scores table<integer, integer> manches gagnées par joueur
---@field round integer
---@field phase 'countdown'|'running'|'pause'|'ended'
---@field dead table<integer, boolean> morts de la manche en cours
---@field endAt integer|nil

---@class GunfightServiceModule
local GunfightService = PVP.define('GunfightService')
local ActivityService = PVP.use('ActivityService')
local ChaseService = PVP.use('ChaseService')
local CvcService = PVP.use('CvcService')
local PlayerService = PVP.use('PlayerService')
local ModeRegistry = PVP.use('ModeRegistry')
local Zones = PVP.use('Zones')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')

GunfightService.ID = 'gunfight'
GunfightService.PLAYERS = 2
GunfightService.CHECK_INTERVAL = 250

---@type integer[] joueurs en attente
GunfightService.queue = {}
---@type table<integer, GunfightMatch>
GunfightService.matches = {}
---@type table<integer, integer> joueur -> partie
GunfightService.playerMatch = {}
GunfightService.nextId = 0

function GunfightService.init()
    ActivityService.register(GunfightService.ID, GunfightService.toggleQueue)

    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        GunfightService.leave(playerSource)
    end)
end

-- ---------------------------------------------------------------------------
-- File d'attente
-- ---------------------------------------------------------------------------

---PNJ du 1VS1 : rejoint la file, ou la quitte si on y est déjà.
---@param player PvpPlayer
---@return boolean, string
function GunfightService.toggleQueue(player)
    local source = player.source
    if GunfightService.playerMatch[source] then return false, 'Tu es déjà dans un 1VS1.' end
    if ChaseService.playerMatch[source] or CvcService.playerMatch[source] then
        return false, 'Termine d\'abord ta partie en cours.'
    end

    for index, queued in ipairs(GunfightService.queue) do
        if queued == source then
            table.remove(GunfightService.queue, index)
            TriggerClientEvent(Events.client.gunfightQueue, source, false)
            GunfightService.updateQueue()
            return true, 'Tu as quitté la file du 1VS1.'
        end
    end

    GunfightService.queue[#GunfightService.queue + 1] = source
    GunfightService.updateQueue()
    if GunfightService.playerMatch[source] then return true, 'Adversaire trouvé : le duel commence !' end
    return true, 'Tu rejoins la file du 1VS1. Reparle à l\'organisateur pour la quitter.'
end

---Deux joueurs dans la file : la partie se lance tout de suite.
function GunfightService.updateQueue()
    while #GunfightService.queue >= GunfightService.PLAYERS do
        GunfightService.startMatch({ table.remove(GunfightService.queue, 1), table.remove(GunfightService.queue, 1) })
    end
    for _, source in ipairs(GunfightService.queue) do
        TriggerClientEvent(Events.client.gunfightQueue, source, { count = #GunfightService.queue, needed = GunfightService.PLAYERS })
    end
end

---Déconnexion ou départ du Freeroam : sort de la file, ou abandonne la partie.
---@param source integer
function GunfightService.leave(source)
    for index, queued in ipairs(GunfightService.queue) do
        if queued == source then
            table.remove(GunfightService.queue, index)
            GunfightService.updateQueue()
            return
        end
    end

    local match = GunfightService.matches[GunfightService.playerMatch[source]]
    if not match or match.phase == 'ended' then return end
    GunfightService.playerMatch[source] = nil
    local opponent = GunfightService.opponentOf(match, source)
    GunfightService.endMatch(match, opponent, ('%s a abandonné : victoire par forfait.'):format(GetPlayerName(source) or 'Ton adversaire'))
end

-- ---------------------------------------------------------------------------
-- Partie
-- ---------------------------------------------------------------------------

---@param match GunfightMatch
---@param source integer
---@return integer
function GunfightService.opponentOf(match, source)
    return match.players[1] == source and match.players[2] or match.players[1]
end

---@param match GunfightMatch
---@param source integer
---@return { us: integer, them: integer }
function GunfightService.scoresFor(match, source)
    return { us = match.scores[source] or 0, them = match.scores[GunfightService.opponentOf(match, source)] or 0 }
end

---@param players integer[]
function GunfightService.startMatch(players)
    GunfightService.nextId = GunfightService.nextId + 1
    local match = {
        id = GunfightService.nextId,
        bucket = Config.Gunfight.bucketBase + GunfightService.nextId,
        players = players,
        scores = {},
        round = 0,
        phase = 'pause',
        dead = {},
    }
    GunfightService.matches[match.id] = match
    SetRoutingBucketPopulationEnabled(match.bucket, false)

    for _, source in ipairs(players) do
        match.scores[source] = 0
        GunfightService.playerMatch[source] = match.id
        SetPlayerRoutingBucket(source, match.bucket)
        TriggerClientEvent(Events.client.gunfightQueue, source, false)
    end
    Logger.info('[gunfight] partie n°%d : %s contre %s', match.id, GetPlayerName(players[1]) or '?', GetPlayerName(players[2]) or '?')
    GunfightService.startRound(match)
end

---Nouvelle manche : chaque joueur à son départ (on échange les côtés à chaque manche), arme redonnée.
---@param match GunfightMatch
function GunfightService.startRound(match)
    if match.phase == 'ended' then return end
    match.round = match.round + 1
    match.phase = 'countdown'
    match.dead = {}
    local spawns = Config.Gunfight.spawns
    local center = (spawns[1].xyz + spawns[2].xyz) / 2

    for index, source in ipairs(match.players) do
        local side = (index + match.round) % 2 + 1
        TriggerClientEvent(Events.client.gunfightRound, source, {
            round = match.round,
            opponent = GetPlayerName(GunfightService.opponentOf(match, source)) or '?',
            opponentId = GunfightService.opponentOf(match, source),
            spawn = spawns[side],
            arena = { center = center, radius = Config.Gunfight.radius },
            kit = Config.Gunfight.kit,
            countdown = Config.Gunfight.countdown,
            roundTime = Config.Gunfight.roundTime,
            outsideDamage = Config.Gunfight.outsideDamage,
            roundsToWin = Config.Gunfight.roundsToWin,
            scores = GunfightService.scoresFor(match, source),
        })
    end

    SetTimeout(Config.Gunfight.countdown * 1000, function()
        if match.phase ~= 'countdown' then return end
        match.phase = 'running'
        match.endAt = GetGameTimer() + Config.Gunfight.roundTime * 1000
        CreateThread(function()
            GunfightService.runRound(match)
        end)
    end)
end

---@param match GunfightMatch
function GunfightService.runRound(match)
    while match.phase == 'running' do
        Wait(GunfightService.CHECK_INTERVAL)
        if match.phase ~= 'running' then return end
        GunfightService.check(match)
    end
end

---@param match GunfightMatch
function GunfightService.check(match)
    for _, source in ipairs(match.players) do
        local ped = GetPlayerPed(source)
        if ped == 0 or GetEntityHealth(ped) <= 0 then match.dead[source] = true end
    end

    local first, second = match.players[1], match.players[2]
    if match.dead[first] or match.dead[second] then
        if match.dead[first] and match.dead[second] then return GunfightService.endRound(match, nil, 'Les deux joueurs sont tombés.') end
        local winner = match.dead[first] and second or first
        return GunfightService.endRound(match, winner, ('%s a remporté le duel.'):format(GetPlayerName(winner) or '?'))
    end

    local now = GetGameTimer()
    if now >= match.endAt then return GunfightService.endRound(match, nil, 'Temps écoulé : la manche est rejouée.') end

    local state = { remaining = math.max(0, math.ceil((match.endAt - now) / 1000)) }
    for _, source in ipairs(match.players) do
        TriggerClientEvent(Events.client.gunfightState, source, state)
    end
end

---@param match GunfightMatch
---@param winner integer|nil nil = manche nulle
---@param reason string
function GunfightService.endRound(match, winner, reason)
    if match.phase ~= 'running' then return end
    match.phase = 'pause'
    if winner then match.scores[winner] = match.scores[winner] + 1 end

    for _, source in ipairs(match.players) do
        TriggerClientEvent(Events.client.gunfightRoundEnd, source, {
            result = winner == nil and 'draw' or (winner == source and 'won' or 'lost'),
            reason = reason,
            round = match.round,
            scores = GunfightService.scoresFor(match, source),
        })
    end

    SetTimeout(Config.Gunfight.roundPause * 1000, function()
        if match.phase ~= 'pause' then return end
        if winner and match.scores[winner] >= Config.Gunfight.roundsToWin then
            return GunfightService.endMatch(match, winner, nil)
        end
        GunfightService.startRound(match)
    end)
end

---Fin de partie : retour dans la zone safe du Freeroam.
---@param match GunfightMatch
---@param winner integer|nil
---@param reason string|nil
function GunfightService.endMatch(match, winner, reason)
    if match.phase == 'ended' then return end
    match.phase = 'ended'
    GunfightService.matches[match.id] = nil

    local freeroam = ModeRegistry.getConfig('freeroam')
    for _, source in ipairs(match.players) do
        -- Celui qui abandonne (GunfightService.leave) n'est déjà plus dans la partie : rien à lui envoyer
        local inMatch = GunfightService.playerMatch[source] == match.id
        if inMatch then GunfightService.playerMatch[source] = nil end
        if inMatch and PlayerService.get(source) then
            if freeroam then SetPlayerRoutingBucket(source, freeroam.bucket) end
            TriggerClientEvent(Events.client.gunfightEnd, source, {
                result = winner == nil and 'draw' or (winner == source and 'won' or 'lost'),
                reason = reason,
                scores = GunfightService.scoresFor(match, source),
                spawn = Zones.randomSpawn('freeroam'),
            })
        end
    end
    Logger.info('[gunfight] partie n°%d terminée (%d - %d)', match.id, match.scores[match.players[1]], match.scores[match.players[2]])
end

---Tirs entre deux joueurs : nil si ce n'est pas une affaire du 1VS1, sinon autorisé ou non
---(seulement pendant la manche, entre les deux joueurs de la même partie).
---@param attacker integer
---@param victim integer
---@return boolean|nil
function GunfightService.damageAllowed(attacker, victim)
    local matchId = GunfightService.playerMatch[attacker]
    if not matchId and not GunfightService.playerMatch[victim] then return nil end
    if GunfightService.playerMatch[victim] ~= matchId then return false end
    local match = GunfightService.matches[matchId]
    return match ~= nil and match.phase == 'running'
end

---@param source integer
---@return boolean dans la file ou dans une partie
function GunfightService.isBusy(source)
    if GunfightService.playerMatch[source] then return true end
    for _, queued in ipairs(GunfightService.queue) do
        if queued == source then return true end
    end
    return false
end
