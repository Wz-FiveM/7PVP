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
State.appearance = nil -- apparence du personnage, reçue au spawn
State.mode = nil -- mode de jeu en cours ('pvp', 'freeroam', 'cod'), nil = lobby ou création
State.activity = nil -- mode de jeu du Freeroam en cours ('chase'), nil = Freeroam libre

-- Options admin (voir client/modules/admin)
State.noclip = false
State.godmode = false
State.invisible = false
State.spectating = false -- mode spectateur (voir client/modules/admin/spectate.lua)

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
function State.inPvp()
    return State.mode == 'pvp'
end

---@return boolean jamais de tir en véhicule : PvP et 1VS1 Bike (on descend de la moto pour se battre)
function State.noDriveBy()
    return State.inPvp() or State.activity == 'bike'
end

---@return boolean
function State.isAlive()
    return State.spawned and not State.dead
end
