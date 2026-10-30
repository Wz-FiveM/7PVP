---@class LeaderboardRow
---@field name string
---@field level integer
---@field xp integer
---@field kills integer
---@field deaths integer
---@field npcKills integer
---@field online boolean

---@class LeaderboardServiceModule
local LeaderboardService = PVP.define('LeaderboardService')
local PlayerService = PVP.use('PlayerService')
local PlayerRepository = PVP.use('PlayerRepository')
local Progression = PVP.use('Progression')
local SeasonService = PVP.use('SeasonService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

LeaderboardService.SIZE = 10
LeaderboardService.CACHE_TIME = 15000
---@type table<string, { rows: LeaderboardRow[], title: string, at: integer }> cache par onglet
LeaderboardService.cache = {}

function LeaderboardService.init()
    Callback.register(Events.callbacks.leaderboard, LeaderboardService.get)
end

---@param source integer
---@param scope any 'season' (défaut), 'previous' ou 'all'
---@return { rows: LeaderboardRow[], title: string }
function LeaderboardService.get(source, scope)
    if scope ~= 'previous' and scope ~= 'all' then scope = 'season' end
    local cached = LeaderboardService.cache[scope]
    if not cached or GetGameTimer() - cached.at > LeaderboardService.CACHE_TIME then
        cached = LeaderboardService.buildScope(scope)
        cached.at = GetGameTimer()
        LeaderboardService.cache[scope] = cached
    end
    return { rows = cached.rows, title = cached.title }
end

---@param scope 'season'|'previous'|'all'
---@return { rows: LeaderboardRow[], title: string }
function LeaderboardService.buildScope(scope)
    if scope == 'all' then
        return { rows = LeaderboardService.build(), title = Locale.t('De tous les temps') }
    end
    local season = SeasonService.current()
    if scope == 'previous' then season = SeasonService.previous(season) end
    return { rows = LeaderboardService.buildSeason(season, scope == 'season'), title = SeasonService.label(season) }
end

---@param season string
---@param withOnline boolean remplacer par les valeurs des joueurs connectés (saison en cours)
---@return LeaderboardRow[]
function LeaderboardService.buildSeason(season, withOnline)
    local byIdentifier = {}
    for _, row in ipairs(PlayerRepository.topSeason(season, LeaderboardService.SIZE * 2)) do
        byIdentifier[row.identifier] = LeaderboardService.toRow(row.name, row.xp, row.kills, row.deaths, row.npc_kills, false)
    end
    if withOnline then
        for _, player in pairs(PlayerService.all()) do
            local stats = player.season
            if stats and stats.id == season and (stats.kills + stats.deaths + stats.npcKills) > 0 then
                byIdentifier[player.identifier] = LeaderboardService.toRow(player.name, player.xp, stats.kills, stats.deaths, stats.npcKills, true)
            end
        end
    end
    return LeaderboardService.sortTop(byIdentifier)
end

---@param byIdentifier table<string, LeaderboardRow>
---@return LeaderboardRow[]
function LeaderboardService.sortTop(byIdentifier)
    local rows = {}
    for _, row in pairs(byIdentifier) do rows[#rows + 1] = row end
    table.sort(rows, LeaderboardService.compare)
    local top = {}
    for i = 1, math.min(LeaderboardService.SIZE, #rows) do top[i] = rows[i] end
    return top
end

---@return LeaderboardRow
function LeaderboardService.toRow(name, xp, kills, deaths, npcKills, online)
    return {
        name = name,
        level = Progression.levelFromXp(xp),
        xp = xp,
        kills = kills,
        deaths = deaths,
        npcKills = npcKills,
        online = online,
    }
end

---@param a LeaderboardRow
---@param b LeaderboardRow
---@return boolean
function LeaderboardService.compare(a, b)
    if a.kills ~= b.kills then return a.kills > b.kills end
    return a.xp > b.xp
end

---Les valeurs en base datent de la dernière sauvegarde :
---on les remplace par celles des joueurs connectés.
---@return LeaderboardRow[]
function LeaderboardService.build()
    local byIdentifier = {}
    for _, row in ipairs(PlayerRepository.top(LeaderboardService.SIZE * 2)) do
        byIdentifier[row.identifier] = LeaderboardService.toRow(row.name, row.xp, row.kills, row.deaths, row.npc_kills, false)
    end
    for _, player in pairs(PlayerService.all()) do
        byIdentifier[player.identifier] = LeaderboardService.toRow(player.name, player.xp, player.kills, player.deaths, player.npcKills, true)
    end

    return LeaderboardService.sortTop(byIdentifier)
end
