---Saisons : une par mois (UTC). Les kills, morts et zombies tués de la saison sont comptés à
---part (table pvp_season_stats) pour le classement de saison ; l'inventaire, l'argent, l'XP et
---les stats de toujours ne sont jamais remis à zéro. Les saisons passées restent en base.
---@class SeasonServiceModule
local SeasonService = PVP.define('SeasonService')
local PlayerService = PVP.use('PlayerService')
local PlayerRepository = PVP.use('PlayerRepository')
local ChatService = PVP.use('ChatService')
local Logger = PVP.use('Logger')

SeasonService.CHECK_INTERVAL = 60000
SeasonService.MONTHS = {
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
}

SeasonService.active = nil

function SeasonService.init()
    SeasonService.active = SeasonService.current()
    CreateThread(SeasonService.loop)
end

---@return string saison en cours, ex : 2026-10
function SeasonService.current()
    return os.date('!%Y-%m')
end

---@param season string
---@return string saison précédente
function SeasonService.previous(season)
    local year, month = season:match('^(%d+)-(%d+)$')
    year, month = tonumber(year), tonumber(month) - 1
    if month == 0 then year, month = year - 1, 12 end
    return ('%04d-%02d'):format(year, month)
end

---@param season string
---@return string ex : « Saison octobre 2026 »
function SeasonService.label(season)
    local year, month = season:match('^(%d+)-(%d+)$')
    return ('Saison %s %s'):format(SeasonService.MONTHS[tonumber(month)] or month, year)
end

---Stats de saison d'un joueur qui se connecte.
---@param identifier string
---@return { id: string, kills: integer, deaths: integer, npcKills: integer }
function SeasonService.load(identifier)
    local season = SeasonService.current()
    local row = PlayerRepository.findSeason(identifier, season) or {}
    return { id = season, kills = row.kills or 0, deaths = row.deaths or 0, npcKills = row.npc_kills or 0 }
end

---Changement de mois : les joueurs connectés passent à la nouvelle saison.
function SeasonService.loop()
    while true do
        Wait(SeasonService.CHECK_INTERVAL)
        local season = SeasonService.current()
        if season ~= SeasonService.active then
            SeasonService.start(season)
        end
    end
end

---@param season string
function SeasonService.start(season)
    local previous = SeasonService.active
    SeasonService.active = season
    for _, player in pairs(PlayerService.all()) do
        PlayerRepository.saveSeason(player)
        player.season = { id = season, kills = 0, deaths = 0, npcKills = 0 }
        player:sync()
    end
    ChatService.announce('pvp', ('%s terminée : place à la %s ! Le classement de saison repart à zéro.')
        :format(SeasonService.label(previous), SeasonService.label(season)))
    Logger.info('[saison] %s -> %s', previous, season)
end
