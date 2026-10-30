---Lobby : écran de choix du mode (PvP, Freeroam...) à l'arrivée, et retour au lobby.
---Le joueur y est caché, figé et seul dans son bucket ; une caméra fixe montre la ville.
---@class LobbyModule
local Lobby = PVP.define('Lobby')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Appearance = PVP.use('Appearance')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Lobby.active = false
Lobby.modes = nil
Lobby.cam = nil

function Lobby.init()
    RegisterNetEvent(Events.client.openLobby, function(modes)
        Lobby.open(modes)
    end)

    RegisterNUICallback('lobbyJoin', function(data, cb)
        cb(Lobby.join(data.mode))
    end)
    RegisterNUICallback('lobbyLeave', function(_, cb)
        cb(Lobby.requestLeave())
    end)

    RegisterCommand('lobby', function()
        CreateThread(function()
            local result = Lobby.requestLeave()
            if result.message and not result.ok then Nui.notify(result.message, 'error') end
        end)
    end, false)
end

---@param modes table[] description des modes envoyée par le serveur
function Lobby.open(modes)
    if State.menuOpen then Nui.setMenu(false) end

    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end

    -- Les systèmes du PvP se mettent en pause (mort, munitions, zones, raccourcis...)
    State.mode = nil
    State.spawned = false
    Nui.send('mode', { mode = false })

    Lobby.hidePlayer()
    Lobby.startCamera()

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DisplayRadar(false)

    Lobby.active = true
    Lobby.modes = modes
    SetNuiFocus(true, true)
    Nui.send('lobby', { open = true, modes = modes })
    DoScreenFadeIn(500)
end

---Ped caché et figé près de la caméra (pour que la ville se charge autour).
function Lobby.hidePlayer()
    local spot = Config.Lobby.Camera.coords
    if State.appearance then
        Appearance.applyToPlayer(State.appearance)
    end

    NetworkResurrectLocalPlayer(spot.x, spot.y, spot.z, 0.0, true, false)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, spot.x, spot.y, spot.z, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    SetEntityInvincible(ped, true)
    RemoveAllPedWeapons(ped, true)
end

function Lobby.startCamera()
    local camera = Config.Lobby.Camera
    if not Lobby.cam then
        Lobby.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    end
    SetCamCoord(Lobby.cam, camera.coords.x, camera.coords.y, camera.coords.z)
    PointCamAtCoord(Lobby.cam, camera.pointAt.x, camera.pointAt.y, camera.pointAt.z)
    SetCamFov(Lobby.cam, camera.fov)
    SetCamActive(Lobby.cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

---Ferme l'écran. Le placement du joueur est fait par le mode (ex : spawn du PvP).
function Lobby.close()
    Lobby.active = false

    if Lobby.cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(Lobby.cam, false)
        Lobby.cam = nil
    end

    SetNuiFocus(false, false)
    Nui.send('lobby', { open = false })
    DisplayRadar(true)
end

---@param modeId string
---@return { ok: boolean, message?: string }
function Lobby.join(modeId)
    if not Lobby.active then return { ok = false } end

    local result = Callback.await(Events.callbacks.joinMode, modeId)
    if not result or not result.ok then
        return result or { ok = false, message = Locale.t('Le serveur ne répond pas.') }
    end

    State.mode = result.mode
    Nui.send('mode', { mode = result.mode })
    Lobby.close()
    return { ok = true }
end

---Demande au serveur de retourner au lobby (refusé hors zone safe en PvP).
---@return { ok: boolean, message?: string }
function Lobby.requestLeave()
    if Lobby.active then return { ok = false } end
    return Callback.await(Events.callbacks.leaveMode) or { ok = false, message = Locale.t('Le serveur ne répond pas.') }
end
