---Parcours de bienvenue (Config.Tutorial) : étapes validées par le serveur, dans n'importe quel ordre.
---Gardé avec le profil (colonne tutorial). Les anciens joueurs ne le voient pas.
---@class PvpTutorial
---@field done table<string, boolean>
---@field finished boolean terminé ou passé

---@class TutorialServiceModule
local TutorialService = PVP.define('TutorialService')
local PlayerService = PVP.use('PlayerService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

TutorialService.MODE = 'pvp'

---@type table<string, table> étapes par id
TutorialService.byId = {}
---@type table<string, table> étapes par compteur
TutorialService.byStat = {}

function TutorialService.init()
    Callback.register(Events.callbacks.tutorialSkip, TutorialService.skip)
end

-- Rempli au chargement du fichier : les profils peuvent arriver avant la fin des init
for _, step in ipairs(Config.Tutorial.steps) do
    TutorialService.byId[step.id] = step
    if step.stat then TutorialService.byStat[step.stat] = step end
end

---@param raw any valeur de la colonne tutorial
---@param row table ligne de pvp_players
---@return PvpTutorial
function TutorialService.decode(raw, row)
    local ok, data = pcall(json.decode, raw or '')
    if ok and type(data) == 'table' then
        local state = { done = {}, finished = data.finished == true }
        for id, on in pairs(type(data.done) == 'table' and data.done or {}) do
            if on == true and TutorialService.byId[id] then state.done[id] = true end
        end
        return state
    end
    local total = (tonumber(row.kills) or 0) + (tonumber(row.npc_kills) or 0)
    return { done = {}, finished = total > Config.Tutorial.veteranKills }
end

---@param player PvpPlayer
---@param id string
function TutorialService.complete(player, id)
    local state = player.tutorial
    local step = TutorialService.byId[id]
    if not state or state.finished or state.done[id] or not step or player.mode ~= TutorialService.MODE then return end

    state.done[id] = true
    player:addMoney(step.money)
    player:notify(Locale.t('Premiers pas : %s (+$%d)', Locale.t(step.label), step.money), 'success')

    local all = true
    for _, entry in ipairs(Config.Tutorial.steps) do
        if not state.done[entry.id] then all = false break end
    end
    if all then
        local reward = Config.Tutorial.finalReward
        state.finished = true
        player:addMoney(reward.money)
        player:addXp(reward.xp)
        player:notify(Locale.t('Premiers pas terminés ! +$%d, +%d XP', reward.money, reward.xp), 'success')
    end
    player:sync()
end

---Un compteur de haut fait a augmenté (voir AchievementService.track).
---@param player PvpPlayer
---@param stat string
function TutorialService.onStat(player, stat)
    local step = TutorialService.byStat[stat]
    if step then TutorialService.complete(player, step.id) end
end

---@param source integer
---@return { ok: boolean, message?: string }
function TutorialService.skip(source)
    local player = PlayerService.get(source)
    if not player or not player.tutorial then return { ok = false } end
    player.tutorial.finished = true
    player:sync()
    return { ok = true, message = Locale.t('Premiers pas masqués.') }
end
