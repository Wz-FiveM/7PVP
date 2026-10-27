---Noclip admin : vol libre à travers les murs, dans la direction de la caméra.
---Z/S avancer-reculer, Q/D de côté, Espace monter, Ctrl descendre, Maj rapide, Alt lent.
---@class NoclipModule
local Noclip = PVP.define('Noclip')
local State = PVP.use('State')

Noclip.active = false

-- Contrôles GTA utilisés (désactivés pour le jeu pendant le vol)
Noclip.CONTROL_FORWARD = 32
Noclip.CONTROL_BACK = 33
Noclip.CONTROL_LEFT = 34
Noclip.CONTROL_RIGHT = 35
Noclip.CONTROL_UP = 22
Noclip.CONTROL_DOWN = 36
Noclip.CONTROL_FAST = 21
Noclip.CONTROL_SLOW = 19
Noclip.DISABLED_CONTROLS = { 21, 22, 24, 25, 30, 31, 32, 33, 34, 35, 36, 19, 44, 140, 141, 142, 143 }

---@param active boolean
function Noclip.set(active)
    Noclip.active = active
    State.noclip = active
    Noclip.applyPedState()
    if active then
        CreateThread(Noclip.loop)
    end
end

function Noclip.toggle()
    Noclip.set(not Noclip.active)
end

---Collisions, gel, invincibilité et visibilité selon le noclip et les options admin.
function Noclip.applyPedState()
    local ped = PlayerPedId()
    local active = Noclip.active
    SetEntityCollision(ped, not active, not active)
    FreezeEntityPosition(ped, active)
    SetEntityInvincible(ped, active or State.godmode or State.isInSafeZone())
    SetEntityVisible(ped, not active and not State.invisible, false)
end

function Noclip.loop()
    while Noclip.active do
        Wait(0)
        Noclip.step()
    end
end

function Noclip.step()
    for _, control in ipairs(Noclip.DISABLED_CONTROLS) do
        DisableControlAction(0, control, true)
    end

    local ped = PlayerPedId()
    local rotation = GetGameplayCamRot(2)
    local yaw = math.rad(rotation.z)
    local pitch = math.rad(rotation.x)

    local forward = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    local right = vector3(math.cos(yaw), math.sin(yaw), 0.0)
    local move = vector3(0.0, 0.0, 0.0)

    if IsDisabledControlPressed(0, Noclip.CONTROL_FORWARD) then move = move + forward end
    if IsDisabledControlPressed(0, Noclip.CONTROL_BACK) then move = move - forward end
    if IsDisabledControlPressed(0, Noclip.CONTROL_RIGHT) then move = move + right end
    if IsDisabledControlPressed(0, Noclip.CONTROL_LEFT) then move = move - right end
    if IsDisabledControlPressed(0, Noclip.CONTROL_UP) then move = move + vector3(0.0, 0.0, 1.0) end
    if IsDisabledControlPressed(0, Noclip.CONTROL_DOWN) then move = move - vector3(0.0, 0.0, 1.0) end

    local length = #move
    if length > 0.0 then
        local speed = Config.Admin.NoclipSpeed * GetFrameTime()
        if IsDisabledControlPressed(0, Noclip.CONTROL_FAST) then
            speed = speed * Config.Admin.NoclipFastMultiplier
        elseif IsDisabledControlPressed(0, Noclip.CONTROL_SLOW) then
            speed = speed * Config.Admin.NoclipSlowMultiplier
        end
        local position = GetEntityCoords(ped) + (move / length) * speed
        SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, true, true, true)
    end
    SetEntityHeading(ped, rotation.z)
end
