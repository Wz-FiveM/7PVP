---Mode Freeroam côté client : menu (F2) d'armes et de véhicules gratuits, outils du joueur,
---PvP au choix et réapparition sur place. Rien ne touche à l'inventaire du PvP.
---@class FreeroamModule
local Freeroam = PVP.define('Freeroam')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Admin = PVP.use('Admin')
local PedUtils = PVP.use('PedUtils')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')

Freeroam.menuOpen = false
Freeroam.pvp = false
Freeroam.vehicle = nil -- dernier véhicule créé (supprimé quand on en crée un autre)
Freeroam.weapons = {} -- armes données : rendues après une mort

-- Actions du menu : nom -> méthode
Freeroam.ACTIONS = {
    weapon = 'giveWeapon',
    clearWeapons = 'clearWeapons',
    vehicle = 'spawnVehicle',
    repair = 'repairVehicle',
    heal = 'heal',
    armor = 'giveArmor',
    waypoint = 'teleportToWaypoint',
    pvp = 'togglePvp',
}

function Freeroam.init()
    RegisterNetEvent(Events.client.freeroamCleanup, function()
        Freeroam.cleanup()
    end)
    RegisterNUICallback('freeroamClose', function(_, cb)
        Freeroam.setMenu(false)
        cb({})
    end)
    RegisterNUICallback('freeroamAction', function(data, cb)
        cb(Freeroam.runAction(data))
    end)
end

---@return boolean
function Freeroam.isActive()
    return State.mode == 'freeroam'
end

-- ---------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------

---@param open boolean
function Freeroam.setMenu(open)
    if open and (not Freeroam.isActive() or not State.isAlive()) then return end
    -- Déjà fermé : ne pas reprendre le focus à une autre interface (ex : le lobby)
    if not open and not Freeroam.menuOpen then return end
    Freeroam.menuOpen = open
    SetNuiFocus(open, open)
    Nui.send('freeroamMenu', {
        open = open,
        pvp = Freeroam.pvp,
        weapons = Config.Freeroam.weapons,
        vehicles = Config.Freeroam.vehicles,
    })
end

function Freeroam.toggleMenu()
    Freeroam.setMenu(not Freeroam.menuOpen)
end

---@param data table { action, ... }
---@return { ok: boolean, message?: string, pvp?: boolean }
function Freeroam.runAction(data)
    local method = type(data) == 'table' and Freeroam.ACTIONS[data.action]
    if not method or not Freeroam.isActive() then return { ok = false } end
    local result = Freeroam[method](data)
    result.pvp = Freeroam.pvp
    return result
end

-- ---------------------------------------------------------------------------
-- Armes
-- ---------------------------------------------------------------------------

---@param weapon string
---@return boolean proposée dans Config.Freeroam.weapons
function Freeroam.isAllowedWeapon(weapon)
    for _, entry in ipairs(Config.Freeroam.weapons) do
        if entry.weapon == weapon then return true end
    end
    return false
end

---@param data { weapon: string }
function Freeroam.giveWeapon(data)
    if not Freeroam.isAllowedWeapon(data.weapon) then return { ok = false, message = 'Arme indisponible.' } end
    local ped = PlayerPedId()
    local hash = GetHashKey(data.weapon)
    GiveWeaponToPed(ped, hash, 9999, false, true)
    SetPedInfiniteAmmo(ped, true, hash)
    Freeroam.weapons[data.weapon] = true
    return { ok = true }
end

function Freeroam.clearWeapons()
    RemoveAllPedWeapons(PlayerPedId(), true)
    Freeroam.weapons = {}
    return { ok = true, message = 'Armes retirées.' }
end

---Après une mort, on rend les armes données.
function Freeroam.restoreWeapons()
    local ped = PlayerPedId()
    for weapon in pairs(Freeroam.weapons) do
        local hash = GetHashKey(weapon)
        GiveWeaponToPed(ped, hash, 9999, false, false)
        SetPedInfiniteAmmo(ped, true, hash)
    end
end

-- ---------------------------------------------------------------------------
-- Véhicules
-- ---------------------------------------------------------------------------

---@param data { model: string }
function Freeroam.spawnVehicle(data)
    local model = type(data.model) == 'string' and data.model:lower():gsub('[^%w_]', '') or ''
    local hash = GetHashKey(model)
    if model == '' or not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return { ok = false, message = ('Véhicule inconnu : %s'):format(model) }
    end

    Freeroam.deleteVehicle()
    if not PedUtils.loadModel(hash) then return { ok = false, message = 'Modèle introuvable.' } end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetVehicleOnGroundProperly(vehicle)
    SetPedIntoVehicle(ped, vehicle, -1)
    SetVehicleNumberPlateText(vehicle, '7PVP')
    SetModelAsNoLongerNeeded(hash)
    Freeroam.vehicle = vehicle
    Freeroam.setMenu(false)
    return { ok = true }
end

function Freeroam.deleteVehicle()
    if Freeroam.vehicle and DoesEntityExist(Freeroam.vehicle) then
        SetEntityAsMissionEntity(Freeroam.vehicle, true, true)
        DeleteVehicle(Freeroam.vehicle)
    end
    Freeroam.vehicle = nil
end

function Freeroam.repairVehicle()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then return { ok = false, message = 'Monte dans un véhicule.' } end
    SetVehicleFixed(vehicle)
    SetVehicleDirtLevel(vehicle, 0.0)
    return { ok = true, message = 'Véhicule réparé.' }
end

-- ---------------------------------------------------------------------------
-- Joueur
-- ---------------------------------------------------------------------------

function Freeroam.heal()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    return { ok = true, message = 'Soigné.' }
end

function Freeroam.giveArmor()
    SetPedArmour(PlayerPedId(), 100)
    return { ok = true, message = 'Armure au maximum.' }
end

function Freeroam.teleportToWaypoint()
    local result = Admin.teleportToWaypoint()
    if result.ok then Freeroam.setMenu(false) end
    return result
end

function Freeroam.togglePvp()
    local result = Callback.await(Events.callbacks.freeroamPvp, not Freeroam.pvp)
    if not result or not result.ok then return { ok = false, message = result and result.message } end
    Freeroam.pvp = result.pvp
    Nui.send('freeroamPvp', { pvp = Freeroam.pvp })
    return { ok = true, message = result.message }
end

---Mort en Freeroam : pas de sac ni d'écran de mort, on réapparaît sur place.
function Freeroam.onDeath()
    State.dead = true
    CreateThread(function()
        Wait(Config.Freeroam.respawnDelay * 1000)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
        ped = PlayerPedId()
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        ClearPedBloodDamage(ped)
        State.dead = false
        Freeroam.restoreWeapons()
    end)
end

---Retour au lobby : armes et véhicule du Freeroam retirés, PvP coupé.
function Freeroam.cleanup()
    Freeroam.setMenu(false)
    Freeroam.deleteVehicle()
    RemoveAllPedWeapons(PlayerPedId(), true)
    Freeroam.weapons = {}
    Freeroam.pvp = false
    Nui.send('freeroamPvp', { pvp = false })
end
