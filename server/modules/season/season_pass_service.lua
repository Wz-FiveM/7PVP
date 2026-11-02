---Passe de saison (Config.SeasonPass) : des points gagnés en jouant font monter les paliers, dont les
---récompenses se réclament dans le menu Saison. Piste premium achetée en points boutique.
---Tout repart à zéro à chaque saison (table pvp_season_pass).
---@class PvpSeasonPass
---@field season string
---@field points integer
---@field premium boolean
---@field claimed table<string, boolean> 'f12' (gratuit) ou 'p12' (premium) -> réclamé

---@class SeasonPassServiceModule
local SeasonPassService = PVP.define('SeasonPassService')
local SeasonService = PVP.use('SeasonService')
local SeasonRewardService = PVP.use('SeasonRewardService')
local ShopPointsService = PVP.use('ShopPointsService')
local PlayerService = PVP.use('PlayerService')
local PlayerRepository = PVP.use('PlayerRepository')
local LootService = PVP.use('LootService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

SeasonPassService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_season_pass (
    season VARCHAR(7) NOT NULL,
    identifier VARCHAR(64) NOT NULL,
    points INT NOT NULL DEFAULT 0,
    premium TINYINT(1) NOT NULL DEFAULT 0,
    claimed TEXT NULL,
    PRIMARY KEY (season, identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

function SeasonPassService.init()
    MySQL.ready(function()
        MySQL.query.await(SeasonPassService.SCHEMA)
    end)
    Callback.register(Events.callbacks.seasonPassClaim, SeasonPassService.claim)
    Callback.register(Events.callbacks.seasonPassBuy, SeasonPassService.buy)
end

---@param season string
---@return PvpSeasonPass
function SeasonPassService.blank(season)
    return { season = season, points = 0, premium = false, claimed = {} }
end

---Passe de la saison en cours, au chargement du profil.
---@param player PvpPlayer
function SeasonPassService.load(player)
    local season = SeasonService.current()
    local row = MySQL.single.await('SELECT points, premium, claimed FROM pvp_season_pass WHERE season = ? AND identifier = ?', { season, player.identifier })
    local pass = SeasonPassService.blank(season)
    if row then
        local ok, claimed = pcall(json.decode, row.claimed or '')
        pass.points = row.points
        pass.premium = row.premium == 1 or row.premium == true
        pass.claimed = ok and type(claimed) == 'table' and claimed or {}
    end
    player.seasonPass = pass
end

---@param player PvpPlayer
function SeasonPassService.save(player)
    local pass = player.seasonPass
    if not pass then return end
    MySQL.insert(
        [[INSERT INTO pvp_season_pass (season, identifier, points, premium, claimed) VALUES (?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE points = VALUES(points), premium = VALUES(premium), claimed = VALUES(claimed)]],
        { pass.season, player.identifier, pass.points, pass.premium and 1 or 0, json.encode(pass.claimed) }
    )
end

---Changement de mois : le passe repart de zéro.
---@param player PvpPlayer
---@param season string
function SeasonPassService.onSeasonStart(player, season)
    SeasonPassService.save(player)
    player.seasonPass = SeasonPassService.blank(season)
end

---@param points integer
---@return integer palier atteint
function SeasonPassService.tierOf(points)
    return math.min(#Config.SeasonPass.tiers, math.floor(points / Config.SeasonPass.pointsPerTier))
end

---Un compteur de haut fait a augmenté (voir AchievementService.track).
---@param player PvpPlayer
---@param stat string
---@param amount integer
function SeasonPassService.onStat(player, stat, amount)
    local value = Config.SeasonPass.sources[stat]
    if not value or not player.seasonPass then return end
    local pass = player.seasonPass
    local before = SeasonPassService.tierOf(pass.points)
    pass.points = pass.points + value * amount
    local tier = SeasonPassService.tierOf(pass.points)
    if tier > before then
        player:notify(Locale.t('Passe de saison : palier %d atteint. Récompense dans le menu Saison.', tier), 'success')
    end
end

---@param source integer
---@param data any { tier, premium }
---@return { ok: boolean, message?: string }
function SeasonPassService.claim(source, data)
    local player = PlayerService.get(source)
    if not player or player.dead or player.mode ~= 'pvp' or type(data) ~= 'table' or not player.seasonPass then return { ok = false } end

    local pass = player.seasonPass
    local tier = math.floor(tonumber(data.tier) or 0)
    local entry = Config.SeasonPass.tiers[tier]
    if not entry then return { ok = false } end
    if tier > SeasonPassService.tierOf(pass.points) then return { ok = false, message = Locale.t('Palier pas encore atteint.') } end
    local premium = data.premium == true
    if premium and not pass.premium then return { ok = false, message = Locale.t('Il faut le passe premium.') } end

    local key = (premium and 'p' or 'f') .. tier
    if pass.claimed[key] then return { ok = false, message = Locale.t('Récompense déjà prise.') } end
    pass.claimed[key] = true

    SeasonPassService.give(player, premium and entry.premium or entry.free, pass.season)
    PlayerRepository.save(player)
    player:sync()
    return { ok = true, message = Locale.t('Palier %d : récompense prise.', tier) }
end

---L'argent et les objets vont dans le sac ; ce qui n'y rentre pas tombe aux pieds du joueur.
---@param player PvpPlayer
---@param reward table
---@param season string
function SeasonPassService.give(player, reward, season)
    if reward.money then player:addMoney(reward.money) end
    if reward.xp then player:addXp(reward.xp) end
    local leftover = {}
    for name, count in pairs(reward.items or {}) do
        local added = player:giveItem(name, count)
        if added < count then leftover[name] = count - added end
    end
    if next(leftover) ~= nil then
        LootService.drop(player:getCoords(), leftover, { bucket = GetPlayerRoutingBucket(player.source) })
        player:notify(Locale.t('Sac plein : le reste du butin est à tes pieds.'), 'info')
    end
    if reward.title then SeasonRewardService.giveTitle(player.identifier, season .. ':pass', reward.title) end
end

---Achat de la piste premium en points boutique.
---@param source integer
---@return { ok: boolean, message?: string }
function SeasonPassService.buy(source)
    local player = PlayerService.get(source)
    if not player or not player.seasonPass or player.seasonPassBuying then return { ok = false } end
    local pass = player.seasonPass
    if pass.premium then return { ok = false, message = Locale.t('Tu as déjà le passe premium.') } end

    -- Réservé pendant l'attente de la base : une 2e demande ne peut pas payer en même temps
    player.seasonPassBuying = true
    local paid = ShopPointsService.spend(player, Config.SeasonPass.premiumPrice, 'season_pass:' .. pass.season)
    player.seasonPassBuying = false
    if not paid then
        player:sync()
        return { ok = false, message = Locale.t('Pas assez de %s.', Locale.t(Config.ShopPoints.label:lower())) }
    end

    Logger.info('[points] %s achète le passe de saison %s', player.name, pass.season)
    pass.premium = true
    SeasonPassService.save(player)
    if PlayerService.get(source) ~= player then return { ok = false } end
    player:sync()
    return { ok = true, message = Locale.t('Passe premium activé pour cette saison.') }
end

---@param player PvpPlayer
---@return table|nil pour le menu Saison
function SeasonPassService.serialize(player)
    local pass = player.seasonPass
    if not pass then return nil end
    return {
        points = pass.points,
        tier = SeasonPassService.tierOf(pass.points),
        premium = pass.premium,
        claimed = pass.claimed,
    }
end
