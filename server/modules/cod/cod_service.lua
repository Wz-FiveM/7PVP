---Mode Call of Duty : recherche de partie (une file par liste de jeu, vote de carte), parties en
---cours, actions du menu et événements envoyés par les clients.
---@class CodQueue
---@field players integer[] joueurs en attente
---@field startAt integer|nil GetGameTimer() du lancement prévu
---@field maps table[]|nil cartes proposées au vote
---@field votes table<integer, string> joueur -> carte

---@class CodServiceModule
local CodService = PVP.define('CodService')
local CodMatch = PVP.use('CodMatch')
local CodStreaks = PVP.use('CodStreaks')
local CodUnits = PVP.use('CodUnits')
local CodCrates = PVP.use('CodCrates')
local CodProfileService = PVP.use('CodProfileService')
local PlayerService = PVP.use('PlayerService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

---@type table<string, CodQueue> par liste de jeu
CodService.queues = {}
---@type table<integer, string> joueur -> liste de jeu où il attend
CodService.playerQueue = {}
---@type table<integer, table> parties en cours
CodService.matches = {}
---@type table<integer, integer> joueur -> partie
CodService.playerMatch = {}
CodService.nextId = 0

function CodService.init()
    for _, playlist in ipairs(Config.Cod.playlists) do
        CodService.queues[playlist.id] = { players = {}, votes = {} }
    end

    Callback.register(Events.callbacks.codQueue, CodService.toggleQueue)
    Callback.register(Events.callbacks.codVote, CodService.vote)
    Callback.register(Events.callbacks.codSaveClass, function(source, index, data)
        local result = CodProfileService.saveClass(source, index, data)
        if result.ok then CodService.refreshSquad(source) end
        return result
    end)
    Callback.register(Events.callbacks.codSaveStreaks, function(source, data)
        local result = CodProfileService.saveStreaks(source, data)
        -- Depuis le menu pause : les cases du HUD suivent le nouveau choix
        local match = CodService.matchOf(source)
        if result.ok and match then CodStreaks.sendState(match, source) end
        return result
    end)
    Callback.register(Events.callbacks.codSavePlayerCard, CodProfileService.savePlayerCard)
    Callback.register(Events.callbacks.codSelectClass, function(source, index)
        local result = CodProfileService.selectClass(source, index)
        if result.ok then CodService.refreshSquad(source) end
        return result
    end)
    Callback.register(Events.callbacks.codLeaderboard, CodProfileService.leaderboard)
    Callback.register(Events.callbacks.codLeaveMatch, CodService.leaveToMenu)

    RegisterNetEvent(Events.server.codDeploy, function()
        local match = CodService.matchOf(source)
        if match then match:deploy(source) end
    end)
    -- Envoyé par le joueur mort : son tueur, l'arme et s'il a été touché à la tête
    RegisterNetEvent(Events.server.codDied, function(killerId, weapon, headshot)
        local match = CodService.matchOf(source)
        if match then match:onDied(source, killerId, weapon, headshot) end
    end)
    RegisterNetEvent(Events.server.codResync, function(target)
        local match = CodService.matchOf(source)
        if match then match:resync(source, target) end
    end)
    RegisterNetEvent(Events.server.codObjective, function(holding)
        local match = CodService.matchOf(source)
        if match then match:setHolding(source, holding) end
    end)
    RegisterNetEvent(Events.server.codUseStreak, function(target)
        local match = CodService.matchOf(source)
        if match then CodStreaks.use(match, source, target) end
    end)
    RegisterNetEvent(Events.server.codPredatorMove, function(target)
        local match = CodService.matchOf(source)
        if match then CodStreaks.predatorMove(match, source, target) end
    end)
    RegisterNetEvent(Events.server.codPredatorImpact, function(target)
        local match = CodService.matchOf(source)
        if match then CodStreaks.predatorImpact(match, source, target) end
    end)
    RegisterNetEvent(Events.server.codUnitFire, function(id, target)
        local match = CodService.matchOf(source)
        if match then CodUnits.fire(match, source, id, target) end
    end)
    RegisterNetEvent(Events.server.codPilotFire, function(id, index, target)
        local match = CodService.matchOf(source)
        if match then CodUnits.pilotFire(match, source, id, index, target) end
    end)
    RegisterNetEvent(Events.server.codUnitHit, function(id)
        local match = CodService.matchOf(source)
        if match then CodUnits.hit(match, source, id) end
    end)
    RegisterNetEvent(Events.server.codCrateTake, function(id)
        local match = CodService.matchOf(source)
        if match then CodCrates.take(match, source, id) end
    end)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        CodService.leave(playerSource)
        CodProfileService.unload(playerSource)
    end)
end

---@param source integer
---@return table|nil partie du joueur
function CodService.matchOf(source)
    return CodService.matches[CodService.playerMatch[source]]
end

---@param id any
---@return table|nil entrée de Config.Cod.playlists
function CodService.findPlaylist(id)
    for _, playlist in ipairs(Config.Cod.playlists) do
        if playlist.id == id then return playlist end
    end
    return nil
end

---@param id string
---@return table|nil entrée de Config.Cod.maps
function CodService.findMap(id)
    for _, map in ipairs(Config.Cod.maps) do
        if map.id == id then return map end
    end
    return nil
end

---Menu du mode : le joueur est seul dans son bucket, avec son personnage (voir client/modules/cod/cod.lua).
---@param player PvpPlayer
function CodService.openMenu(player)
    player.dead = false
    local bucket = Config.Cod.menuBucketBase + player.source
    SetRoutingBucketPopulationEnabled(bucket, false)
    SetPlayerRoutingBucket(player.source, bucket)
    local profile = CodProfileService.load(player)
    TriggerClientEvent(Events.client.codOpen, player.source, {
        profile = CodProfileService.describe(profile),
        catalog = CodProfileService.catalog(),
        appearance = player.appearance,
    })
end

-- ---------------------------------------------------------------------------
-- File d'attente
-- ---------------------------------------------------------------------------

---Lance ou annule la recherche : rejoint une partie en cours qui a de la place, sinon la file.
---@param source integer
---@param playlistId any
---@return { ok: boolean, message?: string }
function CodService.toggleQueue(source, playlistId)
    local player = PlayerService.get(source)
    if not player or player.mode ~= 'cod' then return { ok = false } end
    if CodService.playerMatch[source] then return { ok = false, message = Locale.t('Tu es déjà dans une partie.') } end

    if CodService.playerQueue[source] then
        CodService.leaveQueue(source)
        return { ok = true }
    end
    local playlist = CodService.findPlaylist(playlistId)
    if not playlist then return { ok = false } end
    CodService.joinPlaylist(source, playlist)
    return { ok = true }
end

---@param source integer
---@param playlist table
function CodService.joinPlaylist(source, playlist)
    local match = CodService.joinableMatch(playlist)
    if match then return match:addPlayer(source) end

    local queue = CodService.queues[playlist.id]
    queue.players[#queue.players + 1] = source
    CodService.playerQueue[source] = playlist.id
    CodService.updateQueue(playlist)
end

---@param playlist table
---@return table|nil partie en cours qui a encore de la place et assez de temps
function CodService.joinableMatch(playlist)
    -- Une seule vie par manche : pas d'arrivée en cours de partie
    if playlist.id == 'snd' then return nil end
    local limit = GetGameTimer() + Config.Cod.joinMinRemaining * 1000
    for _, match in pairs(CodService.matches) do
        if match.playlist.id == playlist.id and match.phase ~= 'ended'
            and #match.players < playlist.maxPlayers and match.endAt >= limit then
            return match
        end
    end
    return nil
end

---Compte à rebours dès qu'il y a assez de joueurs ; vote de carte pendant ce temps.
---@param playlist table
function CodService.updateQueue(playlist)
    local queue = CodService.queues[playlist.id]
    local count = #queue.players
    if count < playlist.minPlayers then
        queue.startAt, queue.maps, queue.votes = nil, nil, {}
    elseif count >= playlist.maxPlayers then
        return CodService.launch(playlist)
    elseif not queue.startAt then
        queue.startAt = GetGameTimer() + Config.Cod.queueDelay * 1000
        queue.maps = CodService.pickMaps()
        queue.votes = {}
        local planned = queue.startAt
        SetTimeout(Config.Cod.queueDelay * 1000, function()
            if queue.startAt == planned then CodService.launch(playlist) end
        end)
    end
    CodService.sendSquad(playlist)
    CodService.sendQueue(playlist)
end

---Personnages du salon : chaque joueur voit ceux des autres autour du sien (client/modules/cod/cod_squad.lua).
---@param playlist table
function CodService.sendSquad(playlist)
    local queue = CodService.queues[playlist.id]
    local members = {}
    for index, source in ipairs(queue.players) do
        local player = PlayerService.get(source)
        members[index] = {
            id = source,
            appearance = player and player.appearance,
            weapon = CodProfileService.selectedClass(source).primary,
        }
    end
    for _, source in ipairs(queue.players) do
        TriggerClientEvent(Events.client.codSquad, source, members)
    end
end

---La classe d'un joueur du salon a changé : les autres voient sa nouvelle arme.
---@param source integer
function CodService.refreshSquad(source)
    local playlist = CodService.findPlaylist(CodService.playerQueue[source])
    if playlist then CodService.sendSquad(playlist) end
end

---@return table[] cartes tirées au sort pour le vote
function CodService.pickMaps()
    local pool = { table.unpack(Config.Cod.maps) }
    local maps = {}
    while #pool > 0 and #maps < Config.Cod.voteChoices do
        maps[#maps + 1] = table.remove(pool, math.random(#pool))
    end
    return maps
end

---@param playlist table
function CodService.sendQueue(playlist)
    local queue = CodService.queues[playlist.id]
    local startIn = queue.startAt and math.ceil((queue.startAt - GetGameTimer()) / 1000) or false
    local names, cards = {}, {}
    for index, source in ipairs(queue.players) do
        names[index] = GetPlayerName(source) or '?'
        cards[index] = CodProfileService.playerCard(source)
    end
    local maps = false
    if queue.maps then
        maps = {}
        for index, map in ipairs(queue.maps) do
            local votes = 0
            for _, choice in pairs(queue.votes) do
                if choice == map.id then votes = votes + 1 end
            end
            maps[index] = { id = map.id, label = map.label, place = map.place, votes = votes }
        end
    end
    for _, source in ipairs(queue.players) do
        TriggerClientEvent(Events.client.codQueue, source, {
            playlist = playlist.id,
            count = #queue.players,
            names = names,
            cards = cards,
            needed = playlist.minPlayers,
            max = playlist.maxPlayers,
            startIn = startIn,
            maps = maps,
            vote = queue.votes[source] or false,
        })
    end
end

---@param source integer
---@param mapId any
---@return { ok: boolean }
function CodService.vote(source, mapId)
    local playlist = CodService.findPlaylist(CodService.playerQueue[source])
    local queue = playlist and CodService.queues[playlist.id]
    if not queue or not queue.maps then return { ok = false } end
    for _, map in ipairs(queue.maps) do
        if map.id == mapId then
            queue.votes[source] = map.id
            CodService.sendQueue(playlist)
            return { ok = true }
        end
    end
    return { ok = false }
end

---@param queue CodQueue
---@return table carte qui a le plus de votes (au hasard à égalité)
function CodService.votedMap(queue)
    local counts = {}
    for _, choice in pairs(queue.votes) do
        counts[choice] = (counts[choice] or 0) + 1
    end
    local best, top = {}, -1
    for _, map in ipairs(queue.maps or Config.Cod.maps) do
        local votes = counts[map.id] or 0
        if votes > top then best, top = { map }, votes
        elseif votes == top then best[#best + 1] = map end
    end
    return best[math.random(#best)]
end

---@param playlist table
function CodService.launch(playlist)
    local queue = CodService.queues[playlist.id]
    queue.maps = queue.maps or CodService.pickMaps()
    local map = CodService.votedMap(queue)

    local players = {}
    while #queue.players > 0 and #players < playlist.maxPlayers do
        local source = table.remove(queue.players, 1)
        CodService.playerQueue[source] = nil
        players[#players + 1] = source
        TriggerClientEvent(Events.client.codQueue, source, false)
    end
    queue.startAt, queue.maps, queue.votes = nil, nil, {}
    if #players == 0 then return end

    CodService.nextId = CodService.nextId + 1
    local match = CodMatch.new(CodService.nextId, playlist, map)
    CodService.matches[match.id] = match
    match:start(players)
    CodService.updateQueue(playlist)
end

---@param source integer
function CodService.leaveQueue(source)
    local playlist = CodService.findPlaylist(CodService.playerQueue[source])
    if not playlist then return end
    local queue = CodService.queues[playlist.id]
    CodService.playerQueue[source] = nil
    queue.votes[source] = nil
    for index, queued in ipairs(queue.players) do
        if queued == source then table.remove(queue.players, index) break end
    end
    TriggerClientEvent(Events.client.codQueue, source, false)
    CodService.updateQueue(playlist)
end

-- ---------------------------------------------------------------------------
-- Départs et fin de partie
-- ---------------------------------------------------------------------------

---Déconnexion ou retour au lobby : sort de la file, ou quitte la partie.
---@param source integer
function CodService.leave(source)
    CodService.leaveQueue(source)
    local match = CodService.matchOf(source)
    if match then match:removePlayer(source) end
    CodService.playerMatch[source] = nil
end

---« Quitter la partie » du menu pause : retour au menu du mode.
---@param source integer
---@return { ok: boolean }
function CodService.leaveToMenu(source)
    local player = PlayerService.get(source)
    if not player or player.mode ~= 'cod' or not CodService.playerMatch[source] then return { ok = false } end
    CodService.leave(source)
    CodService.openMenu(player)
    return { ok = true }
end

---Fin de l'écran des résultats : retour au menu et nouvelle recherche dans la même liste de jeu.
---@param match table
function CodService.closeMatch(match)
    CodService.matches[match.id] = nil
    local players = { table.unpack(match.players) }
    for _, source in ipairs(players) do
        CodService.playerMatch[source] = nil
        local player = PlayerService.get(source)
        if player and player.mode == 'cod' then
            CodService.openMenu(player)
            CodService.joinPlaylist(source, match.playlist)
        end
    end
end

---Tirs entre deux joueurs : seulement dans la même partie, selon ses règles.
---@param attacker integer
---@param victim integer
---@return boolean
function CodService.damageAllowed(attacker, victim)
    local match = CodService.matchOf(attacker)
    if not match or CodService.playerMatch[victim] ~= match.id then return false end
    return match:damageAllowed(attacker, victim)
end

---@param source integer
---@return boolean dans la file ou dans une partie
function CodService.isBusy(source)
    return CodService.playerMatch[source] ~= nil or CodService.playerQueue[source] ~= nil
end

---@param source integer
---@return string|table|nil partie en cours (mode spectateur admin)
function CodService.describePlayer(source)
    local match = CodService.matchOf(source)
    if not match then return nil end
    return Locale.t('%s · %s', Locale.t(match.playlist.label), Locale.t(match.map.label))
end
