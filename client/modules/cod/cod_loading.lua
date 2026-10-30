---Écran de chargement à l'arrivée dans une partie du mode Call of Duty : la carte vue en jeu, de haut et du côté
---du joueur, sous le titre, une astuce et le pourcentage (NUI). Le personnage rejoint son point de départ en dessous.
---@class CodLoadingModule
local CodLoading = PVP.define('CodLoading')
local Nui = PVP.use('Nui')

CodLoading.FADE = 300
CodLoading.PROGRESS_INTERVAL = 100 -- ms entre deux envois du pourcentage

---@type table|nil écran affiché : cam, from, push, startedAt, duration
CodLoading.session = nil

---@return boolean
function CodLoading.isActive()
    return CodLoading.session ~= nil
end

---@param data table données d'arrivée dans la partie (voir Cod.start)
function CodLoading.start(data)
    CodLoading.stop()
    local view = Config.Cod.loadingView
    local center, radius = data.arena.center, data.arena.radius
    local heading = math.rad(data.spawn.w)
    local from = vector3(
        center.x + math.sin(heading) * radius * view.distance,
        center.y - math.cos(heading) * radius * view.distance,
        center.z + radius * view.height
    )
    local tips = Config.Cod.loadingTips

    local session = {
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true),
        from = from,
        push = (center - from) * view.push,
        startedAt = GetGameTimer(),
        duration = Config.Cod.loadTime * 1000,
    }
    CodLoading.session = session
    SetCamCoord(session.cam, from.x, from.y, from.z)
    PointCamAtCoord(session.cam, center.x, center.y, center.z)
    SetCamFov(session.cam, view.fov)
    SetCamActive(session.cam, true)
    RenderScriptCams(true, false, 0, true, true)
    -- Le décor se charge autour de la carte regardée
    SetFocusPosAndVel(center.x, center.y, center.z, 0.0, 0.0, 0.0)

    Nui.send('codLoading', {
        open = true,
        map = data.map,
        playlist = data.playlist.label,
        tip = tips[math.random(#tips)],
    })
    CreateThread(function() CodLoading.loop(session) end)
end

---La caméra avance doucement vers la carte pendant que le pourcentage monte.
---@param session table
function CodLoading.loop(session)
    local nextProgress = 0
    while CodLoading.session == session do
        local now = GetGameTimer()
        local elapsed = math.min((now - session.startedAt) / session.duration, 1.0)
        local coords = session.from + session.push * elapsed
        SetCamCoord(session.cam, coords.x, coords.y, coords.z)
        HideHudAndRadarThisFrame()
        if now >= nextProgress then
            nextProgress = now + CodLoading.PROGRESS_INTERVAL
            Nui.send('codLoadingProgress', { progress = math.floor(elapsed * 100) })
        end
        Wait(0)
    end
end

---Attend la fin du temps de chargement, puis rend la main à la suite de l'arrivée.
function CodLoading.finish()
    local session = CodLoading.session
    if not session then return end
    while CodLoading.session == session and GetGameTimer() - session.startedAt < session.duration do Wait(0) end
    if CodLoading.session ~= session then return end

    DoScreenFadeOut(CodLoading.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    CodLoading.stop()
    DoScreenFadeIn(CodLoading.FADE)
end

---Fin immédiate, quelle qu'en soit la raison (partie quittée ou terminée pendant le chargement).
function CodLoading.stop()
    local session = CodLoading.session
    if not session then return end
    CodLoading.session = nil

    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(session.cam, false)
    ClearFocus()
    Nui.send('codLoading', { open = false })
end
