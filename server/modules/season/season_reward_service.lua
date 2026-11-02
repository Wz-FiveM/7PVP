---Récompenses de fin de saison (Config.SeasonRewards) : le classement de la saison passée paie des
---points boutique et un titre, même aux joueurs hors ligne. Une saison n'est payée qu'une fois (table
---pvp_season_rewards) et le crédit des points porte une référence unique. Vérifié au démarrage aussi :
---le serveur peut être éteint au moment du changement de mois.
---@class SeasonRewardServiceModule
local SeasonRewardService = PVP.define('SeasonRewardService')
local SeasonService = PVP.use('SeasonService')
local PlayerService = PVP.use('PlayerService')
local PlayerRepository = PVP.use('PlayerRepository')
local ShopPointsService = PVP.use('ShopPointsService')
local ChatService = PVP.use('ChatService')
local DiscordService = PVP.use('DiscordService')
local Logger = PVP.use('Logger')
local Locale = PVP.use('Locale')

SeasonRewardService.SCHEMAS = {
    [[CREATE TABLE IF NOT EXISTS pvp_season_rewards (
        season VARCHAR(7) NOT NULL,
        winners TEXT NULL,
        granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (season)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS pvp_season_titles (
        identifier VARCHAR(64) NOT NULL,
        title_id VARCHAR(32) NOT NULL,
        label VARCHAR(64) NOT NULL,
        PRIMARY KEY (identifier, title_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}
-- Laisse aux sauvegardes des joueurs le temps d'arriver en base avant de lire le classement (ms)
SeasonRewardService.SAVE_DELAY = 5000

---@type { season: string, rows: table[] }|nil derniers gagnants, pour le bot Discord
SeasonRewardService.lastWinners = nil

function SeasonRewardService.init()
    MySQL.ready(function()
        for _, schema in ipairs(SeasonRewardService.SCHEMAS) do MySQL.query.await(schema) end
        SeasonRewardService.loadWinners()
        SeasonRewardService.grant(SeasonService.previous(SeasonService.current()))
    end)
end

function SeasonRewardService.loadWinners()
    local rows = MySQL.query.await('SELECT season, winners FROM pvp_season_rewards ORDER BY season DESC LIMIT 1') or {}
    local row = rows[1]
    if not row then return end
    local ok, winners = pcall(json.decode, row.winners or '')
    SeasonRewardService.lastWinners = { season = row.season, rows = ok and type(winners) == 'table' and winners or {} }
end

---Fin d'une saison (voir SeasonService.start).
---@param season string
function SeasonRewardService.onSeasonEnded(season)
    CreateThread(function()
        Wait(SeasonRewardService.SAVE_DELAY)
        SeasonRewardService.grant(season)
    end)
end

---@param rank integer
---@return table|nil palier de Config.SeasonRewards.ranks
function SeasonRewardService.rankReward(rank)
    for _, entry in ipairs(Config.SeasonRewards.ranks) do
        if rank >= entry.from and rank <= entry.to then return entry end
    end
    return nil
end

---@param season string
function SeasonRewardService.grant(season)
    -- La ligne réserve le paiement : deux appels ne peuvent pas payer la même saison
    local inserted = MySQL.update.await('INSERT IGNORE INTO pvp_season_rewards (season) VALUES (?)', { season })
    if (inserted or 0) == 0 then return end

    local winners = {}
    for rank, row in ipairs(PlayerRepository.topSeason(season, Config.SeasonRewards.ranks[#Config.SeasonRewards.ranks].to)) do
        local reward = SeasonRewardService.rankReward(rank)
        if reward and row.kills >= Config.SeasonRewards.minKills then
            SeasonRewardService.pay(season, rank, row, reward)
            winners[#winners + 1] = { rank = rank, name = row.name, kills = row.kills, points = reward.points, title = reward.title }
        end
    end

    MySQL.update('UPDATE pvp_season_rewards SET winners = ? WHERE season = ?', { json.encode(winners), season })
    SeasonRewardService.lastWinners = { season = season, rows = winners }
    SeasonRewardService.announce(season, winners)
    Logger.info('[saison] %s : %d joueurs récompensés', season, #winners)
end

---@param season string
---@param rank integer
---@param row table { identifier, name, kills }
---@param reward table
function SeasonRewardService.pay(season, rank, row, reward)
    ShopPointsService.credit(row.identifier, reward.points, 'season', ('season:%s:%s'):format(season, row.identifier))
    SeasonRewardService.giveTitle(row.identifier, ('%s:%s'):format(season, reward.id), reward.title)

    local player = ShopPointsService.findOnline(row.identifier)
    if player then
        player:notify(Locale.t('Saison terminée : tu finis %de et gagnes un titre : %s.', rank, Locale.t(reward.title)), 'success')
    end
end

---@param identifier string
---@param id string
---@param label string
function SeasonRewardService.giveTitle(identifier, id, label)
    MySQL.insert('INSERT IGNORE INTO pvp_season_titles (identifier, title_id, label) VALUES (?, ?, ?)', { identifier, id, label })
    local player = ShopPointsService.findOnline(identifier)
    if player then
        player.seasonTitles[id] = label
        player:sync()
    end
end

---@param season string
---@param winners table[]
function SeasonRewardService.announce(season, winners)
    if #winners == 0 then return end
    local first = winners[1]
    ChatService.announce('pvp', Locale.t('%s : %s remporte la saison avec %d kills !', SeasonService.label(season), first.name, first.kills))
    local lines = {}
    for _, winner in ipairs(winners) do
        lines[#lines + 1] = ('%d. %s : %d kills, %d points'):format(winner.rank, DiscordService.escape(winner.name), winner.kills, winner.points)
    end
    DiscordService.send('admin', { title = ('Récompenses de la saison %s'):format(season), description = table.concat(lines, '\n') })
end

---Titres de saison du joueur, au chargement du profil.
---@param player PvpPlayer
function SeasonRewardService.load(player)
    local rows = MySQL.query.await('SELECT title_id, label FROM pvp_season_titles WHERE identifier = ?', { player.identifier }) or {}
    player.seasonTitles = {}
    for _, row in ipairs(rows) do player.seasonTitles[row.title_id] = row.label end
end
