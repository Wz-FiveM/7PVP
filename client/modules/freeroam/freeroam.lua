---Mode Freeroam côté client : menu (Tab) d'armes et de véhicules gratuits, outils du joueur,
---PvP au choix et réapparition sur place. Rien ne touche à l'inventaire du PvP.
---@class FreeroamModule
local Freeroam = PVP.define('Freeroam')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Chase = PVP.use('Chase')
local Cvc = PVP.use('Cvc')
local Gunfight = PVP.use('Gunfight')
local Gungame = PVP.use('Gungame')
local Admin = PVP.use('Admin')
local PedUtils = PVP.use('PedUtils')
local Vehicles = PVP.use('Vehicles')
local VehicleCustom = PVP.use('VehicleCustom')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Freeroam.menuOpen = false
Freeroam.pvp = false
Freeroam.vehicle = nil -- dernier véhicule créé (supprimé quand on en crée un autre, voir Vehicles.trackMenuVehicle)
Freeroam.vehicleModel = nil -- nom du modèle de ce véhicule
Freeroam.weapons = {} -- armes données : rendues après une mort

-- Actions du menu : nom -> méthode
Freeroam.ACTIONS = {
    weapon = 'giveWeapon',
    clearWeapons = 'clearWeapons',
    vehicle = 'spawnVehicle',
    repair = 'repairVehicle',
    custom = 'customVehicle',
    heal = 'heal',
    armor = 'giveArmor',
    waypoint = 'teleportToWaypoint',
    activity = 'gotoActivity',
    pvp = 'togglePvp',
}

function Freeroam.init()
    RegisterNetEvent(Events.client.freeroamCleanup, function()
        Freeroam.cleanup()
    end)
    -- Liste des véhicules modifiée par un admin (voir FreeroamConfigService)
    RegisterNetEvent(Events.client.freeroamSettings, function(name, vehicles)
        if name == 'menuVehicles' and type(vehicles) == 'table' then Config.Freeroam.vehicles = vehicles end
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
    -- Pendant un mode de jeu (course...), pas d'armes ni de véhicules gratuits
    if open and (not Freeroam.isActive() or not State.isAlive() or State.activity) then return end
    -- Déjà fermé : ne pas reprendre le focus à une autre interface (ex : le lobby)
    if not open and not Freeroam.menuOpen then return end
    Freeroam.menuOpen = open
    SetNuiFocus(open, open)
    Nui.setGameInput(open)
    Nui.send('freeroamMenu', {
        open = open,
        pvp = Freeroam.pvp,
        weapons = Config.Freeroam.weapons,
        vehicles = Config.Freeroam.vehicles,
        owned = Freeroam.ownedWeapons(),
        activities = Freeroam.activityList(),
    })
end

function Freeroam.toggleMenu()
    Freeroam.setMenu(not Freeroam.menuOpen)
end

---@param data table { action, ... }
---@return { ok: boolean, message?: string, pvp?: boolean, owned?: string[] }
function Freeroam.runAction(data)
    local method = type(data) == 'table' and Freeroam.ACTIONS[data.action]
    if not method or not Freeroam.isActive() then return { ok = false } end
    local result = Freeroam[method](data)
    result.pvp = Freeroam.pvp
    result.owned = Freeroam.ownedWeapons()
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

---Liste « Sur moi » du menu : regardée sur le personnage, un parachute utilisé ou une partie finie peuvent en retirer.
---@return string[] armes de Config.Freeroam.weapons portées par le joueur
function Freeroam.ownedWeapons()
    local ped = PlayerPedId()
    local list = {}
    for _, entry in ipairs(Config.Freeroam.weapons) do
        if HasPedGotWeapon(ped, GetHashKey(entry.weapon), false) then list[#list + 1] = entry.weapon end
    end
    return list
end

---@param data { weapon: string }
function Freeroam.giveWeapon(data)
    if not Freeroam.isAllowedWeapon(data.weapon) then return { ok = false, message = Locale.t('Arme indisponible.') } end
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
    return { ok = true, message = Locale.t('Armes retirées.') }
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
        return { ok = false, message = Locale.t('Véhicule inconnu : %s', model) }
    end
    if State.isInSafeZone() then
        return { ok = false, message = Locale.t('Impossible de faire apparaître un véhicule en zone safe : sors de la zone.') }
    end

    local saved = Callback.await(Events.callbacks.freeroamCustomGet, model)
    Freeroam.deleteVehicle()
    if not PedUtils.loadModel(hash) then return { ok = false, message = Locale.t('Modèle introuvable.') } end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetVehicleOnGroundProperly(vehicle)
    SetPedIntoVehicle(ped, vehicle, -1)
    SetVehicleNumberPlateText(vehicle, '7PVP')
    if saved and saved.custom then VehicleCustom.apply(vehicle, saved.custom) end
    SetModelAsNoLongerNeeded(hash)
    Freeroam.vehicle = vehicle
    Freeroam.vehicleModel = model
    CreateThread(function() Vehicles.trackMenuVehicle(vehicle) end)
    Freeroam.setMenu(false)
    return { ok = true }
end

---Supprime le véhicule sorti : tout de suite s'il est encore à nous, sinon par le serveur.
function Freeroam.deleteVehicle()
    if Freeroam.vehicle and DoesEntityExist(Freeroam.vehicle) then
        SetEntityAsMissionEntity(Freeroam.vehicle, true, true)
        DeleteVehicle(Freeroam.vehicle)
    end
    Freeroam.vehicle = nil
    Freeroam.vehicleModel = nil
    Vehicles.trackMenuVehicle(nil)
end

function Freeroam.repairVehicle()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then return { ok = false, message = Locale.t('Monte dans un véhicule.') } end
    SetVehicleFixed(vehicle)
    SetVehicleDirtLevel(vehicle, 0.0)
    return { ok = true, message = Locale.t('Véhicule réparé.') }
end

---@param model string
---@return string nom affiché : celui du menu, sinon celui de GTA (modèle tapé à la main)
function Freeroam.vehicleLabel(model)
    for _, entry in ipairs(Config.Freeroam.vehicles) do
        if entry.model == model then return entry.label end
    end
    local label = GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(model)))
    return label ~= 'NULL' and label or model
end

---Ouvre le menu du mécanicien sur le véhicule sorti de ce menu, joueur au volant et à l'arrêt.
function Freeroam.customVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not Freeroam.vehicle or vehicle ~= Freeroam.vehicle or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return { ok = false, message = Locale.t('Mets-toi au volant du véhicule sorti du menu Freeroam.') }
    end
    if GetEntitySpeed(vehicle) * 3.6 >= Config.VehicleCustom.maxSpeed then
        return { ok = false, message = Locale.t('Arrête le véhicule pour le customiser.') }
    end
    Freeroam.setMenu(false)
    VehicleCustom.openFreeroam(vehicle, Freeroam.vehicleModel, Freeroam.vehicleLabel(Freeroam.vehicleModel))
    return { ok = true }
end

-- ---------------------------------------------------------------------------
-- Joueur
-- ---------------------------------------------------------------------------

function Freeroam.heal()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    return { ok = true, message = Locale.t('Soigné.') }
end

function Freeroam.giveArmor()
    SetPedArmour(PlayerPedId(), 100)
    return { ok = true, message = Locale.t('Armure au maximum.') }
end

function Freeroam.teleportToWaypoint()
    local result = Admin.teleportToWaypoint()
    if result.ok then Freeroam.setMenu(false) end
    return result
end

-- ---------------------------------------------------------------------------
-- Modes de jeu
-- ---------------------------------------------------------------------------

---Onglet « Modes de jeu » : ils se lancent toujours en parlant à leur PNJ.
---@return table[] modes de Config.FreeroamActivities, triés par nom
function Freeroam.activityList()
    local list = {}
    for id, activity in pairs(Config.FreeroamActivities) do
        list[#list + 1] = {
            id = id,
            label = activity.label,
            tagline = activity.tagline,
            description = activity.description,
            icon = activity.icon,
            enabled = activity.enabled == true,
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

---Téléporte devant le PNJ d'un mode de jeu, face à lui.
---@param data { id: string }
function Freeroam.gotoActivity(data)
    if not State.activity then
        for _, npc in ipairs(Config.SafeNpcs.npcs) do
            if npc.activity == data.id then
                local coords = npc.coords
                local heading = math.rad(coords.w)
                local target = vector3(coords.x - math.sin(heading) * 1.5, coords.y + math.cos(heading) * 1.5, coords.z + 1.0)
                CreateThread(function()
                    Admin.teleport(target)
                    SetEntityHeading(PlayerPedId(), (coords.w + 180.0) % 360.0)
                end)
                Freeroam.setMenu(false)
                return { ok = true, message = Locale.t('Téléporté.') }
            end
        end
    end
    return { ok = false, message = Locale.t('Mode de jeu indisponible.') }
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
    -- CVC et 1VS1 : une seule vie par manche, on reste mort jusqu'à la manche suivante
    if Cvc.isActive() then return Cvc.onDeath() end
    if Gunfight.isActive() then return Gunfight.onDeath() end
    -- Gungame : le serveur compte le kill et choisit où réapparaître
    if Gungame.isActive() then return Gungame.onDeath() end
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
    -- Course en cours ou file d'attente : abandonnées (le serveur a déjà réglé la partie)
    Chase.cleanup()
    Cvc.cleanup()
    Gunfight.cleanup()
    Gungame.cleanup()
    Nui.send('cvcQueue', { count = 0 })
    Nui.send('cvcHud', { open = false })
    Nui.send('gunfightQueue', { count = 0 })
    Nui.send('gunfightHud', { open = false })
    Nui.send('gungameQueue', { count = 0 })
    Nui.send('gungameHud', { open = false })
    Nui.send('chaseQueue', { count = 0 })
    Nui.send('chaseHud', { open = false })
    RemoveAllPedWeapons(PlayerPedId(), true)
    Freeroam.weapons = {}
    Freeroam.pvp = false
    Nui.send('freeroamPvp', { pvp = false })
end
