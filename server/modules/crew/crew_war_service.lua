---Guerre de crews (Config.Crews.war) : le chef d'un crew en défie un autre, le chef adverse accepte.
---Chaque crew met la même somme, prise dans l'argent de son coffre. Le crew qui fait le plus de kills
---sur l'autre pendant la guerre prend le pot dans son coffre ; à égalité, chacun reprend sa mise.
---La guerre est gardée en base : un redémarrage ne perd ni la mise ni le score.
---@class CrewWar
---@field id integer
---@field tagA string
---@field tagB string
---@field stake integer mise de chaque crew
---@field killsA integer
---@field killsB integer
---@field endsAt integer os.time()

---@class CrewWarServiceModule
local CrewWarService = PVP.define('CrewWarService')
local CrewService = PVP.use('CrewService')
local CrewStashService = PVP.use('CrewStashService')
local PlayerService = PVP.use('PlayerService')
local ChatService = PVP.use('ChatService')
local Callback = PVP.use('Callback')
local Utils = PVP.use('Utils')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CrewWarService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_crew_wars (
    id INT NOT NULL AUTO_INCREMENT,
    tag_a VARCHAR(3) NOT NULL,
    tag_b VARCHAR(3) NOT NULL,
    stake INT NOT NULL,
    kills_a INT NOT NULL DEFAULT 0,
    kills_b INT NOT NULL DEFAULT 0,
    ends_at INT NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]
CrewWarService.CHECK_INTERVAL = 5000

---@type CrewWar[]
CrewWarService.wars = {}
---@type table<string, { from: string, stake: integer, expires: integer }> label défié -> défi reçu
CrewWarService.challenges = {}
---@type table<string, integer> 'AAA:BBB' (labels triés) -> os.time() de la fin de leur dernière guerre
CrewWarService.lastWar = {}

function CrewWarService.init()
    Callback.register(Events.callbacks.crewWarDeclare, CrewWarService.declare)
    Callback.register(Events.callbacks.crewWarRespond, CrewWarService.respond)
    CreateThread(function()
        while true do
            Wait(CrewWarService.CHECK_INTERVAL)
            CrewWarService.finishExpired()
        end
    end)
end

---Guerres gardées en base : appelé par CrewService une fois crews et coffres chargés.
function CrewWarService.restore()
    MySQL.query.await(CrewWarService.SCHEMA)
    for _, row in ipairs(MySQL.query.await('SELECT * FROM pvp_crew_wars') or {}) do
        CrewWarService.wars[#CrewWarService.wars + 1] = {
            id = row.id, tagA = row.tag_a, tagB = row.tag_b, stake = row.stake,
            killsA = row.kills_a, killsB = row.kills_b, endsAt = row.ends_at,
        }
    end
    Logger.info('Guerres de crews en cours : %d', #CrewWarService.wars)
end

---@param tag string
---@return CrewWar|nil
function CrewWarService.warOf(tag)
    for _, war in ipairs(CrewWarService.wars) do
        if war.tagA == tag or war.tagB == tag then return war end
    end
    return nil
end

---@param a string
---@param b string
---@return string
function CrewWarService.pairKey(a, b)
    return a < b and (a .. ':' .. b) or (b .. ':' .. a)
end

---@param tag string
---@return integer argent du coffre du crew
function CrewWarService.funds(tag)
    return CrewStashService.get(tag).items.money or 0
end

---@param source integer
---@return PvpPlayer|nil, PvpCrew|nil
function CrewWarService.leaderOf(source)
    local player = PlayerService.get(source)
    local crew = CrewService.crewOf(source)
    if not player or not crew or crew.leader ~= player.identifier then return nil, nil end
    return player, crew
end

---Défi lancé par un chef.
---@param source integer
---@param data any { tag, stake }
---@return { ok: boolean, message?: string }
function CrewWarService.declare(source, data)
    local player, crew = CrewWarService.leaderOf(source)
    if not player then return { ok = false, message = Locale.t('Seul le chef du crew peut déclarer une guerre.') } end
    if type(data) ~= 'table' then return { ok = false } end

    local settings = Config.Crews.war
    local enemy = CrewService.crews[CrewService.cleanTag(data.tag) or '']
    local stake = Utils.toCount(data.stake)
    if not enemy or enemy == crew then return { ok = false, message = Locale.t('Ce crew n\'existe pas.') } end
    if stake < settings.minStake or stake > settings.maxStake then
        return { ok = false, message = Locale.t('Mise entre $%d et $%d.', settings.minStake, settings.maxStake) }
    end
    if CrewWarService.warOf(crew.tag) then return { ok = false, message = Locale.t('Ton crew est déjà en guerre.') } end
    if CrewWarService.warOf(enemy.tag) then return { ok = false, message = Locale.t('Ce crew est déjà en guerre.') } end
    if CrewWarService.funds(crew.tag) < stake then return { ok = false, message = Locale.t('Pas assez d\'argent dans le coffre du crew.') } end

    local last = CrewWarService.lastWar[CrewWarService.pairKey(crew.tag, enemy.tag)]
    if last and os.time() - last < settings.cooldown then
        return { ok = false, message = Locale.t('Vos deux crews se sont affrontés il y a peu : réessaie plus tard.') }
    end
    local pending = CrewWarService.challenges[enemy.tag]
    if pending and pending.expires > os.time() then return { ok = false, message = Locale.t('Ce crew a déjà un défi en attente.') } end

    CrewWarService.challenges[enemy.tag] = { from = crew.tag, stake = stake, expires = os.time() + settings.answerTime }
    CrewService.notifyMembers(enemy, Locale.t('[%s] défie ton crew : $%d de mise. Le chef répond dans le menu Crew.', crew.tag, stake))
    CrewService.sync(enemy)
    SetTimeout(settings.answerTime * 1000 + 500, function()
        local challenge = CrewWarService.challenges[enemy.tag]
        if challenge and challenge.expires <= os.time() and CrewService.crews[enemy.tag] then
            CrewWarService.challenges[enemy.tag] = nil
            CrewService.sync(enemy)
        end
    end)
    return { ok = true, message = Locale.t('Défi envoyé à [%s].', enemy.tag) }
end

---Réponse du chef défié.
---@param source integer
---@param accept any
---@return { ok: boolean, message?: string }
function CrewWarService.respond(source, accept)
    local player, crew = CrewWarService.leaderOf(source)
    if not player then return { ok = false, message = Locale.t('Seul le chef du crew peut répondre.') } end
    local challenge = CrewWarService.challenges[crew.tag]
    CrewWarService.challenges[crew.tag] = nil
    if not challenge or challenge.expires <= os.time() then
        CrewService.sync(crew)
        return { ok = false, message = Locale.t('Ce défi a expiré.') }
    end

    local enemy = CrewService.crews[challenge.from]
    if accept ~= true then
        if enemy then CrewService.notifyMembers(enemy, Locale.t('[%s] refuse la guerre.', crew.tag)) end
        CrewService.sync(crew)
        return { ok = true, message = Locale.t('Défi refusé.') }
    end

    if not enemy or CrewWarService.warOf(enemy.tag) or CrewWarService.warOf(crew.tag) then
        CrewService.sync(crew)
        return { ok = false, message = Locale.t('Ce défi a expiré.') }
    end
    -- Le coffre a pu être vidé depuis le défi
    if CrewWarService.funds(crew.tag) < challenge.stake then
        CrewService.sync(crew)
        return { ok = false, message = Locale.t('Pas assez d\'argent dans le coffre du crew.') }
    end
    if CrewWarService.funds(enemy.tag) < challenge.stake then
        CrewService.sync(crew)
        return { ok = false, message = Locale.t('[%s] n\'a plus la mise dans son coffre.', enemy.tag) }
    end

    CrewWarService.start(enemy, crew, challenge.stake)
    return { ok = true, message = Locale.t('Guerre déclarée !') }
end

---@param crewA PvpCrew
---@param crewB PvpCrew
---@param stake integer
function CrewWarService.start(crewA, crewB, stake)
    CrewStashService.moveMoney(crewA.tag, -stake, 'Mise de guerre')
    CrewStashService.moveMoney(crewB.tag, -stake, 'Mise de guerre')

    local war = {
        tagA = crewA.tag, tagB = crewB.tag, stake = stake, killsA = 0, killsB = 0,
        endsAt = os.time() + Config.Crews.war.duration,
    }
    CrewWarService.wars[#CrewWarService.wars + 1] = war
    war.id = MySQL.insert.await(
        'INSERT INTO pvp_crew_wars (tag_a, tag_b, stake, ends_at) VALUES (?, ?, ?, ?)',
        { war.tagA, war.tagB, stake, war.endsAt }
    )
    ChatService.announce('pvp', Locale.t('Guerre de crews : [%s] contre [%s] pour $%d !', war.tagA, war.tagB, stake * 2))
    Logger.info('[crew] guerre [%s] contre [%s], mise $%d', war.tagA, war.tagB, stake)
    CrewService.sync(crewA)
    CrewService.sync(crewB)
end

---Kill entre crews déjà compté au classement (voir CrewStatsService.onPlayerKill).
---@param killerTag string
---@param victimTag string
function CrewWarService.onKill(killerTag, victimTag)
    local war = CrewWarService.warOf(killerTag)
    if not war or (war.tagA ~= victimTag and war.tagB ~= victimTag) or war.endsAt <= os.time() then return end
    if war.tagA == killerTag then war.killsA = war.killsA + 1 else war.killsB = war.killsB + 1 end
    if war.id then
        MySQL.update('UPDATE pvp_crew_wars SET kills_a = ?, kills_b = ? WHERE id = ?', { war.killsA, war.killsB, war.id })
    end
    if CrewService.crews[war.tagA] then CrewService.sync(CrewService.crews[war.tagA]) end
    if CrewService.crews[war.tagB] then CrewService.sync(CrewService.crews[war.tagB]) end
end

function CrewWarService.finishExpired()
    local now = os.time()
    for index = #CrewWarService.wars, 1, -1 do
        local war = CrewWarService.wars[index]
        if war.endsAt <= now then CrewWarService.finish(war) end
    end
end

---@param war CrewWar
---@param forfeit? string label du crew qui abandonne (dissous)
function CrewWarService.finish(war, forfeit)
    for index, other in ipairs(CrewWarService.wars) do
        if other == war then table.remove(CrewWarService.wars, index) break end
    end
    if war.id then MySQL.update('DELETE FROM pvp_crew_wars WHERE id = ?', { war.id }) end
    CrewWarService.lastWar[CrewWarService.pairKey(war.tagA, war.tagB)] = os.time()

    local winner
    if forfeit then
        winner = forfeit == war.tagA and war.tagB or war.tagA
    elseif war.killsA ~= war.killsB then
        winner = war.killsA > war.killsB and war.tagA or war.tagB
    end

    if winner then
        CrewWarService.pay(winner, war.stake * 2)
        local loser = winner == war.tagA and war.tagB or war.tagA
        ChatService.announce('pvp', Locale.t('[%s] gagne la guerre contre [%s] (%d à %d) et prend $%d !', winner, loser,
            math.max(war.killsA, war.killsB), math.min(war.killsA, war.killsB), war.stake * 2))
    else
        CrewWarService.pay(war.tagA, war.stake)
        CrewWarService.pay(war.tagB, war.stake)
        ChatService.announce('pvp', Locale.t('Égalité entre [%s] et [%s] : chacun reprend sa mise.', war.tagA, war.tagB))
    end
    Logger.info('[crew] fin de guerre [%s] %d - %d [%s], gagnant : %s', war.tagA, war.killsA, war.killsB, war.tagB, winner or 'aucun')
end

---@param tag string
---@param amount integer
function CrewWarService.pay(tag, amount)
    local crew = CrewService.crews[tag]
    if not crew then return end
    CrewStashService.moveMoney(tag, amount, 'Gain de guerre')
    CrewService.sync(crew)
end

---Crew dissous : il perd sa guerre, et ses défis tombent.
---@param tag string
function CrewWarService.onDissolve(tag)
    CrewWarService.challenges[tag] = nil
    for target, challenge in pairs(CrewWarService.challenges) do
        if challenge.from == tag then CrewWarService.challenges[target] = nil end
    end
    local war = CrewWarService.warOf(tag)
    if war then CrewWarService.finish(war, tag) end
end

---@param tag string
---@return table|false guerre vue par ce crew, pour le menu
---@return table|false défi reçu
function CrewWarService.describe(tag)
    local war = CrewWarService.warOf(tag)
    local now = os.time()
    local warData = false
    if war then
        local isA = war.tagA == tag
        local enemy = CrewService.crews[isA and war.tagB or war.tagA]
        warData = {
            enemyTag = isA and war.tagB or war.tagA,
            enemyName = enemy and enemy.name or '',
            kills = isA and war.killsA or war.killsB,
            enemyKills = isA and war.killsB or war.killsA,
            stake = war.stake,
            endsIn = math.max(0, war.endsAt - now),
        }
    end
    local challenge = CrewWarService.challenges[tag]
    local challengeData = false
    if challenge and challenge.expires > now then
        challengeData = { tag = challenge.from, stake = challenge.stake, expiresIn = challenge.expires - now }
    end
    return warData, challengeData
end
