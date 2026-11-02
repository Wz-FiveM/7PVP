---Classement des crews, par saison : kills, morts et territoires pris par le crew (Config.Crews.stats).
---Un kill compte pour le crew du tueur au moment du kill : recruter un joueur n'apporte pas ses anciens
---kills, et un membre qui part garde ce qu'il a déjà rapporté au crew.
---@class CrewBoardRow
---@field tag string
---@field name string
---@field members integer
---@field territories integer|false territoires tenus, `false` hors de la saison en cours
---@field score integer
---@field kills integer
---@field deaths integer
---@field captures integer

---@class CrewStatsServiceModule
local CrewStatsService = PVP.define('CrewStatsService')
local CrewService = PVP.use('CrewService')
local CrewRepository = PVP.use('CrewRepository')
local ControlService = PVP.use('ControlService')
local GroupService = PVP.use('GroupService')
local SeasonService = PVP.use('SeasonService')
local CrewWarService = PVP.use('CrewWarService')
local CrewTournamentService = PVP.use('CrewTournamentService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CrewStatsService.SIZE = 10
CrewStatsService.CACHE_TIME = 15000
CrewStatsService.MAX_PAIRS = 2000

---@type table<string, integer> 'tueur:victime' (licences) -> GetGameTimer() du dernier kill compté
CrewStatsService.lastKills = {}
CrewStatsService.pairCount = 0
---@type table<string, { rows: CrewBoardRow[], title: string|table, at: integer }> cache par onglet
CrewStatsService.cache = {}

function CrewStatsService.init()
    Callback.register(Events.callbacks.crewLeaderboard, CrewStatsService.get)
end

---Appelé à chaque kill entre joueurs (voir CombatService.rewardPlayerKill).
---@param killer PvpPlayer
---@param victim PvpPlayer
function CrewStatsService.onPlayerKill(killer, victim)
    if killer.mode ~= 'pvp' or victim.mode ~= 'pvp' then return end
    local killerTag = CrewService.tagOf(killer.identifier)
    local victimTag = CrewService.tagOf(victim.identifier)
    if (not killerTag and not victimTag) or killerTag == victimTag then return end
    if GroupService.areAllies(killer.source, victim.source) or not CrewStatsService.countsAgain(killer, victim) then return end

    local season = SeasonService.current()
    if killerTag then CrewRepository.addStats(killerTag, season, 1, 0, 0) end
    if victimTag then CrewRepository.addStats(victimTag, season, 0, 1, 0) end
    if killerTag and victimTag then
        CrewWarService.onKill(killerTag, victimTag)
        CrewTournamentService.onKill(killerTag, victimTag)
    end
end

---Deux joueurs complices ne font pas monter un crew en se tuant en boucle.
---@param killer PvpPlayer
---@param victim PvpPlayer
---@return boolean
function CrewStatsService.countsAgain(killer, victim)
    local pair = killer.identifier .. ':' .. victim.identifier
    local now = GetGameTimer()
    local last = CrewStatsService.lastKills[pair]
    if last and now - last < Config.Crews.stats.sameVictimDelay * 1000 then return false end

    if not last then
        CrewStatsService.pairCount = CrewStatsService.pairCount + 1
        if CrewStatsService.pairCount > CrewStatsService.MAX_PAIRS then
            CrewStatsService.lastKills = {}
            CrewStatsService.pairCount = 1
        end
    end
    CrewStatsService.lastKills[pair] = now
    return true
end

---Appelé quand un crew prend un territoire (voir ControlService.onTerritoryTaken).
---@param tag string
function CrewStatsService.onCapture(tag)
    CrewRepository.addStats(tag, SeasonService.current(), 0, 0, 1)
end

---@param source integer
---@param scope any 'season' (défaut), 'previous' ou 'all'
---@return { rows: CrewBoardRow[], title: string|table }
function CrewStatsService.get(source, scope)
    if scope ~= 'previous' and scope ~= 'all' then scope = 'season' end
    local cached = CrewStatsService.cache[scope]
    if not cached or GetGameTimer() - cached.at > CrewStatsService.CACHE_TIME then
        cached = CrewStatsService.build(scope)
        cached.at = GetGameTimer()
        CrewStatsService.cache[scope] = cached
    end
    return { rows = cached.rows, title = cached.title }
end

---@param scope 'season'|'previous'|'all'
---@return { rows: CrewBoardRow[], title: string|table }
function CrewStatsService.build(scope)
    if scope == 'all' then
        return { rows = CrewStatsService.toRows(CrewRepository.loadStats(nil), false), title = Locale.t('De tous les temps') }
    end
    local season = SeasonService.current()
    if scope == 'previous' then season = SeasonService.previous(season) end
    return { rows = CrewStatsService.toRows(CrewRepository.loadStats(season), scope == 'season'), title = SeasonService.label(season) }
end

---@param stats { crew_tag: string, kills: any, deaths: any, captures: any }[]
---@param withTerritories boolean afficher les territoires tenus (saison en cours)
---@return CrewBoardRow[] les meilleurs crews, triés par score
function CrewStatsService.toRows(stats, withTerritories)
    local rows = {}
    for _, row in ipairs(stats) do
        local crew = CrewService.crews[row.crew_tag]
        if crew then
            local kills, deaths, captures = tonumber(row.kills) or 0, tonumber(row.deaths) or 0, tonumber(row.captures) or 0
            rows[#rows + 1] = {
                tag = crew.tag,
                name = crew.name,
                members = #crew.members,
                territories = withTerritories and ControlService.territoriesOf(ControlService.CREW_PREFIX .. crew.tag),
                score = kills + captures * Config.Crews.stats.captureScore,
                kills = kills,
                deaths = deaths,
                captures = captures,
            }
        end
    end
    table.sort(rows, CrewStatsService.compare)

    local top = {}
    for index = 1, math.min(CrewStatsService.SIZE, #rows) do top[index] = rows[index] end
    return top
end

---@param a CrewBoardRow
---@param b CrewBoardRow
---@return boolean
function CrewStatsService.compare(a, b)
    if a.score ~= b.score then return a.score > b.score end
    if a.kills ~= b.kills then return a.kills > b.kills end
    return a.tag < b.tag
end
