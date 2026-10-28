---Mode PvP : le gamemode actuel (zones, PvE, inventaire perdu à la mort).
---@class PvpModeModule
local PvpMode = PVP.define('PvpMode')
local ModeRegistry = PVP.use('ModeRegistry')
local SpawnService = PVP.use('SpawnService')
local PlayerRepository = PVP.use('PlayerRepository')
local CombatTagService = PVP.use('CombatTagService')
local GroupService = PVP.use('GroupService')
local VehicleService = PVP.use('VehicleService')

PvpMode.ID = 'pvp'

function PvpMode.init()
    ModeRegistry.register(PvpMode.ID, PvpMode)
end

---@param player PvpPlayer
function PvpMode.enter(player)
    SpawnService.spawn(player)
end

---Pas de fuite en plein combat : on ne quitte le PvP que vivant et en zone safe.
---@param player PvpPlayer
---@return boolean, string|nil
function PvpMode.canLeave(player)
    if player.dead then
        return false, 'Attends de réapparaître.'
    end
    if not player:isInSafeZone() then
        return false, 'Rejoins une zone safe pour retourner au lobby.'
    end
    if CombatTagService.isTagged(player) then
        return false, ('Tu es en combat : attends %d s.'):format(CombatTagService.remaining(player))
    end
    return true
end

---@param player PvpPlayer
function PvpMode.leave(player)
    GroupService.leave(player.source)
    VehicleService.release(player)
    PlayerRepository.save(player)
end
