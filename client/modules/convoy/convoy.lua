---Convoi blindé côté client : repère sur la carte en PvP, et conduite par le client qui a le contrôle réseau
---du fourgon. Le contrôle change de joueur au fil de la route : chacun reprend la consigne à son tour.
---@class ConvoyModule
local Convoy = PVP.define('Convoy')
local State = PVP.use('State')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Convoy.INTERVAL = 1000
-- Une consigne répétée trop souvent fait hésiter le chauffeur
Convoy.RETASK_DELAY = 10000

---@type { id: integer, netId: integer, coords: vector3, target: vector3 }|nil
Convoy.state = nil
---@type integer|nil
Convoy.blip = nil
---@type { ped: integer, x: number, y: number, at: integer }|nil dernière consigne donnée
Convoy.lastTask = nil

function Convoy.init()
    RegisterNetEvent(Events.client.convoyState, function(data)
        Convoy.state = data or nil
    end)
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then Convoy.deleteBlip() end
    end)
    CreateThread(Convoy.loop)
end

function Convoy.loop()
    while true do
        Wait(Convoy.INTERVAL)
        local state = Convoy.state
        if state then Convoy.drive(state) end
        if state and State.inPvp() then
            Convoy.updateBlip(state)
        else
            Convoy.deleteBlip()
        end
    end
end

---@param state table
function Convoy.updateBlip(state)
    if not Convoy.blip then
        local blip = AddBlipForCoord(state.coords.x, state.coords.y, state.coords.z)
        SetBlipSprite(blip, Config.Convoy.blip.sprite)
        SetBlipColour(blip, Config.Convoy.blip.color)
        SetBlipScale(blip, 1.1)
        SetBlipAsShortRange(blip, false)
        SetBlipFlashes(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Locale.t('Convoi blindé'))
        EndTextCommandSetBlipName(blip)
        Convoy.blip = blip
    end
    SetBlipCoords(Convoy.blip, state.coords.x, state.coords.y, state.coords.z)
end

function Convoy.deleteBlip()
    if Convoy.blip and DoesBlipExist(Convoy.blip) then RemoveBlip(Convoy.blip) end
    Convoy.blip = nil
end

---Seul le client qui contrôle le fourgon donne la consigne au chauffeur.
---@param state table
function Convoy.drive(state)
    if not NetworkDoesEntityExistWithNetworkId(state.netId) then return end
    local vehicle = NetworkGetEntityFromNetworkId(state.netId)
    if vehicle == 0 or not NetworkHasControlOfEntity(vehicle) then return end
    local ped = GetPedInVehicleSeat(vehicle, -1)
    if ped == 0 or IsEntityDead(ped) or not NetworkHasControlOfEntity(ped) then return end

    local last = Convoy.lastTask
    local now = GetGameTimer()
    if last and last.ped == ped and last.x == state.target.x and last.y == state.target.y and now - last.at < Convoy.RETASK_DELAY then
        return
    end
    Convoy.lastTask = { ped = ped, x = state.target.x, y = state.target.y, at = now }

    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedKeepTask(ped, true)
    SetDriverAbility(ped, 1.0)
    TaskVehicleDriveToCoordLongrange(ped, vehicle, state.target.x, state.target.y, state.target.z,
        Config.Convoy.speed, Config.Convoy.drivingStyle, Config.Convoy.arriveDistance / 2)
end
