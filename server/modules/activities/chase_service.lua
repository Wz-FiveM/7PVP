---Course poursuite (Config.Chase) : file d'attente, vote des véhicules, deux manches voleur / policier.
---Tout est décidé ici : positions et vitesses sont lues côté serveur (OneSync) toutes les
---CHECK_INTERVAL ms ; les clients créent seulement leur véhicule et affichent l'état reçu.
---@class ChaseMatch
---@field id integer
---@field bucket integer
---@field players integer[] { joueur 1, joueur 2 } (ordre d'arrivée dans la file)
---@field votes table<integer, string> modèle choisi par joueur
---@field scores table<integer, integer>
---@field round integer
---@field phase 'vote'|'countdown'|'running'|'pause'|'ended'
---@field thief integer|nil
---@field cop integer|nil
---@field endAt integer|nil GetGameTimer() de la fin du temps de la manche
---@field immobileSince integer|nil
---@field warns table<integer, integer> avertissements anti-PIT sur toute la partie
---@field headings table<integer, { at: integer, heading: number }[]> caps récents du véhicule de chaque joueur
---@field upsideSince table<integer, integer> depuis quand chaque véhicule est sur le toit
---@field lastPit table<integer, integer> dernier PIT compté contre chaque joueur (anti-doublon)
---@field identities table<integer, { identifier: string, name: string }> figées au départ (ELO)

---@class ChaseServiceModule
local ChaseService = PVP.define('ChaseService')
local ChaseRating = PVP.use('ChaseRating')
local ActivityService = PVP.use('ActivityService')
local PlayerService = PVP.use('PlayerService')
local ModeRegistry = PVP.use('ModeRegistry')
local Callback = PVP.use('Callback')
local Utils = PVP.use('Utils')
local Zones = PVP.use('Zones')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')

ChaseService.ID = 'chase'
ChaseService.CHECK_INTERVAL = 250
-- L'état (distance, temps, immobilisation) part vers les deux joueurs une fois sur deux
ChaseService.STATE_EVERY = 2

---@type integer[] joueurs en attente
ChaseService.queue = {}
---@type table<integer, ChaseMatch>
ChaseService.matches = {}
---@type table<integer, integer> joueur -> partie
ChaseService.playerMatch = {}
ChaseService.nextId = 0

function ChaseService.init()
    ActivityService.register(ChaseService.ID, ChaseService.toggleQueue)
    Callback.register(Events.callbacks.chaseVote, ChaseService.vote)
    -- Signalements du client : PIT subi (vérifié ici) ou saut trop important (le sien)
    RegisterNetEvent(Events.server.chaseReport, function(kind)
        ChaseService.onReport(source, kind)
    end)

    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        ChaseService.leave(playerSource)
    end)
end

-- ---------------------------------------------------------------------------
-- File d'attente
-- ---------------------------------------------------------------------------

---PNJ de la course : rejoint la file, ou la quitte si on y est déjà.
---@param player PvpPlayer
---@return boolean, string
function ChaseService.toggleQueue(player)
    local source = player.source
    if ChaseService.playerMatch[source] then return false, 'Tu es déjà dans une course.' end

    for index, queued in ipairs(ChaseService.queue) do
        if queued == source then
            table.remove(ChaseService.queue, index)
            TriggerClientEvent(Events.client.chaseQueue, source, false)
            return true, 'Tu as quitté la file de la course poursuite.'
        end
    end

    ChaseService.queue[#ChaseService.queue + 1] = source
    ChaseService.broadcastQueue()
    if #ChaseService.queue >= 2 then
        ChaseService.startMatch(table.remove(ChaseService.queue, 1), table.remove(ChaseService.queue, 1))
        ChaseService.broadcastQueue()
        return true, 'Adversaire trouvé : la course commence !'
    end
    return true, 'Tu attends un adversaire. Reparle à l\'organisateur pour quitter la file.'
end

function ChaseService.broadcastQueue()
    for _, source in ipairs(ChaseService.queue) do
        TriggerClientEvent(Events.client.chaseQueue, source, { count = #ChaseService.queue, needed = 2 })
    end
end

---Déconnexion ou départ du Freeroam : sort de la file ou abandonne la partie.
---@param source integer
function ChaseService.leave(source)
    for index, queued in ipairs(ChaseService.queue) do
        if queued == source then
            table.remove(ChaseService.queue, index)
            ChaseService.broadcastQueue()
            return
        end
    end
    local match = ChaseService.matches[ChaseService.playerMatch[source]]
    if match and match.phase ~= 'ended' then
        local other = ChaseService.opponent(match, source)
        ChaseService.endMatch(match, other, 'Ton adversaire a quitté la course : victoire par forfait.', source)
    end
end

-- ---------------------------------------------------------------------------
-- Partie
-- ---------------------------------------------------------------------------

---@param match ChaseMatch
---@param source integer
---@return integer
function ChaseService.opponent(match, source)
    return match.players[1] == source and match.players[2] or match.players[1]
end

---@param a integer joueur 1
---@param b integer joueur 2
function ChaseService.startMatch(a, b)
    ChaseService.nextId = ChaseService.nextId + 1
    local match = {
        id = ChaseService.nextId,
        bucket = Config.Chase.bucketBase + ChaseService.nextId,
        players = { a, b },
        votes = {},
        scores = { [a] = 0, [b] = 0 },
        warns = { [a] = 0, [b] = 0 },
        headings = {},
        upsideSince = {},
        lastPit = {},
        identities = {},
        round = 0,
        phase = 'vote',
    }
    for _, source in ipairs(match.players) do
        local player = PlayerService.get(source)
        if player then match.identities[source] = { identifier = player.identifier, name = player.name } end
    end
    ChaseService.matches[match.id] = match
    SetRoutingBucketPopulationEnabled(match.bucket, false)

    local vehicles = Config.Chase.vehicles
    for _, source in ipairs(match.players) do
        ChaseService.playerMatch[source] = match.id
        SetPlayerRoutingBucket(source, match.bucket)
        TriggerClientEvent(Events.client.chaseQueue, source, false)
        TriggerClientEvent(Events.client.chaseVote, source, {
            vehicles = vehicles,
            seconds = Config.Chase.voteTime,
            opponent = GetPlayerName(ChaseService.opponent(match, source)) or 'Adversaire',
        })
    end
    Logger.info('[course] partie n°%d : %s contre %s', match.id, GetPlayerName(a) or a, GetPlayerName(b) or b)

    SetTimeout(Config.Chase.voteTime * 1000, function()
        if match.phase == 'vote' then ChaseService.startRound(match) end
    end)
end

---@param source integer
---@param model any
function ChaseService.vote(source, model)
    local match = ChaseService.matches[ChaseService.playerMatch[source]]
    if not match or match.phase ~= 'vote' then return { ok = false } end
    for _, vehicle in ipairs(Config.Chase.vehicles) do
        if vehicle.model == model then
            match.votes[source] = model
            if match.votes[match.players[1]] and match.votes[match.players[2]] then ChaseService.startRound(match) end
            return { ok = true, message = ('Vote : %s'):format(vehicle.label) }
        end
    end
    return { ok = false, message = 'Véhicule inconnu.' }
end

---@param match ChaseMatch
---@param source integer
---@return string modèle voté (ou tiré au sort sans vote)
function ChaseService.voteOf(match, source)
    if not match.votes[source] then match.votes[source] = Utils.pick(Config.Chase.vehicles).model end
    return match.votes[source]
end

---Manche 1 : voleur = joueur 1, véhicule du joueur 1 ; manche 2 : tout est inversé.
---@param match ChaseMatch
function ChaseService.startRound(match)
    if match.phase == 'ended' then return end
    match.round = match.round + 1
    match.phase = 'countdown'
    match.immobileSince = nil
    match.headings = { [match.players[1]] = {}, [match.players[2]] = {} }
    match.upsideSince = {}
    local first = match.round == 1
    match.thief = first and match.players[1] or match.players[2]
    match.cop = first and match.players[2] or match.players[1]
    local model = ChaseService.voteOf(match, match.thief)

    local start = Utils.pick(Config.Chase.starts)
    local radians = math.rad(start.w)
    local back = vector3(math.sin(radians), -math.cos(radians), 0.0) * Config.Chase.copGap
    local spawns = {
        [match.thief] = start,
        [match.cop] = vector4(start.x + back.x, start.y + back.y, start.z, start.w),
    }

    for _, source in ipairs(match.players) do
        TriggerClientEvent(Events.client.chaseRound, source, {
            round = match.round,
            role = source == match.thief and 'thief' or 'cop',
            model = model,
            spawn = spawns[source],
            start = start, -- calé sur la route par chaque client (voir Chase.roadSpawn)
            copGap = Config.Chase.copGap,
            countdown = Config.Chase.countdown,
            roundTime = Config.Chase.roundTime,
            escapeDistance = Config.Chase.escapeDistance,
            arrestTime = Config.Chase.arrestTime,
            scores = { me = match.scores[source], opponent = match.scores[ChaseService.opponent(match, source)] },
            opponent = GetPlayerName(ChaseService.opponent(match, source)) or 'Adversaire',
            opponentId = ChaseService.opponent(match, source),
            warns = match.warns[source],
            rules = { pit = Config.Chase.pit, stunt = Config.Chase.stunt, damage = Config.Chase.damageRealism },
        })
    end

    SetTimeout(Config.Chase.countdown * 1000, function()
        if match.phase ~= 'countdown' then return end
        match.phase = 'running'
        match.endAt = GetGameTimer() + Config.Chase.roundTime * 1000
        CreateThread(function()
            ChaseService.runRound(match)
        end)
    end)
end

---@param match ChaseMatch
function ChaseService.runRound(match)
    local tick = 0
    while match.phase == 'running' do
        Wait(ChaseService.CHECK_INTERVAL)
        if match.phase ~= 'running' then return end
        tick = tick + 1
        ChaseService.check(match, tick % ChaseService.STATE_EVERY == 0)
    end
end

---@param ped integer
---@return number km/h du véhicule du joueur (ou du joueur à pied)
function ChaseService.speedOf(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    return #GetEntityVelocity(vehicle ~= 0 and vehicle or ped) * 3.6
end

---@param match ChaseMatch
---@param sendState boolean
function ChaseService.check(match, sendState)
    local thiefPed, copPed = GetPlayerPed(match.thief), GetPlayerPed(match.cop)
    if thiefPed == 0 or copPed == 0 then return end
    local now = GetGameTimer()

    if GetEntityHealth(thiefPed) <= 0 then return ChaseService.endRound(match, match.cop, 'Le voleur est hors d\'état de nuire.') end
    if GetEntityHealth(copPed) <= 0 then return ChaseService.endRound(match, match.thief, 'Le policier est hors course.') end

    local thiefPos, copPos = GetEntityCoords(thiefPed), GetEntityCoords(copPed)
    local distance = #(thiefPos.xy - copPos.xy)
    if distance >= Config.Chase.escapeDistance then
        return ChaseService.endRound(match, match.thief, 'Le voleur a semé le policier.')
    end

    -- Immobilisé : à l'arrêt, avec le policier collé à lui
    if ChaseService.speedOf(thiefPed) < Config.Chase.arrestSpeed and distance <= Config.Chase.arrestDistance then
        match.immobileSince = match.immobileSince or now
        if now - match.immobileSince >= Config.Chase.arrestTime * 1000 then
            return ChaseService.endRound(match, match.cop, 'Le policier a immobilisé le voleur.')
        end
    else
        match.immobileSince = nil
    end

    if now >= match.endAt then
        return ChaseService.endRound(match, match.cop, 'Temps écoulé : le voleur n\'a pas réussi à fuir.')
    end

    -- Véhicules : dégâts, sur le toit, et caps récents (pour vérifier les PIT signalés)
    local health = {}
    for _, source in ipairs(match.players) do
        local result = ChaseService.checkVehicle(match, source, now)
        if result == false then return end
        health[source] = result
    end

    if sendState then
        local arrest = match.immobileSince and (now - match.immobileSince) / (Config.Chase.arrestTime * 1000) or 0
        local remaining = math.max(0, math.ceil((match.endAt - now) / 1000))
        -- Ni distance ni position de l'adversaire : chacun doit le chercher (ou le semer) à vue
        for _, source in ipairs(match.players) do
            TriggerClientEvent(Events.client.chaseState, source, {
                remaining = remaining,
                arrest = arrest,
                health = health[source],
                warns = match.warns[source],
                maxWarns = Config.Chase.pit.maxWarns,
            })
        end
    end
end

ChaseService.HEADING_HISTORY = 3000

---@param a number
---@param b number
---@return number écart entre deux caps, de 0 à 180 degrés
function ChaseService.headingGap(a, b)
    return math.abs((a - b + 540.0) % 360.0 - 180.0)
end

---Véhicule d'un joueur : trop endommagé ou sur le toit, il perd la manche.
---@param match ChaseMatch
---@param source integer
---@param now integer
---@return integer|nil|false santé du véhicule en % (nil : à pied), false : la manche est finie
function ChaseService.checkVehicle(match, source, now)
    local vehicle = GetVehiclePedIsIn(GetPlayerPed(source), false)
    if vehicle == 0 then return nil end
    local other = ChaseService.opponent(match, source)
    local name = GetPlayerName(source) or 'Un joueur'

    local engine, body = GetVehicleEngineHealth(vehicle), GetVehicleBodyHealth(vehicle)
    local damage = Config.Chase.damage
    if engine < damage.minEngine or body < damage.minBody then
        ChaseService.endRound(match, other, ('Véhicule de %s trop endommagé.'):format(name))
        return false
    end

    local roof = Config.Chase.roof
    if math.abs(GetEntityRotation(vehicle).y) >= roof.angle then
        match.upsideSince[source] = match.upsideSince[source] or now
        if now - match.upsideSince[source] >= roof.time * 1000 then
            ChaseService.endRound(match, other, ('Véhicule de %s sur le toit.'):format(name))
            return false
        end
    else
        match.upsideSince[source] = nil
    end

    local history = match.headings[source]
    history[#history + 1] = { at = now, heading = GetEntityHeading(vehicle) }
    while history[1] and now - history[1].at > ChaseService.HEADING_HISTORY do table.remove(history, 1) end

    local worst = math.min(engine, body)
    return math.max(0, math.floor((worst - damage.minEngine) / (1000.0 - damage.minEngine) * 100))
end

---Signalement d'un client : 'pit' (il vient d'être PIT par son adversaire) ou 'stunt' (son propre saut).
---@param source integer
---@param kind any
function ChaseService.onReport(source, kind)
    local match = ChaseService.matches[ChaseService.playerMatch[source]]
    if not match or match.phase ~= 'running' then return end
    local other = ChaseService.opponent(match, source)

    if kind == 'stunt' then
        return ChaseService.endRound(match, other, ('Saut trop important de %s.'):format(GetPlayerName(source) or 'un joueur'))
    end
    if kind == 'pit' then ChaseService.onPit(match, source, other) end
end

---PIT signalé par la victime : vérifié (adversaire à côté, victime qui a pivoté), puis
---avertissement pour l'auteur et réparation du véhicule de la victime.
---@param match ChaseMatch
---@param victim integer
---@param attacker integer
function ChaseService.onPit(match, victim, attacker)
    local now = GetGameTimer()
    local pit = Config.Chase.pit
    if match.lastPit[victim] and now - match.lastPit[victim] < pit.window * 2000 then return end

    local victimVehicle = GetVehiclePedIsIn(GetPlayerPed(victim), false)
    local attackerVehicle = GetVehiclePedIsIn(GetPlayerPed(attacker), false)
    if victimVehicle == 0 or attackerVehicle == 0 then return end
    if #(GetEntityCoords(victimVehicle) - GetEntityCoords(attackerVehicle)) > pit.maxDistance then return end

    -- La victime a bien pivoté ces dernières secondes (pas un simple accrochage)
    local history, turned = match.headings[victim], 0
    for _, sample in ipairs(history) do
        turned = math.max(turned, ChaseService.headingGap(sample.heading, GetEntityHeading(victimVehicle)))
    end
    if turned < pit.turnAngle * 0.7 then return end

    match.lastPit[victim] = now
    match.warns[attacker] = match.warns[attacker] + 1
    TriggerClientEvent(Events.client.chaseRepair, victim)
    local warns = match.warns[attacker]
    TriggerClientEvent(Events.client.notify, attacker,
        ('PIT interdit : avertissement %d/%d.'):format(warns, pit.maxWarns), 'error')
    TriggerClientEvent(Events.client.notify, victim,
        'Ton adversaire t\'a fait un PIT : il prend un avertissement, ton véhicule est réparé.', 'info')

    if warns >= pit.maxWarns then
        ChaseService.endRound(match, victim, ('%s a fait trop de PIT.'):format(GetPlayerName(attacker) or 'Ton adversaire'))
    end
end

---@param match ChaseMatch
---@param winner integer
---@param reason string
function ChaseService.endRound(match, winner, reason)
    if match.phase ~= 'running' then return end
    match.phase = 'pause'
    match.scores[winner] = match.scores[winner] + 1
    for _, source in ipairs(match.players) do
        TriggerClientEvent(Events.client.chaseRoundEnd, source, {
            won = source == winner,
            reason = reason,
            round = match.round,
            scores = { me = match.scores[source], opponent = match.scores[ChaseService.opponent(match, source)] },
        })
    end

    SetTimeout(Config.Chase.roundPause * 1000, function()
        if match.phase ~= 'pause' then return end
        if match.round >= 2 then
            ChaseService.finish(match)
        else
            ChaseService.startRound(match)
        end
    end)
end

---Fin des deux manches : vainqueur au score, 1 - 1 = égalité.
---@param match ChaseMatch
function ChaseService.finish(match)
    local a, b = match.players[1], match.players[2]
    local winner = match.scores[a] > match.scores[b] and a or (match.scores[b] > match.scores[a] and b or nil)
    ChaseService.endMatch(match, winner, nil)
end

---Termine la partie et ramène les joueurs dans la zone safe du Freeroam.
---@param match ChaseMatch
---@param winner integer|nil nil = égalité
---@param reason string|nil
---@param leaver integer|nil joueur parti (déconnecté) : on ne le ramène pas
---Met à jour l'ELO des deux joueurs ; renvoie le changement de chacun, par source.
---@param match ChaseMatch
---@param winner integer|nil nil = égalité
---@return table<integer, { before: integer, after: integer, delta: integer }>
function ChaseService.applyElo(match, winner)
    local a, b = match.players[1], match.players[2]
    local idA, idB = match.identities[a], match.identities[b]
    if not idA or not idB or idA.identifier == idB.identifier then return {} end
    local scoreA = winner == nil and 0.5 or (winner == a and 1 or 0)
    local ok, changes = pcall(ChaseRating.applyMatch, idA, idB, scoreA)
    if not ok then
        Logger.error('[course] ELO non enregistré : %s', changes)
        return {}
    end
    return { [a] = changes[idA.identifier], [b] = changes[idB.identifier] }
end

function ChaseService.endMatch(match, winner, reason, leaver)
    if match.phase == 'ended' then return end
    local played = match.phase ~= 'vote' -- une partie quittée pendant le vote ne compte pas
    match.phase = 'ended'
    ChaseService.matches[match.id] = nil
    local elo = played and ChaseService.applyElo(match, winner) or {}

    local freeroam = ModeRegistry.getConfig('freeroam')
    for _, source in ipairs(match.players) do
        ChaseService.playerMatch[source] = nil
        if source ~= leaver and PlayerService.get(source) then
            if freeroam then SetPlayerRoutingBucket(source, freeroam.bucket) end
            local result = winner == nil and 'draw' or (winner == source and 'won' or 'lost')
            TriggerClientEvent(Events.client.chaseEnd, source, {
                result = result,
                reason = reason,
                scores = { me = match.scores[source], opponent = match.scores[ChaseService.opponent(match, source)] },
                spawn = Zones.randomSpawn('freeroam'),
                elo = elo[source],
            })
        end
    end
    Logger.info('[course] partie n°%d terminée', match.id)
end
