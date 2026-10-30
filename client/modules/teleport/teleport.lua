---Téléportation entre zones safe (F1, mode PvP) : menu de choix et déplacement du ped.
---Les conditions (combat, délai, attente hors zone safe) sont vérifiées par le serveur.
---@class TeleportModule
local Teleport = PVP.define('Teleport')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Zone = PVP.use('Zone')
local Zones = PVP.use('Zones')
local PedUtils = PVP.use('PedUtils')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Teleport.FADE = 400
Teleport.open = false

function Teleport.init()
    RegisterCommand('pvp_teleport', function()
        Teleport.toggle()
    end, false)
    RegisterKeyMapping('pvp_teleport', Locale.t('Téléportation entre zones safe 7PVP'), 'keyboard', Config.Teleport.key)

    RegisterNUICallback('teleportClose', function(_, cb)
        Teleport.close()
        cb({})
    end)
    RegisterNUICallback('teleportGo', function(data, cb)
        cb(Teleport.request(type(data) == 'table' and data.zone or nil))
    end)

    RegisterNetEvent(Events.client.teleport, function(spawn, label)
        Teleport.arrive(spawn, label)
    end)
    RegisterNetEvent(Events.client.teleportCancel, function()
        Nui.send('teleportChannel', { seconds = false })
    end)
end

function Teleport.toggle()
    if Teleport.open then return Teleport.close() end
    if State.mode ~= 'pvp' or not State.isAlive() or State.menuOpen or IsNuiFocused() then return end
    CreateThread(Teleport.show)
end

function Teleport.show()
    local info = Callback.await(Events.callbacks.teleportInfo)
    -- Un autre menu a pu s'ouvrir pendant la requête
    if not info or Teleport.open or IsNuiFocused() or State.menuOpen then return end

    Teleport.open = true
    SetNuiFocus(true, true)
    Nui.send('teleport', {
        open = true,
        zones = Teleport.buildZones(),
        channel = info.channel,
        pending = info.pending,
        key = Config.Teleport.key,
    })
end

function Teleport.close()
    if not Teleport.open then return end
    Teleport.open = false
    SetNuiFocus(false, false)
    Nui.send('teleport', { open = false })
end

---@return table[] zones safe, la plus proche en premier
function Teleport.buildZones()
    local coords = GetEntityCoords(PlayerPedId())
    local list = {}
    for _, zone in ipairs(Zones.byType('safe')) do
        list[#list + 1] = {
            id = zone.id,
            label = zone.label,
            description = zone.description,
            distance = math.floor(#(coords.xy - zone.coords.xy)),
            current = State.zone == zone,
        }
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

---@param zoneId any
---@return table { ok, message?, channel? }
function Teleport.request(zoneId)
    local result = Callback.await(Events.callbacks.teleport, zoneId) or { ok = false }
    if not result.ok then return result end

    Teleport.close()
    if result.channel and result.channel > 0 then
        Nui.send('teleportChannel', { seconds = result.channel })
    end
    if result.message then Nui.notify(result.message, 'info') end
    return result
end

---@param spawn vector4
---@param label string
function Teleport.arrive(spawn, label)
    Teleport.close()
    Nui.send('teleportChannel', { seconds = false })
    CreateThread(function()
        DoScreenFadeOut(Teleport.FADE)
        while not IsScreenFadedOut() do Wait(0) end

        local ped = PlayerPedId()
        -- Sort du véhicule : seul le joueur est téléporté
        if IsPedInAnyVehicle(ped, false) then ClearPedTasksImmediately(ped) end
        FreezeEntityPosition(ped, true)
        RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
        SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)

        local timeout = GetGameTimer() + 5000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end
        SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, PedUtils.findGroundZ(spawn.x, spawn.y, spawn.z), false, false, false)
        SetEntityHeading(ped, spawn.w)
        FreezeEntityPosition(ped, State.noclip)

        Zone.update()
        DoScreenFadeIn(Teleport.FADE)
        Nui.notify(Locale.t('Téléporté : %s.', Locale.t(label)), 'success')
    end)
end
