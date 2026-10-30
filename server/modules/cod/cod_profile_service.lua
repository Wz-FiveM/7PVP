---Progression du mode Call of Duty (Config.Cod) : rang, statistiques, classes et séries de chaque joueur.
---Les profils vivent à part de pvp_players : rien ici ne touche à l'inventaire ni à l'argent du PvP.
---Le serveur valide chaque choix du joueur (arme débloquée, atout du bon niveau...).
---@class CodClass
---@field name string
---@field primary string arme du catalogue
---@field secondary string
---@field equipment string|false
---@field perks string[] un atout par niveau (1, 2, 3)

---@class CodPlayerCard
---@field banner string
---@field emblem string
---@field tag string tag de clan, peut être vide

---@class CodProfile
---@field identifier string
---@field name string
---@field xp integer
---@field kills integer
---@field deaths integer
---@field assists integer
---@field wins integer
---@field losses integer
---@field bestStreak integer
---@field selected integer classe choisie
---@field classes CodClass[]
---@field streaks string[] séries choisies
---@field card CodPlayerCard

---@class CodProfileServiceModule
local CodProfileService = PVP.define('CodProfileService')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CodProfileService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_cod_profiles (
    identifier VARCHAR(64) NOT NULL,
    name VARCHAR(64) NOT NULL DEFAULT '',
    xp INT NOT NULL DEFAULT 0,
    kills INT NOT NULL DEFAULT 0,
    deaths INT NOT NULL DEFAULT 0,
    assists INT NOT NULL DEFAULT 0,
    wins INT NOT NULL DEFAULT 0,
    losses INT NOT NULL DEFAULT 0,
    best_streak INT NOT NULL DEFAULT 0,
    selected_class TINYINT NOT NULL DEFAULT 1,
    classes LONGTEXT NULL,
    streaks LONGTEXT NULL,
    player_card LONGTEXT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier),
    KEY idx_xp (xp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

-- Évolutions du schéma pour les bases créées avant l'ajout d'une colonne
CodProfileService.MIGRATIONS = {
    'ALTER TABLE pvp_cod_profiles ADD COLUMN IF NOT EXISTS player_card LONGTEXT NULL AFTER streaks',
}

---@type table<integer, CodProfile> par joueur connecté dans le mode
CodProfileService.profiles = {}
---@type { at: integer, rows: table[] }|nil
CodProfileService.leaderboardCache = nil
-- Catalogues indexés par id, construits au démarrage
CodProfileService.primary = {}
CodProfileService.secondary = {}
CodProfileService.equipment = {}
CodProfileService.perks = {}
CodProfileService.streaks = {}
CodProfileService.banners = {}
CodProfileService.emblems = {}
-- Séries retirées du jeu, encore enregistrées dans les profils : ancienne -> remplaçante
CodProfileService.REPLACED_STREAKS = { airstrike = 'predator' }

function CodProfileService.init()
    for _, entry in ipairs(Config.Cod.weapons.primary) do CodProfileService.primary[entry.id] = entry end
    for _, entry in ipairs(Config.Cod.weapons.secondary) do CodProfileService.secondary[entry.id] = entry end
    for _, entry in ipairs(Config.Cod.weapons.equipment) do CodProfileService.equipment[entry.id] = entry end
    for _, entry in ipairs(Config.Cod.perks) do CodProfileService.perks[entry.id] = entry end
    for _, entry in ipairs(Config.Cod.streaks) do CodProfileService.streaks[entry.id] = entry end
    for _, entry in ipairs(Config.CodPlayerCards.banners) do CodProfileService.banners[entry.id] = entry end
    for _, entry in ipairs(Config.CodPlayerCards.emblems) do CodProfileService.emblems[entry.id] = entry end

    MySQL.ready(function()
        MySQL.query.await(CodProfileService.SCHEMA)
        for _, query in ipairs(CodProfileService.MIGRATIONS) do MySQL.query.await(query) end
    end)
end

-- ---------------------------------------------------------------------------
-- Rangs
-- ---------------------------------------------------------------------------

---@param rank integer
---@return integer XP pour passer de ce rang au suivant
function CodProfileService.xpForRank(rank)
    return Config.Cod.ranks.base + Config.Cod.ranks.growth * (rank - 1)
end

---@param xp integer
---@return integer rang, integer XP dans le rang, integer XP pour le rang suivant (0 au rang maximum)
function CodProfileService.rankFromXp(xp)
    local rank, left = 1, xp
    while rank < Config.Cod.ranks.max do
        local needed = CodProfileService.xpForRank(rank)
        if left < needed then return rank, left, needed end
        left = left - needed
        rank = rank + 1
    end
    return rank, 0, 0
end

---@param source integer
---@return integer
function CodProfileService.rankOf(source)
    local profile = CodProfileService.profiles[source]
    return profile and CodProfileService.rankFromXp(profile.xp) or 1
end

---Commande admin : le joueur arrive au début du rang visé.
---@param source integer profil chargé
---@param amount integer négatif pour descendre
---@return integer rang avant, integer rang après
function CodProfileService.addRanks(source, amount)
    local profile = CodProfileService.profiles[source]
    local before = CodProfileService.rankFromXp(profile.xp)
    local after = math.max(1, math.min(before + amount, Config.Cod.ranks.max))
    if after == before then return before, after end

    local xp = 0
    for rank = 1, after - 1 do xp = xp + CodProfileService.xpForRank(rank) end
    profile.xp = xp
    CodProfileService.save(profile)
    TriggerClientEvent(Events.client.codProfile, source, CodProfileService.describe(profile))
    return before, after
end

---Ce qui se débloque en atteignant les rangs de `from` (exclu) à `to` (inclus).
---@param from integer
---@param to integer
---@return string[] noms à traduire
function CodProfileService.unlocksBetween(from, to)
    local labels = {}
    for _, list in ipairs({ Config.Cod.weapons.primary, Config.Cod.weapons.secondary, Config.Cod.weapons.equipment, Config.Cod.perks, Config.Cod.streaks, Config.CodPlayerCards.banners, Config.CodPlayerCards.emblems }) do
        for _, entry in ipairs(list) do
            if entry.rank > from and entry.rank <= to then labels[#labels + 1] = entry.label end
        end
    end
    return labels
end

-- ---------------------------------------------------------------------------
-- Chargement et sauvegarde
-- ---------------------------------------------------------------------------

---@param player PvpPlayer
---@return CodProfile
function CodProfileService.load(player)
    local cached = CodProfileService.profiles[player.source]
    if cached then return cached end

    local row = MySQL.single.await('SELECT * FROM pvp_cod_profiles WHERE identifier = ?', { player.identifier }) or {}
    ---@type CodProfile
    local profile = {
        identifier = player.identifier,
        name = player.name,
        xp = row.xp or 0,
        kills = row.kills or 0,
        deaths = row.deaths or 0,
        assists = row.assists or 0,
        wins = row.wins or 0,
        losses = row.losses or 0,
        bestStreak = row.best_streak or 0,
        selected = row.selected_class or 1,
        classes = {},
        streaks = {},
    }
    local rank = CodProfileService.rankFromXp(profile.xp)
    local savedClasses = CodProfileService.decode(row.classes)
    for index, default in ipairs(Config.Cod.defaultClasses) do
        profile.classes[index] = CodProfileService.cleanClass(savedClasses[index], rank) or CodProfileService.copyClass(default)
    end
    local savedStreaks = CodProfileService.decode(row.streaks)
    for index, id in ipairs(savedStreaks) do
        savedStreaks[index] = CodProfileService.REPLACED_STREAKS[id] or id
    end
    profile.streaks = CodProfileService.cleanStreaks(savedStreaks, rank) or { table.unpack(Config.Cod.defaultStreaks) }
    if not profile.classes[profile.selected] then profile.selected = 1 end
    profile.card = CodProfileService.cleanPlayerCard(CodProfileService.decode(row.player_card), rank) or CodProfileService.defaultPlayerCard()
    CodProfileService.profiles[player.source] = profile
    return profile
end

---@param raw any
---@return table
function CodProfileService.decode(raw)
    if type(raw) ~= 'string' then return {} end
    local ok, data = pcall(json.decode, raw)
    return ok and type(data) == 'table' and data or {}
end

---@param class CodClass
---@return CodClass
function CodProfileService.copyClass(class)
    return {
        name = class.name,
        primary = class.primary,
        secondary = class.secondary,
        equipment = class.equipment,
        perks = { table.unpack(class.perks) },
    }
end

---@return CodPlayerCard
function CodProfileService.defaultPlayerCard()
    local default = Config.CodPlayerCards.default
    return { banner = default.banner, emblem = default.emblem, tag = default.tag }
end

---@param profile CodProfile
function CodProfileService.save(profile)
    MySQL.insert(
        [[INSERT INTO pvp_cod_profiles (identifier, name, xp, kills, deaths, assists, wins, losses, best_streak, selected_class, classes, streaks, player_card)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE name = VALUES(name), xp = VALUES(xp), kills = VALUES(kills), deaths = VALUES(deaths),
              assists = VALUES(assists), wins = VALUES(wins), losses = VALUES(losses), best_streak = VALUES(best_streak),
              selected_class = VALUES(selected_class), classes = VALUES(classes), streaks = VALUES(streaks),
              player_card = VALUES(player_card)]],
        {
            profile.identifier, profile.name, profile.xp, profile.kills, profile.deaths, profile.assists,
            profile.wins, profile.losses, profile.bestStreak, profile.selected,
            json.encode(profile.classes), json.encode(profile.streaks), json.encode(profile.card),
        }
    )
end

---Sauvegarde et oublie le profil (retour au lobby, déconnexion).
---@param source integer
function CodProfileService.unload(source)
    local profile = CodProfileService.profiles[source]
    if not profile then return end
    CodProfileService.save(profile)
    CodProfileService.profiles[source] = nil
end

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------

---@param catalog table<string, table>
---@param id any
---@param rank integer
---@return boolean l'entrée existe et est débloquée
function CodProfileService.unlocked(catalog, id, rank)
    local entry = type(id) == 'string' and catalog[id]
    return entry ~= nil and entry ~= false and entry.rank <= rank
end

---@param text any
---@return string|nil nom sans caractères de contrôle, coupé à classNameLength caractères
function CodProfileService.cleanName(text)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' or not utf8.len(text) then return nil end
    if utf8.len(text) > Config.Cod.classNameLength then
        text = text:sub(1, utf8.offset(text, Config.Cod.classNameLength + 1) - 1)
    end
    return text
end

---@param data any classe reçue du client ou lue en base
---@param rank integer
---@return CodClass|nil classe propre, ou nil si un choix n'existe pas ou n'est pas débloqué
function CodProfileService.cleanClass(data, rank)
    if type(data) ~= 'table' or type(data.perks) ~= 'table' then return nil end
    local name = CodProfileService.cleanName(data.name)
    if not name then return nil end
    if not CodProfileService.unlocked(CodProfileService.primary, data.primary, rank) then return nil end
    if not CodProfileService.unlocked(CodProfileService.secondary, data.secondary, rank) then return nil end
    -- Le JSON n'a pas toujours gardé `false` : sans équipement = false
    local equipment = data.equipment or false
    if equipment and not CodProfileService.unlocked(CodProfileService.equipment, equipment, rank) then return nil end

    local perks = {}
    for tier = 1, 3 do
        local id = data.perks[tier]
        if not CodProfileService.unlocked(CodProfileService.perks, id, rank) then return nil end
        if CodProfileService.perks[id].tier ~= tier then return nil end
        perks[tier] = id
    end
    return { name = name, primary = data.primary, secondary = data.secondary, equipment = equipment, perks = perks }
end

---@param data any
---@param rank integer
---@return string[]|nil séries propres, ou nil si une n'existe pas, n'est pas débloquée, ou s'il y en a trop
function CodProfileService.cleanStreaks(data, rank)
    if type(data) ~= 'table' or #data == 0 or #data > Config.Cod.maxStreaks then return nil end
    local clean, seen = {}, {}
    for _, id in ipairs(data) do
        if not CodProfileService.unlocked(CodProfileService.streaks, id, rank) or seen[id] then return nil end
        seen[id] = true
        clean[#clean + 1] = id
    end
    return clean
end

---@param data any carte reçue du client ou lue en base
---@param rank integer
---@return CodPlayerCard|nil carte propre, ou nil si un choix n'existe pas ou n'est pas débloqué
function CodProfileService.cleanPlayerCard(data, rank)
    if type(data) ~= 'table' or type(data.tag) ~= 'string' then return nil end
    if not CodProfileService.unlocked(CodProfileService.banners, data.banner, rank) then return nil end
    if not CodProfileService.unlocked(CodProfileService.emblems, data.emblem, rank) then return nil end
    local tag = data.tag:gsub('[^%w%-_!%.]', ''):sub(1, Config.CodPlayerCards.tagLength)
    return { banner = data.banner, emblem = data.emblem, tag = tag }
end

-- ---------------------------------------------------------------------------
-- Actions du menu
-- ---------------------------------------------------------------------------

---@param source integer
---@param index any
---@param data any
---@return { ok: boolean, message?: string, profile?: table }
function CodProfileService.saveClass(source, index, data)
    local profile = CodProfileService.profiles[source]
    index = math.tointeger(tonumber(index))
    if not profile or not index or not profile.classes[index] then return { ok = false } end
    local clean = CodProfileService.cleanClass(data, CodProfileService.rankOf(source))
    if not clean then return { ok = false, message = Locale.t('Classe invalide : un choix n\'est pas débloqué.') } end
    profile.classes[index] = clean
    CodProfileService.save(profile)
    return { ok = true, message = Locale.t('Classe enregistrée.'), profile = CodProfileService.describe(profile) }
end

---@param source integer
---@param data any
---@return { ok: boolean, message?: string, profile?: table }
function CodProfileService.saveStreaks(source, data)
    local profile = CodProfileService.profiles[source]
    if not profile then return { ok = false } end
    local clean = CodProfileService.cleanStreaks(data, CodProfileService.rankOf(source))
    if not clean then
        return { ok = false, message = Locale.t('Choisis de 1 à %d séries débloquées.', Config.Cod.maxStreaks) }
    end
    profile.streaks = clean
    CodProfileService.save(profile)
    return { ok = true, message = Locale.t('Séries enregistrées.'), profile = CodProfileService.describe(profile) }
end

---@param source integer
---@param data any
---@return { ok: boolean, message?: string, profile?: table }
function CodProfileService.savePlayerCard(source, data)
    local profile = CodProfileService.profiles[source]
    if not profile then return { ok = false } end
    local clean = CodProfileService.cleanPlayerCard(data, CodProfileService.rankOf(source))
    if not clean then return { ok = false, message = Locale.t('Carte invalide : un choix n\'est pas débloqué.') } end
    profile.card = clean
    CodProfileService.save(profile)
    return { ok = true, message = Locale.t('Carte de joueur enregistrée.'), profile = CodProfileService.describe(profile) }
end

---Carte vue par les autres joueurs (kill, mort, salon).
---@param source integer
---@return table
function CodProfileService.playerCard(source)
    local profile = CodProfileService.profiles[source]
    local card = profile and profile.card or Config.CodPlayerCards.default
    return {
        name = GetPlayerName(source) or '?',
        tag = card.tag,
        banner = card.banner,
        emblem = card.emblem,
        rank = CodProfileService.rankOf(source),
    }
end

---Classe utilisée à la prochaine apparition.
---@param source integer
---@param index any
---@return { ok: boolean, profile?: table }
function CodProfileService.selectClass(source, index)
    local profile = CodProfileService.profiles[source]
    index = math.tointeger(tonumber(index))
    if not profile or not index or not profile.classes[index] then return { ok = false } end
    profile.selected = index
    return { ok = true, profile = CodProfileService.describe(profile) }
end

---@param source integer
---@return CodClass
function CodProfileService.selectedClass(source)
    local profile = CodProfileService.profiles[source]
    if profile then return profile.classes[profile.selected] end
    return Config.Cod.defaultClasses[1]
end

---@return { rows: table[] }
function CodProfileService.leaderboard()
    local now = os.time()
    local cache = CodProfileService.leaderboardCache
    if cache and now - cache.at < Config.Cod.leaderboardCache then return { rows = cache.rows } end

    local rows = MySQL.query.await(
        'SELECT name, xp, kills, deaths, wins FROM pvp_cod_profiles ORDER BY xp DESC, kills DESC LIMIT ?',
        { Config.Cod.leaderboardSize }) or {}
    local list = {}
    for index, row in ipairs(rows) do
        list[index] = {
            name = row.name,
            rank = CodProfileService.rankFromXp(row.xp),
            kills = row.kills,
            deaths = row.deaths,
            wins = row.wins,
        }
    end
    CodProfileService.leaderboardCache = { at = now, rows = list }
    return { rows = list }
end

-- ---------------------------------------------------------------------------
-- Fin de partie
-- ---------------------------------------------------------------------------

---Compte une partie jouée.
---@param source integer
---@param stats { kills: integer, deaths: integer, assists: integer, bestStreak: integer, xp: integer }
---@param result 'won'|'lost'|'draw'
---@return table|nil résumé de la progression pour l'écran de fin
function CodProfileService.applyMatch(source, stats, result)
    local profile = CodProfileService.profiles[source]
    if not profile then return nil end

    local xpConfig = Config.Cod.xp
    local bonus = result == 'won' and xpConfig.win or (result == 'draw' and xpConfig.draw or xpConfig.loss)
    local before = CodProfileService.rankFromXp(profile.xp)
    local earned = stats.xp + bonus

    profile.name = GetPlayerName(source) or profile.name
    profile.xp = profile.xp + earned
    profile.kills = profile.kills + stats.kills
    profile.deaths = profile.deaths + stats.deaths
    profile.assists = profile.assists + stats.assists
    profile.bestStreak = math.max(profile.bestStreak, stats.bestStreak)
    if result == 'won' then profile.wins = profile.wins + 1 end
    if result == 'lost' then profile.losses = profile.losses + 1 end
    CodProfileService.save(profile)

    local after = CodProfileService.rankFromXp(profile.xp)
    return {
        earned = earned,
        bonus = bonus,
        rankBefore = before,
        rankAfter = after,
        unlocks = after > before and CodProfileService.unlocksBetween(before, after) or {},
    }
end

---Partie quittée avant la fin : les kills et l'XP déjà gagnés restent, sans bonus de fin.
---@param source integer
---@param stats table
function CodProfileService.applyAbandon(source, stats)
    local profile = CodProfileService.profiles[source]
    if not profile then return end
    profile.xp = profile.xp + stats.xp
    profile.kills = profile.kills + stats.kills
    profile.deaths = profile.deaths + stats.deaths
    profile.assists = profile.assists + stats.assists
    profile.bestStreak = math.max(profile.bestStreak, stats.bestStreak)
    profile.losses = profile.losses + 1
    CodProfileService.save(profile)
end

---Profil envoyé à l'interface.
---@param profile CodProfile
---@return table
function CodProfileService.describe(profile)
    local rank, into, needed = CodProfileService.rankFromXp(profile.xp)
    return {
        name = profile.name,
        rank = rank,
        maxRank = Config.Cod.ranks.max,
        xp = profile.xp,
        xpInto = into,
        xpNeeded = needed,
        kills = profile.kills,
        deaths = profile.deaths,
        assists = profile.assists,
        wins = profile.wins,
        losses = profile.losses,
        bestStreak = profile.bestStreak,
        selected = profile.selected,
        classes = profile.classes,
        streaks = profile.streaks,
        card = profile.card,
    }
end

---Catalogue affiché par le menu.
---@return table
function CodProfileService.catalog()
    return {
        playlists = Config.Cod.playlists,
        primary = Config.Cod.weapons.primary,
        secondary = Config.Cod.weapons.secondary,
        equipment = Config.Cod.weapons.equipment,
        perks = Config.Cod.perks,
        streaks = Config.Cod.streaks,
        maxStreaks = Config.Cod.maxStreaks,
        classNameLength = Config.Cod.classNameLength,
        banners = Config.CodPlayerCards.banners,
        emblems = Config.CodPlayerCards.emblems,
        tagLength = Config.CodPlayerCards.tagLength,
        keys = { streak = Config.Cod.streakKey, class = Config.Cod.classKey, scoreboard = Config.MenuKeyLabel },
    }
end
