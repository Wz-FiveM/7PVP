---@class SpawnServiceModule
local SpawnService = PVP.define('SpawnService')
local PlayerService = PVP.use('PlayerService')
local Zones = PVP.use('Zones')
local AntiCheatService = PVP.use('AntiCheatService')
local Events = PVP.use('Events')

function SpawnService.init()
    -- Avant la sauvegarde du joueur qui quitte (voir PlayerService.unload)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        SpawnService.onPlayerLeaving(playerSource)
    end)
end

---Parti alors qu'il était mort : son sac est déjà au sol, il revient avec le kit
---de réapparition qu'il aurait reçu en réapparaissant.
---@param source integer
function SpawnService.onPlayerLeaving(source)
    local player = PlayerService.get(source)
    if player and player.dead then
        player:applyRespawnKit()
    end
end

---Le client applique lui-même ses armes après le spawn (voir client/modules/loadout).
---@param player PvpPlayer
function SpawnService.spawn(player)
    player.dead = false
    AntiCheatService.grace(player.source)
    player.combatLog = { taken = {}, dealt = {} }
    player:sync()
    TriggerClientEvent(Events.client.spawn, player.source, Zones.randomSpawn('pvp'), player.appearance)
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
        -- Le joueur a pu se déconnecter (et revenir), ou être réanimé par un admin entre-temps
        if PlayerService.get(player.source) == player and player.dead then
            SpawnService.respawn(player)
        end
    end)
end
