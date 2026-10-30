---Effets du mode Call of Duty : atouts, drone, carte coupée, frappe aérienne, frappe nucléaire, bombe.
---Les dégâts des frappes sont calculés par le serveur (voir server/modules/cod/cod_streaks.lua) :
---le client ne fait que les appliquer à son personnage et afficher l'effet.
---@class CodEffectsModule
local CodEffects = PVP.define('CodEffects')
local Cod = PVP.use('Cod')
local Nui = PVP.use('Nui')
local Events = PVP.use('Events')

CodEffects.AIM_DISTANCE = 300.0
CodEffects.REVENGE_TIME = 6000
CodEffects.SHAKE_DISTANCE = 60.0

---@type { blip: integer, untilAt: integer }[] repères temporaires (drone, frappe, tueur)
CodEffects.blips = {}
CodEffects.jamUntil = 0
CodEffects.jammed = false

-- Effets envoyés par le serveur : type -> méthode
CodEffects.HANDLERS = {
    uav = 'onUav',
    jam = 'onJam',
    airstrikeCall = 'onAirstrikeCall',
    airstrikeBomb = 'onAirstrikeBomb',
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
        local method = type(data) == 'table' and CodEffects.HANDLERS[data.type]
        if method and Cod.isActive() then CodEffects[method](data) end
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
-- Frappe aérienne
-- ---------------------------------------------------------------------------

---@return { x: number, y: number, z: number } point visé par la caméra
function CodEffects.aimPoint()
    local from = GetGameplayCamCoord()
    local rotation = GetGameplayCamRot(2)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local direction = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    local to = from + direction * CodEffects.AIM_DISTANCE
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 16, PlayerPedId(), 7)
    local _, hit, coords = GetShapeTestResult(ray)
    local point = hit == 1 and coords or to
    return { x = point.x, y = point.y, z = point.z }
end

---@param data { x: number, y: number, z: number, delay: integer }
function CodEffects.onAirstrikeCall(data)
    local blip = AddBlipForRadius(data.x, data.y, data.z, Config.Cod.airstrike.spread + Config.Cod.airstrike.radius)
    SetBlipColour(blip, 1)
    SetBlipAlpha(blip, 110)
    local total = data.delay * 1000 + Config.Cod.airstrike.bombs * Config.Cod.airstrike.interval
    CodEffects.keepBlip(blip, total)
    PlaySoundFrontend(-1, '5_SEC_WARNING', 'HUD_MINI_GAME_SOUNDSET', true)
end

---@param data { x: number, y: number, z: number, owner: boolean, explosion: integer }
function CodEffects.onAirstrikeBomb(data)
    CodEffects.blast(data, data.explosion, 1.5)
end

---Explosion sans dégâts créée par un seul client (l'explosion est synchronisée pour les autres).
---@param data { x: number, y: number, z: number, owner: boolean }
---@param explosion integer type d'explosion de GTA
---@param shake number
function CodEffects.blast(data, explosion, shake)
    local found, ground = GetGroundZFor_3dCoord(data.x, data.y, data.z + 30.0, false)
    local z = found and ground or data.z
    if data.owner then AddExplosion(data.x, data.y, z, explosion, 0.0, true, false, 2.0) end
    local distance = #(GetEntityCoords(PlayerPedId()) - vector3(data.x, data.y, z))
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
    CodEffects.blast(data, Config.Cod.airstrike.explosionType, 2.0)
end

---Nouvelle manche : bloqué au départ pendant le compte à rebours.
---@param data { countdown: integer }
function CodEffects.onRoundStart(data)
    Cod.lockedUntil = GetGameTimer() + data.countdown * 1000
    Nui.send('codRoundStart', { countdown = data.countdown })
end
