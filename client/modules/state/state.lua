---État local du joueur, partagé entre les modules client.
---@class StateModule
local State = PVP.define('State')
local Nui = PVP.use('Nui')
local Loadout = PVP.use('Loadout')
local Events = PVP.use('Events')

State.player = nil -- dernière synchro serveur (argent, xp, inventaire...)
State.spawned = false
State.dead = false
State.zone = nil -- entrée de Config.Zones, nil = PvP libre, false = à recalculer
State.menuOpen = false

function State.init()
    RegisterNetEvent(Events.client.sync, function(data)
        State.setPlayer(data)
    end)
end

---@param data table
function State.setPlayer(data)
    State.player = data
    Loadout.onSync(data)
    Nui.send('sync', data)
end

---@return boolean
function State.isInSafeZone()
    return type(State.zone) == 'table' and State.zone.type == 'safe'
end

---@return boolean
function State.isAlive()
    return State.spawned and not State.dead
end
