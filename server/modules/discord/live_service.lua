---Données en direct pour le bot Discord (D:\7PVP\bot) : joueurs, parties en cours, files d'attente,
---événements du PvP, derniers résultats et classements. Le bot les lit en HTTP sur /7PVP/live,
---/7PVP/boards et /7PVP/player?name=... avec le jeton de la convar 7pvp_discord_live_token
---(générée par le bot dans bot/data/webhooks.cfg) ; sans elle, rien n'est exposé.
---Les libellés restent en français : le bot les traduit avec les fichiers de locales/.
---Aucun identifiant de joueur (licence) ne sort d'ici.
---@class LiveServiceModule
local LiveService = PVP.define('LiveService')
local PlayerService = PVP.use('PlayerService')
local LeaderboardService = PVP.use('LeaderboardService')
local SeasonService = PVP.use('SeasonService')
local Progression = PVP.use('Progression')
local CodService = PVP.use('CodService')
local CodProfileService = PVP.use('CodProfileService')
local CvcService = PVP.use('CvcService')
local ChaseService = PVP.use('ChaseService')
local GunfightService = PVP.use('GunfightService')
local GungameService = PVP.use('GungameService')
local AirdropService = PVP.use('AirdropService')
local ControlService = PVP.use('ControlService')
local CrewStatsService = PVP.use('CrewStatsService')
local HordeService = PVP.use('HordeService')
local BountyService = PVP.use('BountyService')
local Logger = PVP.use('Logger')

LiveService.TOKEN_CONVAR = 'live_token'
LiveService.TOP = 15 -- joueurs par classement
LiveService.MATCH_TOP = 3 -- meilleurs joueurs affichés par partie
LiveService.RESULT_TOP = 5 -- joueurs gardés par résultat de partie Call of Duty
LiveService.MAX_RESULTS = 20 -- résultats gardés en mémoire
LiveService.BOARDS_CACHE = 30 -- secondes
LiveService.TIME_STEP = 15 -- secondes : arrondi des heures de fin, pour ne pas déclencher une mise à jour Discord à chaque lecture
LiveService.KD_MIN_KILLS = 50 -- kills minimum pour le classement K/D

LiveService.startedAt = os.time()
LiveService.peak = 0
LiveService.nextResult = 0
---@type table[] du plus ancien au plus récent
LiveService.results = {}
---@type { at: integer, data: table }|nil
LiveService.boardsCache = nil

function LiveService.init()
    LiveService.token = GetConvar(Config.Discord.ConvarPrefix .. LiveService.TOKEN_CONVAR, '')
    if LiveService.token == '' then
        return Logger.info('Discord : pas de jeton, données en direct désactivées (voir config/discord.lua)')
    end
    SetHttpHandler(LiveService.onRequest)
end

-- ---------------------------------------------------------------------------
-- HTTP
-- ---------------------------------------------------------------------------

---@param req table
---@param res table
function LiveService.onRequest(req, res)
    if not LiveService.isAuthorized(req) then return LiveService.reply(res, 403, { error = 'forbidden' }) end
    local path, query = req.path:match('^([^?]*)%??(.*)$')

    -- Les classements et la recherche lisent la base : attente dans un thread
    CreateThread(function()
        local ok, data = pcall(LiveService.route, path, query)
        if not ok then
            Logger.error('[live] %s : %s', path, data)
            return LiveService.reply(res, 500, { error = 'internal' })
        end
        if not data then return LiveService.reply(res, 404, { error = 'not found' }) end
        LiveService.reply(res, 200, data)
    end)
end

---@param req table
---@return boolean
function LiveService.isAuthorized(req)
    for name, value in pairs(req.headers or {}) do
        if name:lower() == 'x-7pvp-token' then return value == LiveService.token end
    end
    return false
end

---@param res table
---@param status integer
---@param data table
function LiveService.reply(res, status, data)
    res.writeHead(status, { ['Content-Type'] = 'application/json' })
    res.send(json.encode(data))
end

---@param path string
---@param query string
---@return table|nil
function LiveService.route(path, query)
    if path == '/live' then return LiveService.live() end
    if path == '/boards' then return LiveService.boards() end
    if path == '/player' then return LiveService.player(LiveService.queryValue(query, 'name')) end
    return nil
end

---@param query string
---@param key string
---@return string
function LiveService.queryValue(query, key)
    for name, value in query:gmatch('([^&=]+)=([^&]*)') do
        if name == key then
            return (value:gsub('%+', ' '):gsub('%%(%x%x)', function(hex) return string.char(tonumber(hex, 16)) end))
        end
    end
    return ''
end

-- ---------------------------------------------------------------------------
-- Direct
-- ---------------------------------------------------------------------------

---Une section en panne (mode en cours d'évolution) ne prive pas le bot de tout le reste.
---@param label string
---@param fn function
---@param fallback any
---@return any
function LiveService.safe(label, fn, fallback)
    local ok, value = pcall(fn)
    if ok then return value end
    Logger.warn('[live] %s : %s', label, value)
    return fallback
end

---@param timer integer|nil GetGameTimer() de la fin
---@return integer|false heure de la fin (os.time), arrondie
function LiveService.endTime(timer)
    if not timer then return false end
    return LiveService.roundTime(math.max(0, math.ceil((timer - GetGameTimer()) / 1000)))
end

---@param seconds integer dans combien de temps
---@return integer heure (os.time), arrondie
function LiveService.roundTime(seconds)
    local at = os.time() + seconds
    return at - at % LiveService.TIME_STEP
end

---@return table
function LiveService.live()
    local players = LiveService.players()
    LiveService.peak = math.max(LiveService.peak, players.online)
    players.peak = LiveService.peak
    return {
        at = os.time(),
        startedAt = LiveService.startedAt,
        players = players,
        matches = LiveService.safe('parties CoD', LiveService.codMatches, {}),
        activities = LiveService.safe('parties Freeroam', LiveService.activityMatches, {}),
        queues = LiveService.safe('files', LiveService.queues, {}),
        pvp = LiveService.safe('événements PvP', LiveService.pvpEvents, {}),
        results = LiveService.results,
    }
end

---Ce que fait le joueur en ce moment, en plus de son mode.
---@param source integer
---@return string|false
function LiveService.activityOf(source)
    local codMatch = CodService.matches[CodService.playerMatch[source]]
    if codMatch then return codMatch.playlist.label end
    if CvcService.playerMatch[source] then return Config.FreeroamActivities.cvc.label end
    if ChaseService.playerMatch[source] then return Config.FreeroamActivities.chase.label end
    if GungameService.playerMatch[source] then return Config.FreeroamActivities.gungame.label end
    local duel = GunfightService.matches[GunfightService.playerMatch[source]]
    if duel then return Config.FreeroamActivities[duel.mode].label end
    return false
end

---@return table
function LiveService.players()
    local list, modes = {}, { lobby = 0, pvp = 0, freeroam = 0, cod = 0 }
    for source, player in pairs(PlayerService.all()) do
        local mode = player.mode or 'lobby'
        modes[mode] = (modes[mode] or 0) + 1
        list[#list + 1] = {
            name = player:displayName(),
            mode = mode,
            activity = LiveService.safe('activité', function() return LiveService.activityOf(source) end, false),
        }
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return { online = #GetPlayers(), max = GetConvarInt('sv_maxclients', 48), modes = modes, list = list }
end

---@return table[]
function LiveService.codMatches()
    local list = {}
    for _, match in pairs(CodService.matches) do
        local entry = {
            id = match.id,
            playlist = match.playlist.id,
            label = match.playlist.label,
            map = match.map.label,
            phase = match.phase,
            players = #match.players,
            max = match.playlist.maxPlayers,
            private = match.private,
            endsAt = LiveService.endTime(match.endAt),
            top = {},
        }
        if match.playlist.warzone then
            local state = match.rules.describe(match)
            entry.warzone = { alive = state.alive, squads = state.squads, zone = state.phase }
        elseif match.playlist.teams then
            entry.teams = {}
            for index, team in ipairs(Config.Cod.teams) do
                entry.teams[index] = { label = team.label, score = match.scores[team.id] or 0 }
            end
        end
        -- Partie privée : on annonce qu'elle existe, pas qui y joue
        if not match.private then
            for index, row in ipairs(match:board()) do
                if index > LiveService.MATCH_TOP then break end
                entry.top[index] = { name = row.name, kills = row.kills, deaths = row.deaths, assists = row.assists, points = row.points }
            end
        end
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

---@param sources integer[]
---@param identities table<integer, { name: string }>|nil
---@return string[]
function LiveService.names(sources, identities)
    local names = {}
    for _, source in ipairs(sources) do
        names[#names + 1] = identities and identities[source] and identities[source].name or GetPlayerName(source) or '?'
    end
    return names
end

---@return table[]
function LiveService.activityMatches()
    local list = {}
    for _, match in pairs(CvcService.matches) do
        list[#list + 1] = {
            activity = CvcService.ID, label = Config.FreeroamActivities.cvc.label, round = match.round, phase = match.phase,
            sides = {
                { names = LiveService.names(match.teams[1], match.identityOf), score = match.scores[1] },
                { names = LiveService.names(match.teams[2], match.identityOf), score = match.scores[2] },
            },
        }
    end
    for _, match in pairs(ChaseService.matches) do
        local sides = {}
        for index, source in ipairs(match.players) do
            sides[index] = { names = LiveService.names({ source }, match.identities), score = match.scores[source] }
        end
        list[#list + 1] = { activity = ChaseService.ID, label = Config.FreeroamActivities.chase.label, round = match.round, phase = match.phase, sides = sides }
    end
    for _, match in pairs(GunfightService.matches) do
        local sides = {}
        for index, source in ipairs(match.players) do
            sides[index] = { names = LiveService.names({ source }, match.identities), score = match.scores[source] }
        end
        list[#list + 1] = { activity = match.mode, label = Config.FreeroamActivities[match.mode].label, round = match.round, phase = match.phase, sides = sides }
    end
    for _, match in pairs(GungameService.matches) do
        local top = {}
        for index, source in ipairs(GungameService.ranking(match)) do
            if index > LiveService.MATCH_TOP then break end
            local stats = match.stats[source]
            top[index] = { name = stats.name, level = stats.level, kills = stats.kills, deaths = stats.deaths }
        end
        list[#list + 1] = {
            activity = GungameService.ID, label = Config.FreeroamActivities.gungame.label, phase = match.phase,
            players = #match.players, endsAt = LiveService.endTime(match.endAt), top = top,
        }
    end
    table.sort(list, function(a, b) return a.activity < b.activity end)
    return list
end

---@return { label: string, players: integer }[] files où quelqu'un attend
function LiveService.queues()
    local list = {}
    for _, playlist in ipairs(Config.Cod.playlists) do
        local queue = CodService.queues[playlist.id]
        if queue and #queue.players > 0 then
            list[#list + 1] = { mode = 'cod', label = playlist.label, players = #queue.players, min = playlist.minPlayers }
        end
    end
    local activities = {
        { id = 'cvc', queue = CvcService.queue },
        { id = 'chase', queue = ChaseService.queue },
        { id = 'gungame', queue = GungameService.queue },
        { id = 'gunfight', queue = GunfightService.queues.gunfight },
        { id = 'bike', queue = GunfightService.queues.bike },
    }
    for _, entry in ipairs(activities) do
        if entry.queue and #entry.queue > 0 then
            list[#list + 1] = { mode = 'freeroam', label = Config.FreeroamActivities[entry.id].label, players = #entry.queue }
        end
    end
    return list
end

---@return table
function LiveService.pvpEvents()
    local drops = {}
    for _, drop in pairs(AirdropService.drops) do
        drops[#drops + 1] = { landAt = drop.landAt, unlockAt = drop.unlockAt }
    end
    table.sort(drops, function(a, b) return a.unlockAt < b.unlockAt end)

    local control = {}
    for _, zone in ipairs(ControlService.describe()) do
        control[#control + 1] = {
            label = zone.label, owner = zone.ownerLabel, capturing = zone.capturer ~= false,
            progress = zone.progress, contested = zone.contested,
        }
    end

    local bounties = BountyService.list()
    table.sort(bounties, function(a, b) return a.amount > b.amount end)
    for _, bounty in ipairs(bounties) do bounty.id = nil end

    local horde = HordeService.describe()
    return {
        drops = drops,
        control = control,
        bounties = bounties,
        horde = horde and { label = horde.label, kills = horde.kills, endsAt = LiveService.roundTime(horde.endsIn) } or false,
    }
end

-- ---------------------------------------------------------------------------
-- Résultats des parties terminées
-- ---------------------------------------------------------------------------

---Un résultat raté ne doit jamais empêcher la fin d'une partie.
---@param build fun(): table
function LiveService.pushResult(build)
    local ok, entry = pcall(build)
    if not ok then return Logger.warn('[live] résultat non enregistré : %s', entry) end
    LiveService.nextResult = LiveService.nextResult + 1
    entry.id = LiveService.nextResult
    entry.boot = LiveService.startedAt
    entry.at = os.time()
    LiveService.results[#LiveService.results + 1] = entry
    if #LiveService.results > LiveService.MAX_RESULTS then table.remove(LiveService.results, 1) end
end

---Fin d'une partie Call of Duty.
---@param match table CodMatch
---@param winner string|integer|nil
---@param board table[]
function LiveService.codResult(match, winner, board)
    if match.private then return end
    LiveService.pushResult(function()
        local players = {}
        for index, row in ipairs(board) do
            if index > LiveService.RESULT_TOP then break end
            players[index] = { name = row.name, kills = row.kills, deaths = row.deaths, assists = row.assists, won = match:sideKey(row.id) == winner }
        end
        local entry = { mode = 'cod', label = match.playlist.label, map = match.map.label, total = #board, draw = winner == nil, players = players }
        if match.playlist.teams and not match.playlist.warzone then
            for _, team in ipairs(Config.Cod.teams) do
                if team.id == winner then entry.winner = team.label end
            end
            entry.score = ('%d - %d'):format(match.scores.alpha or 0, match.scores.bravo or 0)
        end
        return entry
    end)
end

---Fin d'une partie du Freeroam jouée en camps (CVC, course poursuite, 1VS1).
---@param activity string clé de Config.FreeroamActivities
---@param sides { names: string[], score: integer, elo: table[] }[] les deux camps
---@param winner integer|nil index du camp gagnant
function LiveService.activityResult(activity, sides, winner)
    LiveService.pushResult(function()
        local players = {}
        for index, side in ipairs(sides) do
            for position, name in ipairs(side.names) do
                local elo = side.elo[position]
                players[#players + 1] = { name = name, won = winner == index, delta = elo and elo.delta or false, elo = elo and elo.after or false }
            end
        end
        return {
            mode = 'freeroam', label = Config.FreeroamActivities[activity].label, draw = winner == nil, players = players,
            score = ('%d - %d'):format(sides[1].score, sides[2].score), total = #players,
        }
    end)
end

---Fin d'un Gungame.
---@param match table GungameMatch
---@param ranking integer[] du premier au dernier
---@param winner integer|nil
---@param elo table<integer, table> par joueur
function LiveService.gungameResult(match, ranking, winner, elo)
    LiveService.pushResult(function()
        local players = {}
        for index, source in ipairs(ranking) do
            if index > LiveService.RESULT_TOP then break end
            local stats, change = match.stats[source], elo[source]
            players[index] = {
                name = stats.name, kills = stats.kills, deaths = stats.deaths, won = source == winner,
                delta = change and change.delta or false, elo = change and change.after or false,
            }
        end
        return { mode = 'freeroam', label = Config.FreeroamActivities.gungame.label, draw = winner == nil, total = #ranking, players = players }
    end)
end

-- ---------------------------------------------------------------------------
-- Classements
-- ---------------------------------------------------------------------------

---@return table
function LiveService.boards()
    local now = os.time()
    local cache = LiveService.boardsCache
    if cache and now - cache.at < LiveService.BOARDS_CACHE then return cache.data end
    local data = LiveService.buildBoards()
    LiveService.boardsCache = { at = now, data = data }
    return data
end

---@return table
function LiveService.buildBoards()
    local season = SeasonService.current()
    return {
        at = os.time(),
        season = season,
        pvp = {
            season = LeaderboardService.buildSeason(season, true),
            all = LeaderboardService.build(),
            crews = CrewStatsService.build('season').rows,
            zombies = MySQL.query.await('SELECT name, npc_kills AS npcKills, kills, deaths FROM pvp_players WHERE npc_kills > 0 ORDER BY npc_kills DESC LIMIT ?', { LiveService.TOP }) or {},
        },
        elo = LiveService.eloBoards(),
        cod = LiveService.codBoards(),
        totals = LiveService.totals(),
    }
end

---@return table<string, table[]> par mode du Freeroam
function LiveService.eloBoards()
    local boards = {}
    for _, board in ipairs(Config.FreeroamBoards.boards) do
        boards[board.activity] = MySQL.query.await(
            'SELECT name, elo, wins, losses, draws FROM pvp_activity_ratings WHERE activity = ? ORDER BY elo DESC, wins DESC LIMIT ?',
            { board.activity, LiveService.TOP }) or {}
    end
    return boards
end

---@param rows table[]
---@return table[] avec le rang à la place de l'XP
function LiveService.withCodRank(rows)
    for _, row in ipairs(rows) do
        row.rank = CodProfileService.rankFromXp(row.xp)
        row.xp = nil
    end
    return rows
end

---@param where string
---@param order string
---@param ... any paramètres de la requête
---@return table[]
function LiveService.codTop(where, order, ...)
    local columns = 'name, xp, prestige, kills, deaths, assists, wins, losses, best_streak AS bestStreak'
    return LiveService.withCodRank(MySQL.query.await(
        ('SELECT %s FROM pvp_cod_profiles %s ORDER BY %s LIMIT ?'):format(columns, where, order), { ... }) or {})
end

---@return table
function LiveService.codBoards()
    return {
        ranks = LiveService.codTop('', 'prestige DESC, xp DESC, kills DESC', LiveService.TOP),
        kills = LiveService.codTop('WHERE kills > 0', 'kills DESC, deaths ASC', LiveService.TOP),
        kd = LiveService.codTop('WHERE kills >= ?', 'kills / GREATEST(deaths, 1) DESC', LiveService.KD_MIN_KILLS, LiveService.TOP),
        wins = LiveService.codTop('WHERE wins > 0', 'wins DESC, losses ASC', LiveService.TOP),
        streaks = LiveService.codTop('WHERE best_streak > 0', 'best_streak DESC, kills DESC', LiveService.TOP),
    }
end

---@return table
function LiveService.totals()
    local pvp = MySQL.single.await(
        'SELECT COUNT(*) AS players, COALESCE(SUM(kills), 0) AS kills, COALESCE(SUM(deaths), 0) AS deaths, COALESCE(SUM(npc_kills), 0) AS npcKills FROM pvp_players') or {}
    local cod = MySQL.single.await(
        'SELECT COUNT(*) AS players, COALESCE(SUM(kills), 0) AS kills, COALESCE(SUM(deaths), 0) AS deaths, COALESCE(SUM(wins), 0) AS wins FROM pvp_cod_profiles') or {}
    local elo = MySQL.single.await(
        'SELECT COUNT(DISTINCT identifier) AS players, COALESCE(SUM(wins + losses + draws), 0) AS games FROM pvp_activity_ratings') or {}
    return { pvp = pvp, cod = cod, elo = elo }
end

-- ---------------------------------------------------------------------------
-- Fiche d'un joueur (/stats sur Discord)
-- ---------------------------------------------------------------------------

---@param name string
---@return table
function LiveService.player(name)
    if name == '' or #name > 64 then return { found = false } end
    local pattern = name:gsub('[\\%%_]', '\\%0') .. '%'
    local row = MySQL.single.await(
        [[SELECT identifier, name, xp, kills, deaths, npc_kills, UNIX_TIMESTAMP(last_seen) AS last_seen FROM pvp_players
          WHERE name = ? OR name LIKE ? ORDER BY name = ? DESC, last_seen DESC LIMIT 1]],
        { name, pattern, name })
    if not row then return { found = false } end

    local online = nil
    for _, player in pairs(PlayerService.all()) do
        if player.identifier == row.identifier then online = player end
    end
    local identifier, season = row.identifier, SeasonService.current()
    local seasonRow = MySQL.single.await('SELECT kills, deaths, npc_kills FROM pvp_season_stats WHERE identifier = ? AND season = ?', { identifier, season }) or {}
    local stats = online and online.season or nil
    local cod = MySQL.single.await(
        'SELECT xp, prestige, kills, deaths, assists, wins, losses, best_streak AS bestStreak FROM pvp_cod_profiles WHERE identifier = ?', { identifier })
    if cod then LiveService.withCodRank({ cod }) end

    local elo = MySQL.query.await(
        [[SELECT r.activity, r.elo, r.wins, r.losses, r.draws,
              (SELECT COUNT(*) + 1 FROM pvp_activity_ratings o WHERE o.activity = r.activity AND o.elo > r.elo) AS position
          FROM pvp_activity_ratings r WHERE r.identifier = ?]], { identifier }) or {}
    for _, rating in ipairs(elo) do
        rating.label = Config.FreeroamActivities[rating.activity] and Config.FreeroamActivities[rating.activity].label or rating.activity
    end

    return {
        found = true,
        name = row.name,
        online = online ~= nil,
        mode = online and (online.mode or 'lobby') or false,
        lastSeen = row.last_seen,
        pvp = {
            level = Progression.levelFromXp(online and online.xp or row.xp),
            kills = online and online.kills or row.kills,
            deaths = online and online.deaths or row.deaths,
            npcKills = online and online.npcKills or row.npc_kills,
            seasonKills = stats and stats.kills or seasonRow.kills or 0,
            seasonDeaths = stats and stats.deaths or seasonRow.deaths or 0,
        },
        cod = cod or false,
        elo = elo,
    }
end
