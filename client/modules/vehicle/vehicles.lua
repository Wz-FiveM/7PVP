---Véhicules en objets : création du véhicule demandée par le serveur (objet utilisé),
---joueur placé au volant, armes montées désactivées. Voir server/modules/vehicle.
---@class VehiclesModule
local Vehicles = PVP.define('Vehicles')
local State = PVP.use('State')
local PedUtils = PVP.use('PedUtils')
local Nui = PVP.use('Nui')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')

Vehicles.WEAPON_CHECK_INTERVAL = 250
Vehicles.MAX_VEHICLE_WEAPONS = 8

---@type integer|nil véhicule sorti par le joueur (entité locale)
Vehicles.current = nil

function Vehicles.init()
    RegisterNetEvent(Events.client.vehicleSpawn, function(name, model)
        Vehicles.spawn(name, model)
    end)
    CreateThread(Vehicles.weaponLoop)
end

---@param name string objet véhicule
---@param model string modèle GTA
function Vehicles.spawn(name, model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) or not PedUtils.loadModel(hash) then
        return TriggerServerEvent(Events.server.vehicleSpawned, name, false)
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(hash)
    if vehicle == 0 then
        return TriggerServerEvent(Events.server.vehicleSpawned, name, false)
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle, Config.VehicleOptions.plate)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehRadioStation(vehicle, 'OFF')
    SetPedIntoVehicle(ped, vehicle, -1)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    Vehicles.current = vehicle
    TriggerServerEvent(Events.server.vehicleSpawned, name, netId)
end

---@param entity integer
---@return boolean c'est le véhicule sorti par le joueur
function Vehicles.isMine(entity)
    return Vehicles.current ~= nil and Vehicles.current == entity and DoesEntityExist(entity)
end

---Range le véhicule (menu ALT) : le serveur vérifie distance, état et passagers.
function Vehicles.store()
    local result = Callback.await(Events.callbacks.vehicleStore)
    if result and result.ok then Vehicles.current = nil end
    if result and result.message then Nui.notify(result.message, result.ok and 'success' or 'error') end
end

---Pas d'armes montées en PvP (mitrailleuses, missiles...) : seules les armes de l'inventaire comptent.
function Vehicles.weaponLoop()
    while true do
        Wait(Vehicles.WEAPON_CHECK_INTERVAL)
        if State.inPvp() then
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= 0 then Vehicles.disableWeapons(ped, vehicle) end
        end
    end
end

---@param ped integer
---@param vehicle integer
function Vehicles.disableWeapons(ped, vehicle)
    -- Désactiver l'arme sélectionnée fait passer à la suivante : on recommence tant qu'il en reste
    for _ = 1, Vehicles.MAX_VEHICLE_WEAPONS do
        local hasWeapon, weapon = GetCurrentPedVehicleWeapon(ped)
        if not hasWeapon or weapon == 0 then return end
        DisableVehicleWeapon(true, weapon, vehicle, ped)
    end
end
