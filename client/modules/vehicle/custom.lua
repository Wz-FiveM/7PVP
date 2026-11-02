---Custom des véhicules (Config.VehicleCustom) : repère devant chaque mécanicien, menu d'essai sur le
---véhicule immobilisé, et application de la custom enregistrée à chaque sortie du modèle (Vehicles.spawn).
---Annuler remet le véhicule comme il était. Voir server/modules/vehicle/vehicle_custom_service.lua.
---@class VehicleCustomModule
local VehicleCustom = PVP.define('VehicleCustom')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Vehicles = PVP.use('Vehicles')
local HelpNotify = PVP.use('HelpNotify')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

VehicleCustom.CONTROL_OPEN = 38 -- E
VehicleCustom.CONTROL_HORN = 86 -- le klaxon est aussi sur E
VehicleCustom.CHECK_INTERVAL = 500
VehicleCustom.WATCH_INTERVAL = 250
VehicleCustom.MOD_TURBO = 18
VehicleCustom.MOD_XENON = 22
VehicleCustom.MOD_FRONT_WHEELS = 23
VehicleCustom.NEON_SIDES = 4
VehicleCustom.MARKER_COLOR = { 255, 107, 26 }

---@type integer|nil véhicule en cours de custom
VehicleCustom.vehicle = nil
---@type table|nil custom du véhicule avant d'ouvrir le menu (rétablie si on annule)
VehicleCustom.original = nil
---@type table|nil custom à l'essai
VehicleCustom.props = nil
VehicleCustom.opening = false
-- Au volant sur un repère : l'aide « Customiser » remplace l'aide « Ranger » (voir Vehicles.helpLoop)
VehicleCustom.atSpot = false
VehicleCustom.cam = nil
VehicleCustom.camAngle = 0.0
VehicleCustom.camDistance = 0.0
VehicleCustom.camHeight = 0.0

function VehicleCustom.init()
    RegisterNUICallback('vehicleCustomPreview', function(data, cb)
        cb(VehicleCustom.preview(data))
    end)
    RegisterNUICallback('vehicleCustomRotate', function(data, cb)
        VehicleCustom.rotate(tonumber(data.delta) or 0)
        cb({})
    end)
    RegisterNUICallback('vehicleCustomSave', function(_, cb)
        cb(VehicleCustom.save())
    end)
    RegisterNUICallback('vehicleCustomCancel', function(_, cb)
        VehicleCustom.cancel()
        cb({})
    end)
    CreateThread(VehicleCustom.loop)
end

-- ---------------------------------------------------------------------------
-- Repères
-- ---------------------------------------------------------------------------

---@param npc table entrée de Config.SafeNpcs.npcs
---@return vector3 centre du repère, devant le mécanicien (déplacé avec lui depuis le panneau admin)
function VehicleCustom.spotOf(npc)
    local heading = math.rad(npc.coords.w)
    local offset = Config.VehicleCustom.spotOffset
    return vector3(npc.coords.x - math.sin(heading) * offset, npc.coords.y + math.cos(heading) * offset, npc.coords.z)
end

function VehicleCustom.loop()
    while true do
        local needsFrame = false
        VehicleCustom.atSpot = false
        if State.inPvp() and not VehicleCustom.vehicle then
            local pos = GetEntityCoords(PlayerPedId())
            for _, npc in ipairs(Config.SafeNpcs.npcs) do
                if npc.role == Config.VehicleCustom.role and VehicleCustom.updateSpot(npc, pos) then
                    needsFrame = true
                end
            end
        end
        Wait(needsFrame and 0 or VehicleCustom.CHECK_INTERVAL)
    end
end

---@param npc table
---@param pos vector3 position du joueur
---@return boolean true si le repère est assez proche pour être dessiné à chaque image
function VehicleCustom.updateSpot(npc, pos)
    local spot = VehicleCustom.spotOf(npc)
    local dist = #(pos.xy - spot.xy)
    if dist > Config.VehicleCustom.markerDistance then return false end

    VehicleCustom.drawMarker(spot)
    if dist <= Config.VehicleCustom.spotRadius and VehicleCustom.parkedVehicle() then
        VehicleCustom.atSpot = true
        DisableControlAction(0, VehicleCustom.CONTROL_HORN, true)
        HelpNotify.show(HelpNotify.controlKey(VehicleCustom.CONTROL_OPEN), Locale.t('Customiser le véhicule'))
        if IsControlJustReleased(0, VehicleCustom.CONTROL_OPEN) then CreateThread(VehicleCustom.open) end
    end
    return true
end

---@param spot vector3
function VehicleCustom.drawMarker(spot)
    local found, ground = GetGroundZFor_3dCoord(spot.x, spot.y, spot.z + 2.0, false)
    local z = found and ground or spot.z - 1.0
    local size = Config.VehicleCustom.spotRadius * 2.0
    local color = VehicleCustom.MARKER_COLOR
    DrawMarker(1, spot.x, spot.y, z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, 0.5, color[1], color[2], color[3], 70, false, false, 2, false, nil, nil, false)
    DrawMarker(36, spot.x, spot.y, z + 2.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.4, 1.4, 1.4, color[1], color[2], color[3], 180, true, true, 2, false, nil, nil, false)
end

---@return integer|nil véhicule sorti d'un objet, à l'arrêt, dont le joueur est au volant, si rien d'autre n'est ouvert
function VehicleCustom.parkedVehicle()
    if not State.isAlive() or IsNuiFocused() or State.menuOpen then return nil end
    local vehicle = Vehicles.storable()
    if not vehicle or GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then return nil end
    if GetEntitySpeed(vehicle) * 3.6 >= Config.VehicleCustom.maxSpeed then return nil end
    return vehicle
end

---E à côté du mécanicien, sans être sur le repère (voir Npcs.interact).
function VehicleCustom.talk()
    if VehicleCustom.atSpot then return end
    Nui.notify(Locale.t('Gare sur le repère au sol, au volant du véhicule que tu as sorti de ton inventaire.'))
end

-- ---------------------------------------------------------------------------
-- Lecture et application d'une custom
-- ---------------------------------------------------------------------------

---@param hex string #RRGGBB
---@return integer, integer, integer
function VehicleCustom.hexToRgb(hex)
    return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

---@param vehicle integer
---@return table custom actuelle du véhicule
function VehicleCustom.read(vehicle)
    local primary, secondary = GetVehicleColours(vehicle)
    local pearl, wheelColor = GetVehicleExtraColours(vehicle)
    local red, green, blue = GetVehicleNeonLightsColour(vehicle)
    local props = {
        primary = primary,
        secondary = secondary,
        pearl = pearl,
        wheelColor = wheelColor,
        tint = GetVehicleWindowTint(vehicle),
        plate = GetVehicleNumberPlateTextIndex(vehicle),
        wheelType = GetVehicleWheelType(vehicle),
        neon = IsVehicleNeonLightEnabled(vehicle, 0) and true or false,
        neonColor = ('#%02x%02x%02x'):format(red, green, blue),
        xenon = IsToggleModOn(vehicle, VehicleCustom.MOD_XENON) and true or false,
        xenonColor = GetVehicleXenonLightsColor(vehicle),
        turbo = IsToggleModOn(vehicle, VehicleCustom.MOD_TURBO) and true or false,
        mods = {},
    }
    if GetVehicleLiveryCount(vehicle) > 0 then props.livery = GetVehicleLivery(vehicle) end
    for _, mod in ipairs(Config.VehicleCustom.mods) do
        if GetNumVehicleMods(vehicle, mod.id) > 0 then
            props.mods[tostring(mod.id)] = GetVehicleMod(vehicle, mod.id)
        end
    end
    return props
end

---Applique une custom, à l'essai ou à la sortie du véhicule. Les champs absents ne changent pas ;
---une pièce déjà en place n'est pas remise (le véhicule ne clignote pas à chaque clic).
---@param vehicle integer
---@param props table
function VehicleCustom.apply(vehicle, props)
    SetVehicleModKit(vehicle, 0)
    -- Le type de jantes d'abord : il change la liste des jantes
    if props.wheelType and props.wheelType >= 0 then SetVehicleWheelType(vehicle, math.floor(props.wheelType)) end

    if type(props.mods) == 'table' then
        for id, index in pairs(props.mods) do
            local modType, value = math.floor(tonumber(id)), math.floor(index)
            if value < GetNumVehicleMods(vehicle, modType) and value ~= GetVehicleMod(vehicle, modType) then
                SetVehicleMod(vehicle, modType, value, false)
            end
        end
    end

    local primary, secondary = GetVehicleColours(vehicle)
    SetVehicleColours(vehicle, math.floor(props.primary or primary), math.floor(props.secondary or secondary))
    local pearl, wheelColor = GetVehicleExtraColours(vehicle)
    SetVehicleExtraColours(vehicle, math.floor(props.pearl or pearl), math.floor(props.wheelColor or wheelColor))

    if props.tint then SetVehicleWindowTint(vehicle, math.floor(props.tint)) end
    if props.plate then SetVehicleNumberPlateTextIndex(vehicle, math.floor(props.plate)) end
    if props.livery and GetVehicleLiveryCount(vehicle) > 0 then SetVehicleLivery(vehicle, math.floor(props.livery)) end

    for side = 0, VehicleCustom.NEON_SIDES - 1 do
        SetVehicleNeonLightEnabled(vehicle, side, props.neon == true)
    end
    if props.neonColor then SetVehicleNeonLightsColour(vehicle, VehicleCustom.hexToRgb(props.neonColor)) end

    ToggleVehicleMod(vehicle, VehicleCustom.MOD_XENON, props.xenon == true)
    if props.xenonColor then SetVehicleXenonLightsColor(vehicle, math.floor(props.xenonColor)) end
    ToggleVehicleMod(vehicle, VehicleCustom.MOD_TURBO, props.turbo == true)
end

---Ce que le modèle permet, pour le menu. Les noms des pièces viennent de GTA, dans la langue du jeu.
---@param vehicle integer
---@return table
function VehicleCustom.describe(vehicle)
    local model = GetEntityModel(vehicle)
    local mods = {}
    for _, mod in ipairs(Config.VehicleCustom.mods) do
        local count = GetNumVehicleMods(vehicle, mod.id)
        if count > 0 and (mod.tab ~= 'performance' or Config.VehicleCustom.performance) then
            -- Le premier choix est la pièce d'origine (index -1 de GTA)
            local options = { Locale.t('D\'origine') }
            for index = 0, count - 1 do
                local text = GetModTextLabel(vehicle, mod.id, index)
                local name = text and GetLabelText(text)
                options[#options + 1] = (name and name ~= 'NULL') and name or Locale.t('Option %d', index + 1)
            end
            mods[#mods + 1] = { id = tostring(mod.id), label = mod.label, tab = mod.tab, options = options }
        end
    end
    return {
        mods = mods,
        isCar = IsThisModelACar(model) and true or false,
        liveries = GetVehicleLiveryCount(vehicle),
        performance = Config.VehicleCustom.performance,
    }
end

-- ---------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------

function VehicleCustom.open()
    if VehicleCustom.opening or VehicleCustom.vehicle then return end
    VehicleCustom.opening = true
    local result = Callback.await(Events.callbacks.vehicleCustomOpen)
    VehicleCustom.opening = false
    if not result or not result.ok then
        if result and result.message then Nui.notify(result.message, 'error') end
        return
    end
    -- Il a pu repartir, ou ouvrir autre chose, pendant la requête
    local vehicle = VehicleCustom.parkedVehicle()
    if not vehicle then return end

    VehicleCustom.vehicle = vehicle
    SetVehicleModKit(vehicle, 0)
    VehicleCustom.original = VehicleCustom.read(vehicle)
    VehicleCustom.props = VehicleCustom.original
    FreezeEntityPosition(vehicle, true)
    VehicleCustom.startCamera(vehicle)
    DisplayRadar(false)
    SetNuiFocus(true, true)
    Nui.send('vehicleCustom', {
        open = true,
        label = result.label,
        props = VehicleCustom.original,
        options = VehicleCustom.describe(vehicle),
        palettes = {
            colors = Config.VehicleCustom.colors,
            neonColors = Config.VehicleCustom.neonColors,
            xenonColors = Config.VehicleCustom.xenonColors,
            tints = Config.VehicleCustom.tints,
            plates = Config.VehicleCustom.plates,
            wheelTypes = Config.VehicleCustom.wheelTypes,
        },
    })
    CreateThread(VehicleCustom.watch)
end

---Mort, éjecté, véhicule disparu, changement de mode : le menu se referme sans enregistrer.
function VehicleCustom.watch()
    local vehicle = VehicleCustom.vehicle
    while VehicleCustom.vehicle == vehicle do
        if not DoesEntityExist(vehicle) or not State.inPvp() or not State.isAlive()
            or GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then
            return VehicleCustom.cancel()
        end
        Wait(VehicleCustom.WATCH_INTERVAL)
    end
end

---@param data any custom à l'essai
---@return table options du modèle si le type de jantes a changé (la liste des jantes n'est plus la même)
function VehicleCustom.preview(data)
    local vehicle = VehicleCustom.vehicle
    if not vehicle or not DoesEntityExist(vehicle) or type(data) ~= 'table' then return {} end
    local wheelsChanged = data.wheelType ~= VehicleCustom.props.wheelType
    VehicleCustom.props = data
    VehicleCustom.apply(vehicle, data)
    return wheelsChanged and { options = VehicleCustom.describe(vehicle) } or {}
end

---@return { ok: boolean, message?: string }
function VehicleCustom.save()
    if not VehicleCustom.vehicle then return { ok = false } end
    local result = Callback.await(Events.callbacks.vehicleCustomSave, VehicleCustom.props)
    if not result or not result.ok then
        return result or { ok = false, message = Locale.t('Le serveur ne répond pas.') }
    end
    VehicleCustom.close()
    Nui.notify(result.message, 'success')
    return { ok = true }
end

function VehicleCustom.cancel()
    local vehicle = VehicleCustom.vehicle
    if not vehicle then return end
    if DoesEntityExist(vehicle) then VehicleCustom.apply(vehicle, VehicleCustom.original) end
    VehicleCustom.close()
end

function VehicleCustom.close()
    local vehicle = VehicleCustom.vehicle
    VehicleCustom.vehicle = nil
    VehicleCustom.original = nil
    VehicleCustom.props = nil
    if vehicle and DoesEntityExist(vehicle) then FreezeEntityPosition(vehicle, false) end
    if VehicleCustom.cam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(VehicleCustom.cam, false)
        VehicleCustom.cam = nil
    end
    DisplayRadar(true)
    SetNuiFocus(false, false)
    Nui.send('vehicleCustom', { open = false })
end

-- ---------------------------------------------------------------------------
-- Caméra : tourne autour du véhicule immobilisé
-- ---------------------------------------------------------------------------

---@param vehicle integer
function VehicleCustom.startCamera(vehicle)
    local min, max = GetModelDimensions(GetEntityModel(vehicle))
    local size = max - min
    VehicleCustom.camDistance = math.max(size.x, size.y) * 0.7 + 2.5
    VehicleCustom.camHeight = size.z * 0.5 + 0.5
    VehicleCustom.camAngle = GetEntityHeading(vehicle) + 50.0
    VehicleCustom.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(VehicleCustom.cam, 50.0)
    VehicleCustom.placeCamera()
    RenderScriptCams(true, true, 500, true, true)
end

function VehicleCustom.placeCamera()
    local center = GetEntityCoords(VehicleCustom.vehicle)
    local angle = math.rad(VehicleCustom.camAngle)
    SetCamCoord(
        VehicleCustom.cam,
        center.x + math.cos(angle) * VehicleCustom.camDistance,
        center.y + math.sin(angle) * VehicleCustom.camDistance,
        center.z + VehicleCustom.camHeight
    )
    PointCamAtCoord(VehicleCustom.cam, center.x, center.y, center.z)
end

---@param delta number degrés
function VehicleCustom.rotate(delta)
    if not VehicleCustom.cam or not VehicleCustom.vehicle then return end
    VehicleCustom.camAngle = VehicleCustom.camAngle + delta
    VehicleCustom.placeCamera()
end
