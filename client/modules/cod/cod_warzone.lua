---Warzone côté client (server/modules/cod/cod_warzone.lua) : avion et parachute, mur et repères de la zone, caisses de
---butin, stations d'achat, véhicules, plaques d'armure, goulag. Le serveur décide de tout ce qui compte : ici, on affiche
---et on demande. Le butin et les véhicules sont calés sur la route la plus proche, que seul le client connaît.
---@class CodWarzoneClientModule
local CodWarzone = PVP.define('CodWarzone')
local Cod = PVP.use('Cod')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local PedUtils = PVP.use('PedUtils')
local HelpNotify = PVP.use('HelpNotify')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CodWarzone.CONTROL_ACTION = 38 -- INPUT_PICKUP (E)
CodWarzone.SCAN_INTERVAL = 300 -- ms entre deux relevés de ce qui est proche
CodWarzone.NODE_RANGE = 70.0 -- m : au-delà, la route la plus proche n'est plus celle de ce point
CodWarzone.TAKE_COOLDOWN = 500
CodWarzone.PARACHUTE_FREEFALL = 0 -- GetPedParachuteState : en chute, parachute fermé
CodWarzone.WALL_COLOR = { 255, 130, 30, 40 }
CodWarzone.WALL_HEIGHT = 500.0
CodWarzone.PLANE_CAM_BACK = 55.0
CodWarzone.PLANE_CAM_UP = 18.0
CodWarzone.PARACHUTE = GetHashKey('GADGET_PARACHUTE')
CodWarzone.STATION_BLIP = 431
CodWarzone.LOOT_NAMES = { cash = 'Argent', plates = 'Plaques d\'armure', ammo = 'Munitions' }

CodWarzone.loot = {}
CodWarzone.stations = {}
CodWarzone.vehicles = {}
CodWarzone.visible = {} -- caisses et stations à portée d'affichage
CodWarzone.inGulag = false
CodWarzone.falling = false
CodWarzone.nextScan = 0
CodWarzone.nextTake = 0
CodWarzone.shopStation = nil
---@type table|nil avion en cours : plane, startAt, ready, vehicle, cam
CodWarzone.planeSession = nil
CodWarzone.nextBlip = nil
CodWarzone.lastRadius = nil

function CodWarzone.init()
    RegisterNetEvent(Events.client.codWzWorld, function(data)
        CodWarzone.setWorld(data)
    end)
    RegisterNetEvent(Events.client.codWz, function(data)
        local handler = CodWarzone.HANDLERS[data.type]
        if handler then handler(data) end
    end)
    RegisterCommand('pvp_cod_plate', function()
        if Cod.isActive() and Cod.match.warzone and State.isAlive() and not IsNuiFocused() then
            TriggerServerEvent(Events.server.codWzPlate)
        end
    end, false)
    RegisterKeyMapping('pvp_cod_plate', Locale.t('Warzone : poser une plaque d\'armure'), 'keyboard', Config.CodWarzone.plateKey)
    RegisterNUICallback('codWzBuy', function(data, cb)
        cb(Callback.await(Events.callbacks.codWzBuy, CodWarzone.shopStation, data.id) or { ok = false })
    end)
    RegisterNUICallback('codWzShopClose', function(_, cb)
        CodWarzone.closeShop()
        cb({})
    end)
end

-- Événements du serveur : type -> fonction
CodWarzone.HANDLERS = {
    state = function(data) Nui.send('codWz', data) end,
    lootAdd = function(data) CodWarzone.loot[data.loot.id] = data.loot end,
    lootGone = function(data) CodWarzone.removeLoot(data.id) end,
    plate = function(data)
        local ped = PlayerPedId()
        SetPedArmour(ped, math.min(100, GetPedArmour(ped) + data.armor))
        Cod.lastArmor = GetPedArmour(ped)
        PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end,
    gulagLost = function() SetEntityHealth(PlayerPedId(), 0) end,
    vehicleClaimed = function(data)
        local vehicle = CodWarzone.vehicles[data.id]
        if vehicle then vehicle.claimed = true end
    end,
    vehicleSpawn = function(data) CreateThread(function() CodWarzone.spawnVehicle(data) end) end,
}

---@param data { loot: table[], stations: table[], vehicles: table[] }
function CodWarzone.setWorld(data)
    CodWarzone.clearWorld()
    for _, entry in ipairs(data.loot) do CodWarzone.loot[entry.id] = entry end
    for _, entry in ipairs(data.vehicles) do CodWarzone.vehicles[entry.id] = entry end
    for _, entry in ipairs(data.stations) do
        CodWarzone.stations[entry.id] = entry
        entry.blip = AddBlipForCoord(entry.x, entry.y, 0.0)
        SetBlipSprite(entry.blip, CodWarzone.STATION_BLIP)
        SetBlipScale(entry.blip, 0.7)
        SetBlipAsShortRange(entry.blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Locale.t('Station d\'achat'))
        EndTextCommandSetBlipName(entry.blip)
    end
end

-- ---------------------------------------------------------------------------
-- Apparitions
-- ---------------------------------------------------------------------------

---Après le placement du personnage (Cod.respawn).
---@param data { plane: table|nil, air: number|nil, gulag: boolean|nil }
function CodWarzone.onSpawn(data)
    CodWarzone.inGulag = data.gulag == true
    if data.plane then
        CreateThread(function() CodWarzone.boardPlane(data.plane) end)
    elseif data.air then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        GiveWeaponToPed(ped, CodWarzone.PARACHUTE, 1, false, false)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z + data.air, false, false, false)
        CodWarzone.falling = true
    end
end

---Le personnage reste caché dans l'avion jusqu'au saut. Il suit l'avion pour que le décor se charge sous lui.
---@param plane table
function CodWarzone.boardPlane(plane)
    local ped = PlayerPedId()
    local session = { plane = plane, startAt = math.max(Cod.lockedUntil, GetGameTimer()) }
    CodWarzone.planeSession = session
    Cod.protectedUntil = GetGameTimer() + 600000
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)

    local model = GetHashKey(plane.model)
    if PedUtils.loadModel(model) and CodWarzone.planeSession == session then
        session.vehicle = CreateVehicle(model, plane.fromX, plane.fromY, plane.height, 0.0, false, false)
        SetEntityCollision(session.vehicle, false, false)
        FreezeEntityPosition(session.vehicle, true)
        SetVehicleEngineOn(session.vehicle, true, true, false)
        SetModelAsNoLongerNeeded(model)
    end
    session.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(session.cam, 55.0)
    SetCamActive(session.cam, true)
    RenderScriptCams(true, false, 0, true, true)
    session.ready = true
    Nui.send('codWzPlane', { open = true })
end

---@param session table
---@param now integer
function CodWarzone.updatePlane(session, now)
    for _, control in ipairs(Cod.LOCKED_CONTROLS) do DisableControlAction(0, control, true) end
    if not session.ready then return end
    local plane = session.plane
    local travelled = math.min(plane.length, math.max(0, now - session.startAt) / 1000 * plane.speed)
    local x, y = plane.fromX + plane.dirX * travelled, plane.fromY + plane.dirY * travelled
    session.x, session.y = x, y
    SetEntityCoordsNoOffset(PlayerPedId(), x, y, plane.height - 4.0, false, false, false)
    if session.vehicle then
        SetEntityCoordsNoOffset(session.vehicle, x, y, plane.height, false, false, false)
        SetEntityHeading(session.vehicle, GetHeadingFromVector_2d(plane.dirX, plane.dirY))
    end
    SetCamCoord(session.cam, x - plane.dirX * CodWarzone.PLANE_CAM_BACK, y - plane.dirY * CodWarzone.PLANE_CAM_BACK, plane.height + CodWarzone.PLANE_CAM_UP)
    PointCamAtCoord(session.cam, x, y, plane.height)
    if now >= session.startAt and (IsControlJustPressed(0, CodWarzone.CONTROL_ACTION) or travelled >= plane.length) then
        CodWarzone.jump(session)
    end
end

---@param session table
function CodWarzone.jump(session)
    CodWarzone.closePlane(session)
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    GiveWeaponToPed(ped, CodWarzone.PARACHUTE, 1, false, false)
    SetEntityCoordsNoOffset(ped, session.x, session.y, session.plane.height - 8.0, false, false, false)
    CodWarzone.falling = true
    Cod.endProtection()
end

---@param session table
function CodWarzone.closePlane(session)
    if CodWarzone.planeSession == session then CodWarzone.planeSession = nil end
    if session.cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(session.cam, false)
    end
    if session.vehicle and DoesEntityExist(session.vehicle) then DeleteEntity(session.vehicle) end
    Nui.send('codWzPlane', { open = false })
end

---En chute : le parachute s'ouvre seul avant le sol, pour qu'un saut ne tue pas celui qui ne connaît pas la touche.
function CodWarzone.updateFall()
    local ped = PlayerPedId()
    local state = GetPedParachuteState(ped)
    local height = GetEntityHeightAboveGround(ped)
    if state == CodWarzone.PARACHUTE_FREEFALL and height <= Config.CodWarzone.parachuteOpenHeight then
        ForcePedToOpenParachute(ped)
    elseif state == -1 and height < 3.0 then
        CodWarzone.falling = false
    end
end

-- ---------------------------------------------------------------------------
-- Zone
-- ---------------------------------------------------------------------------

---@param state table objective de type 'wz'
function CodWarzone.onState(state)
    local match = Cod.match
    match.arena.center = vector3(state.x, state.y, match.arena.center.z)
    match.arena.radius = state.r
    match.outsideDamage = state.damage
    if CodWarzone.lastRadius ~= state.r then
        CodWarzone.lastRadius = state.r
        Cod.drawArena(match.arena)
    end
    if not CodWarzone.nextBlip or CodWarzone.nextRadius ~= state.nr then
        if CodWarzone.nextBlip and DoesBlipExist(CodWarzone.nextBlip) then RemoveBlip(CodWarzone.nextBlip) end
        CodWarzone.nextRadius = state.nr
        CodWarzone.nextBlip = AddBlipForRadius(state.nx, state.ny, match.arena.center.z, state.nr)
        SetBlipColour(CodWarzone.nextBlip, 0)
        SetBlipAlpha(CodWarzone.nextBlip, 70)
    end
end

---@return boolean le joueur n'est pas concerné par la zone : dans l'avion ou au goulag
function CodWarzone.ignoresArena()
    return CodWarzone.planeSession ~= nil or CodWarzone.inGulag
end

function CodWarzone.drawWall()
    local arena = Cod.match.arena
    local color = CodWarzone.WALL_COLOR
    local z = GetEntityCoords(PlayerPedId()).z - CodWarzone.WALL_HEIGHT / 2
    DrawMarker(1, arena.center.x, arena.center.y, z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        arena.radius * 2, arena.radius * 2, CodWarzone.WALL_HEIGHT, color[1], color[2], color[3], color[4], false, false, 2, false, nil, nil, false)
end

-- ---------------------------------------------------------------------------
-- Butin, stations, véhicules
-- ---------------------------------------------------------------------------

---Cale un point sur la route la plus proche, sinon sur le sol. Le décalage dépend de l'id : même place pour tous.
---@param entry table
---@param playerZ number
---@return boolean position connue
function CodWarzone.resolve(entry, playerZ)
    if entry.z then return true end
    if not entry.exact then
        local found, node = GetClosestVehicleNode(entry.x, entry.y, playerZ, 1, 3.0, 0)
        if found and #(vector2(node.x, node.y) - vector2(entry.x, entry.y)) <= CodWarzone.NODE_RANGE then
            entry.x = node.x + (entry.id * 37) % 9 - 4
            entry.y = node.y + (entry.id * 53) % 9 - 4
            entry.z = node.z
        end
    end
    if not entry.z then
        local found, ground = GetGroundZFor_3dCoord(entry.x, entry.y, playerZ + 150.0, false)
        if found then entry.z = ground end
    end
    return entry.z ~= nil
end

---@param now integer
function CodWarzone.scan(now)
    if now < CodWarzone.nextScan then return end
    CodWarzone.nextScan = now + CodWarzone.SCAN_INTERVAL
    local settings = Config.CodWarzone
    local coords = GetEntityCoords(PlayerPedId())
    local range = settings.loot.showRange
    local visible = {}

    for _, entry in pairs(CodWarzone.loot) do
        local dx, dy = entry.x - coords.x, entry.y - coords.y
        if dx * dx + dy * dy <= range * range and CodWarzone.resolve(entry, coords.z) then
            visible[#visible + 1] = entry
            CodWarzone.showCrate(entry)
        elseif entry.object and dx * dx + dy * dy > range * range then
            CodWarzone.hideCrate(entry)
        end
    end
    for _, entry in pairs(CodWarzone.stations) do
        local dx, dy = entry.x - coords.x, entry.y - coords.y
        if dx * dx + dy * dy <= range * range and CodWarzone.resolve(entry, coords.z) then
            entry.station = true
            visible[#visible + 1] = entry
        end
    end
    CodWarzone.visible = visible

    local claim = settings.vehicles.claimRange
    for _, vehicle in pairs(CodWarzone.vehicles) do
        local dx, dy = vehicle.x - coords.x, vehicle.y - coords.y
        if not vehicle.claimed and dx * dx + dy * dy <= claim * claim then
            vehicle.claimed = true
            TriggerServerEvent(Events.server.codWzVehicleClaim, vehicle.id)
        end
    end
end

---@param entry table
function CodWarzone.showCrate(entry)
    if entry.object or entry.loading then return end
    local model = GetHashKey(Config.CodWarzone.loot.model)
    if not IsModelInCdimage(model) then return end
    entry.loading = true
    CreateThread(function()
        if PedUtils.loadModel(model, 2000) and CodWarzone.loot[entry.id] == entry then
            entry.object = CreateObject(model, entry.x, entry.y, entry.z, false, false, false)
            PlaceObjectOnGroundProperly(entry.object)
            FreezeEntityPosition(entry.object, true)
        end
        entry.loading = false
    end)
end

---@param entry table
function CodWarzone.hideCrate(entry)
    if entry.object and DoesEntityExist(entry.object) then DeleteObject(entry.object) end
    entry.object = nil
end

---@param id integer
function CodWarzone.removeLoot(id)
    local entry = CodWarzone.loot[id]
    if not entry then return end
    CodWarzone.hideCrate(entry)
    CodWarzone.loot[id] = nil
    for index, shown in ipairs(CodWarzone.visible) do
        if shown == entry then table.remove(CodWarzone.visible, index) break end
    end
end

---@param entry table
---@return string nom affiché, traduit
function CodWarzone.lootName(entry)
    if entry.kind == 'weapon' or entry.kind == 'equipment' then
        local weapon = Cod.weapons[entry.item]
        return weapon and Locale.t(weapon.label) or entry.item
    end
    local name = Locale.t(CodWarzone.LOOT_NAMES[entry.kind])
    return entry.amount and ('%s (%d)'):format(name, entry.amount) or name
end

---@param entry table
---@return number, number, number couleur du marqueur
function CodWarzone.lootColor(entry)
    for _, rarity in ipairs(Config.CodWarzone.loot.rarities) do
        if rarity.id == entry.rarity then return rarity.color[1], rarity.color[2], rarity.color[3] end
    end
    if entry.kind == 'cash' then return 95, 209, 110 end
    return 255, 200, 90
end

---@param now integer
function CodWarzone.drawVisible(now)
    local coords = GetEntityCoords(PlayerPedId())
    local nearest, nearestDistance = nil, math.huge
    for _, entry in ipairs(CodWarzone.visible) do
        local r, g, b = 255, 140, 40
        if not entry.station then r, g, b = CodWarzone.lootColor(entry) end
        DrawMarker(entry.station and 1 or 21, entry.x, entry.y, entry.z + (entry.station and -0.5 or 1.0), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            entry.station and 3.0 or 0.5, entry.station and 3.0 or 0.5, entry.station and 1.0 or 0.5, r, g, b, entry.station and 80 or 220,
            not entry.station, false, 2, not entry.station, nil, nil, false)
        local distance = #(coords - vector3(entry.x, entry.y, entry.z))
        local reach = entry.station and Config.CodWarzone.stations.useRange or Config.CodWarzone.loot.pickRange
        if distance <= reach and distance < nearestDistance then nearest, nearestDistance = entry, distance end
    end
    if not nearest or not State.isAlive() or IsNuiFocused() then return end

    local text = nearest.station and Locale.t('Station d\'achat') or Locale.t('Ramasser : %s', CodWarzone.lootName(nearest))
    HelpNotify.show(HelpNotify.controlKey(CodWarzone.CONTROL_ACTION), text)
    if IsControlJustPressed(0, CodWarzone.CONTROL_ACTION) and now >= CodWarzone.nextTake then
        CodWarzone.nextTake = now + CodWarzone.TAKE_COOLDOWN
        if nearest.station then
            CodWarzone.openShop(nearest)
        else
            TriggerServerEvent(Events.server.codWzTake, nearest.id)
        end
    end
end

---@param station table
function CodWarzone.openShop(station)
    CodWarzone.shopStation = station.id
    SetNuiFocus(true, true)
    Nui.send('codWzShop', { open = true, items = Config.CodWarzone.shop })
end

function CodWarzone.closeShop()
    if not CodWarzone.shopStation then return end
    CodWarzone.shopStation = nil
    SetNuiFocus(false, false)
    Nui.send('codWzShop', { open = false })
end

---Le premier joueur à portée crée le véhicule, en réseau : le serveur le retire en fin de partie.
---@param data { id: integer, model: string, x: number, y: number }
function CodWarzone.spawnVehicle(data)
    local model = GetHashKey(data.model)
    if not PedUtils.loadModel(model) then return end
    local z = GetEntityCoords(PlayerPedId()).z
    local found, node, heading = GetClosestVehicleNodeWithHeading(data.x, data.y, z, 1, 3.0, 0)
    local x, y = found and node.x or data.x, found and node.y or data.y
    z = found and node.z or PedUtils.findGroundZ(x, y, z)
    local vehicle = CreateVehicle(model, x, y, z + 0.5, found and heading or 0.0, true, false)
    SetModelAsNoLongerNeeded(model)
    if vehicle == 0 then return end
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehRadioStation(vehicle, 'OFF')
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    TriggerServerEvent(Events.server.codWzVehicleSpawned, netId)
end

-- ---------------------------------------------------------------------------
-- Boucle et fin
-- ---------------------------------------------------------------------------

---À chaque image de la partie (Cod.loop).
---@param now integer
function CodWarzone.frame(now)
    local session = CodWarzone.planeSession
    if session then return CodWarzone.updatePlane(session, now) end
    if CodWarzone.falling then CodWarzone.updateFall() end
    if CodWarzone.shopStation and not State.isAlive() then CodWarzone.closeShop() end
    if CodWarzone.inGulag then return end
    CodWarzone.drawWall()
    CodWarzone.scan(now)
    CodWarzone.drawVisible(now)
end

---Fin de la partie : le personnage redevient normal s'il était encore dans l'avion.
function CodWarzone.stopPlane()
    local session = CodWarzone.planeSession
    CodWarzone.closeShop()
    if not session then return end
    CodWarzone.closePlane(session)
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
end

function CodWarzone.clearWorld()
    for _, entry in pairs(CodWarzone.loot) do CodWarzone.hideCrate(entry) end
    for _, entry in pairs(CodWarzone.stations) do
        if entry.blip and DoesBlipExist(entry.blip) then RemoveBlip(entry.blip) end
    end
    CodWarzone.loot, CodWarzone.stations, CodWarzone.vehicles, CodWarzone.visible = {}, {}, {}, {}
end

---Retour au menu ou au lobby.
function CodWarzone.clear()
    CodWarzone.stopPlane()
    CodWarzone.clearWorld()
    if CodWarzone.nextBlip and DoesBlipExist(CodWarzone.nextBlip) then RemoveBlip(CodWarzone.nextBlip) end
    CodWarzone.nextBlip, CodWarzone.nextRadius, CodWarzone.lastRadius = nil, nil, nil
    CodWarzone.inGulag = false
    CodWarzone.falling = false
    Nui.send('codWz', { type = 'state', cash = 0, plates = 0, state = 'alive' })
end
