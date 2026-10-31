---Effets du mode Call of Duty : atouts, drone, carte coupée, explosions des séries, avions, EMP, frappe nucléaire, bombe.
---Les dégâts des séries sont calculés par le serveur (voir server/modules/cod/cod_streaks.lua) :
---le client ne fait que les appliquer à son personnage et afficher l'effet.
---@class CodEffectsModule
local CodEffects = PVP.define('CodEffects')
local Cod = PVP.use('Cod')
local CodPredator = PVP.use('CodPredator')
local Nui = PVP.use('Nui')
local PedUtils = PVP.use('PedUtils')
local Events = PVP.use('Events')

CodEffects.AIM_DISTANCE = 300.0
CodEffects.FRONT_DISTANCE = 1.8 -- m entre le joueur et la tourelle
CodEffects.REVENGE_TIME = 6000
CodEffects.SHAKE_DISTANCE = 60.0
CodEffects.PLANE_SPEED = 110.0 -- m/s
CodEffects.PLANE_HEIGHT = 120.0 -- m au-dessus du point visé
CodEffects.PLANE_SPACING = 25.0 -- m entre deux avions d'une formation

-- Effets gérés par d'autres modules (CodUnits, CodCrates) : type -> fonction
CodEffects.EXTERNAL = {}

---@type { blip: integer, untilAt: integer }[] repères temporaires (drone, tueur)
CodEffects.blips = {}
CodEffects.jamUntil = 0
CodEffects.jammed = false
CodEffects.radarUntil = 0 -- GetGameTimer() de fin du dernier balayage de drone (carte du mode Hardcore)

-- Effets envoyés par le serveur : type -> méthode
CodEffects.HANDLERS = {
    uav = 'onUav',
    jam = 'onJam',
    predatorCall = 'onPredatorCall',
    blast = 'onBlast',
    flyby = 'onFlyby',
    empBlast = 'onEmpBlast',
    hurt = 'onHurt',
    juggernaut = 'onJuggernaut',
    streakEarned = 'onStreakEarned',
    nukeCall = 'onNukeCall',
    nukeBlast = 'onNukeBlast',
    bombPlanted = 'onBombPlanted',
    bombBlast = 'onBombBlast',
    roundStart = 'onRoundStart',
}

function CodEffects.init()
    RegisterNetEvent(Events.client.codEffect, function(data)
        if type(data) ~= 'table' or not Cod.isActive() then return end
        local handler = CodEffects.EXTERNAL[data.type] or CodEffects[CodEffects.HANDLERS[data.type]]
        if handler then handler(data) end
    end)
end

-- ---------------------------------------------------------------------------
-- Atouts
-- ---------------------------------------------------------------------------

---Réglages du joueur (pas du personnage) : ils doivent être remis à zéro en quittant le mode.
---@param perks table<string, boolean>
function CodEffects.applyPerks(perks)
    local player = PlayerId()
    SetRunSprintMultiplierForPlayer(player, perks.lightweight and Config.Cod.lightweightSpeed or 1.0)
    SetPlayerWeaponDamageModifier(player, perks.stopping and Config.Cod.stoppingPower or 1.0)
end

-- ---------------------------------------------------------------------------
-- À chaque image
-- ---------------------------------------------------------------------------

---@param now integer
function CodEffects.frame(now)
    if Cod.perks.marathon then ResetPlayerStamina(PlayerId()) end

    local jammed = now < CodEffects.jamUntil
    if jammed ~= CodEffects.jammed then
        CodEffects.jammed = jammed
        DisplayRadar(not jammed)
        Nui.send('codJam', { active = jammed })
    end

    for index = #CodEffects.blips, 1, -1 do
        local entry = CodEffects.blips[index]
        if now >= entry.untilAt then
            if DoesBlipExist(entry.blip) then RemoveBlip(entry.blip) end
            table.remove(CodEffects.blips, index)
        end
    end
end

---@param blip integer
---@param duration integer ms
function CodEffects.keepBlip(blip, duration)
    CodEffects.blips[#CodEffects.blips + 1] = { blip = blip, untilAt = GetGameTimer() + duration }
end

function CodEffects.clear()
    for _, entry in ipairs(CodEffects.blips) do
        if DoesBlipExist(entry.blip) then RemoveBlip(entry.blip) end
    end
    CodEffects.blips = {}
    CodEffects.jamUntil = 0
    CodEffects.radarUntil = 0
    if CodEffects.jammed then
        CodEffects.jammed = false
        DisplayRadar(true)
    end
    CodEffects.applyPerks({})
end

-- ---------------------------------------------------------------------------
-- Drone et contre-drone
-- ---------------------------------------------------------------------------

---Relevé du drone : un repère par ennemi, jusqu'au relevé suivant.
---@param data { points: table[], ttl: integer }
function CodEffects.onUav(data)
    for _, point in ipairs(data.points) do
        local blip = AddBlipForCoord(point.x, point.y, point.z)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, false)
        CodEffects.keepBlip(blip, data.ttl * 1000)
    end
    CodEffects.radarUntil = GetGameTimer() + data.ttl * 1000
    Nui.send('codRadar', { seconds = data.ttl })
end

---@param data { duration: integer }
function CodEffects.onJam(data)
    CodEffects.jamUntil = GetGameTimer() + data.duration * 1000
end

---Atout Vengeance : le tueur reste sur la carte quelques secondes.
---@param coords vector3
function CodEffects.markRevenge(coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipColour(blip, 1)
    SetBlipSprite(blip, 303)
    CodEffects.keepBlip(blip, CodEffects.REVENGE_TIME)
end

-- ---------------------------------------------------------------------------
-- Séries
-- ---------------------------------------------------------------------------

---@return vector3 direction du regard de la caméra
function CodEffects.camDirection()
    local rotation = GetGameplayCamRot(2)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    return vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
end

---@return { x: number, y: number, z: number, heading: number } point visé par la caméra, et son cap
function CodEffects.aimPoint()
    local from = GetGameplayCamCoord()
    local to = from + CodEffects.camDirection() * CodEffects.AIM_DISTANCE
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 16, PlayerPedId(), 7)
    local _, hit, coords = GetShapeTestResult(ray)
    local point = hit == 1 and coords or to
    return { x = point.x, y = point.y, z = point.z, heading = GetGameplayCamRot(2).z }
end

---@return { x: number, y: number, z: number, heading: number } sol juste devant le joueur, et son cap
function CodEffects.frontPoint()
    local ped = PlayerPedId()
    local point = GetOffsetFromEntityInWorldCoords(ped, 0.0, CodEffects.FRONT_DISTANCE, 0.0)
    local found, ground = GetGroundZFor_3dCoord(point.x, point.y, point.z + 2.0, false)
    return { x = point.x, y = point.y, z = found and ground or point.z - 1.0, heading = GetEntityHeading(ped) }
end

---@param data { pilot: integer }
function CodEffects.onPredatorCall(data)
    PlaySoundFrontend(-1, '5_SEC_WARNING', 'HUD_MINI_GAME_SOUNDSET', true)
    if data.pilot == Cod.match.self then CodPredator.launch() end
end

---Une bombe est posée au sol ; un obus ou un missile explose là où il a touché, qui peut être un toit.
---@param data { x: number, y: number, z: number, owner: boolean, explosion: integer, snap: boolean }
function CodEffects.onBlast(data)
    local z = data.z
    if data.snap then
        local found, ground = GetGroundZFor_3dCoord(data.x, data.y, data.z + 30.0, false)
        if found then z = ground end
    end
    CodEffects.explode(data.x, data.y, z, data.owner, data.explosion, 2.0)
end

---Avions qui passent au-dessus du point au moment où les bombes tombent. Copie locale chez chaque client.
---@param data { x: number, y: number, z: number, heading: number, model: string, planes: integer, delay: number, warn: boolean }
function CodEffects.onFlyby(data)
    if data.warn then PlaySoundFrontend(-1, '5_SEC_WARNING', 'HUD_MINI_GAME_SOUNDSET', true) end
    CreateThread(function()
        local match = Cod.match
        local model = GetHashKey(data.model)
        if not PedUtils.loadModel(model) or Cod.match ~= match then return end
        local yaw = math.rad(data.heading)
        local forward = vector3(-math.sin(yaw), math.cos(yaw), 0.0)
        local right = vector3(math.cos(yaw), math.sin(yaw), 0.0)
        local center = vector3(data.x, data.y, data.z + CodEffects.PLANE_HEIGHT)

        local planes = {}
        for index = 1, data.planes do
            local plane = CreateVehicle(model, center.x, center.y, center.z, data.heading, false, false)
            SetEntityCollision(plane, false, false)
            FreezeEntityPosition(plane, true)
            SetEntityInvincible(plane, true)
            SetVehicleEngineOn(plane, true, true, false)
            ControlLandingGear(plane, 3)
            planes[index] = { entity = plane, offset = right * (index - (data.planes + 1) / 2) * CodEffects.PLANE_SPACING }
        end
        SetModelAsNoLongerNeeded(model)

        local start = GetGameTimer()
        local duration = data.delay * 2000
        while Cod.match == match and GetGameTimer() - start < duration do
            local along = (GetGameTimer() - start - duration / 2) / 1000 * CodEffects.PLANE_SPEED
            for _, plane in ipairs(planes) do
                local coords = center + forward * along + plane.offset
                SetEntityCoordsNoOffset(plane.entity, coords.x, coords.y, coords.z, false, false, false)
            end
            Wait(0)
        end
        for _, plane in ipairs(planes) do
            if DoesEntityExist(plane.entity) then DeleteEntity(plane.entity) end
        end
    end)
end

---@param data { enemy: boolean }
function CodEffects.onEmpBlast(data)
    AnimpostfxPlay('ExplosionJosh3', 800, false)
    if data.enemy then ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 0.4) end
end

---Explosion sans dégâts créée par un seul client (l'explosion est synchronisée pour les autres).
---@param x number
---@param y number
---@param z number
---@param owner boolean
---@param explosion integer type d'explosion de GTA
---@param shake number
function CodEffects.explode(x, y, z, owner, explosion, shake)
    if owner then AddExplosion(x, y, z, explosion, 0.0, true, false, 2.0) end
    local distance = #(GetEntityCoords(PlayerPedId()) - vector3(x, y, z))
    if distance <= CodEffects.SHAKE_DISTANCE then
        ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', shake * (1 - distance / CodEffects.SHAKE_DISTANCE))
    end
end

---@param data { damage: integer }
function CodEffects.onHurt(data)
    ApplyDamageToPed(PlayerPedId(), tonumber(data.damage) or 0, false)
end

-- ---------------------------------------------------------------------------
-- Autres séries
-- ---------------------------------------------------------------------------

function CodEffects.onJuggernaut()
    local settings = Config.Cod.juggernaut
    local ped = PlayerPedId()
    local hash = GetHashKey(settings.weapon)
    GiveWeaponToPed(ped, hash, settings.ammo, false, true)
    SetCurrentPedWeapon(ped, hash, true)
    SetPedArmour(ped, settings.armor)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
end

---@param data { label: string }
function CodEffects.onStreakEarned(data)
    PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true)
    Nui.send('codStreakEarned', { label = data.label })
end

---@param data { seconds: integer }
function CodEffects.onNukeCall(data)
    PlaySoundFrontend(-1, '5_SEC_WARNING', 'HUD_MINI_GAME_SOUNDSET', true)
    Nui.send('codNuke', { seconds = data.seconds })
end

function CodEffects.onNukeBlast()
    AnimpostfxPlay('ExplosionJosh3', 1500, false)
    ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 2.0)
end

-- ---------------------------------------------------------------------------
-- Bombe
-- ---------------------------------------------------------------------------

function CodEffects.onBombPlanted()
    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
end

---@param data { x: number, y: number, z: number, owner: boolean }
function CodEffects.onBombBlast(data)
    local found, ground = GetGroundZFor_3dCoord(data.x, data.y, data.z + 30.0, false)
    CodEffects.explode(data.x, data.y, found and ground or data.z, data.owner, Config.Cod.bombExplosion, 2.0)
end

---Nouvelle manche : bloqué au départ pendant le compte à rebours.
---@param data { countdown: integer }
function CodEffects.onRoundStart(data)
    Cod.lockedUntil = GetGameTimer() + data.countdown * 1000
    Nui.send('codRoundStart', { countdown = data.countdown })
end
