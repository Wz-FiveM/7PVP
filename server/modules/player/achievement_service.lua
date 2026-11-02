---Hauts faits et titres du mode PvP (config/achievements.lua). Compteurs et hauts faits terminés sont
---gardés avec le profil (colonne achievements). Un titre se choisit parmi ceux que le joueur possède.
---@class PvpAchievements
---@field stats table<string, integer> valeur de chaque compteur
---@field done table<string, boolean> hauts faits terminés
---@field title string|nil titre affiché : id d'un haut faut, ou titre de saison

---@class AchievementServiceModule
local AchievementService = PVP.define('AchievementService')
local PlayerService = PVP.use('PlayerService')
local CrewService = PVP.use('CrewService')
local Callback = PVP.use('Callback')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

---@type table<string, table> entrées de Config.Achievements par id
AchievementService.byId = {}
---@type table<string, table[]> entrées de Config.Achievements par compteur
AchievementService.byStat = {}

function AchievementService.init()
    Callback.register(Events.callbacks.titleSelect, AchievementService.selectTitle)
end

-- Rempli au chargement du fichier : les profils peuvent arriver avant la fin des init
for _, entry in ipairs(Config.Achievements) do
    AchievementService.byId[entry.id] = entry
    AchievementService.byStat[entry.stat] = AchievementService.byStat[entry.stat] or {}
    table.insert(AchievementService.byStat[entry.stat], entry)
end

---@param raw any valeur de la colonne achievements
---@param row table ligne de pvp_players : les kills d'avant les hauts faits comptent
---@return PvpAchievements
function AchievementService.decode(raw, row)
    local ok, data = pcall(json.decode, raw or '')
    data = ok and type(data) == 'table' and data or {}

    local state = { stats = {}, done = {}, title = type(data.title) == 'string' and data.title or nil }
    for stat in pairs(Config.AchievementStats) do
        local value = type(data.stats) == 'table' and tonumber(data.stats[stat]) or 0
        state.stats[stat] = math.max(0, math.floor(value or 0))
    end
    for id, on in pairs(type(data.done) == 'table' and data.done or {}) do
        if on == true and AchievementService.byId[id] then state.done[id] = true end
    end
    state.stats.playerKill = math.max(state.stats.playerKill, tonumber(row.kills) or 0)
    state.stats.npcKill = math.max(state.stats.npcKill, tonumber(row.npc_kills) or 0)
    state.stats.assists = math.max(state.stats.assists, tonumber(row.assists) or 0)
    return state
end

---Ajoute à un compteur (ou garde la meilleure valeur pour un compteur `max`), puis verse ce qui est atteint.
---@param player PvpPlayer
---@param stat string
---@param amount integer
function AchievementService.track(player, stat, amount)
    local definition = Config.AchievementStats[stat]
    if not definition or player.mode ~= 'pvp' then return end
    local stats = player.achievements.stats
    stats[stat] = definition.max and math.max(stats[stat] or 0, amount) or (stats[stat] or 0) + amount

    for _, entry in ipairs(AchievementService.byStat[stat] or {}) do
        if stats[stat] >= entry.goal and not player.achievements.done[entry.id] then
            AchievementService.complete(player, entry)
        end
    end
end

---@param player PvpPlayer
---@param entry table
function AchievementService.complete(player, entry)
    player.achievements.done[entry.id] = true
    player:addMoney(entry.reward.money)
    player:addXp(entry.reward.xp)
    player:notify(Locale.t('Haut fait : %s (+$%d, +%d XP)', Locale.t(entry.label), entry.reward.money, entry.reward.xp), 'success')
    Logger.info('[haut fait] %s : %s', player.name, entry.label)
    player:sync()
end

---Territoire pris : le haut fait compte pour les membres en PvP.
---@param tag string
function AchievementService.onCapture(tag)
    for _, player in pairs(PlayerService.all()) do
        if CrewService.tagOf(player.identifier) == tag then AchievementService.track(player, 'captures', 1) end
    end
end

---@param player PvpPlayer
---@param id any
---@return boolean le joueur possède ce titre
function AchievementService.ownsTitle(player, id)
    local entry = AchievementService.byId[id]
    if entry then return entry.title == true and player.achievements.done[id] == true end
    return player.seasonTitles ~= nil and player.seasonTitles[id] ~= nil
end

---@param player PvpPlayer
---@return string|table|nil texte du titre affiché
function AchievementService.titleOf(player)
    local id = player.achievements.title
    if not id or not AchievementService.ownsTitle(player, id) then return nil end
    local entry = AchievementService.byId[id]
    return Locale.t(entry and entry.label or player.seasonTitles[id])
end

---Nom dans le chat : précédé du titre choisi.
---@param player PvpPlayer
---@return string|table
function AchievementService.chatName(player)
    local title = player.mode == 'pvp' and AchievementService.titleOf(player)
    if not title then return player:displayName() end
    return Locale.t('« %s » %s', title, player:displayName())
end

---@param source integer
---@param id any id du titre, chaîne vide pour n'en afficher aucun
---@return { ok: boolean, message?: string }
function AchievementService.selectTitle(source, id)
    local player = PlayerService.get(source)
    if not player or type(id) ~= 'string' then return { ok = false } end
    local chosen = id ~= '' and id or nil
    if chosen and not AchievementService.ownsTitle(player, chosen) then
        return { ok = false, message = Locale.t('Tu ne possèdes pas ce titre.') }
    end
    player.achievements.title = chosen
    player:sync()
    return { ok = true, message = chosen and Locale.t('Titre équipé.') or Locale.t('Titre retiré.') }
end

---@param player PvpPlayer
---@return table pour le menu Hauts faits
function AchievementService.serialize(player)
    local state = player.achievements
    local titles = {}
    for id, label in pairs(player.seasonTitles or {}) do titles[#titles + 1] = { id = id, label = label } end
    table.sort(titles, function(a, b) return a.id > b.id end)
    return { stats = state.stats, done = state.done, title = state.title, seasonTitles = titles }
end
