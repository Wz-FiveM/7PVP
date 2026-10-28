---Panneau admin (F10) et commandes admin reçues du serveur.
---Les actions sur les joueurs passent par le serveur (permission ACE vérifiée là-bas) ;
---les options personnelles (noclip, invincible...) s'appliquent ici, réservées aux admins.
---@class AdminModule
local Admin = PVP.define('Admin')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Noclip = PVP.use('Noclip')
local Loadout = PVP.use('Loadout')
local PedUtils = PVP.use('PedUtils')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')

Admin.isAdmin = false
Admin.open = false

-- Options personnelles : nom d'action -> méthode
Admin.LOCAL_ACTIONS = {
    noclip = 'toggleNoclip',
    god = 'toggleGod',
    invisible = 'toggleInvisible',
    tpWaypoint = 'teleportToWaypoint',
    spawnVehicle = 'spawnVehicle',
    deleteVehicle = 'deleteVehicle',
}

-- Commandes envoyées par le serveur : nom -> méthode
Admin.COMMANDS = {
    heal = 'commandHeal',
    revive = 'commandRevive',
    kill = 'commandKill',
    freeze = 'commandFreeze',
    teleport = 'teleport',
}

function Admin.init()
    RegisterNetEvent(Events.client.adminStatus, function(isAdmin)
        Admin.isAdmin = isAdmin == true
    end)
    RegisterNetEvent(Events.client.adminCommand, function(command, payload)
        Admin.onCommand(command, payload)
    end)

    RegisterCommand('pvp_admin', function()
        Admin.toggle()
    end, false)
    RegisterKeyMapping('pvp_admin', 'Panneau admin', 'keyboard', Config.Admin.Key)

    RegisterCommand('pvp_noclip', function()
        if Admin.isAdmin and State.mode then Admin.toggleNoclip() end
    end, false)
    RegisterKeyMapping('pvp_noclip', 'Noclip (admin)', 'keyboard', Config.Admin.NoclipKey)

    -- /tpm : téléportation au marqueur de la carte
    RegisterCommand('tpm', function()
        Admin.commandTeleportToMarker()
    end, false)

    RegisterNUICallback('adminClose', function(_, cb)
        Admin.close()
        cb({})
    end)
    RegisterNUICallback('adminPlayers', function(_, cb)
        cb(Admin.isAdmin and Callback.await(Events.callbacks.adminPlayers) or {})
    end)
    RegisterNUICallback('adminAction', function(data, cb)
        cb(Admin.runAction(data))
    end)

    -- Onglet « Butin » : tables de butin et butin des zones PvE (vérifié par le serveur)
    RegisterNUICallback('adminLoot', function(_, cb)
        cb(Callback.await(Events.callbacks.adminLoot) or { ok = false })
    end)
    RegisterNUICallback('adminLootSave', function(data, cb)
        cb(Callback.await(Events.callbacks.adminLootSave, data.name, data.table) or { ok = false })
    end)
    RegisterNUICallback('adminLootReset', function(data, cb)
        cb(Callback.await(Events.callbacks.adminLootReset, data.name) or { ok = false })
    end)
    RegisterNUICallback('adminLootZones', function(data, cb)
        cb(Callback.await(Events.callbacks.adminLootZones, data.zones) or { ok = false })
    end)
end

-- ---------------------------------------------------------------------------
-- Panneau
-- ---------------------------------------------------------------------------

---@return table
function Admin.selfState()
    return { noclip = State.noclip == true, god = State.godmode == true, invisible = State.invisible == true }
end

function Admin.toggle()
    if Admin.open then return Admin.close() end
    if not Admin.isAdmin or not State.mode then return end
    if State.menuOpen then Nui.setMenu(false) end

    Admin.open = true
    SetNuiFocus(true, true)
    Nui.send('admin', { open = true, self = Admin.selfState() })
end

function Admin.close()
    if not Admin.open then return end
    Admin.open = false
    SetNuiFocus(false, false)
    Nui.send('admin', { open = false })
end

---@param data table { action, ... }
---@return { ok: boolean, message?: string, self?: table }
function Admin.runAction(data)
    if not Admin.isAdmin or type(data) ~= 'table' then return { ok = false, message = 'Accès refusé.' } end

    local method = Admin.LOCAL_ACTIONS[data.action]
    if method then
        local result = Admin[method](data)
        result.self = Admin.selfState()
        return result
    end
    return Callback.await(Events.callbacks.adminAction, data) or { ok = false, message = 'Le serveur ne répond pas.' }
end

-- ---------------------------------------------------------------------------
-- Options personnelles
-- ---------------------------------------------------------------------------

function Admin.toggleNoclip()
    Noclip.toggle()
    return { ok = true, message = Noclip.active and 'Noclip activé.' or 'Noclip désactivé.' }
end

function Admin.toggleGod()
    State.godmode = not State.godmode
    Noclip.applyPedState()
    return { ok = true, message = State.godmode and 'Invincibilité activée.' or 'Invincibilité désactivée.' }
end

function Admin.toggleInvisible()
    State.invisible = not State.invisible
    Noclip.applyPedState()
    return { ok = true, message = State.invisible and 'Tu es invisible.' or 'Tu es visible.' }
end

---/tpm, réservé aux admins en jeu (pas au lobby ni dans le créateur).
function Admin.commandTeleportToMarker()
    if not Admin.isAdmin then
        return Nui.notify('Commande réservée aux admins.', 'error')
    end
    if not State.mode then return end
    local result = Admin.teleportToWaypoint()
    Nui.notify(result.message, result.ok and 'success' or 'error')
end

function Admin.teleportToWaypoint()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then
        return { ok = false, message = 'Place un marqueur sur la carte.' }
    end
    local coords = GetBlipInfoIdCoord(blip)
    CreateThread(function()
        -- Gelé pendant la recherche du sol : pas de chute ni de dégâts entre deux hauteurs testées
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, true)
        Admin.teleport(vector3(coords.x, coords.y, Admin.findGroundZ(coords.x, coords.y)))
        FreezeEntityPosition(ped, Noclip.active)
    end)
    return { ok = true, message = 'Téléporté au marqueur.' }
end

---Altitude du sol à une position dont on ne connaît pas la hauteur (ex : marqueur de carte).
---@return number
function Admin.findGroundZ(x, y)
    local ped = PlayerPedId()
    for height = 0, 1000, 50 do
        RequestCollisionAtCoord(x, y, height + 0.0)
        SetEntityCoordsNoOffset(ped, x, y, height + 0.0, false, false, false)
        Wait(50)
        local found, ground = GetGroundZFor_3dCoord(x, y, height + 0.0, false)
        if found then return ground end
    end
    return 100.0
end

---@param data table { model }
function Admin.spawnVehicle(data)
    local model = type(data.model) == 'string' and data.model:lower():gsub('[^%w_]', '') or ''
    local hash = GetHashKey(model)
    if model == '' or not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return { ok = false, message = ('Véhicule inconnu : %s'):format(model) }
    end

    CreateThread(function()
        PedUtils.loadModel(hash)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
        SetVehicleOnGroundProperly(vehicle)
        SetPedIntoVehicle(ped, vehicle, -1)
        SetModelAsNoLongerNeeded(hash)
    end)
    return { ok = true, message = ('Véhicule %s créé.'):format(model) }
end

function Admin.deleteVehicle()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then
        return { ok = false, message = 'Monte dans le véhicule à supprimer.' }
    end
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
    return { ok = true, message = 'Véhicule supprimé.' }
end

-- ---------------------------------------------------------------------------
-- Commandes reçues du serveur (seul le serveur peut les envoyer)
-- ---------------------------------------------------------------------------

---@param command string
---@param payload any
function Admin.onCommand(command, payload)
    local method = Admin.COMMANDS[command]
    if method then Admin[method](payload) end
end

function Admin.commandHeal()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    Nui.notify('Un admin t\'a soigné.', 'success')
end

function Admin.commandRevive()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedTasksImmediately(ped)
    State.dead = false
    Loadout.apply()
    Nui.send('alive')
    Nui.notify('Un admin t\'a réanimé.', 'success')
end

function Admin.commandKill()
    SetEntityHealth(PlayerPedId(), 0)
end

---@param frozen boolean
function Admin.commandFreeze(frozen)
    FreezeEntityPosition(PlayerPedId(), frozen == true)
    Nui.notify(frozen and 'Un admin t\'a gelé.' or 'Tu peux bouger.', 'info')
end

---@param coords vector3
function Admin.teleport(coords)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    local timeout = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end
end
