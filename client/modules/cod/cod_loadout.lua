---Écran de choix de classe à l'arrivée dans une partie du mode Call of Duty, après l'écran de chargement : vue aérienne
---de la carte, le personnage attend caché. Le serveur le place au déploiement (CodMatch:deploy), comme à une réapparition.
---@class CodLoadoutModule
local CodLoadout = PVP.define('CodLoadout')
local Cod = PVP.use('Cod')
local CodEffects = PVP.use('CodEffects')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Spawn = PVP.use('Spawn')
local Events = PVP.use('Events')

CodLoadout.FADE = 300
CodLoadout.PORTRAIT_TIMEOUT = 1500 -- ms d'attente du portrait du personnage

---@type table|nil personnage en attente de déploiement : deadline, cam, headshot, portrait, hidden, screen, deploying
CodLoadout.session = nil

function CodLoadout.init()
    RegisterNUICallback('codDeploy', function(_, cb)
        cb({})
        CodLoadout.deploy()
    end)
end

---@return boolean
function CodLoadout.isActive()
    return CodLoadout.session ~= nil
end

---Sous l'écran de chargement : le personnage rejoint la carte et se cache.
---@param data table données d'arrivée dans la partie (voir Cod.start)
function CodLoadout.prepare(data)
    Spawn.spawnAt(data.spawn, data.appearance)
    if not Cod.match then return end
    local session = {}
    CodLoadout.session = session
    -- Ni la mort, ni le HUD, ni les zones ne concernent le personnage tant qu'il n'est pas déployé
    State.spawned = false
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    CreateThread(function() CodLoadout.hidePed(session, ped) end)
end

---Le portrait est pris sur le personnage visible : il n'est caché qu'ensuite, aux yeux des autres joueurs aussi.
---@param session table
---@param ped integer
function CodLoadout.hidePed(session, ped)
    session.headshot = RegisterPedheadshotTransparent(ped)
    local timeout = GetGameTimer() + CodLoadout.PORTRAIT_TIMEOUT
    while CodLoadout.session == session and not IsPedheadshotReady(session.headshot) and GetGameTimer() < timeout do Wait(0) end
    if CodLoadout.session ~= session then return end
    if IsPedheadshotReady(session.headshot) and IsPedheadshotValid(session.headshot) then
        session.portrait = GetPedheadshotTxdString(session.headshot)
    end
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    session.hidden = true
end

---Après l'écran de chargement : vue aérienne et choix de la classe, jusqu'au déploiement.
---@param data table
function CodLoadout.open(data)
    local session = CodLoadout.session
    if not session then return end
    while CodLoadout.session == session and not session.hidden do Wait(0) end
    if CodLoadout.session ~= session then return end

    session.deadline = GetGameTimer() + Config.Cod.loadoutTime * 1000
    session.screen = true
    CodLoadout.startCamera(session, data.arena, data.spawn.w)
    DisplayRadar(false)
    SetNuiFocus(true, true)
    Nui.send('codLoadout', { open = true, seconds = Config.Cod.loadoutTime, profile = Cod.profile, portrait = session.portrait })
    CreateThread(function()
        while CodLoadout.session == session and GetGameTimer() < session.deadline do Wait(100) end
        if CodLoadout.session == session then CodLoadout.deploy() end
    end)
end

---@param session table
---@param arena { center: vector3, radius: number }
---@param heading number
function CodLoadout.startCamera(session, arena, heading)
    local camera = Config.Cod.loadoutCamera
    session.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(session.cam, arena.center.x, arena.center.y, arena.center.z + arena.radius * camera.height)
    SetCamRot(session.cam, -90.0, 0.0, heading, 2)
    SetCamFov(session.cam, camera.fov)
    SetCamActive(session.cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

---@param session table
function CodLoadout.closeScreen(session)
    if not session.screen then return end
    session.screen = false
    SetNuiFocus(false, false)
    Nui.send('codLoadout', { open = false })
end

---Fin de l'attente sans déploiement (partie finie, manche suivante, retour au menu).
function CodLoadout.close()
    local session = CodLoadout.session
    if not session then return end
    CodLoadout.session = nil
    CodLoadout.closeScreen(session)
    if session.cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(session.cam, false)
        DisplayRadar(not CodEffects.jammed)
    end
    if session.headshot then UnregisterPedheadshot(session.headshot) end
end

---Demande sa place au serveur, avec la classe choisie. L'écran reste noir jusqu'au placement (Spawn.spawnAt).
function CodLoadout.deploy()
    local session = CodLoadout.session
    if not session or not session.screen or session.deploying then return end
    session.deploying = true
    CodLoadout.closeScreen(session)
    DoScreenFadeOut(CodLoadout.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    if CodLoadout.session ~= session then return end
    CodLoadout.close()
    TriggerServerEvent(Events.server.codDeploy)
end
