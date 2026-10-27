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
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')

LeaderboardService.SIZE = 10
LeaderboardService.CACHE_TIME = 15000
LeaderboardService.cache = nil
LeaderboardService.cachedAt = 0

function LeaderboardService.init()
    Callback.register(Events.callbacks.leaderboard, LeaderboardService.get)
end

---@return LeaderboardRow[]
function LeaderboardService.get()
    if not LeaderboardService.cache or GetGameTimer() - LeaderboardService.cachedAt > LeaderboardService.CACHE_TIME then
        LeaderboardService.cache = LeaderboardService.build()
        LeaderboardService.cachedAt = GetGameTimer()
    end
    return LeaderboardService.cache
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

    local rows = {}
    for _, row in pairs(byIdentifier) do
        rows[#rows + 1] = row
    end
    table.sort(rows, LeaderboardService.compare)

    local top = {}
    for i = 1, math.min(LeaderboardService.SIZE, #rows) do
        top[i] = rows[i]
    end
    return top
end
