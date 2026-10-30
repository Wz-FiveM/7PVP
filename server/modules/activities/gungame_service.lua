---Gungame du Freeroam (Config.Gungame) : chacun pour soi, une arme de plus à chaque kill, le premier
---qui fait un kill avec la dernière arme gagne. Le serveur décide de tout (niveaux, kills, réapparitions,
---tirs autorisés, fin de partie) ; les clients placent le joueur, donnent l'arme du niveau et affichent l'état.
---@class GungameStats
---@field name string
---@field level integer
---@field kills integer
---@field deaths integer
---@field reachedAt integer GetGameTimer() du dernier changement de niveau (départage à égalité)
---@field alive boolean
---@field protectedUntil integer GetGameTimer() de fin de la protection d'apparition
---@field left boolean|nil a quitté la partie

---@class GungameMatch
---@field id integer
---@field bucket integer
---@field players integer[] joueurs encore dans la partie
---@field order integer[] tous les joueurs passés par la partie (classement final)
---@field stats table<integer, GungameStats> par joueur, gardées après un départ
---@field identities table<integer, ActivityRatingIdentity> figées à l'arrivée (ELO)
---@field recentSpawns { coords: vector3, at: integer }[] apparitions récentes (évite deux joueurs au même endroit)
---@field phase 'countdown'|'running'|'ended'
---@field runAt integer GetGameTimer() de la fin du compte à rebours
---@field endAt integer GetGameTimer() de la fin de la partie

---@class GungameServiceModule
local GungameService = PVP.define('GungameService')
local ActivityService = PVP.use('ActivityService')
local ActivityRating = PVP.use('ActivityRating')
local ChaseService = PVP.use('ChaseService')
local CvcService = PVP.use('CvcService')
local GunfightService = PVP.use('GunfightService')
local PlayerService = PVP.use('PlayerService')
local ModeRegistry = PVP.use('ModeRegistry')
local Zones = PVP.use('Zones')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

GungameService.ID = 'gungame'
GungameService.TICK = 1000 -- ms entre deux envois de l'état (temps, classement)
GungameService.TOP = 5 -- joueurs affichés dans le classement du HUD et des résultats
GungameService.SPAWN_CHOICES = 3 -- tirage parmi les points les plus éloignés des autres joueurs
GungameService.RECENT_SPAWN = 5000 -- ms : un point qui vient de servir compte comme occupé
GungameService.KILL_RANGE = 300.0 -- m : au-delà, le kill signalé par la victime est refusé

---@type integer[] joueurs en attente
GungameService.queue = {}
---@type integer|nil GetGameTimer() du lancement prévu de la prochaine partie
GungameService.startAt = nil
---@type table<integer, GungameMatch>
GungameService.matches = {}
---@type table<integer, integer> joueur -> partie
GungameService.playerMatch = {}
GungameService.nextId = 0

function GungameService.init()
    ActivityService.register(GungameService.ID, GungameService.toggleQueue)

    -- Envoyé par le joueur mort : son tueur et l'arme (couteau : la victime recule d'un niveau)
    RegisterNetEvent(Events.server.gungameDied, function(killerId, weapon)
        GungameService.onDied(source, killerId, weapon)
    end)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        GungameService.leave(playerSource)
    end)
end

-- ---------------------------------------------------------------------------
-- File d'attente
-- ---------------------------------------------------------------------------

---@param source integer
---@return integer|nil position dans la file
function GungameService.queueIndex(source)
    for index, queued in ipairs(GungameService.queue) do
        if queued == source then return index end
    end
    return nil
end

---@param source integer
---@return boolean dans une autre partie ou une autre file du Freeroam
function GungameService.busyElsewhere(source)
    if ChaseService.playerMatch[source] or CvcService.playerMatch[source] or GunfightService.isBusy(source) then return true end
    for _, queue in ipairs({ ChaseService.queue, CvcService.queue }) do
        for _, queued in ipairs(queue) do
            if queued == source then return true end
        end
    end
    return false
end

---PNJ du Gungame : rejoint une partie en cours qui a de la place, sinon la file ; la quitte si on y est déjà.
---@param player PvpPlayer
---@return boolean, string
function GungameService.toggleQueue(player)
    local source = player.source
    if GungameService.playerMatch[source] then return false, Locale.t('Tu es déjà dans une partie de Gungame.') end

    local index = GungameService.queueIndex(source)
    if index then
        table.remove(GungameService.queue, index)
        TriggerClientEvent(Events.client.gungameQueue, source, false)
        GungameService.updateQueue()
        return true, Locale.t('Tu as quitté la file du Gungame.')
    end
    if GungameService.busyElsewhere(source) then
        return false, Locale.t('Termine d\'abord ta partie en cours (ou quitte sa file).')
    end

    local match = GungameService.joinableMatch()
    if match then
        GungameService.addPlayer(match, source)
        return true, Locale.t('Tu rejoins la partie de Gungame en cours !')
    end
    GungameService.queue[#GungameService.queue + 1] = source
    GungameService.updateQueue()
    if GungameService.playerMatch[source] then return true, Locale.t('La partie de Gungame commence !') end
    return true, Locale.t('Tu rejoins la file du Gungame. Reparle à l\'organisateur pour la quitter.')
end

---Compte à rebours dès qu'il y a assez de joueurs ; partie lancée tout de suite si c'est plein.
function GungameService.updateQueue()
    local settings = Config.Gungame
    local count = #GungameService.queue
    if count < settings.minPlayers then
        GungameService.startAt = nil
    elseif count >= settings.maxPlayers then
        GungameService.launch()
        return
    elseif not GungameService.startAt then
        GungameService.startAt = GetGameTimer() + settings.queueDelay * 1000
        local planned = GungameService.startAt
        SetTimeout(settings.queueDelay * 1000, function()
            if GungameService.startAt == planned then GungameService.launch() end
        end)
    end

    local startIn = GungameService.startAt and math.ceil((GungameService.startAt - GetGameTimer()) / 1000) or nil
    for _, source in ipairs(GungameService.queue) do
        TriggerClientEvent(Events.client.gungameQueue, source, {
            count = count, needed = settings.minPlayers, max = settings.maxPlayers, startIn = startIn,
        })
    end
end

function GungameService.launch()
    GungameService.startAt = nil
    -- Partis entre-temps dans une autre partie du Freeroam : retirés de la file
    for index = #GungameService.queue, 1, -1 do
        local source = GungameService.queue[index]
        if ChaseService.playerMatch[source] or CvcService.playerMatch[source] or GunfightService.playerMatch[source] then
            table.remove(GungameService.queue, index)
            TriggerClientEvent(Events.client.gungameQueue, source, false)
        end
    end
    if #GungameService.queue < Config.Gungame.minPlayers then return GungameService.updateQueue() end

    local players = {}
    while #GungameService.queue > 0 and #players < Config.Gungame.maxPlayers do
        players[#players + 1] = table.remove(GungameService.queue, 1)
    end
    GungameService.startMatch(players)
    GungameService.updateQueue()
end

---@return GungameMatch|nil partie en cours qui a encore de la place et assez de temps
function GungameService.joinableMatch()
    local limit = GetGameTimer() + Config.Gungame.joinMinRemaining * 1000
    for _, match in pairs(GungameService.matches) do
        if match.phase ~= 'ended' and #match.players < Config.Gungame.maxPlayers and match.endAt >= limit then
            return match
        end
    end
    return nil
end

---Déconnexion ou départ du Freeroam : sort de la file, ou quitte la partie (comptée comme une défaite).
---@param source integer
function GungameService.leave(source)
    local index = GungameService.queueIndex(source)
    if index then
        table.remove(GungameService.queue, index)
        GungameService.updateQueue()
        return
    end

    local match = GungameService.matches[GungameService.playerMatch[source]]
    if not match or match.phase == 'ended' then return end
    GungameService.playerMatch[source] = nil
    match.stats[source].left = true
    for position, member in ipairs(match.players) do
        if member == source then table.remove(match.players, position) break end
    end
    if #match.players < Config.Gungame.minPlayers then
        GungameService.endMatch(match, Locale.t('Plus assez de joueurs : la partie s\'arrête.'))
    end
end

-- ---------------------------------------------------------------------------
-- Partie
-- ---------------------------------------------------------------------------

---@return { center: vector3, radius: number } zone de combat (relue à chaque fois : spawns modifiables en jeu)
function GungameService.arena()
    local center = vector3(0.0, 0.0, 0.0)
    local spawns = Config.Gungame.spawns
    for _, spawn in ipairs(spawns) do center = center + spawn.xyz end
    return { center = center / #spawns, radius = Config.Gungame.radius }
end

---@param players integer[]
function GungameService.startMatch(players)
    local settings = Config.Gungame
    GungameService.nextId = GungameService.nextId + 1
    local now = GetGameTimer()
    ---@type GungameMatch
    local match = {
        id = GungameService.nextId,
        bucket = settings.bucketBase + GungameService.nextId,
        players = {},
        order = {},
        stats = {},
        identities = {},
        recentSpawns = {},
        phase = 'countdown',
        runAt = now + settings.countdown * 1000,
        endAt = now + (settings.countdown + settings.matchTime) * 1000,
    }
    GungameService.matches[match.id] = match
    SetRoutingBucketPopulationEnabled(match.bucket, false)

    for _, source in ipairs(players) do
        GungameService.addPlayer(match, source)
    end
    Logger.info('[gungame] partie n°%d : %d joueurs', match.id, #players)

    SetTimeout(settings.countdown * 1000, function()
        if match.phase ~= 'countdown' then return end
        match.phase = 'running'
    end)
    CreateThread(function()
        GungameService.run(match)
    end)
end

---Arrivée d'un joueur (au lancement ou en cours de partie, au niveau du dernier joueur).
---@param match GungameMatch
---@param source integer
function GungameService.addPlayer(match, source)
    local settings = Config.Gungame
    local now = GetGameTimer()
    local player = PlayerService.get(source)
    if player then match.identities[source] = { identifier = player.identifier, name = player.name } end

    -- Un joueur parti qui revient reprend son niveau et ses kills
    local stats = match.stats[source]
    if not stats then
        stats = {
            name = GetPlayerName(source) or '?',
            level = GungameService.lowestLevel(match),
            kills = 0,
            deaths = 0,
            reachedAt = now,
        }
        match.stats[source] = stats
        match.order[#match.order + 1] = source
    end
    stats.alive = true
    stats.left = nil
    local countdown = math.max(0, math.ceil((match.runAt - now) / 1000))
    stats.protectedUntil = now + (countdown + settings.spawnProtection) * 1000
    match.players[#match.players + 1] = source
    GungameService.playerMatch[source] = match.id
    SetPlayerRoutingBucket(source, match.bucket)

    TriggerClientEvent(Events.client.gungameQueue, source, false)
    TriggerClientEvent(Events.client.gungameStart, source, {
        level = stats.level,
        spawn = GungameService.chooseSpawn(match),
        arena = GungameService.arena(),
        countdown = countdown,
        remaining = math.max(0, math.ceil((match.endAt - now) / 1000)),
        outsideDamage = settings.outsideDamage,
        protection = settings.spawnProtection,
    })
end

---@param match GungameMatch
---@return integer niveau de départ d'un nouveau joueur : celui du dernier joueur en jeu (1 au lancement)
function GungameService.lowestLevel(match)
    local lowest
    for _, source in ipairs(match.players) do
        local level = match.stats[source].level
        if not lowest or level < lowest then lowest = level end
    end
    return lowest or 1
end

---Point d'apparition le plus loin des autres joueurs (et des apparitions récentes), tiré parmi les meilleurs.
---@param match GungameMatch
---@return vector4
function GungameService.chooseSpawn(match)
    local now = GetGameTimer()
    local taken = {}
    for _, source in ipairs(match.players) do
        local ped = GetPlayerPed(source)
        if match.stats[source].alive and ped ~= 0 then taken[#taken + 1] = GetEntityCoords(ped) end
    end
    for index = #match.recentSpawns, 1, -1 do
        local recent = match.recentSpawns[index]
        if now - recent.at < GungameService.RECENT_SPAWN then
            taken[#taken + 1] = recent.coords
        else
            table.remove(match.recentSpawns, index)
        end
    end

    local candidates = {}
    for _, spawn in ipairs(Config.Gungame.spawns) do
        local nearest = math.huge
        for _, coords in ipairs(taken) do
            nearest = math.min(nearest, #(spawn.xyz - coords))
        end
        candidates[#candidates + 1] = { spawn = spawn, distance = nearest }
    end
    table.sort(candidates, function(a, b) return a.distance > b.distance end)

    local choice = candidates[math.random(math.min(GungameService.SPAWN_CHOICES, #candidates))].spawn
    match.recentSpawns[#match.recentSpawns + 1] = { coords = choice.xyz, at = now }
    return choice
end

---Fin du temps et état envoyé chaque seconde (temps restant, classement).
---@param match GungameMatch
function GungameService.run(match)
    while match.phase ~= 'ended' do
        Wait(GungameService.TICK)
        if match.phase == 'ended' then return end
        if GetGameTimer() >= match.endAt then
            local ranking = GungameService.ranking(match, false)
            local leader = ranking[1] and match.stats[ranking[1]].name or '?'
            return GungameService.endMatch(match, Locale.t('Temps écoulé : %s est le plus avancé.', leader))
        end
        GungameService.broadcastState(match)
    end
end

---@param match GungameMatch
---@param includeLeft boolean avec les joueurs partis (classés derniers)
---@return integer[] joueurs du premier au dernier
function GungameService.ranking(match, includeLeft)
    local list = {}
    for _, source in ipairs(includeLeft and match.order or match.players) do list[#list + 1] = source end
    table.sort(list, function(a, b)
        local first, second = match.stats[a], match.stats[b]
        if (first.left == true) ~= (second.left == true) then return not first.left end
        if first.level ~= second.level then return first.level > second.level end
        if first.kills ~= second.kills then return first.kills > second.kills end
        if first.deaths ~= second.deaths then return first.deaths < second.deaths end
        if first.reachedAt ~= second.reachedAt then return first.reachedAt < second.reachedAt end
        return a < b
    end)
    return list
end

---@param match GungameMatch
---@param ranking integer[]
---@return { name: string, level: integer, kills: integer }[]
function GungameService.top(match, ranking)
    local top = {}
    for place = 1, math.min(GungameService.TOP, #ranking) do
        local stats = match.stats[ranking[place]]
        top[place] = { name = stats.name, level = math.min(stats.level, #Config.Gungame.levels), kills = stats.kills }
    end
    return top
end

---@param match GungameMatch
function GungameService.broadcastState(match)
    local ranking = GungameService.ranking(match, false)
    local top = GungameService.top(match, ranking)
    local remaining = math.max(0, math.ceil((match.endAt - GetGameTimer()) / 1000))
    for place, source in ipairs(ranking) do
        local stats = match.stats[source]
        TriggerClientEvent(Events.client.gungameState, source, {
            remaining = remaining,
            rank = place,
            players = #ranking,
            kills = stats.kills,
            deaths = stats.deaths,
            top = top,
        })
    end
end

---@param weapon any hash envoyé par le client (signé ou non)
---@return boolean
function GungameService.isKnife(weapon)
    weapon = tonumber(weapon)
    if not weapon then return false end
    return (math.floor(weapon) & 0xFFFFFFFF) == (GetHashKey(Config.Gungame.knife) & 0xFFFFFFFF)
end

---@param match GungameMatch
---@param victim integer
---@param killerId any server id du tueur, calculé par le client de la victime
---@return integer|nil tueur, s'il est dans la même partie et assez proche
function GungameService.resolveKiller(match, victim, killerId)
    killerId = tonumber(killerId)
    if not killerId or killerId == victim or GungameService.playerMatch[killerId] ~= match.id then return nil end
    local killerPed, victimPed = GetPlayerPed(killerId), GetPlayerPed(victim)
    if killerPed == 0 or victimPed == 0 then return nil end
    if #(GetEntityCoords(killerPed) - GetEntityCoords(victimPed)) > GungameService.KILL_RANGE then return nil end
    return killerId
end

---Mort d'un joueur : le tueur passe à l'arme suivante (ou gagne avec la dernière), la victime réapparaît.
---@param source integer victime
---@param killerId any
---@param weapon any hash de l'arme qui a tué
function GungameService.onDied(source, killerId, weapon)
    local match = GungameService.matches[GungameService.playerMatch[source]]
    if not match or match.phase == 'ended' then return end
    local victim = match.stats[source]
    if not victim.alive then return end
    victim.alive = false
    victim.deaths = victim.deaths + 1

    local settings = Config.Gungame
    local killer = match.phase == 'running' and GungameService.resolveKiller(match, source, killerId) or nil
    local knife = killer ~= nil and GungameService.isKnife(weapon)
    GungameService.broadcastKill(match, killer, source, knife)
    SetTimeout(settings.respawnDelay * 1000, function()
        GungameService.respawn(match, source)
    end)

    if killer then
        local stats = match.stats[killer]
        stats.kills = stats.kills + 1
        if knife and settings.knifeDemotes then GungameService.setLevel(match, source, victim.level - 1, 'knifed') end
        if stats.level >= #settings.levels then
            -- Kill avec la dernière arme : la partie est gagnée (niveau « au-delà » pour le classement)
            stats.level = #settings.levels + 1
            return GungameService.endMatch(match, Locale.t('%s a terminé le Gungame !', stats.name))
        end
        GungameService.setLevel(match, killer, stats.level + 1, 'kill')
    elseif match.phase == 'running' and settings.suicideDemotes then
        GungameService.setLevel(match, source, victim.level - 1, 'suicide')
    end
end

---@param match GungameMatch
---@param source integer
---@param level integer borné entre 1 et la dernière arme
---@param reason 'kill'|'knifed'|'suicide'
function GungameService.setLevel(match, source, level, reason)
    local stats = match.stats[source]
    level = math.max(1, math.min(level, #Config.Gungame.levels))
    if level == stats.level then return end
    stats.level = level
    stats.reachedAt = GetGameTimer()
    TriggerClientEvent(Events.client.gungameLevel, source, { level = level, reason = reason })
end

---Fil des kills de la partie.
---@param match GungameMatch
---@param killer integer|nil
---@param victim integer
---@param knife boolean
function GungameService.broadcastKill(match, killer, victim, knife)
    local data = {
        killer = killer and match.stats[killer].name or nil,
        victim = match.stats[victim].name,
        knife = knife,
    }
    for _, source in ipairs(match.players) do
        TriggerClientEvent(Events.client.gungameKill, source, data)
    end
end

---@param match GungameMatch
---@param source integer
function GungameService.respawn(match, source)
    if match.phase == 'ended' or GungameService.playerMatch[source] ~= match.id then return end
    local stats = match.stats[source]
    stats.alive = true
    stats.protectedUntil = GetGameTimer() + Config.Gungame.spawnProtection * 1000
    TriggerClientEvent(Events.client.gungameSpawn, source, {
        spawn = GungameService.chooseSpawn(match),
        level = stats.level,
        protection = Config.Gungame.spawnProtection,
    })
end

---ELO en chacun pour soi : chaque joueur est comparé à tous les autres selon le classement final.
---@param match GungameMatch
---@param ranking integer[] avec les joueurs partis (derniers, à égalité)
---@return table<integer, { before: integer, after: integer, delta: integer }> par source
function GungameService.applyElo(match, ranking)
    local entries, last = {}, #ranking
    for place, source in ipairs(ranking) do
        local identity = match.identities[source]
        if identity then
            identity.left = match.stats[source].left
            entries[#entries + 1] = { identity = identity, place = identity.left and last or place }
        end
    end
    local changes = ActivityRating.safeApplyFreeForAll(GungameService.ID, entries)
    local bySource = {}
    for source, identity in pairs(match.identities) do bySource[source] = changes[identity.identifier] end
    return bySource
end

---Fin de partie : classement, ELO, retour dans la zone safe du Freeroam.
---@param match GungameMatch
---@param reason string|table message à traduire (Locale.t)
function GungameService.endMatch(match, reason)
    if match.phase == 'ended' then return end
    match.phase = 'ended'
    GungameService.matches[match.id] = nil

    local ranking = GungameService.ranking(match, true)
    local winner = ranking[1] and not match.stats[ranking[1]].left and ranking[1] or nil
    local top = GungameService.top(match, ranking)
    local elo = GungameService.applyElo(match, ranking)

    local freeroam = ModeRegistry.getConfig('freeroam')
    for place, source in ipairs(ranking) do
        -- Ceux qui sont partis (GungameService.leave) ne sont plus dans la partie : rien à leur envoyer
        local inMatch = GungameService.playerMatch[source] == match.id
        if inMatch then GungameService.playerMatch[source] = nil end
        if inMatch and PlayerService.get(source) then
            if freeroam then SetPlayerRoutingBucket(source, freeroam.bucket) end
            TriggerClientEvent(Events.client.gungameEnd, source, {
                result = source == winner and 'won' or 'lost',
                reason = reason,
                place = place,
                players = #ranking,
                top = top,
                spawn = Zones.randomSpawn('freeroam'),
                elo = elo[source],
            })
        end
    end
    Logger.info('[gungame] partie n°%d terminée : %s', match.id, Locale.resolve(reason, Locale.SOURCE))
end

---Tirs entre deux joueurs : nil si ce n'est pas une affaire du Gungame, sinon autorisé ou non
---(seulement pendant la partie, entre joueurs de la même partie, pas sur un joueur protégé).
---Toucher quelqu'un met fin à sa propre protection d'apparition.
---@param attacker integer
---@param victim integer
---@return boolean|nil
function GungameService.damageAllowed(attacker, victim)
    local matchId = GungameService.playerMatch[attacker]
    if not matchId and not GungameService.playerMatch[victim] then return nil end
    if GungameService.playerMatch[victim] ~= matchId then return false end
    local match = GungameService.matches[matchId]
    if not match or match.phase ~= 'running' then return false end
    local target = match.stats[victim]
    if not target.alive or GetGameTimer() < target.protectedUntil then return false end
    match.stats[attacker].protectedUntil = 0
    return true
end

---@param source integer
---@return boolean dans la file ou dans une partie
function GungameService.isBusy(source)
    return GungameService.playerMatch[source] ~= nil or GungameService.queueIndex(source) ~= nil
end

---@param source integer
---@return string|nil partie en cours (mode spectateur admin)
function GungameService.describePlayer(source)
    if not GungameService.playerMatch[source] then return nil end
    return Locale.t('Partie de Gungame')
end
