---Podium de fin de partie : les meilleurs joueurs sur le toit du menu, avec leur personnage et l'arme de leur classe.
---Ce sont des copies locales, sans entité réseau ; le joueur réel reste où il est. Un joueur que le jeu n'a pas chargé
---(trop loin de la caméra de ce client) n'a pas de personnage mais garde sa carte dans l'interface.
---@class CodPodiumModule
local CodPodium = PVP.define('CodPodium')
local Cod = PVP.use('Cod')
local PedUtils = PVP.use('PedUtils')

CodPodium.FADE = 250
CodPodium.COLLISION_TIMEOUT = 1500
CodPodium.ANIM_TIMEOUT = 1000
CodPodium.ANIM_DICT = 'anim@mp_player_intcelebrationmale@salute'
CodPodium.ANIM_NAME = 'salute'

---@type { peds: integer[], cam: integer|nil }|nil
CodPodium.session = nil

---@param entries table[] du meilleur au moins bon : id, weapon, mods
function CodPodium.start(entries)
    CodPodium.clear()
    local session = { peds = {} }
    CodPodium.session = session
    CreateThread(function()
        local ok, message = pcall(CodPodium.build, session, entries)
        if not ok then print(('[7PVP] Podium : %s'):format(message)) end
        if CodPodium.session == session then DoScreenFadeIn(CodPodium.FADE) end
        while CodPodium.session == session do
            HideHudAndRadarThisFrame()
            Wait(0)
        end
    end)
end

---@param session table
---@param entries table[]
function CodPodium.build(session, entries)
    DoScreenFadeOut(CodPodium.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    if CodPodium.session ~= session then return end

    local scene = Config.Cod.menuScene
    local settings = Config.Cod.podium
    local base = vector3(scene.ped.x, scene.ped.y, scene.ped.z + Cod.PED_HEIGHT)
    local yaw = math.rad(scene.ped.w)
    local forward = vector3(-math.sin(yaw), math.cos(yaw), 0.0)
    local right = vector3(forward.y, -forward.x, 0.0)

    SetFocusPosAndVel(base.x, base.y, base.z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(base.x, base.y, base.z)
    local timeout = GetGameTimer() + CodPodium.COLLISION_TIMEOUT
    while CodPodium.session == session and GetGameTimer() < timeout do Wait(100) end
    if CodPodium.session ~= session then return end

    RequestAnimDict(CodPodium.ANIM_DICT)
    timeout = GetGameTimer() + CodPodium.ANIM_TIMEOUT
    while not HasAnimDictLoaded(CodPodium.ANIM_DICT) and GetGameTimer() < timeout do Wait(0) end
    if CodPodium.session ~= session then return end

    for index, entry in ipairs(entries) do
        local slot = settings.slots[index]
        local player = GetPlayerFromServerId(entry.id)
        if slot and player ~= -1 then
            CodPodium.place(session, GetPlayerPed(player), entry, base + right * slot.x + forward * slot.y, scene.ped.w, index == 1)
        end
    end

    session.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(session.cam, base.x + forward.x * settings.cameraDistance, base.y + forward.y * settings.cameraDistance, base.z + settings.cameraHeight)
    PointCamAtCoord(session.cam, base.x, base.y, base.z + settings.lookHeight)
    SetCamFov(session.cam, settings.fov)
    SetCamActive(session.cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

---@param session table
---@param source integer personnage réel du joueur
---@param entry table
---@param coords vector3
---@param heading number
---@param winner boolean
function CodPodium.place(session, source, entry, coords, heading, winner)
    local ped = ClonePed(source, false, false, true)
    if not DoesEntityExist(ped) then return end
    session.peds[#session.peds + 1] = ped
    if IsEntityDead(ped) then ResurrectPed(ped) end
    ClearPedTasksImmediately(ped)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, heading)
    FreezeEntityPosition(ped, true)
    if entry.weapon then
        local hash = GetHashKey(entry.weapon)
        RemoveAllPedWeapons(ped, true)
        GiveWeaponToPed(ped, hash, 1, false, true)
        Cod.applyMods(ped, entry.weapon, entry.mods)
        SetCurrentPedWeapon(ped, hash, true)
    end
    if winner and HasAnimDictLoaded(CodPodium.ANIM_DICT) then
        TaskPlayAnim(ped, CodPodium.ANIM_DICT, CodPodium.ANIM_NAME, 8.0, -8.0, -1, 0, 0.0, false, false, false)
    end
end

---Fin des résultats ou retour au menu. Peut être appelé plusieurs fois.
function CodPodium.clear()
    local session = CodPodium.session
    if not session then return end
    CodPodium.session = nil
    if session.cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(session.cam, false)
    end
    ClearFocus()
    for _, ped in ipairs(session.peds) do
        if DoesEntityExist(ped) then DeletePed(ped) end
    end
end
