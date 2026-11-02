---Némésis et vengeance (Config.Rivalry) : tuer son dernier tueur rapporte un bonus, et un joueur qui
---te tue plusieurs fois de suite devient ta némésis, dont la mort rapporte davantage.
---Gardé en mémoire : une rivalité ne survit pas à une déconnexion du joueur qui la subit.
---@class PvpRivals
---@field streaks table<string, integer> licence du tueur -> kills de suite sur ce joueur
---@field names table<string, string> licence du tueur -> nom affiché
---@field lastKiller string|nil licence de son dernier tueur
---@field lastKilledAt integer os.time()
---@field bonusAt table<string, integer> licence de la victime -> os.time() du dernier bonus touché

---@class RivalryServiceModule
local RivalryService = PVP.define('RivalryService')
local GroupService = PVP.use('GroupService')
local Locale = PVP.use('Locale')

---@param player PvpPlayer
---@return PvpRivals
function RivalryService.of(player)
    if not player.rivals then
        player.rivals = { streaks = {}, names = {}, lastKilledAt = 0, bonusAt = {} }
    end
    return player.rivals
end

---Appelé à chaque kill entre joueurs (voir CombatService.rewardPlayerKill).
---@param killer PvpPlayer
---@param victim PvpPlayer
function RivalryService.onPlayerKill(killer, victim)
    if killer.mode ~= 'pvp' or victim.mode ~= 'pvp' or GroupService.areAllies(killer.source, victim.source) then return end
    local settings = Config.Rivalry
    local mine, theirs = RivalryService.of(killer), RivalryService.of(victim)
    local now = os.time()

    local wasNemesis = (mine.streaks[victim.identifier] or 0) >= settings.nemesisKills
    local isRevenge = mine.lastKiller == victim.identifier and now - mine.lastKilledAt <= settings.revengeWindow
    mine.streaks[victim.identifier] = nil
    if isRevenge then mine.lastKiller = nil end
    if wasNemesis or isRevenge then RivalryService.reward(killer, victim, mine, wasNemesis, now) end

    local streak = (theirs.streaks[killer.identifier] or 0) + 1
    theirs.streaks[killer.identifier] = streak
    theirs.names[killer.identifier] = killer:displayName()
    theirs.lastKiller = killer.identifier
    theirs.lastKilledAt = now
    if streak == settings.nemesisKills then
        victim:notify(Locale.t('%s t\'a tué %d fois de suite : c\'est ta némésis. Abats-le pour un gros bonus.', killer:displayName(), streak), 'error')
        killer:notify(Locale.t('Tu es devenu la némésis de %s.', victim:displayName()), 'info')
        victim:sync()
    end
end

---Deux complices ne se font pas gagner de bonus en se tuant à tour de rôle : un seul par délai.
---@param killer PvpPlayer
---@param victim PvpPlayer
---@param mine PvpRivals
---@param wasNemesis boolean
---@param now integer
function RivalryService.reward(killer, victim, mine, wasNemesis, now)
    local settings = Config.Rivalry
    if now - (mine.bonusAt[victim.identifier] or 0) < settings.bonusDelay then return end
    mine.bonusAt[victim.identifier] = now

    local reward = wasNemesis and settings.nemesisReward or settings.revengeReward
    killer:addMoney(reward.money)
    killer:addXp(reward.xp)
    local text = wasNemesis and Locale.t('Némésis abattue : %s (+$%d)', victim:displayName(), reward.money)
        or Locale.t('Vengeance sur %s (+$%d)', victim:displayName(), reward.money)
    killer:notify(text, 'success')
end

---Pour le profil.
---@param player PvpPlayer
---@return string[] noms des joueurs qui sont sa némésis
function RivalryService.nemeses(player)
    local names = {}
    if not player.rivals then return names end
    for identifier, streak in pairs(player.rivals.streaks) do
        if streak >= Config.Rivalry.nemesisKills then names[#names + 1] = player.rivals.names[identifier] end
    end
    table.sort(names)
    return names
end
