---Zones de conflit : de temps en temps, une zone apparaît sur la carte avec un compteur.
---Le joueur qui y fait le plus de kills est le kill leader ; à la fin du compteur, il remporte
---l'argent, l'XP et le butin de Config.ConflictZones.reward.
---@class ConflictScore
---@field kills integer
---@field at integer numéro d'ordre de son dernier kill compté (égalité : le premier arrivé reste devant)

---@class ActiveConflict
---@field def table entrée de Config.ConflictZones.zones
---@field endsAt integer GetGameTimer() de la fin du compteur
---@field scores table<integer, ConflictScore> server id -> score
---@field lastKills table<string, integer> 'tueur:victime' -> GetGameTimer() du dernier kill compté
---@field killCount integer kills comptés depuis le début

---@class ConflictServiceModule
local ConflictService = PVP.define('ConflictService')
local AchievementService = PVP.use('AchievementService')
local PlayerService = PVP.use('PlayerService')
local GroupService = PVP.use('GroupService')
local LootService = PVP.use('LootService')
local ModeRegistry = PVP.use('ModeRegistry')
local ChatService = PVP.use('ChatService')
local Items = PVP.use('Items')
local Utils = PVP.use('Utils')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

ConflictService.TICK = 1000
-- Réapparition du gagnant mort à la fin du compteur : on attend pour ne pas perdre son butin
ConflictService.RESPAWN_POLL = 500

---@type ActiveConflict|nil
ConflictService.active = nil
ConflictService.lastZoneId = nil
ConflictService.lastSent = ''

function ConflictService.init()
    RegisterNetEvent(Events.server.ready, function()
        TriggerClientEvent(Events.client.conflictState, source, ConflictService.describe())
    end)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        if ConflictService.active then ConflictService.active.scores[playerSource] = nil end
    end)
    if Config.ConflictZones.enabled then
        CreateThread(ConflictService.loop)
    end
end

function ConflictService.loop()
    Wait(Config.ConflictZones.firstDelay * 1000)
    while true do
        local started = ModeRegistry.countPlayers('pvp') >= Config.ConflictZones.minPlayers and ConflictService.start() ~= nil
        Wait((started and Config.ConflictZones.interval or Config.ConflictZones.retryDelay) * 1000)
    end
end

---@return table|nil zone de la config au hasard, pas deux fois de suite la même
function ConflictService.pickZone()
    local candidates = {}
    for _, def in ipairs(Config.ConflictZones.zones) do
        if def.id ~= ConflictService.lastZoneId then candidates[#candidates + 1] = def end
    end
    if #candidates == 0 then return Config.ConflictZones.zones[1] end
    return Utils.pick(candidates)
end

---@param def? table zone imposée (admin), sinon une zone de la config au hasard
---@return ActiveConflict|nil nil : une zone est déjà en cours
function ConflictService.start(def)
    if ConflictService.active then return nil end
    def = def or ConflictService.pickZone()
    if not def then return nil end

    local conflict = {
        def = def,
        endsAt = GetGameTimer() + Config.ConflictZones.duration * 1000,
        scores = {},
        lastKills = {},
        killCount = 0,
    }
    ConflictService.active = conflict
    ConflictService.lastZoneId = def.id

    local label = Locale.t(def.label)
    ChatService.announce('pvp', Locale.t('Une zone de conflit apparaît : %s ! %d minutes pour y faire le plus de kills.', label, math.floor(Config.ConflictZones.duration / 60)))
    ModeRegistry.broadcast('pvp', Events.client.notify, Locale.t('Zone de conflit : %s', label), 'info')
    Logger.info('[conflit] %s', def.label)

    ConflictService.broadcast(true)
    CreateThread(function() ConflictService.watch(conflict) end)
    return conflict
end

---@param conflict ActiveConflict
function ConflictService.watch(conflict)
    while ConflictService.active == conflict and GetGameTimer() < conflict.endsAt do
        Wait(ConflictService.TICK)
        ConflictService.broadcast(false)
    end
    if ConflictService.active == conflict then ConflictService.finish() end
end

---@param conflict ActiveConflict
---@param player PvpPlayer
---@return boolean
function ConflictService.isInside(conflict, player)
    return #(player:getCoords().xy - conflict.def.coords.xy) <= conflict.def.radius
end

---Appelé à chaque kill entre joueurs (voir CombatService.rewardPlayerKill).
---@param killer PvpPlayer
---@param victim PvpPlayer
function ConflictService.onPlayerKill(killer, victim)
    local conflict = ConflictService.active
    if not conflict or killer.mode ~= 'pvp' or victim.mode ~= 'pvp' then return end
    if not ConflictService.isInside(conflict, killer) or not ConflictService.isInside(conflict, victim) then return end
    if GroupService.areAllies(killer.source, victim.source) then return end

    local now = GetGameTimer()
    local pair = killer.source .. ':' .. victim.source
    local last = conflict.lastKills[pair]
    if last and now - last < Config.ConflictZones.sameVictimDelay * 1000 then return end
    conflict.lastKills[pair] = now

    conflict.killCount = conflict.killCount + 1
    local score = conflict.scores[killer.source] or { kills = 0 }
    score.kills = score.kills + 1
    score.at = conflict.killCount
    conflict.scores[killer.source] = score
    ConflictService.broadcast(false)
end

---Meilleur score parmi les joueurs encore en PvP.
---@param conflict ActiveConflict
---@return PvpPlayer|nil, ConflictScore|nil
function ConflictService.leaderOf(conflict)
    local leader, best = nil, nil
    for source, score in pairs(conflict.scores) do
        local player = PlayerService.get(source)
        if player and player.mode == 'pvp' and (not best or score.kills > best.kills or (score.kills == best.kills and score.at < best.at)) then
            leader, best = player, score
        end
    end
    return leader, best
end

---Fin du compteur : le kill leader remporte la zone.
---@return boolean false : aucune zone en cours
function ConflictService.finish()
    local conflict = ConflictService.active
    if not conflict then return false end
    ConflictService.active = nil

    local label = Locale.t(conflict.def.label)
    local winner, score = ConflictService.leaderOf(conflict)
    if winner then
        ChatService.announce('pvp', Locale.t('%s remporte la zone de conflit %s (kills : %d) !', winner:displayName(), label, score.kills))
        CreateThread(function() ConflictService.rewardWhenAlive(winner) end)
    else
        ChatService.announce('pvp', Locale.t('La zone de conflit %s se termine sans vainqueur.', label))
    end
    Logger.info('[conflit] fin : %s, vainqueur : %s', conflict.def.label, winner and winner.name or 'aucun')
    TriggerClientEvent(Events.client.conflictState, -1, false)
    return true
end

---La réapparition remplace le sac par le kit de départ : un gagnant mort reçoit sa récompense après.
---@param player PvpPlayer
function ConflictService.rewardWhenAlive(player)
    while player.dead and PlayerService.get(player.source) == player do
        Wait(ConflictService.RESPAWN_POLL)
    end
    if PlayerService.get(player.source) == player and player.mode == 'pvp' then
        ConflictService.reward(player)
    end
end

---L'argent et les objets vont dans le sac ; ce qui n'y rentre pas tombe aux pieds du gagnant.
---@param player PvpPlayer
function ConflictService.reward(player)
    AchievementService.track(player, 'conflictWins', 1)
    local reward = Config.ConflictZones.reward
    player:addMoney(reward.money)
    player:addXp(reward.xp)
    player:notify(Locale.t('Zone de conflit remportée : +$%d, +%d XP', reward.money, reward.xp), 'success')

    local taken, leftover = {}, {}
    for name, count in pairs(LootService.roll(reward.loot)) do
        local added = player:giveItem(name, count)
        if added > 0 then taken[name] = added end
        if added < count then leftover[name] = count - added end
    end
    if next(taken) ~= nil then
        player:notify(Locale.t('Butin : %s', Items.describeText(taken)), 'success')
    end
    if next(leftover) ~= nil then
        LootService.drop(player:getCoords(), leftover, {
            bucket = GetPlayerRoutingBucket(player.source),
            browse = true,
            label = Locale.t('Fouiller le butin'),
            title = Locale.t('Butin de la zone de conflit'),
        })
        player:notify(Locale.t('Sac plein : le reste du butin est à tes pieds.'), 'info')
    end
    player:sync()
end

---État envoyé aux clients : durée restante plutôt qu'une date (horloges différentes).
---@return table|false
function ConflictService.describe()
    local conflict = ConflictService.active
    if not conflict then return false end
    local leader, best = ConflictService.leaderOf(conflict)
    return {
        id = conflict.def.id,
        label = conflict.def.label,
        coords = conflict.def.coords,
        radius = conflict.def.radius,
        endsIn = math.max(0, math.ceil((conflict.endsAt - GetGameTimer()) / 1000)),
        leader = leader and { name = leader:displayName(), colors = leader:displayColors(), kills = best.kills } or false,
    }
end

---Envoie l'état à tous, seulement s'il a changé (leader parti, zone déplacée par un admin).
---@param force boolean
function ConflictService.broadcast(force)
    local conflict = ConflictService.active
    if not conflict then return end
    local leader, best = ConflictService.leaderOf(conflict)
    local coords = conflict.def.coords
    local key = ('%s:%d:%.1f:%.1f:%.1f'):format(leader and leader:displayName() or '', best and best.kills or 0, coords.x, coords.y, conflict.def.radius)
    if not force and key == ConflictService.lastSent then return end
    ConflictService.lastSent = key
    TriggerClientEvent(Events.client.conflictState, -1, ConflictService.describe())
end
