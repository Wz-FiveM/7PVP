---Morts des joueurs, récompenses de kill et killfeed.
---@class CombatServiceModule
local CombatService = PVP.define('CombatService')
local PlayerService = PVP.use('PlayerService')
local SpawnService = PVP.use('SpawnService')
local LootService = PVP.use('LootService')
local Events = PVP.use('Events')

function CombatService.init()
    RegisterNetEvent(Events.server.died, function(killerId)
        CombatService.onPlayerDied(source, killerId)
    end)
end

---@param source integer
---@param killerId integer|nil server id du tueur, calculé par le client
function CombatService.onPlayerDied(source, killerId)
    local victim = PlayerService.get(source)
    if not victim or victim.dead then return end

    victim.dead = true
    victim.deaths = victim.deaths + 1

    CombatService.dropVictimLoot(victim)

    local killer = CombatService.resolveKiller(victim, killerId)
    if killer then
        CombatService.rewardPlayerKill(killer, victim)
    end
    CombatService.broadcastKill(killer and killer.name, victim.name)

    victim:sync()
    TriggerClientEvent(Events.client.dead, victim.source, Config.RespawnDelay)
    SpawnService.scheduleRespawn(victim, Config.RespawnDelay)
end

---Le contenu du sac (argent compris) tombe au sol, le conteneur protégé est conservé.
---@param victim PvpPlayer
function CombatService.dropVictimLoot(victim)
    LootService.drop(victim:getCoords(), victim:takeBag())
end

---@param victim PvpPlayer
---@param killerId any
---@return PvpPlayer|nil
function CombatService.resolveKiller(victim, killerId)
    killerId = tonumber(killerId)
    if not killerId or killerId == victim.source then return nil end

    local killer = PlayerService.get(killerId)
    if not killer or not CombatService.isWithinKillRange(killer:getCoords(), victim:getCoords()) then
        return nil
    end
    return killer
end

---@param a vector3
---@param b vector3
---@return boolean
function CombatService.isWithinKillRange(a, b)
    return #(a - b) <= Config.MaxKillDistance
end

---@param killer PvpPlayer
---@param victim PvpPlayer
function CombatService.rewardPlayerKill(killer, victim)
    local reward = Config.Rewards.playerKill
    killer.kills = killer.kills + 1
    killer:addMoney(reward.money)
    killer:addXp(reward.xp)
    killer:notify(('Tu as tué %s (+$%d)'):format(victim.name, reward.money), 'success')
    killer:sync()
end

---@param killer PvpPlayer
function CombatService.rewardNpcKill(killer)
    local reward = Config.Rewards.npcKill
    killer.npcKills = killer.npcKills + 1
    killer:addMoney(reward.money)
    killer:addXp(reward.xp)
    killer:sync()
end

---@param killerName string|nil
---@param victimName string
function CombatService.broadcastKill(killerName, victimName)
    TriggerClientEvent(Events.client.killfeed, -1, { killer = killerName, victim = victimName })
end
