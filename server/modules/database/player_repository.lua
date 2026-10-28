---Accès à la table `pvp_players`.
---@class PlayerRepositoryModule
local PlayerRepository = PVP.define('PlayerRepository')
local Logger = PVP.use('Logger')

-- Évolutions du schéma pour les bases créées avant l'ajout d'une colonne
PlayerRepository.MIGRATIONS = {
    'ALTER TABLE pvp_players ADD COLUMN IF NOT EXISTS appearance LONGTEXT NULL AFTER inventory',
    'ALTER TABLE pvp_players ADD COLUMN IF NOT EXISTS is_admin TINYINT(1) NOT NULL DEFAULT 0 AFTER appearance',
    'ALTER TABLE pvp_players ADD COLUMN IF NOT EXISTS contracts LONGTEXT NULL AFTER is_admin',
    [[CREATE TABLE IF NOT EXISTS pvp_season_stats (
        season VARCHAR(7) NOT NULL,
        identifier VARCHAR(64) NOT NULL,
        name VARCHAR(64) NOT NULL DEFAULT '',
        kills INT NOT NULL DEFAULT 0,
        deaths INT NOT NULL DEFAULT 0,
        npc_kills INT NOT NULL DEFAULT 0,
        PRIMARY KEY (season, identifier),
        KEY idx_season_kills (season, kills)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

function PlayerRepository.init()
    local schema = LoadResourceFile(GetCurrentResourceName(), 'sql/7pvp.sql')
    MySQL.ready(function()
        MySQL.query.await(schema)
        for _, migration in ipairs(PlayerRepository.MIGRATIONS) do
            MySQL.query.await(migration)
        end
        Logger.info('Base de données prête')
    end)
end

---@param identifier string
---@return table|nil
function PlayerRepository.find(identifier)
    return MySQL.single.await('SELECT * FROM pvp_players WHERE identifier = ?', { identifier })
end

---@param identifier string
---@param name string
---@param inventory string inventaire encodé en JSON (l'argent en fait partie)
function PlayerRepository.create(identifier, name, inventory)
    MySQL.insert.await('INSERT INTO pvp_players (identifier, name, inventory) VALUES (?, ?, ?)', {
        identifier, name, inventory,
    })
end

---@param player PvpPlayer
function PlayerRepository.save(player)
    MySQL.update(
        'UPDATE pvp_players SET name = ?, xp = ?, kills = ?, deaths = ?, npc_kills = ?, inventory = ?, appearance = ?, contracts = ? WHERE identifier = ?',
        {
            player.name, player.xp, player.kills, player.deaths, player.npcKills,
            player.inventory:encode(), player.appearance and json.encode(player.appearance) or nil,
            json.encode(player.contracts), player.identifier,
        }
    )
    PlayerRepository.saveSeason(player)
end

---Stats de la saison en cours du joueur (créées au besoin).
---@param player PvpPlayer
function PlayerRepository.saveSeason(player)
    local season = player.season
    if not season then return end
    MySQL.insert(
        [[INSERT INTO pvp_season_stats (season, identifier, name, kills, deaths, npc_kills) VALUES (?, ?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE name = VALUES(name), kills = VALUES(kills), deaths = VALUES(deaths), npc_kills = VALUES(npc_kills)]],
        { season.id, player.identifier, player.name, season.kills, season.deaths, season.npcKills }
    )
end

---@param identifier string
---@param season string
---@return table|nil
function PlayerRepository.findSeason(identifier, season)
    return MySQL.single.await('SELECT kills, deaths, npc_kills FROM pvp_season_stats WHERE identifier = ? AND season = ?', {
        identifier, season,
    })
end

---Meilleurs joueurs d'une saison, avec leur XP actuelle (pour le niveau).
---@param season string
---@param limit integer
---@return table[]
function PlayerRepository.topSeason(season, limit)
    return MySQL.query.await(
        [[SELECT s.identifier, s.name, s.kills, s.deaths, s.npc_kills, COALESCE(p.xp, 0) AS xp
          FROM pvp_season_stats s LEFT JOIN pvp_players p ON p.identifier = s.identifier
          WHERE s.season = ? ORDER BY s.kills DESC, s.npc_kills DESC LIMIT ?]],
        { season, limit }
    ) or {}
end

---@param identifier string
---@param isAdmin boolean
---@return boolean false si aucun joueur n'a cette licence en base
function PlayerRepository.setAdmin(identifier, isAdmin)
    local changed = MySQL.update.await('UPDATE pvp_players SET is_admin = ? WHERE identifier = ?', {
        isAdmin and 1 or 0, identifier,
    })
    return (changed or 0) > 0
end

---@return table[] { identifier, name }
function PlayerRepository.listAdmins()
    return MySQL.query.await('SELECT identifier, name FROM pvp_players WHERE is_admin = 1 ORDER BY name') or {}
end

---@param identifier string
---@return table|nil { identifier, name, is_admin }
function PlayerRepository.findByIdentifier(identifier)
    return MySQL.single.await('SELECT identifier, name, is_admin FROM pvp_players WHERE identifier = ?', { identifier })
end

---@param limit integer
---@return table[]
function PlayerRepository.top(limit)
    return MySQL.query.await(
        'SELECT identifier, name, xp, kills, deaths, npc_kills FROM pvp_players ORDER BY kills DESC, xp DESC LIMIT ?',
        { limit }
    ) or {}
end
