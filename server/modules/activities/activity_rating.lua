---ELO des modes de jeu du Freeroam (Config.FreeroamBoards) : une cote par joueur et par mode, mise
---à jour à chaque partie terminée (victoire 1, égalité 0,5, défaite 0 ; un abandon compte comme une
---défaite). En équipe (CVC), la cote attendue se calcule sur la moyenne de chaque équipe ; en chacun
---pour soi (Gungame), chaque joueur est comparé à tous les autres selon le classement final.
---Le top de chaque mode est publié dans un state bag global, affiché sur son tableau DUI de la zone safe.
---@class ActivityRatingRow
---@field identifier string
---@field name string
---@field elo integer
---@field wins integer
---@field losses integer
---@field draws integer

---@class ActivityRatingIdentity
---@field identifier string
---@field name string
---@field left boolean|nil a quitté la partie en cours (compte comme une défaite)

---@class ActivityRatingModule
local ActivityRating = PVP.define('ActivityRating')
local Logger = PVP.use('Logger')

ActivityRating.STATE_PREFIX = '7pvp:board:'
ActivityRating.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_activity_ratings (
    activity VARCHAR(32) NOT NULL,
    identifier VARCHAR(64) NOT NULL,
    name VARCHAR(64) NOT NULL DEFAULT '',
    elo INT NOT NULL DEFAULT 1000,
    wins INT NOT NULL DEFAULT 0,
    losses INT NOT NULL DEFAULT 0,
    draws INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (activity, identifier),
    KEY idx_board (activity, elo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]
-- Ancienne table de la course poursuite (avant les classements par mode) : reprise une fois
ActivityRating.LEGACY_CHASE = 'pvp_chase_ratings'

---@type table<string, table<string, ActivityRatingRow>> cotes déjà lues, par mode (cache)
ActivityRating.cache = {}

function ActivityRating.init()
    MySQL.ready(function()
        MySQL.query.await(ActivityRating.SCHEMA)
        ActivityRating.migrateChase()
        for _, board in ipairs(Config.FreeroamBoards.boards) do
            ActivityRating.publishTop(board.activity)
        end
    end)
end

---Reprend les cotes de pvp_chase_ratings (sans écraser celles déjà dans la nouvelle table).
function ActivityRating.migrateChase()
    local exists = MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?',
        { ActivityRating.LEGACY_CHASE })
    if not exists or exists == 0 then return end
    local result = MySQL.update.await(([[INSERT IGNORE INTO pvp_activity_ratings (activity, identifier, name, elo, wins, losses, draws)
        SELECT 'chase', identifier, name, elo, wins, losses, draws FROM %s]]):format(ActivityRating.LEGACY_CHASE))
    if result and result > 0 then
        Logger.info('[classement] %d cotes de la course poursuite reprises de %s', result, ActivityRating.LEGACY_CHASE)
    end
end

---@param activity string
---@param identifier string
---@param name string
---@return ActivityRatingRow
function ActivityRating.get(activity, identifier, name)
    local cache = ActivityRating.cache[activity] or {}
    ActivityRating.cache[activity] = cache
    local row = cache[identifier]
    if not row then
        local found = MySQL.single.await(
            'SELECT identifier, name, elo, wins, losses, draws FROM pvp_activity_ratings WHERE activity = ? AND identifier = ?',
            { activity, identifier })
        row = found or { identifier = identifier, name = name, elo = Config.FreeroamBoards.elo.start, wins = 0, losses = 0, draws = 0 }
        cache[identifier] = row
    end
    row.name = name or row.name
    return row
end

---Résultat d'une partie entre deux équipes (un duel : une équipe d'un joueur chacune) : la cote attendue vient de la moyenne de chaque équipe,
---chaque joueur gagne ou perd selon le résultat de son équipe (défaite s'il a quitté la partie).
---Un même joueur dans les deux équipes (même compte) : la partie ne compte pas.
---@param activity string clé de Config.FreeroamActivities
---@param teamA ActivityRatingIdentity[]
---@param teamB ActivityRatingIdentity[]
---@param scoreA number 1 victoire de l'équipe A, 0,5 égalité, 0 victoire de l'équipe B
---@return table<string, { before: integer, after: integer, delta: integer }> par identifiant
function ActivityRating.applyTeams(activity, teamA, teamB, scoreA)
    local seen = {}
    for _, team in ipairs({ teamA, teamB }) do
        for _, identity in ipairs(team) do
            if seen[identity.identifier] then return {} end
            seen[identity.identifier] = true
        end
    end
    if #teamA == 0 or #teamB == 0 then return {} end

    local rows, averages = { {}, {} }, {}
    for index, team in ipairs({ teamA, teamB }) do
        local total = 0
        for _, identity in ipairs(team) do
            local row = ActivityRating.get(activity, identity.identifier, identity.name)
            rows[index][#rows[index] + 1] = row
            total = total + row.elo
        end
        averages[index] = total / #team
    end

    local k = Config.FreeroamBoards.elo.k
    local expected = { 1 / (1 + 10 ^ ((averages[2] - averages[1]) / 400)) }
    expected[2] = 1 - expected[1]
    local teamScores = { scoreA, 1 - scoreA }
    local changes, summary = {}, {}
    for index, team in ipairs({ teamA, teamB }) do
        for position, identity in ipairs(team) do
            local row = rows[index][position]
            local score = identity.left and 0 or teamScores[index]
            local delta = math.floor(k * (score - expected[index]) + 0.5)
            local after = math.max(0, row.elo + delta)
            changes[identity.identifier] = { before = row.elo, after = after, delta = after - row.elo }
            ActivityRating.record(activity, row, after, score)
            summary[#summary + 1] = ('%s %d (%+d)'):format(row.name, after, changes[identity.identifier].delta)
        end
    end
    ActivityRating.publishTop(activity)
    Logger.info('[classement] %s : %s', activity, table.concat(summary, ', '))
    return changes
end

---Résultat d'une partie chacun pour soi (Gungame) : chaque joueur est comparé à tous les autres selon
---son classement final (devant 1, même place 0,5, derrière 0), les points en jeu (k) étant partagés
---entre ses adversaires. Seul le premier compte une victoire, les autres une défaite.
---Un même joueur deux fois (même compte) : la partie ne compte pas.
---@param activity string clé de Config.FreeroamActivities
---@param ranking { identity: ActivityRatingIdentity, place: integer }[] place 1 = premier
---@return table<string, { before: integer, after: integer, delta: integer }> par identifiant
function ActivityRating.applyFreeForAll(activity, ranking)
    local seen = {}
    for _, entry in ipairs(ranking) do
        if seen[entry.identity.identifier] then return {} end
        seen[entry.identity.identifier] = true
    end
    if #ranking < 2 then return {} end

    local rows = {}
    for index, entry in ipairs(ranking) do
        rows[index] = ActivityRating.get(activity, entry.identity.identifier, entry.identity.name)
    end

    -- Calculé sur les cotes d'avant la partie, appliqué ensuite
    local k = Config.FreeroamBoards.elo.k / (#ranking - 1)
    local deltas = {}
    for index, entry in ipairs(ranking) do
        local total = 0
        for other, opponent in ipairs(ranking) do
            if other ~= index then
                local expected = 1 / (1 + 10 ^ ((rows[other].elo - rows[index].elo) / 400))
                local score = entry.place < opponent.place and 1 or (entry.place == opponent.place and 0.5 or 0)
                total = total + score - expected
            end
        end
        deltas[index] = math.floor(k * total + 0.5)
    end

    local changes, summary = {}, {}
    for index, entry in ipairs(ranking) do
        local row = rows[index]
        local after = math.max(0, row.elo + deltas[index])
        changes[entry.identity.identifier] = { before = row.elo, after = after, delta = after - row.elo }
        ActivityRating.record(activity, row, after, entry.place == 1 and 1 or 0)
        summary[#summary + 1] = ('%s %d (%+d)'):format(row.name, after, changes[entry.identity.identifier].delta)
    end
    ActivityRating.publishTop(activity)
    Logger.info('[classement] %s : %s', activity, table.concat(summary, ', '))
    return changes
end

---@param activity string
---@param row ActivityRatingRow
---@param elo integer
---@param score number
function ActivityRating.record(activity, row, elo, score)
    row.elo = elo
    if score == 1 then row.wins = row.wins + 1
    elseif score == 0 then row.losses = row.losses + 1
    else row.draws = row.draws + 1 end
    MySQL.insert.await([[INSERT INTO pvp_activity_ratings (activity, identifier, name, elo, wins, losses, draws)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), elo = VALUES(elo), wins = VALUES(wins),
            losses = VALUES(losses), draws = VALUES(draws)]],
        { activity, row.identifier, row.name, row.elo, row.wins, row.losses, row.draws })
end

---Top d'un mode publié à tous les clients (son tableau DUI dans la zone safe).
---@param activity string
function ActivityRating.publishTop(activity)
    local rows = MySQL.query.await(
        'SELECT name, elo, wins, losses, draws FROM pvp_activity_ratings WHERE activity = ? ORDER BY elo DESC, wins DESC LIMIT ?',
        { activity, Config.FreeroamBoards.size }) or {}
    GlobalState[ActivityRating.STATE_PREFIX .. activity] = rows
end

---Applique un résultat sans faire échouer la fin de partie si la base ne répond pas.
---@param activity string
---@param teamA ActivityRatingIdentity[]
---@param teamB ActivityRatingIdentity[]
---@param scoreA number
---@return table<string, { before: integer, after: integer, delta: integer }> par identifiant ({} en cas d'erreur)
function ActivityRating.safeApply(activity, teamA, teamB, scoreA)
    local ok, changes = pcall(ActivityRating.applyTeams, activity, teamA, teamB, scoreA)
    if not ok then
        Logger.error('[classement] ELO du %s non enregistré : %s', activity, changes)
        return {}
    end
    return changes
end

---ActivityRating.applyFreeForAll sans faire échouer la fin de partie si la base ne répond pas.
---@param activity string
---@param ranking { identity: ActivityRatingIdentity, place: integer }[]
---@return table<string, { before: integer, after: integer, delta: integer }> par identifiant ({} en cas d'erreur)
function ActivityRating.safeApplyFreeForAll(activity, ranking)
    local ok, changes = pcall(ActivityRating.applyFreeForAll, activity, ranking)
    if not ok then
        Logger.error('[classement] ELO du %s non enregistré : %s', activity, changes)
        return {}
    end
    return changes
end
