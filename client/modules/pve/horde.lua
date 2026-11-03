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

---Le mini boss se bat comme un zombie (Pve.updatePed) : seule sa vie lui est propre. Appliquée une fois,
---sinon un changement de propriétaire la remettrait au max.
---@param ped integer
function Horde.setupBoss(ped)
    local state = Entity(ped).state
    if state.pvpNpcReady then return end
    local health = 100 + state.hordeBoss
    SetPedMaxHealth(ped, health)
    SetEntityHealth(ped, health)
    state:set('pvpNpcReady', true, true)
end
