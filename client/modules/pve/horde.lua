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
