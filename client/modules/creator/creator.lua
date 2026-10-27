---Créateur de personnage : caméra, ped en direct et pont avec l'interface React.
---  mode 'create' : première connexion, dans une salle isolée (bucket dédié côté serveur)
---  mode 'edit'   : /pvp_apparence en zone safe, sur place
---@class CreatorModule
local Creator = PVP.define('Creator')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Zone = PVP.use('Zone')
local Loadout = PVP.use('Loadout')
local Appearance = PVP.use('Appearance')
local AppearanceSchema = PVP.use('AppearanceSchema')
local Callback = PVP.use('Callback')
local PedUtils = PVP.use('PedUtils')
local Events = PVP.use('Events')

-- Position de la caméra par rapport au ped (repère du ped à son orientation de départ)
Creator.CAMERA_PRESETS = {
    face = { offset = vector3(0.0, 0.75, 0.65), target = vector3(0.0, 0.0, 0.62), fov = 32.0 },
    torso = { offset = vector3(0.0, 1.35, 0.35), target = vector3(0.0, 0.0, 0.25), fov = 40.0 },
    body = { offset = vector3(0.0, 2.7, 0.15), target = vector3(0.0, 0.0, -0.1), fov = 45.0 },
}

Creator.active = false
Creator.mode = nil
Creator.cam = nil
Creator.baseCoords = nil
Creator.baseHeading = 0.0
Creator.current = nil -- apparence affichée
Creator.original = nil -- apparence avant modification (mode edit)

function Creator.init()
    RegisterNetEvent(Events.client.openCreator, function(mode, appearance)
        Creator.open(mode, appearance)
    end)

    RegisterCommand('pvp_apparence', function()
        Creator.requestEdit()
    end, false)

    RegisterNUICallback('creatorApply', function(data, cb)
        cb(Creator.applyLive(data))
    end)
    RegisterNUICallback('creatorCamera', function(data, cb)
        Creator.setCamera(data.preset)
        cb({})
    end)
    RegisterNUICallback('creatorRotate', function(data, cb)
        Creator.rotate(tonumber(data.delta) or 0)
        cb({})
    end)
    RegisterNUICallback('creatorSave', function(_, cb)
        cb(Creator.save())
    end)
    RegisterNUICallback('creatorCancel', function(_, cb)
        Creator.cancel()
        cb({})
    end)
end

-- ---------------------------------------------------------------------------
-- Ouverture / fermeture
-- ---------------------------------------------------------------------------

function Creator.requestEdit()
    if Creator.active then return end
    if not State.isAlive() or not State.isInSafeZone() then
        return Nui.notify('L\'apparence ne se modifie qu\'en zone safe.', 'error')
    end
    if State.menuOpen then Nui.setMenu(false) end
    Creator.open('edit', State.appearance)
end

---@param mode 'create'|'edit'
---@param appearance table|nil
function Creator.open(mode, appearance)
    Creator.mode = mode
    Creator.original = appearance and AppearanceSchema.copy(appearance) or nil
    Creator.current = AppearanceSchema.sanitize(appearance) or AppearanceSchema.default('male')

    if mode == 'create' then
        Creator.prepareRoom()
    end

    Appearance.applyToPlayer(Creator.current)

    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    Creator.baseCoords = GetEntityCoords(ped)
    Creator.baseHeading = GetEntityHeading(ped)

    Creator.active = true
    DisplayRadar(false)
    Creator.setCamera('body')
    SetNuiFocus(true, true)

    Nui.send('creator', {
        open = true,
        mode = mode,
        appearance = Creator.current,
        limits = Appearance.getLimits(ped, Creator.current),
        palettes = Appearance.getPalettes(),
        schema = AppearanceSchema.describe(),
    })

    if mode == 'create' then
        DoScreenFadeIn(500)
    end
end

---Première connexion : place le ped dans la salle de création, sans HUD ni écran de chargement.
function Creator.prepareRoom()
    DoScreenFadeOut(0)
    local spot = Config.Appearance.CreatorLocation

    Appearance.ensureModel(Creator.current.sex)
    RequestCollisionAtCoord(spot.x, spot.y, spot.z)
    NetworkResurrectLocalPlayer(spot.x, spot.y, spot.z, spot.w, true, false)

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, spot.x, spot.y, spot.z, false, false, false)
    SetEntityHeading(ped, spot.w)

    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end
    SetEntityCoordsNoOffset(ped, spot.x, spot.y, PedUtils.findGroundZ(spot.x, spot.y, spot.z), false, false, false)

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end

function Creator.close()
    Creator.active = false

    if Creator.cam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(Creator.cam, false)
        Creator.cam = nil
    end

    SetNuiFocus(false, false)
    Nui.send('creator', { open = false })
    DisplayRadar(true)

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    -- La zone réapplique l'invincibilité si on est en zone safe
    Zone.reset()
end

-- ---------------------------------------------------------------------------
-- Modifications en direct
-- ---------------------------------------------------------------------------

---Appelé par l'interface à chaque changement.
---@param data table
---@return table limites des sélecteurs pour l'apparence affichée
function Creator.applyLive(data)
    if not Creator.active then return {} end

    local appearance = AppearanceSchema.sanitize(data)
    if not appearance then return {} end

    if appearance.sex ~= Creator.current.sex then
        appearance = AppearanceSchema.default(appearance.sex)
    end

    local modelChanged = Appearance.applyToPlayer(appearance)
    Creator.current = appearance

    local ped = PlayerPedId()
    if modelChanged then
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetEntityCoordsNoOffset(ped, Creator.baseCoords.x, Creator.baseCoords.y, Creator.baseCoords.z, false, false, false)
        SetEntityHeading(ped, Creator.baseHeading)
    end

    return {
        limits = Appearance.getLimits(ped, appearance),
        appearance = modelChanged and appearance or nil,
    }
end

---Calcule une position dans le repère du ped à son orientation de départ.
---@param offset vector3
---@return vector3
function Creator.worldOffset(offset)
    local rad = math.rad(Creator.baseHeading)
    local cos, sin = math.cos(rad), math.sin(rad)
    return vector3(
        Creator.baseCoords.x + offset.x * cos - offset.y * sin,
        Creator.baseCoords.y + offset.x * sin + offset.y * cos,
        Creator.baseCoords.z + offset.z
    )
end

---@param preset 'face'|'torso'|'body'
function Creator.setCamera(preset)
    local camera = Creator.CAMERA_PRESETS[preset] or Creator.CAMERA_PRESETS.body
    local position = Creator.worldOffset(camera.offset)
    local target = Creator.worldOffset(camera.target)

    if not Creator.cam then
        Creator.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        RenderScriptCams(true, true, 500, true, true)
    end

    SetCamCoord(Creator.cam, position.x, position.y, position.z)
    PointCamAtCoord(Creator.cam, target.x, target.y, target.z)
    SetCamFov(Creator.cam, camera.fov)
end

---@param delta number degrés
function Creator.rotate(delta)
    local ped = PlayerPedId()
    SetEntityHeading(ped, (GetEntityHeading(ped) + delta) % 360.0)
end

-- ---------------------------------------------------------------------------
-- Validation / annulation
-- ---------------------------------------------------------------------------

---@return { ok: boolean, message?: string }
function Creator.save()
    local result = Callback.await(Events.callbacks.saveAppearance, Creator.current)
    if not result or not result.ok then
        return result or { ok = false, message = 'Le serveur ne répond pas.' }
    end

    State.appearance = Creator.current
    local mode = Creator.mode
    Creator.close()

    -- En création, le serveur nous fait apparaître ; en modification, on récupère nos armes
    if mode == 'edit' then
        Loadout.apply()
        if result.message then Nui.notify(result.message, 'success') end
    end
    return { ok = true }
end

function Creator.cancel()
    if Creator.mode ~= 'edit' or not Creator.original then return end
    Appearance.applyToPlayer(Creator.original)
    Creator.close()
    Loadout.apply()
end
