---Accès à la table `pvp_players`.
---@class PlayerRepositoryModule
local PlayerRepository = PVP.define('PlayerRepository')
local Logger = PVP.use('Logger')

-- Évolutions du schéma pour les bases créées avant l'ajout d'une colonne
PlayerRepository.MIGRATIONS = {
    'ALTER TABLE pvp_players ADD COLUMN IF NOT EXISTS appearance LONGTEXT NULL AFTER inventory',
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
        'UPDATE pvp_players SET name = ?, xp = ?, kills = ?, deaths = ?, npc_kills = ?, inventory = ?, appearance = ? WHERE identifier = ?',
        {
            player.name, player.xp, player.kills, player.deaths, player.npcKills,
            player.inventory:encode(), player.appearance and json.encode(player.appearance) or nil, player.identifier,
        }
    )
end

---@param limit integer
---@return table[]
function PlayerRepository.top(limit)
    return MySQL.query.await(
        'SELECT identifier, name, xp, kills, deaths, npc_kills FROM pvp_players ORDER BY kills DESC, xp DESC LIMIT ?',
        { limit }
    ) or {}
end
