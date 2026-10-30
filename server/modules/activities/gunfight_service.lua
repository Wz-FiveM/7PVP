---Duels 1VS1 du Freeroam : 1VS1 GunFight (Config.Gunfight, à pied) et 1VS1 Bike (Config.Bike, à moto).
---File d'attente par mode, duel au pistolet en manches à une seule vie.
---Le serveur décide de tout (vivants, fin de manche, tirs autorisés) ; les clients placent le joueur,
---créent la moto, donnent l'arme et affichent l'état.
---@class GunfightMatch
---@field id integer
---@field mode string clé de GunfightService.MODES
---@field bucket integer
---@field players integer[] les deux joueurs (départ 1 et 2)
---@field scores table<integer, integer> manches gagnées par joueur
---@field round integer
---@field phase 'countdown'|'running'|'pause'|'ended'
---@field dead table<integer, boolean> morts de la manche en cours
---@field identities table<integer, ActivityRatingIdentity> figées au départ (ELO)
---@field endAt integer|nil

---@class GunfightServiceModule
local GunfightService = PVP.define('GunfightService')
local ActivityService = PVP.use('ActivityService')
local ActivityRating = PVP.use('ActivityRating')
local ChaseService = PVP.use('ChaseService')
local CvcService = PVP.use('CvcService')
local PlayerService = PVP.use('PlayerService')
local GungameService = PVP.use('GungameService')
local ModeRegistry = PVP.use('ModeRegistry')
local Zones = PVP.use('Zones')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

-- Modes de duel : clé de Config.FreeroamActivities -> table de Config (relue à chaque manche :
-- les spawns et la moto modifiés dans le panneau admin s'appliquent tout de suite)
GunfightService.MODES = { gunfight = 'Gunfight', bike = 'Bike' }
GunfightService.PLAYERS = 2
GunfightService.CHECK_INTERVAL = 250

---@type table<string, integer[]> joueurs en attente, par mode
GunfightService.queues = {}
---@type table<integer, GunfightMatch>
GunfightService.matches = {}
---@type table<integer, integer> joueur -> partie
GunfightService.playerMatch = {}
GunfightService.nextId = 0

function GunfightService.init()
    for mode in pairs(GunfightService.MODES) do
        GunfightService.queues[mode] = {}
        ActivityService.register(mode, function(player)
            return GunfightService.toggleQueue(player, mode)
        end)
    end

    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        GunfightService.leave(playerSource)
    end)
end

-- ---------------------------------------------------------------------------
-- File d'attente
-- ---------------------------------------------------------------------------

---@param mode string
---@return string
function GunfightService.label(mode)
    return Config.FreeroamActivities[mode].label
end

---@param mode string
---@return table Config.Gunfight ou Config.Bike
function GunfightService.config(mode)
    return Config[GunfightService.MODES[mode]]
end

---@param source integer
---@return string|nil mode dont le joueur est dans la file
---@return integer|nil position dans la file
function GunfightService.queuedIn(source)
    for mode, queue in pairs(GunfightService.queues) do
        for index, queued in ipairs(queue) do
            if queued == source then return mode, index end
        end
    end
    return nil, nil
end

---PNJ du 1VS1 : rejoint la file de ce mode, ou la quitte si on y est déjà.
---@param player PvpPlayer
---@param mode string
---@return boolean, string
function GunfightService.toggleQueue(player, mode)
    local source = player.source
    local label = GunfightService.label(mode)
    if GunfightService.playerMatch[source] then return false, Locale.t('Tu es déjà dans un 1VS1.') end
    if ChaseService.playerMatch[source] or CvcService.playerMatch[source] or GungameService.isBusy(source) then
        return false, Locale.t('Termine d\'abord ta partie en cours.')
    end

    local queuedMode, index = GunfightService.queuedIn(source)
    if queuedMode and queuedMode ~= mode then
        return false, Locale.t('Tu es déjà dans la file du %s.', Locale.t(GunfightService.label(queuedMode)))
    end
    if queuedMode then
        table.remove(GunfightService.queues[mode], index)
        TriggerClientEvent(Events.client.gunfightQueue, source, false)
        GunfightService.updateQueue(mode)
        return true, Locale.t('Tu as quitté la file du %s.', Locale.t(label))
    end

    local queue = GunfightService.queues[mode]
    queue[#queue + 1] = source
    GunfightService.updateQueue(mode)
    if GunfightService.playerMatch[source] then return true, Locale.t('Adversaire trouvé : le duel commence !') end
    return true, Locale.t('Tu rejoins la file du %s. Reparle à l\'organisateur pour la quitter.', Locale.t(label))
end

---Deux joueurs dans la file : la partie se lance tout de suite.
---@param mode string
function GunfightService.updateQueue(mode)
    local queue = GunfightService.queues[mode]
    while #queue >= GunfightService.PLAYERS do
        GunfightService.startMatch(mode, { table.remove(queue, 1), table.remove(queue, 1) })
    end
    for _, source in ipairs(queue) do
        TriggerClientEvent(Events.client.gunfightQueue, source, {
            count = #queue,
            needed = GunfightService.PLAYERS,
            label = GunfightService.label(mode),
        })
    end
end

---Déconnexion ou départ du Freeroam : sort de la file, ou abandonne la partie.
---@param source integer
function GunfightService.leave(source)
    local queuedMode, index = GunfightService.queuedIn(source)
    if queuedMode then
        table.remove(GunfightService.queues[queuedMode], index)
        GunfightService.updateQueue(queuedMode)
        return
    end

    local match = GunfightService.matches[GunfightService.playerMatch[source]]
    if not match or match.phase == 'ended' then return end
    GunfightService.playerMatch[source] = nil
    local opponent = GunfightService.opponentOf(match, source)
    GunfightService.endMatch(match, opponent, Locale.t('%s a abandonné : victoire par forfait.', GetPlayerName(source) or Locale.t('Ton adversaire')))
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

---@param mode string
---@param players integer[]
function GunfightService.startMatch(mode, players)
    GunfightService.nextId = GunfightService.nextId + 1
    local match = {
        id = GunfightService.nextId,
        mode = mode,
        bucket = GunfightService.config(mode).bucketBase + GunfightService.nextId,
        players = players,
        scores = {},
        round = 0,
        phase = 'pause',
        dead = {},
        identities = {},
    }
    GunfightService.matches[match.id] = match
    SetRoutingBucketPopulationEnabled(match.bucket, false)

    for _, source in ipairs(players) do
        local player = PlayerService.get(source)
        if player then match.identities[source] = { identifier = player.identifier, name = player.name } end
        match.scores[source] = 0
        GunfightService.playerMatch[source] = match.id
        SetPlayerRoutingBucket(source, match.bucket)
        TriggerClientEvent(Events.client.gunfightQueue, source, false)
    end
    Logger.info('[%s] partie n°%d : %s contre %s', mode, match.id,GetPlayerName(players[1]) or '?', GetPlayerName(players[2]) or '?')
    GunfightService.startRound(match)
end

---Nouvelle manche : chaque joueur à son départ (on échange les côtés à chaque manche), arme
---(et moto en 1VS1 Bike) redonnée.
---@param match GunfightMatch
function GunfightService.startRound(match)
    if match.phase == 'ended' then return end
    match.round = match.round + 1
    match.phase = 'countdown'
    match.dead = {}
    local config = GunfightService.config(match.mode)
    local spawns = config.spawns
    local center = (spawns[1].xyz + spawns[2].xyz) / 2

    for index, source in ipairs(match.players) do
        local side = (index + match.round) % 2 + 1
        TriggerClientEvent(Events.client.gunfightRound, source, {
            activity = match.mode,
            label = GunfightService.label(match.mode),
            round = match.round,
            opponent = GetPlayerName(GunfightService.opponentOf(match, source)) or '?',
            opponentId = GunfightService.opponentOf(match, source),
            spawn = spawns[side],
            vehicle = config.vehicle, -- nil en 1VS1 GunFight (à pied)
            arena = { center = center, radius = config.radius },
            kit = config.kit,
            countdown = config.countdown,
            roundTime = config.roundTime,
            outsideDamage = config.outsideDamage,
            roundsToWin = config.roundsToWin,
            scores = GunfightService.scoresFor(match, source),
        })
    end

    SetTimeout(config.countdown * 1000, function()
        if match.phase ~= 'countdown' then return end
        match.phase = 'running'
        match.endAt = GetGameTimer() + config.roundTime * 1000
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
        if match.dead[first] and match.dead[second] then return GunfightService.endRound(match, nil, Locale.t('Les deux joueurs sont tombés.')) end
        local winner = match.dead[first] and second or first
        return GunfightService.endRound(match, winner, Locale.t('%s a remporté le duel.', GetPlayerName(winner) or '?'))
    end

    local now = GetGameTimer()
    if now >= match.endAt then return GunfightService.endRound(match, nil, Locale.t('Temps écoulé : la manche est rejouée.')) end

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

    local config = GunfightService.config(match.mode)
    SetTimeout(config.roundPause * 1000, function()
        if match.phase ~= 'pause' then return end
        if winner and match.scores[winner] >= config.roundsToWin then
            return GunfightService.endMatch(match, winner, nil)
        end
        GunfightService.startRound(match)
    end)
end

---Met à jour l'ELO des deux joueurs dans le classement du mode ; renvoie le changement de chacun, par source.
---@param match GunfightMatch
---@param winner integer|nil nil = égalité
---@return table<integer, { before: integer, after: integer, delta: integer }>
function GunfightService.applyElo(match, winner)
    local a, b = match.players[1], match.players[2]
    local idA, idB = match.identities[a], match.identities[b]
    if not idA or not idB then return {} end
    local scoreA = winner == nil and 0.5 or (winner == a and 1 or 0)
    local changes = ActivityRating.safeApply(match.mode, { idA }, { idB }, scoreA)
    return { [a] = changes[idA.identifier], [b] = changes[idB.identifier] }
end

---Fin de partie : retour dans la zone safe du Freeroam.
---@param match GunfightMatch
---@param winner integer|nil
---@param reason string|nil
function GunfightService.endMatch(match, winner, reason)
    if match.phase == 'ended' then return end
    match.phase = 'ended'
    GunfightService.matches[match.id] = nil
    local elo = GunfightService.applyElo(match, winner)

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
                elo = elo[source],
            })
        end
    end
    Logger.info('[%s] partie n°%d terminée (%d - %d)', match.mode, match.id, match.scores[match.players[1]], match.scores[match.players[2]])
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
---@return boolean dans une file ou dans une partie
function GunfightService.isBusy(source)
    return GunfightService.playerMatch[source] ~= nil or GunfightService.queuedIn(source) ~= nil
end

---@param source integer
---@return string|nil partie en cours (mode spectateur admin)
function GunfightService.describePlayer(source)
    local match = GunfightService.matches[GunfightService.playerMatch[source]]
    if not match then return nil end
    return Locale.t('Partie de %s', Locale.t(GunfightService.label(match.mode)))
end
