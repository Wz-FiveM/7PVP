---Horde en cours (server/modules/pve/horde_service.lua) : relayée au HUD.
---@class HordeModule
local Horde = PVP.define('Horde')
local Nui = PVP.use('Nui')
local Events = PVP.use('Events')

function Horde.init()
    RegisterNetEvent(Events.client.hordeState, function(state)
        Nui.send('horde', { horde = state or false })
    end)
end

---Le mini boss se bat comme un zombie (Pve.updatePed) : seule sa vie lui est propre. Le serveur ne peut pas
---la lire (la synchro de GTA ne transmet pas une vie max posée par script tant que le ped est à pleine vie :
---il y lit 200), alors le client qui le pilote la publie dans hordeBossHealth. Un nouveau propriétaire qui
---reçoit le boss sans sa vie max la remet, avec la dernière vie publiée.
---@param ped integer
function Horde.setupBoss(ped)
    local state = Entity(ped).state
    local maxHealth = 100 + state.hordeBoss
    if GetEntityMaxHealth(ped) ~= maxHealth then
        SetPedMaxHealth(ped, maxHealth)
        SetEntityHealth(ped, 100 + (state.hordeBossHealth or state.hordeBoss))
    end
    local remaining = math.max(0, GetEntityHealth(ped) - 100)
    if state.hordeBossHealth ~= remaining then state:set('hordeBossHealth', remaining, true) end
    if not state.pvpNpcReady then state:set('pvpNpcReady', true, true) end
end
