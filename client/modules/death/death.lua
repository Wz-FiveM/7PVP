---Détection de la mort du joueur local.
---@class DeathModule
local Death = PVP.define('Death')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Loadout = PVP.use('Loadout')
local PedUtils = PVP.use('PedUtils')
local Events = PVP.use('Events')

Death.CHECK_INTERVAL = 250

function Death.init()
    RegisterNetEvent(Events.client.dead, function(seconds)
        Death.onConfirmed(seconds)
    end)

    CreateThread(Death.watchLoop)
end

function Death.watchLoop()
    while true do
        Wait(Death.CHECK_INTERVAL)
        if State.isAlive() then
            Death.check()
        end
    end
end

function Death.check()
    local ped = PlayerPedId()
    if not IsEntityDead(ped) then return end

    State.dead = true
    -- Les munitions tirées sont envoyées avant la mort (les événements arrivent dans l'ordre)
    Loadout.onDeath()
    TriggerServerEvent(Events.server.died, PedUtils.getKillerServerId(ped))
end

---@param seconds integer délai avant respawn
function Death.onConfirmed(seconds)
    if State.menuOpen then
        Nui.setMenu(false)
    end
    Nui.send('death', { seconds = seconds })
end
