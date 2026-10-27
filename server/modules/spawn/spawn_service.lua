---@class SpawnServiceModule
local SpawnService = PVP.define('SpawnService')
local PlayerService = PVP.use('PlayerService')
local Zones = PVP.use('Zones')
local Events = PVP.use('Events')

---Le client applique lui-même ses armes après le spawn (voir client/modules/loadout).
---@param player PvpPlayer
function SpawnService.spawn(player)
    player.dead = false
    player:sync()
    TriggerClientEvent(Events.client.spawn, player.source, Zones.randomSpawn(), player.appearance)
end

---@param player PvpPlayer
function SpawnService.respawn(player)
    player:applyRespawnKit()
    SpawnService.spawn(player)
end

---@param player PvpPlayer
---@param delay integer secondes
function SpawnService.scheduleRespawn(player, delay)
    SetTimeout(delay * 1000, function()
        -- Le joueur a pu se déconnecter (et revenir) entre-temps
        if PlayerService.get(player.source) == player then
            SpawnService.respawn(player)
        end
    end)
end
