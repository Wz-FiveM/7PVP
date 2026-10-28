---ELO de la course poursuite (Config.Chase.elo) : chaque partie terminée met à jour la cote des
---deux joueurs (victoire 1, égalité 0,5, défaite 0 ; un abandon compte comme une défaite).
---Le top est publié dans un state bag global, affiché sur le tableau DUI de la zone safe.
---@class ChaseRatingRow
---@field identifier string
---@field name string
---@field elo integer
---@field wins integer
---@field losses integer
---@field draws integer

---@class ChaseRatingModule
local ChaseRating = PVP.define('ChaseRating')
local Logger = PVP.use('Logger')

ChaseRating.STATE_KEY = '7pvp:chaseBoard'
ChaseRating.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_chase_ratings (
    identifier VARCHAR(64) NOT NULL,
    name VARCHAR(64) NOT NULL DEFAULT '',
    elo INT NOT NULL DEFAULT 1000,
    wins INT NOT NULL DEFAULT 0,
    losses INT NOT NULL DEFAULT 0,
    draws INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier),
    KEY idx_elo (elo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

---@type table<string, ChaseRatingRow> cotes déjà lues (cache)
ChaseRating.cache = {}

function ChaseRating.init()
    MySQL.ready(function()
        MySQL.query.await(ChaseRating.SCHEMA)
        ChaseRating.publishTop()
    end)
end

---@param identifier string
---@param name string
---@return ChaseRatingRow
function ChaseRating.get(identifier, name)
    local row = ChaseRating.cache[identifier]
    if not row then
        local found = MySQL.single.await(
            'SELECT identifier, name, elo, wins, losses, draws FROM pvp_chase_ratings WHERE identifier = ?', { identifier })
        row = found or { identifier = identifier, name = name, elo = Config.Chase.elo.start, wins = 0, losses = 0, draws = 0 }
        ChaseRating.cache[identifier] = row
    end
    row.name = name or row.name
    return row
end

---Applique le résultat d'une partie.
---@param a { identifier: string, name: string } joueur A
---@param b { identifier: string, name: string } joueur B
---@param scoreA number 1 victoire de A, 0,5 égalité, 0 victoire de B
---@return table<string, { before: integer, after: integer, delta: integer }> par identifiant
function ChaseRating.applyMatch(a, b, scoreA)
    local rowA, rowB = ChaseRating.get(a.identifier, a.name), ChaseRating.get(b.identifier, b.name)
    local k = Config.Chase.elo.k
    local expectedA = 1 / (1 + 10 ^ ((rowB.elo - rowA.elo) / 400))
    local deltaA = math.floor(k * (scoreA - expectedA) + 0.5)
    local deltaB = -deltaA

    local changes = {
        [a.identifier] = { before = rowA.elo, after = math.max(0, rowA.elo + deltaA), delta = deltaA },
        [b.identifier] = { before = rowB.elo, after = math.max(0, rowB.elo + deltaB), delta = deltaB },
    }
    ChaseRating.record(rowA, changes[a.identifier].after, scoreA)
    ChaseRating.record(rowB, changes[b.identifier].after, 1 - scoreA)
    ChaseRating.publishTop()
    Logger.info('[course] ELO : %s %d (%+d), %s %d (%+d)', rowA.name, rowA.elo, deltaA, rowB.name, rowB.elo, deltaB)
    return changes
end

---@param row ChaseRatingRow
---@param elo integer
---@param score number
function ChaseRating.record(row, elo, score)
    row.elo = elo
    if score == 1 then row.wins = row.wins + 1
    elseif score == 0 then row.losses = row.losses + 1
    else row.draws = row.draws + 1 end
    MySQL.insert.await([[INSERT INTO pvp_chase_ratings (identifier, name, elo, wins, losses, draws)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), elo = VALUES(elo), wins = VALUES(wins),
            losses = VALUES(losses), draws = VALUES(draws)]],
        { row.identifier, row.name, row.elo, row.wins, row.losses, row.draws })
end

---Top publié à tous les clients (tableau DUI de la zone safe).
function ChaseRating.publishTop()
    local rows = MySQL.query.await(
        'SELECT name, elo, wins, losses, draws FROM pvp_chase_ratings ORDER BY elo DESC, wins DESC LIMIT ?',
        { Config.Chase.elo.boardSize }) or {}
    GlobalState[ChaseRating.STATE_KEY] = rows
end
