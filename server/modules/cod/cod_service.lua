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
local CodOperatorService = PVP.use('CodOperatorService')
local CodMapService = PVP.use('CodMapService')
local CodParty = PVP.use('CodParty')
local CodWarzone = PVP.use('CodWarzone')
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
    Callback.register(Events.callbacks.codPrivate, CodService.startPrivate)
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
    Callback.register(Events.callbacks.codPrestige, CodService.enterPrestige)
    Callback.register(Events.callbacks.codPrestigeUnlock, CodProfileService.unlockPermanent)
    Callback.register(Events.callbacks.codSelectOperator, function(source, id)
        return CodService.changeOperator(source, CodOperatorService.select, id)
    end)
    Callback.register(Events.callbacks.codBuyOperator, function(source, id)
        return CodService.changeOperator(source, CodOperatorService.buy, id)
    end)

    RegisterNetEvent(Events.server.codDeploy, function()
        local match = CodService.matchOf(source)
        if match then match:deploy(source) end
    end)
    -- Envoyé par le joueur mort : son tueur, l'arme et s'il a été touché à la tête
    RegisterNetEvent(Events.server.codDied, function(killerId, weapon, headshot)
        local match = CodService.matchOf(source)
        if match then match:onDied(source, killerId, weapon, headshot) end
    end)
    RegisterNetEvent(Events.server.codWzTake, function(id)
        local match = CodService.warzoneOf(source)
        if match then CodWarzone.take(match, source, id) end
    end)
    RegisterNetEvent(Events.server.codWzPlate, function()
        local match = CodService.warzoneOf(source)
        if match then CodWarzone.usePlate(match, source) end
    end)
    RegisterNetEvent(Events.server.codWzVehicleClaim, function(id)
        local match = CodService.warzoneOf(source)
        if match then CodWarzone.claimVehicle(match, source, id) end
    end)
    RegisterNetEvent(Events.server.codWzVehicleSpawned, function(netId)
        local match = CodService.warzoneOf(source)
        if match then CodWarzone.vehicleSpawned(match, netId) end
    end)
    Callback.register(Events.callbacks.codWzBuy, function(player, station, item)
        local match = CodService.warzoneOf(player)
        return match and CodWarzone.buy(match, player, station, item) or { ok = false }
    end)
    RegisterNetEvent(Events.server.codInsertion, function()
        local match = CodService.matchOf(source)
        if match then match:placeInsertion(source) end
    end)
    RegisterNetEvent(Events.server.codKillcamClip, function(victim, clip)
        local match = CodService.matchOf(source)
        if match then match:killcamClip(source, victim, clip) end
    end)
    RegisterNetEvent(Events.server.codKillcamOwn, function(clip)
        local match = CodService.matchOf(source)
        if match then match:killcamOwn(source, clip) end
    end)
    RegisterNetEvent(Events.server.codKillcamDone, function()
        local match = CodService.matchOf(source)
        if match then match:killcamDone(source) end
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

---@param source integer
---@return table|nil partie Warzone du joueur
function CodService.warzoneOf(source)
    local match = CodService.matchOf(tonumber(source))
    return match and match.playlist.warzone and match or nil
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

---Le rang repart de 1 : seulement depuis le menu, ni en partie ni en recherche.
---@param source integer
---@return { ok: boolean, message?: string, profile?: table }
function CodService.enterPrestige(source)
    if CodService.playerMatch[source] or CodService.playerQueue[source] then
        return { ok = false, message = Locale.t('Annule ta recherche de partie avant de passer en Prestige.') }
    end
    return CodProfileService.enterPrestige(source)
end

---Le personnage ne change que depuis le menu ; les autres joueurs du salon le voient aussitôt.
---@param source integer
---@param action fun(source: integer, id: any): { ok: boolean, message?: string, profile?: table }
---@param id any
---@return { ok: boolean, message?: string, profile?: table }
function CodService.changeOperator(source, action, id)
    if CodService.playerMatch[source] then return { ok = false } end
    local result = action(source, id)
    if result.ok then CodService.refreshSquad(source) end
    return result
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

    local party = CodParty.of(source)
    local leader = not party or party.leader == source
    -- Annuler : le chef pour toute l'escouade, un membre seulement pour lui (retour de partie, recherche relancée)
    if CodService.playerQueue[source] then
        for _, member in ipairs(leader and CodParty.membersOf(source) or { source }) do CodService.leaveQueue(member) end
        return { ok = true }
    end
    if not leader then return { ok = false, message = Locale.t('Seul le chef de l\'escouade lance la recherche.') } end

    local members = CodParty.membersOf(source)
    for _, member in ipairs(members) do
        if CodService.playerMatch[member] then return { ok = false, message = Locale.t('Un membre de ton escouade est encore en partie.') } end
    end
    local playlist = CodService.findPlaylist(playlistId)
    if not playlist then return { ok = false } end
    if not CodService.joinableMatch(playlist, #members) and #CodService.pickMaps(playlist) == 0 then
        return { ok = false, message = Locale.t('Aucune carte disponible pour le moment.') }
    end
    for _, member in ipairs(members) do CodService.leaveQueue(member) end
    CodService.joinPlaylist(members, playlist)
    return { ok = true }
end

---@param members integer[] joueur seul ou escouade : ils restent ensemble
---@param playlist table
function CodService.joinPlaylist(members, playlist)
    local match = CodService.joinableMatch(playlist, #members)
    if match then
        for _, source in ipairs(members) do match:addPlayer(source) end
        return
    end

    local queue = CodService.queues[playlist.id]
    for _, source in ipairs(members) do
        queue.players[#queue.players + 1] = source
        CodService.playerQueue[source] = playlist.id
    end
    CodService.updateQueue(playlist)
end

---Partie privée : l'escouade seule (ou le joueur seul, pour découvrir une carte), sans XP ni progression.
---@param source integer
---@param playlistId any
---@param mapId any
---@return { ok: boolean, message?: string }
function CodService.startPrivate(source, playlistId, mapId)
    local player = PlayerService.get(source)
    if not player or player.mode ~= 'cod' then return { ok = false } end
    local party = CodParty.of(source)
    if party and party.leader ~= source then return { ok = false, message = Locale.t('Seul le chef de l\'escouade lance une partie privée.') } end
    local members = CodParty.membersOf(source)
    for _, member in ipairs(members) do
        if CodService.isBusy(member) then return { ok = false, message = Locale.t('Toute l\'escouade doit être au menu, sans recherche en cours.') } end
    end
    local playlist = CodService.findPlaylist(playlistId)
    -- Warzone : ses cartes ne sont pas celles du multijoueur
    local map = playlist and playlist.warzone and CodService.pickMaps(playlist)[1] or (type(mapId) == 'string' and CodService.findMap(mapId))
    if not playlist or not map or not (playlist.warzone or CodMapService.playable(map)) then
        return { ok = false, message = Locale.t('Cette carte n\'est pas disponible.') }
    end

    CodService.nextId = CodService.nextId + 1
    local match = CodMatch.new(CodService.nextId, playlist, map, true)
    CodService.matches[match.id] = match
    match:start(members)
    return { ok = true }
end

---@param playlist table
---@param count integer joueurs à faire entrer ensemble
---@return table|nil partie en cours qui a encore de la place et assez de temps
function CodService.joinableMatch(playlist, count)
    -- Une seule vie par manche, ou tout le monde part du même avion : pas d'arrivée en cours de partie
    if playlist.id == 'snd' or playlist.warzone then return nil end
    local limit = GetGameTimer() + Config.Cod.joinMinRemaining * 1000
    for _, match in pairs(CodService.matches) do
        if match.playlist.id == playlist.id and match.phase ~= 'ended' and not match.private
            and #match.players + count <= playlist.maxPlayers and match.endAt >= limit then
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
        queue.maps = CodService.pickMaps(playlist)
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
            mods = CodProfileService.selectedClass(source).primaryMods,
            model = CodOperatorService.modelOf(source),
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

---@param playlist table
---@return table[] cartes tirées au sort pour le vote
function CodService.pickMaps(playlist)
    local pool = {}
    if playlist.warzone then
        for _, map in ipairs(Config.CodWarzone.maps) do
            if map.mode == playlist.warzone then pool[#pool + 1] = map end
        end
    else
        for _, map in ipairs(Config.Cod.maps) do
            if CodMapService.playable(map) then pool[#pool + 1] = map end
        end
    end
    local maps = {}
    while #pool > 0 and #maps < Config.Cod.voteChoices do
        maps[#maps + 1] = table.remove(pool, math.random(#pool))
    end
    return maps
end

---Cartes modifiées par un admin : le vote en cours ne garde que celles encore jouables.
function CodService.refreshVotes()
    for _, playlist in ipairs(Config.Cod.playlists) do
        local queue = CodService.queues[playlist.id]
        if queue.maps and not playlist.warzone then
            local maps, kept = {}, {}
            for _, map in ipairs(queue.maps) do
                if CodMapService.playable(map) then
                    maps[#maps + 1] = map
                    kept[map.id] = true
                end
            end
            for source, choice in pairs(queue.votes) do
                if not kept[choice] then queue.votes[source] = nil end
            end
            queue.maps = #maps > 0 and maps or CodService.pickMaps(playlist)
            CodService.sendQueue(playlist)
        end
    end
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
---@return table|nil carte qui a le plus de votes (au hasard à égalité), nil sans carte jouable
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
    if #best == 0 then return nil end
    return best[math.random(#best)]
end

---Plus aucune carte jouable (toutes retirées par un admin) : la recherche s'arrête.
---@param playlist table
function CodService.cancelQueue(playlist)
    local queue = CodService.queues[playlist.id]
    for _, source in ipairs(queue.players) do
        CodService.playerQueue[source] = nil
        TriggerClientEvent(Events.client.codQueue, source, false)
        local player = PlayerService.get(source)
        if player then player:notify(Locale.t('Aucune carte disponible pour le moment.'), 'error') end
    end
    queue.players, queue.startAt, queue.maps, queue.votes = {}, nil, nil, {}
end

---@param playlist table
function CodService.launch(playlist)
    local queue = CodService.queues[playlist.id]
    queue.maps = queue.maps or CodService.pickMaps(playlist)
    local map = CodService.votedMap(queue)
    if not map then return CodService.cancelQueue(playlist) end

    -- Une escouade part entière, ou attend la partie suivante
    local players = {}
    while #queue.players > 0 do
        local squad = CodService.queuedSquad(queue, queue.players[1])
        if #players + #squad > playlist.maxPlayers then break end
        for _, source in ipairs(squad) do
            for index, queued in ipairs(queue.players) do
                if queued == source then table.remove(queue.players, index) break end
            end
            CodService.playerQueue[source] = nil
            players[#players + 1] = source
            TriggerClientEvent(Events.client.codQueue, source, false)
        end
    end
    queue.startAt, queue.maps, queue.votes = nil, nil, {}
    if #players == 0 then return end

    CodService.nextId = CodService.nextId + 1
    local match = CodMatch.new(CodService.nextId, playlist, map)
    CodService.matches[match.id] = match
    match:start(players)
    CodService.updateQueue(playlist)
end

---@param queue CodQueue
---@param source integer joueur de la file
---@return integer[] lui et les membres de son escouade présents dans cette file
function CodService.queuedSquad(queue, source)
    local squad = {}
    for _, member in ipairs(CodParty.membersOf(source)) do
        for _, queued in ipairs(queue.players) do
            if queued == member then squad[#squad + 1] = member break end
        end
    end
    return squad
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
    if match.rules.cleanup then match.rules.cleanup(match) end
    local players = { table.unpack(match.players) }
    local inMenu = {}
    for _, source in ipairs(players) do
        CodService.playerMatch[source] = nil
        local player = PlayerService.get(source)
        if player and player.mode == 'cod' then
            CodService.openMenu(player)
            inMenu[source] = true
        end
    end
    if match.private then return end

    -- Les escouades repartent ensemble
    for _, source in ipairs(players) do
        if inMenu[source] then
            local together = {}
            for _, member in ipairs(CodParty.membersOf(source)) do
                if inMenu[member] then
                    together[#together + 1] = member
                    inMenu[member] = nil
                end
            end
            CodService.joinPlaylist(together, match.playlist)
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
