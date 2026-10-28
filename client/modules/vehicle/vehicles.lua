---Véhicules en objets : création du véhicule demandée par le serveur (objet utilisé),
---joueur placé au volant, armes montées désactivées. Voir server/modules/vehicle.
---@class VehiclesModule
local Vehicles = PVP.define('Vehicles')
local State = PVP.use('State')
local PedUtils = PVP.use('PedUtils')
local Nui = PVP.use('Nui')
local HelpNotify = PVP.use('HelpNotify')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')

Vehicles.WEAPON_CHECK_INTERVAL = 250
Vehicles.MAX_VEHICLE_WEAPONS = 8
Vehicles.NETWORK_TIMEOUT = 2000 -- ms pour que le véhicule créé soit en réseau avant d'abandonner

---@type integer|nil véhicule sorti par le joueur (entité locale)
Vehicles.current = nil

function Vehicles.init()
    RegisterNetEvent(Events.client.vehicleSpawn, function(name, model)
        Vehicles.spawn(name, model)
    end)
    -- Son véhicule n'est plus à lui : refusé par le serveur (objet rendu, il ne doit pas rester
    -- en jeu) ou rangé par un autre joueur
    RegisterNetEvent(Events.client.vehicleReleased, function()
        Vehicles.discard()
    end)

    RegisterCommand('pvp_ranger_vehicule', function()
        if not State.inPvp() or not State.isAlive() or IsNuiFocused() then return end
        local vehicle = Vehicles.storable()
        if not vehicle then
            return Nui.notify('Monte dans un véhicule sorti d\'un objet pour le ranger.', 'error')
        end
        if Vehicles.isMoving(vehicle) then
            return Nui.notify(('Arrête le véhicule pour le ranger (moins de %d km/h).'):format(Config.VehicleOptions.storeMaxSpeed), 'error')
        end
        CreateThread(Vehicles.store)
    end, false)
    RegisterKeyMapping('pvp_ranger_vehicule', 'Ranger un véhicule 7PVP (assis dedans)', 'keyboard', Config.VehicleOptions.storeKey)

    CreateThread(Vehicles.weaponLoop)
    CreateThread(Vehicles.helpLoop)
end

Vehicles.HELP_CHECK_INTERVAL = 500
-- State bag posé par le serveur sur les véhicules sortis d'un objet (VehicleService.ITEM_STATE)
Vehicles.ITEM_STATE = '7pvp:vehicleItem'

---Véhicule dans lequel le joueur est assis, s'il est sorti d'un objet (le sien ou celui d'un autre).
---@return integer|nil
function Vehicles.storable()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 or not Entity(vehicle).state[Vehicles.ITEM_STATE] then return nil end
    return vehicle
end

---@param vehicle integer
---@return boolean le véhicule roule encore (au-dessus de Config.VehicleOptions.storeMaxSpeed)
function Vehicles.isMoving(vehicle)
    return GetEntitySpeed(vehicle) * 3.6 >= Config.VehicleOptions.storeMaxSpeed
end

---Aide « K Ranger le véhicule » à bord d'un véhicule sorti d'un objet, une fois arrêté
---(en roulant, elle gênerait ; la touche répond alors qu'il faut s'arrêter).
function Vehicles.helpLoop()
    while true do
        local vehicle = State.inPvp() and State.isAlive() and not IsNuiFocused() and Vehicles.storable()
        if vehicle and not Vehicles.isMoving(vehicle) then
            HelpNotify.show(Config.VehicleOptions.storeKey, 'Ranger le véhicule')
            Wait(0)
        else
            Wait(Vehicles.HELP_CHECK_INTERVAL)
        end
    end
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

    -- Le net id n'est valable qu'une fois le véhicule en réseau
    local timeout = GetGameTimer() + Vehicles.NETWORK_TIMEOUT
    while not NetworkGetEntityIsNetworked(vehicle) and GetGameTimer() < timeout do Wait(0) end
    if not NetworkGetEntityIsNetworked(vehicle) then
        DeleteEntity(vehicle)
        return TriggerServerEvent(Events.server.vehicleSpawned, name, false)
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    Vehicles.current = vehicle
    TriggerServerEvent(Events.server.vehicleSpawned, name, netId)
end

---Oublie son véhicule sorti et le supprime s'il est encore là (refusé par le serveur).
function Vehicles.discard()
    local vehicle = Vehicles.current
    Vehicles.current = nil
    if not vehicle or not DoesEntityExist(vehicle) then return end
    if GetVehiclePedIsIn(PlayerPedId(), false) == vehicle then TaskLeaveVehicle(PlayerPedId(), vehicle, 16) end
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteEntity(vehicle)
end

---Range le véhicule dans lequel le joueur est assis : le serveur vérifie l'origine (objet),
---l'état, la vitesse et les passagers, et donne l'objet à celui qui range.
function Vehicles.store()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local result = Callback.await(Events.callbacks.vehicleStore)
    if result and result.ok and vehicle == Vehicles.current then Vehicles.current = nil end
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
