---Mode Sabotage : recherche de partie (une seule file), parties en cours, actions du menu et
---événements envoyés par les clients.
---@class TacticalServiceModule
local TacticalService = PVP.define('TacticalService')
local TacticalMatch = PVP.use('TacticalMatch')
local TacticalAbilities = PVP.use('TacticalAbilities')
local TacticalProfileService = PVP.use('TacticalProfileService')
local CodMapService = PVP.use('CodMapService')
local PlayerService = PVP.use('PlayerService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

TacticalService.MODE = 'tactical'

---@type { players: integer[], startAt: integer|nil }
TacticalService.queue = { players = {} }
---@type table<integer, boolean> joueurs dans la file
TacticalService.queued = {}
---@type table<integer, table> parties en cours
TacticalService.matches = {}
---@type table<integer, integer> joueur -> partie
TacticalService.playerMatch = {}
TacticalService.nextId = 0

function TacticalService.init()
    Callback.register(Events.callbacks.tacQueue, TacticalService.toggleQueue)
    Callback.register(Events.callbacks.tacSelectRole, function(source, role)
        if TacticalService.playerMatch[source] then
            return { ok = false, message = Locale.t('Le rôle se choisit au menu, entre deux parties.') }
        end
        return TacticalProfileService.selectRole(source, role)
    end)
    Callback.register(Events.callbacks.tacBuy, function(source, item)
        local match = TacticalService.matchOf(source)
        return match and match:buy(source, item) or { ok = false }
    end)
    Callback.register(Events.callbacks.tacSell, function(source, key)
        local match = TacticalService.matchOf(source)
        return match and match:sell(source, key) or { ok = false }
    end)
    Callback.register(Events.callbacks.tacLeaderboard, TacticalProfileService.leaderboard)
    Callback.register(Events.callbacks.tacLeaveMatch, TacticalService.leaveToMenu)

    RegisterNetEvent(Events.server.tacDied, function(killerId, weapon, headshot)
        local match = TacticalService.matchOf(source)
        if match then match:onDied(source, killerId, weapon, headshot) end
    end)
    RegisterNetEvent(Events.server.tacObjective, function(holding)
        local match = TacticalService.matchOf(source)
        if match then match:setHolding(source, holding) end
    end)
    RegisterNetEvent(Events.server.tacAbility, function(slot, data)
        local match = TacticalService.matchOf(source)
        if match then TacticalAbilities.use(match, source, slot, data) end
    end)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        TacticalService.leave(playerSource)
        TacticalProfileService.unload(playerSource)
    end)
end

---@param source any
---@return table|nil partie du joueur
function TacticalService.matchOf(source)
    return TacticalService.matches[TacticalService.playerMatch[tonumber(source)]]
end

---Menu du mode : le joueur est seul dans son bucket, caché, devant la caméra du lobby.
---@param player PvpPlayer
function TacticalService.openMenu(player)
    player.dead = false
    local bucket = Config.Tactical.menuBucketBase + player.source
    SetRoutingBucketPopulationEnabled(bucket, false)
    SetPlayerRoutingBucket(player.source, bucket)
    local profile = TacticalProfileService.load(player)
    TriggerClientEvent(Events.client.tacOpen, player.source, {
        profile = TacticalProfileService.describe(profile),
        maps = #TacticalService.playableMaps(),
    })
    if TacticalService.queued[player.source] then TacticalService.sendQueue() end
end

---@return table[] cartes de Seven of Duty jouables ici (apparitions et deux sites)
function TacticalService.playableMaps()
    local maps = {}
    for _, map in ipairs(Config.Cod.maps) do
        local sites = Config.CodSpawns[map.id .. '_sites']
        if not Config.Tactical.excludedMaps[map.id] and CodMapService.playable(map) and sites and #sites >= 2 then
            maps[#maps + 1] = map
        end
    end
    return maps
end

-- ---------------------------------------------------------------------------
-- File d'attente
-- ---------------------------------------------------------------------------

---@param source integer
---@return { ok: boolean, message?: string }
function TacticalService.toggleQueue(source)
    local player = PlayerService.get(source)
    if not player or player.mode ~= TacticalService.MODE then return { ok = false } end
    if TacticalService.playerMatch[source] then return { ok = false, message = Locale.t('Tu es déjà dans une partie.') } end
    if TacticalService.queued[source] then
        TacticalService.leaveQueue(source)
        return { ok = true }
    end
    if #TacticalService.playableMaps() == 0 then
        return { ok = false, message = Locale.t('Aucune carte disponible pour le moment.') }
    end
    TacticalService.queued[source] = true
    table.insert(TacticalService.queue.players, source)
    TacticalService.updateQueue()
    return { ok = true }
end

---@param source integer
function TacticalService.leaveQueue(source)
    if not TacticalService.queued[source] then return end
    TacticalService.queued[source] = nil
    for index, queued in ipairs(TacticalService.queue.players) do
        if queued == source then table.remove(TacticalService.queue.players, index) break end
    end
    TriggerClientEvent(Events.client.tacQueue, source, false)
    TacticalService.updateQueue()
end

---Compte à rebours dès qu'il y a assez de joueurs, lancement immédiat quand la partie est pleine.
function TacticalService.updateQueue()
    local settings = Config.Tactical
    local queue = TacticalService.queue
    local count = #queue.players
    if count < settings.minPlayers then
        queue.startAt = nil
    elseif count >= settings.maxPlayers then
        return TacticalService.launch()
    elseif not queue.startAt then
        queue.startAt = GetGameTimer() + settings.queueDelay * 1000
        local planned = queue.startAt
        SetTimeout(settings.queueDelay * 1000, function()
            if queue.startAt == planned then TacticalService.launch() end
        end)
    end
    TacticalService.sendQueue()
end

function TacticalService.sendQueue()
    local queue = TacticalService.queue
    local startIn = queue.startAt and math.max(0, math.ceil((queue.startAt - GetGameTimer()) / 1000)) or false
    local names, players = {}, {}
    for index, source in ipairs(queue.players) do
        names[index] = GetPlayerName(source) or '?'
        local rating, division = TacticalMatch.rankOf(source)
        -- Bannières du menu : rôle et division de chaque joueur en file
        players[index] = { name = names[index], role = TacticalProfileService.roleOf(source), rating = rating, division = division }
    end
    for _, source in ipairs(queue.players) do
        TriggerClientEvent(Events.client.tacQueue, source, {
            count = #queue.players,
            needed = Config.Tactical.minPlayers,
            max = Config.Tactical.maxPlayers,
            startIn = startIn,
            names = names,
            players = players,
        })
    end
end

function TacticalService.launch()
    local queue = TacticalService.queue
    queue.startAt = nil
    local maps = TacticalService.playableMaps()
    if #maps == 0 then
        for _, source in ipairs(queue.players) do
            TacticalService.queued[source] = nil
            TriggerClientEvent(Events.client.tacQueue, source, false)
            local player = PlayerService.get(source)
            if player then player:notify(Locale.t('Aucune carte disponible pour le moment.'), 'error') end
        end
        queue.players = {}
        return
    end

    local players = {}
    while #queue.players > 0 and #players < Config.Tactical.maxPlayers do
        local source = table.remove(queue.players, 1)
        TacticalService.queued[source] = nil
        TriggerClientEvent(Events.client.tacQueue, source, false)
        players[#players + 1] = source
    end
    if #players < 2 then return TacticalService.updateQueue() end

    TacticalService.nextId = TacticalService.nextId + 1
    local match = TacticalMatch.new(TacticalService.nextId, maps[math.random(#maps)])
    TacticalService.matches[match.id] = match
    match:start(players)
    TacticalService.updateQueue()
end

-- ---------------------------------------------------------------------------
-- Départs et fin de partie
-- ---------------------------------------------------------------------------

---Déconnexion ou retour au lobby : sort de la file, ou quitte la partie.
---@param source integer
function TacticalService.leave(source)
    TacticalService.leaveQueue(source)
    local match = TacticalService.matchOf(source)
    if match then match:removePlayer(source) end
    TacticalService.playerMatch[source] = nil
end

---« Quitter la partie » : retour au menu du mode (compté comme une défaite).
---@param source integer
---@return { ok: boolean }
function TacticalService.leaveToMenu(source)
    local player = PlayerService.get(source)
    if not player or player.mode ~= TacticalService.MODE or not TacticalService.playerMatch[source] then return { ok = false } end
    TacticalService.leave(source)
    TacticalService.openMenu(player)
    return { ok = true }
end

---Fin de l'écran des résultats : retour au menu.
---@param match table
function TacticalService.closeMatch(match)
    TacticalService.matches[match.id] = nil
    for _, source in ipairs({ table.unpack(match.players) }) do
        TacticalService.playerMatch[source] = nil
        local player = PlayerService.get(source)
        if player and player.mode == TacticalService.MODE then TacticalService.openMenu(player) end
    end
end

---Tirs entre deux joueurs : seulement dans la même partie, entre ennemis, pendant la manche.
---@param attacker integer
---@param victim integer
---@param damage number
---@return boolean
function TacticalService.damageAllowed(attacker, victim, damage)
    local match = TacticalService.matchOf(attacker)
    if not match or TacticalService.playerMatch[victim] ~= match.id then return false end
    return match:damageAllowed(attacker, victim, damage)
end

---@param source integer
---@return string|table|nil partie en cours (mode spectateur admin)
function TacticalService.describePlayer(source)
    local match = TacticalService.matchOf(source)
    if not match then return nil end
    return Locale.t('Sabotage · %s', Locale.t(match.map.label))
end
