---Accès aux tables des crews. Le label est la clé : il ne change jamais.
---Les écritures n'attendent pas la base : CrewService tient l'état à jour en mémoire.
---@class CrewRepositoryModule
local CrewRepository = PVP.define('CrewRepository')

CrewRepository.SCHEMAS = {
    [[CREATE TABLE IF NOT EXISTS pvp_crews (
        tag CHAR(3) NOT NULL,
        name VARCHAR(64) NOT NULL DEFAULT '',
        leader VARCHAR(64) NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (tag)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS pvp_crew_members (
        identifier VARCHAR(64) NOT NULL,
        crew_tag CHAR(3) NOT NULL,
        name VARCHAR(64) NOT NULL DEFAULT '',
        joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (identifier),
        KEY idx_crew (crew_tag)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS pvp_crew_territories (
        zone_id VARCHAR(32) NOT NULL,
        crew_tag CHAR(3) NOT NULL,
        protected_until INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (zone_id),
        KEY idx_crew (crew_tag)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS pvp_crew_stashes (
        crew_tag CHAR(3) NOT NULL,
        items LONGTEXT NOT NULL,
        log LONGTEXT NOT NULL,
        PRIMARY KEY (crew_tag)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS pvp_crew_stats (
        crew_tag CHAR(3) NOT NULL,
        season CHAR(7) NOT NULL,
        kills INT UNSIGNED NOT NULL DEFAULT 0,
        deaths INT UNSIGNED NOT NULL DEFAULT 0,
        captures INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (crew_tag, season),
        KEY idx_season (season)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

---Crée les tables si besoin et renvoie tous les crews et leurs membres.
---@return table[] crews { tag, name, leader }, table[] members { identifier, crew_tag, name }
function CrewRepository.loadAll()
    for _, schema in ipairs(CrewRepository.SCHEMAS) do
        MySQL.query.await(schema)
    end
    local crews = MySQL.query.await('SELECT tag, name, leader FROM pvp_crews') or {}
    local members = MySQL.query.await('SELECT identifier, crew_tag, name FROM pvp_crew_members ORDER BY joined_at, identifier') or {}
    return crews, members
end

---@param tag string
---@param name string
---@param leader string
function CrewRepository.create(tag, name, leader)
    MySQL.insert('REPLACE INTO pvp_crews (tag, name, leader) VALUES (?, ?, ?)', { tag, name, leader })
end

---@param tag string
---@param leader string
function CrewRepository.setLeader(tag, leader)
    MySQL.update('UPDATE pvp_crews SET leader = ? WHERE tag = ?', { leader, tag })
end

---@param identifier string
---@param tag string
---@param name string
function CrewRepository.addMember(identifier, tag, name)
    MySQL.insert('REPLACE INTO pvp_crew_members (identifier, crew_tag, name) VALUES (?, ?, ?)', { identifier, tag, name })
end

---@param identifier string
---@param name string
function CrewRepository.setMemberName(identifier, name)
    MySQL.update('UPDATE pvp_crew_members SET name = ? WHERE identifier = ?', { name, identifier })
end

---@param identifier string
function CrewRepository.removeMember(identifier)
    MySQL.update('DELETE FROM pvp_crew_members WHERE identifier = ?', { identifier })
end

---@param tag string
function CrewRepository.delete(tag)
    MySQL.update('DELETE FROM pvp_crew_territories WHERE crew_tag = ?', { tag })
    -- Un futur crew peut reprendre ce label : il ne doit hériter de rien
    MySQL.update('DELETE FROM pvp_crew_stashes WHERE crew_tag = ?', { tag })
    MySQL.update('DELETE FROM pvp_crew_stats WHERE crew_tag = ?', { tag })
    MySQL.update('DELETE FROM pvp_crew_members WHERE crew_tag = ?', { tag })
    MySQL.update('DELETE FROM pvp_crews WHERE tag = ?', { tag })
end

---À appeler après loadAll, qui crée la table.
---@return table[] territoires { zone_id, crew_tag, protected_until }
function CrewRepository.loadTerritories()
    return MySQL.query.await('SELECT zone_id, crew_tag, protected_until FROM pvp_crew_territories') or {}
end

---@param zoneId string
---@param tag string
---@param protectedUntil integer os.time() de la fin de la protection
function CrewRepository.setTerritory(zoneId, tag, protectedUntil)
    MySQL.insert('REPLACE INTO pvp_crew_territories (zone_id, crew_tag, protected_until) VALUES (?, ?, ?)', { zoneId, tag, protectedUntil })
end

---À appeler après loadAll, qui crée la table.
---@return table[] coffres { crew_tag, items, log } en JSON
function CrewRepository.loadStashes()
    return MySQL.query.await('SELECT crew_tag, items, log FROM pvp_crew_stashes') or {}
end

---@param tag string
---@param items string JSON
---@param log string JSON
function CrewRepository.saveStash(tag, items, log)
    MySQL.insert('REPLACE INTO pvp_crew_stashes (crew_tag, items, log) VALUES (?, ?, ?)', { tag, items, log })
end

---@param tag string
---@param season string
---@param kills integer
---@param deaths integer
---@param captures integer
function CrewRepository.addStats(tag, season, kills, deaths, captures)
    MySQL.insert([[INSERT INTO pvp_crew_stats (crew_tag, season, kills, deaths, captures) VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE kills = kills + VALUES(kills), deaths = deaths + VALUES(deaths), captures = captures + VALUES(captures)]],
        { tag, season, kills, deaths, captures })
end

---@param season? string nil : toutes les saisons additionnées
---@return table[] { crew_tag, kills, deaths, captures } (les sommes peuvent arriver en texte)
function CrewRepository.loadStats(season)
    if season then
        return MySQL.query.await('SELECT crew_tag, kills, deaths, captures FROM pvp_crew_stats WHERE season = ?', { season }) or {}
    end
    return MySQL.query.await('SELECT crew_tag, SUM(kills) AS kills, SUM(deaths) AS deaths, SUM(captures) AS captures FROM pvp_crew_stats GROUP BY crew_tag') or {}
end
