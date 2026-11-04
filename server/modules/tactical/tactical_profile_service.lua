---Profils du mode Sabotage (Config.Tactical) : rôle choisi, cote de classement et statistiques.
---Ils vivent à part de pvp_players : rien ici ne touche à l'inventaire ni à l'argent du PvP.
---@class TacticalProfile
---@field identifier string
---@field name string
---@field role string rôle choisi (Config.Tactical.roles)
---@field rating integer
---@field matches integer
---@field wins integer
---@field losses integer
---@field kills integer
---@field deaths integer
---@field assists integer
---@field plants integer
---@field defuses integer
---@field mvps integer

---@class TacticalProfileServiceModule
local TacticalProfileService = PVP.define('TacticalProfileService')
local Logger = PVP.use('Logger')

TacticalProfileService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_tactical_profiles (
    identifier VARCHAR(64) NOT NULL,
    name VARCHAR(64) NOT NULL DEFAULT '',
    role VARCHAR(16) NOT NULL DEFAULT '',
    rating INT NOT NULL DEFAULT 1000,
    matches INT NOT NULL DEFAULT 0,
    wins INT NOT NULL DEFAULT 0,
    losses INT NOT NULL DEFAULT 0,
    kills INT NOT NULL DEFAULT 0,
    deaths INT NOT NULL DEFAULT 0,
    assists INT NOT NULL DEFAULT 0,
    plants INT NOT NULL DEFAULT 0,
    defuses INT NOT NULL DEFAULT 0,
    mvps INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier),
    KEY rating (rating)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

TacticalProfileService.STATS = { 'matches', 'wins', 'losses', 'kills', 'deaths', 'assists', 'plants', 'defuses', 'mvps' }

---@type table<integer, TacticalProfile> profils chargés, par joueur
TacticalProfileService.profiles = {}
---@type table<string, table> rôle -> entrée de Config.Tactical.roles
TacticalProfileService.roles = {}
TacticalProfileService.leaderboardCache = nil

function TacticalProfileService.init()
    for _, role in ipairs(Config.Tactical.roles) do TacticalProfileService.roles[role.id] = role end
    MySQL.ready(function()
        MySQL.query.await(TacticalProfileService.SCHEMA)
    end)
end

---@param id any
---@return table|nil
function TacticalProfileService.role(id)
    return TacticalProfileService.roles[id]
end

---@param player PvpPlayer
---@return TacticalProfile
function TacticalProfileService.load(player)
    local loaded = TacticalProfileService.profiles[player.source]
    if loaded then return loaded end

    local row = MySQL.single.await('SELECT * FROM pvp_tactical_profiles WHERE identifier = ?', { player.identifier }) or {}
    local profile = {
        identifier = player.identifier,
        name = GetPlayerName(player.source) or '?',
        role = TacticalProfileService.roles[row.role] and row.role or Config.Tactical.roles[1].id,
        rating = tonumber(row.rating) or Config.Tactical.rating.start,
    }
    for _, stat in ipairs(TacticalProfileService.STATS) do profile[stat] = tonumber(row[stat]) or 0 end
    TacticalProfileService.profiles[player.source] = profile
    return profile
end

---@param source integer
---@return TacticalProfile|nil
function TacticalProfileService.get(source)
    return TacticalProfileService.profiles[source]
end

---@param source integer
function TacticalProfileService.unload(source)
    TacticalProfileService.profiles[source] = nil
end

---@param profile TacticalProfile
function TacticalProfileService.save(profile)
    MySQL.insert([[INSERT INTO pvp_tactical_profiles
        (identifier, name, role, rating, matches, wins, losses, kills, deaths, assists, plants, defuses, mvps)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), role = VALUES(role), rating = VALUES(rating),
        matches = VALUES(matches), wins = VALUES(wins), losses = VALUES(losses), kills = VALUES(kills),
        deaths = VALUES(deaths), assists = VALUES(assists), plants = VALUES(plants), defuses = VALUES(defuses),
        mvps = VALUES(mvps)]], {
        profile.identifier, profile.name, profile.role, profile.rating, profile.matches, profile.wins, profile.losses,
        profile.kills, profile.deaths, profile.assists, profile.plants, profile.defuses, profile.mvps,
    })
end

---@param rating integer
---@return string division (nom à traduire)
function TacticalProfileService.division(rating)
    local label = Config.Tactical.divisions[1].label
    for _, division in ipairs(Config.Tactical.divisions) do
        if rating >= division.min then label = division.label end
    end
    return label
end

---@param profile TacticalProfile
---@return table ce que le menu affiche
function TacticalProfileService.describe(profile)
    local data = { name = profile.name, role = profile.role, rating = profile.rating, division = TacticalProfileService.division(profile.rating) }
    for _, stat in ipairs(TacticalProfileService.STATS) do data[stat] = profile[stat] end
    return data
end

---@param source integer
---@param roleId any
---@return { ok: boolean, profile?: table }
function TacticalProfileService.selectRole(source, roleId)
    local profile = TacticalProfileService.profiles[source]
    if not profile or not TacticalProfileService.roles[roleId] then return { ok = false } end
    profile.role = roleId
    TacticalProfileService.save(profile)
    return { ok = true, profile = TacticalProfileService.describe(profile) }
end

---Fin de partie : statistiques et cote. Un joueur parti avant la fin compte une défaite (applyAbandon).
---@param source integer
---@param stats table statistiques de la partie (TacticalMatch)
---@param result 'won'|'lost'|'draw'
---@param mvp boolean
---@return table|nil bilan pour l'écran de résultats
function TacticalProfileService.applyMatch(source, stats, result, mvp)
    local profile = TacticalProfileService.profiles[source]
    if not profile then return nil end
    local settings = Config.Tactical.rating
    local before = profile.rating
    local change = 0
    if result == 'won' then change = settings.win elseif result == 'lost' then change = -settings.loss end
    if mvp then change = change + settings.mvp end
    profile.rating = math.max(settings.min, profile.rating + change)
    profile.name = GetPlayerName(source) or profile.name
    profile.matches = profile.matches + 1
    if result == 'won' then profile.wins = profile.wins + 1 end
    if result == 'lost' then profile.losses = profile.losses + 1 end
    if mvp then profile.mvps = profile.mvps + 1 end
    for _, stat in ipairs({ 'kills', 'deaths', 'assists', 'plants', 'defuses' }) do
        profile[stat] = profile[stat] + (stats[stat] or 0)
    end
    TacticalProfileService.save(profile)
    return {
        before = before,
        after = profile.rating,
        change = profile.rating - before,
        division = TacticalProfileService.division(profile.rating),
        promoted = TacticalProfileService.division(before) ~= TacticalProfileService.division(profile.rating) and profile.rating > before,
        profile = TacticalProfileService.describe(profile),
    }
end

---@param source integer
---@param stats table
function TacticalProfileService.applyAbandon(source, stats)
    local profile = TacticalProfileService.profiles[source]
    if not profile then return end
    Logger.info('[sabotage] %s quitte une partie en cours : défaite comptée', profile.name)
    TacticalProfileService.applyMatch(source, stats, 'lost', false)
end

---@return { rows: table[] }
function TacticalProfileService.leaderboard()
    local now = os.time()
    local cache = TacticalProfileService.leaderboardCache
    if cache and now - cache.at < Config.Tactical.leaderboardCache then return { rows = cache.rows } end

    local rows = MySQL.query.await(
        'SELECT name, rating, matches, wins, kills, deaths FROM pvp_tactical_profiles WHERE matches > 0 ORDER BY rating DESC, wins DESC LIMIT ?',
        { Config.Tactical.leaderboardSize }) or {}
    local list = {}
    for index, row in ipairs(rows) do
        list[index] = {
            name = row.name,
            rating = row.rating,
            division = TacticalProfileService.division(row.rating),
            matches = row.matches,
            wins = row.wins,
            kills = row.kills,
            deaths = row.deaths,
        }
    end
    TacticalProfileService.leaderboardCache = { at = now, rows = list }
    return { rows = list }
end

---@param source integer
---@return string rôle choisi (le premier sans profil chargé)
function TacticalProfileService.roleOf(source)
    local profile = TacticalProfileService.profiles[source]
    return profile and profile.role or Config.Tactical.roles[1].id
end

