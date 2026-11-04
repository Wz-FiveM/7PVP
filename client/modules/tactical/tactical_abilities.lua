---Capacités de Sabotage côté client : visée (point, allié), puis effets envoyés par le serveur — fumées,
---flash, barricades, capteurs, alarmes, verrou, ennemis révélés, ralentissement, course, soin, bouclier,
---relève, et les effets de la charge (pose, désamorçage, explosion sans dégâts).
---@class TacticalAbilitiesClientModule
local TacticalAbilities = PVP.define('TacticalAbilities')
local Tactical = PVP.use('Tactical')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

TacticalAbilities.SMOKE_ASSET = 'core'
TacticalAbilities.SMOKE_EFFECT = 'exp_grd_grenade_smoke'
TacticalAbilities.SMOKE_PUFFS = 5 -- nuages par fumée : un au centre, les autres autour
TacticalAbilities.SMOKE_REFRESH = 6000 -- ms : une fumée de grenade se dissipe seule, elle est relancée
TacticalAbilities.FLASH_ANGLE = 75.0 -- degrés : au-delà, le joueur ne regardait pas la flash
TacticalAbilities.FLASH_RANGE = 40.0
TacticalAbilities.MATE_ANGLE = 12.0 -- degrés entre la visée et un allié pour le viser
TacticalAbilities.BARRIER_FALLBACK = 'prop_mp_barrier_02b'
TacticalAbilities.REVEAL_COLOR = { 255, 90, 60 }
TacticalAbilities.FRIEND_COLOR = { 95, 209, 232 }
TacticalAbilities.SHAPE_FLAGS = 1 + 16 -- monde et objets

TacticalAbilities.smokes = {}
TacticalAbilities.objects = {} -- barricades : { id, entities, untilAt }
TacticalAbilities.markers = {} -- capteurs, alarmes, verrous : { id, kind, coords, radius, startAt, untilAt }
TacticalAbilities.revealed = {} -- server id -> { untilAt, blip }
TacticalAbilities.flashAt = 0
TacticalAbilities.flashUntil = 0
TacticalAbilities.flashStrength = 0
TacticalAbilities.slowUntil = 0
TacticalAbilities.slowFactor = 1.0
TacticalAbilities.sprintUntil = 0
TacticalAbilities.healLeft = 0
TacticalAbilities.healPerTick = 0
TacticalAbilities.nextHeal = 0

function TacticalAbilities.init()
    RegisterNetEvent(Events.client.tacEffect, function(data)
        if Tactical.isActive() and type(data) == 'table' then TacticalAbilities.onEffect(data) end
    end)
    RegisterNetEvent(Events.client.tacReveal, function(data)
        if Tactical.isActive() and type(data) == 'table' then TacticalAbilities.onReveal(data) end
    end)
end

---@param slot 'c'|'q'|'x'
---@return table|nil capacité du rôle du joueur
function TacticalAbilities.abilityOf(slot)
    local self = Tactical.self
    if not self then return nil end
    for _, role in ipairs(Config.Tactical.roles) do
        if role.id == self.role then return role.abilities[slot] end
    end
    return nil
end

---Touche d'une capacité : vérifiée ici pour ne rien envoyer d'inutile, puis par le serveur.
---@param slot 'c'|'q'|'x'
function TacticalAbilities.use(slot)
    if not Tactical.isActive() or Tactical.ended or Tactical.phase ~= 'running' or not State.isAlive() then return end
    if IsNuiFocused() or Tactical.acting then return end
    local ability = TacticalAbilities.abilityOf(slot)
    local self = Tactical.self
    if not ability then return end
    if slot == 'x' and self.ult < ability.cost then return Nui.send('tacNotice', { text = Locale.t('Ultime pas encore prête'), private = true }) end
    if slot ~= 'x' and (self.charges[slot] or 0) <= 0 then return Nui.send('tacNotice', { text = Locale.t('Plus de charge'), private = true }) end

    local data = {}
    if ability.target == 'aim' then
        local point = TacticalAbilities.aimPoint(ability.range)
        data.target = { x = point.x, y = point.y, z = point.z }
    elseif ability.target == 'mate' then
        data.mate = TacticalAbilities.aimedMate(ability.range)
    end
    TriggerServerEvent(Events.server.tacAbility, slot, data)
end

---@return vector3 position de la caméra
---@return vector3 direction de la caméra
function TacticalAbilities.camera()
    local rotation = GetGameplayCamRot(2)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local direction = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    return GetGameplayCamCoord(), direction
end

---@param range number
---@return vector3 point visé (mur, sol, objet), à au plus `range` m du joueur
function TacticalAbilities.aimPoint(range)
    local ped = PlayerPedId()
    local origin, direction = TacticalAbilities.camera()
    local finish = origin + direction * (range + 5.0)
    local probe = StartExpensiveSynchronousShapeTestLosProbe(origin.x, origin.y, origin.z, finish.x, finish.y, finish.z,
        TacticalAbilities.SHAPE_FLAGS, ped, 7)
    local _, hit, coords = GetShapeTestResult(probe)
    local point = hit == 1 and coords or finish
    -- Un peu en retrait du mur : la fumée ou le verrou ne naissent pas dedans
    if hit == 1 then point = point - direction * 0.5 end
    local from = GetEntityCoords(ped)
    local offset = point - from
    if #offset > range then point = from + offset / #offset * range end
    return point
end

---@param range number
---@return integer|nil server id de l'allié visé
function TacticalAbilities.aimedMate(range)
    local origin, direction = TacticalAbilities.camera()
    local ped = PlayerPedId()
    local from = GetEntityCoords(ped)
    local best, bestAngle = nil, TacticalAbilities.MATE_ANGLE
    for _, id in ipairs(Tactical.mates) do
        local player = GetPlayerFromServerId(id)
        if player ~= -1 then
            local mate = GetPlayerPed(player)
            local coords = GetEntityCoords(mate)
            if #(coords - from) <= range and HasEntityClearLosToEntity(ped, mate, 17) then
                local toMate = coords - origin
                local angle = math.deg(math.acos(math.max(-1.0, math.min(1.0, (toMate / #toMate).x * direction.x
                    + (toMate / #toMate).y * direction.y + (toMate / #toMate).z * direction.z))))
                if angle < bestAngle then best, bestAngle = id, angle end
            end
        end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- Effets reçus
-- ---------------------------------------------------------------------------

---@param data table
function TacticalAbilities.onEffect(data)
    local handler = TacticalAbilities.effects[data.type]
    if handler then handler(data) end
end

TacticalAbilities.effects = {}

function TacticalAbilities.effects.smoke(data)
    local now = GetGameTimer()
    TacticalAbilities.smokes[#TacticalAbilities.smokes + 1] = {
        coords = vector3(data.x, data.y, data.z), radius = data.radius, untilAt = now + data.seconds * 1000, handles = {}, nextPuff = 0,
    }
end

function TacticalAbilities.effects.flash(data)
    CreateThread(function()
        Wait(math.floor(data.delay * 1000))
        if not Tactical.isActive() then return end
        local point = vector3(data.x, data.y, data.z)
        PlaySoundFromCoord(-1, 'MP_Flash', point.x, point.y, point.z, 'WastedSounds', false, 40, false)
        if not State.isAlive() then return end
        local origin, direction = TacticalAbilities.camera()
        local toPoint = point - origin
        local distance = #toPoint
        if distance > TacticalAbilities.FLASH_RANGE then return end
        local unit = toPoint / math.max(distance, 0.01)
        local angle = math.deg(math.acos(math.max(-1.0, math.min(1.0, unit.x * direction.x + unit.y * direction.y + unit.z * direction.z))))
        if angle > TacticalAbilities.FLASH_ANGLE then return end
        -- Un mur entre le joueur et la flash le protège
        local probe = StartExpensiveSynchronousShapeTestLosProbe(origin.x, origin.y, origin.z, point.x, point.y, point.z,
            TacticalAbilities.SHAPE_FLAGS, PlayerPedId(), 7)
        local _, hit, coords = GetShapeTestResult(probe)
        if hit == 1 and #(coords - point) > 1.0 then return end
        local strength = (1.0 - angle / TacticalAbilities.FLASH_ANGLE * 0.5) * (1.0 - distance / TacticalAbilities.FLASH_RANGE * 0.4)
        local now = GetGameTimer()
        TacticalAbilities.flashAt = now
        TacticalAbilities.flashUntil = now + math.floor(data.seconds * 1000 * strength)
        TacticalAbilities.flashStrength = strength
    end)
end

function TacticalAbilities.effects.sensor(data)
    TacticalAbilities.addMarker('sensor', data, data.seconds)
end

function TacticalAbilities.effects.alarm(data)
    TacticalAbilities.addMarker('alarm', data, nil)
end

function TacticalAbilities.effects.lockdown(data)
    TacticalAbilities.addMarker('lockdown', data, data.delay + data.seconds, data.delay)
end

function TacticalAbilities.effects.remove(data)
    for index = #TacticalAbilities.markers, 1, -1 do
        if TacticalAbilities.markers[index].id == data.id then table.remove(TacticalAbilities.markers, index) end
    end
end

function TacticalAbilities.effects.barrier(data)
    CreateThread(function()
        local model = GetHashKey(data.model)
        if not IsModelInCdimage(model) then model = GetHashKey(TacticalAbilities.BARRIER_FALLBACK) end
        RequestModel(model)
        local timeout = GetGameTimer() + 3000
        while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
        if not HasModelLoaded(model) or not Tactical.isActive() then return end
        local entities = {}
        for _, point in ipairs(data.points) do
            local entity = CreateObjectNoOffset(model, point.x, point.y, point.z, false, false, false)
            SetEntityHeading(entity, data.heading)
            PlaceObjectOnGroundProperly(entity)
            FreezeEntityPosition(entity, true)
            entities[#entities + 1] = entity
        end
        SetModelAsNoLongerNeeded(model)
        TacticalAbilities.objects[#TacticalAbilities.objects + 1] = {
            id = data.id, entities = entities, untilAt = GetGameTimer() + data.seconds * 1000,
        }
    end)
end

function TacticalAbilities.effects.sprint(data)
    TacticalAbilities.sprintUntil = GetGameTimer() + data.seconds * 1000
    SetRunSprintMultiplierForPlayer(PlayerId(), math.min(1.49, data.multiplier))
end

function TacticalAbilities.effects.slow(data)
    TacticalAbilities.slowUntil = GetGameTimer() + data.seconds * 1000
    TacticalAbilities.slowFactor = data.factor
end

function TacticalAbilities.effects.revealed(data)
    Nui.send('tacNotice', { text = Locale.t('Tu es repéré'), private = true, danger = true })
    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
end

function TacticalAbilities.effects.heal(data)
    local ticks = math.max(1, math.floor(data.seconds * 4))
    TacticalAbilities.healLeft = data.amount
    TacticalAbilities.healPerTick = math.ceil(data.amount / ticks)
    TacticalAbilities.nextHeal = 0
end

function TacticalAbilities.effects.armor(data)
    local ped = PlayerPedId()
    SetPedArmour(ped, math.min(100, GetPedArmour(ped) + data.amount))
end

function TacticalAbilities.effects.revive(data)
    if Tactical.self then Tactical.self.loadout = data.loadout end
    CreateThread(function() Tactical.revive(data.spawn) end)
end

function TacticalAbilities.effects.roundStart()
    Nui.send('tacNotice', { text = Locale.t('La manche commence'), big = true })
    PlaySoundFrontend(-1, 'GO', 'HUD_MINI_GAME_SOUNDSET', true)
end

function TacticalAbilities.effects.bombPlanted(data)
    Tactical.onBombPlanted(data)
    PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
end

function TacticalAbilities.effects.bombDefused()
    Tactical.bomb = nil
end

---Explosion sans dégâts : un seul client la crée (elle est synchronisée), tout le monde sent la secousse.
function TacticalAbilities.effects.bombBlast(data)
    Tactical.bomb = nil
    if data.owner then
        for index = 0, 2 do
            AddExplosion(data.x + (index - 1) * 2.0, data.y, data.z, 4, 0.0, true, false, 1.0)
        end
    end
    local distance = #(GetEntityCoords(PlayerPedId()) - vector3(data.x, data.y, data.z))
    if distance < 120.0 then ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', math.max(0.2, 1.0 - distance / 120.0)) end
end

---@param kind string
---@param data table x, y, z, radius, id
---@param seconds number|nil nil = jusqu'à la fin de la manche
---@param delay number|nil secondes avant l'effet (verrou)
function TacticalAbilities.addMarker(kind, data, seconds, delay)
    local now = GetGameTimer()
    TacticalAbilities.markers[#TacticalAbilities.markers + 1] = {
        id = data.id,
        kind = kind,
        coords = vector3(data.x, data.y, data.z),
        radius = data.radius,
        startAt = now + math.floor((delay or 0) * 1000),
        untilAt = seconds and now + math.floor(seconds * 1000) or math.huge,
    }
end

---@param data { ids: integer[], seconds: number }
function TacticalAbilities.onReveal(data)
    local untilAt = GetGameTimer() + math.floor(data.seconds * 1000)
    for _, id in ipairs(data.ids) do
        local entry = TacticalAbilities.revealed[id]
        if entry then
            entry.untilAt = math.max(entry.untilAt, untilAt)
        else
            TacticalAbilities.revealed[id] = { untilAt = untilAt }
        end
    end
end

-- ---------------------------------------------------------------------------
-- Chaque image
-- ---------------------------------------------------------------------------

---@param now integer
function TacticalAbilities.frame(now)
    TacticalAbilities.updateSmokes(now)
    TacticalAbilities.updateObjects(now)
    TacticalAbilities.drawMarkers(now)
    TacticalAbilities.drawRevealed(now)
    TacticalAbilities.drawFlash(now)
    TacticalAbilities.updateSelf(now)
end

---@param now integer
function TacticalAbilities.updateSmokes(now)
    for index = #TacticalAbilities.smokes, 1, -1 do
        local smoke = TacticalAbilities.smokes[index]
        if now >= smoke.untilAt then
            TacticalAbilities.stopSmoke(smoke)
            table.remove(TacticalAbilities.smokes, index)
        elseif now >= smoke.nextPuff then
            smoke.nextPuff = now + TacticalAbilities.SMOKE_REFRESH
            TacticalAbilities.puff(smoke)
        end
    end
end

---Nuages de la fumée : relancés avant de se dissiper, l'ancien s'arrête doucement.
---@param smoke table
function TacticalAbilities.puff(smoke)
    if not HasNamedPtfxAssetLoaded(TacticalAbilities.SMOKE_ASSET) then
        RequestNamedPtfxAsset(TacticalAbilities.SMOKE_ASSET)
        smoke.nextPuff = GetGameTimer() + 100
        return
    end
    local previous = smoke.handles
    smoke.handles = {}
    local spread = smoke.radius * 0.55
    for index = 1, TacticalAbilities.SMOKE_PUFFS do
        local angle = (index - 1) / (TacticalAbilities.SMOKE_PUFFS - 1) * math.pi * 2.0
        local distance = index == 1 and 0.0 or spread
        UseParticleFxAssetNextCall(TacticalAbilities.SMOKE_ASSET)
        smoke.handles[index] = StartParticleFxLoopedAtCoord(TacticalAbilities.SMOKE_EFFECT,
            smoke.coords.x + math.cos(angle) * distance, smoke.coords.y + math.sin(angle) * distance, smoke.coords.z,
            0.0, 0.0, 0.0, smoke.radius / 2.5, false, false, false, false)
    end
    for _, handle in ipairs(previous) do StopParticleFxLooped(handle, false) end
end

---@param smoke table
function TacticalAbilities.stopSmoke(smoke)
    for _, handle in ipairs(smoke.handles) do StopParticleFxLooped(handle, false) end
    smoke.handles = {}
end

---@param now integer
function TacticalAbilities.updateObjects(now)
    for index = #TacticalAbilities.objects, 1, -1 do
        local object = TacticalAbilities.objects[index]
        if now >= object.untilAt then
            TacticalAbilities.deleteObject(object)
            table.remove(TacticalAbilities.objects, index)
        end
    end
end

---@param object table
function TacticalAbilities.deleteObject(object)
    for _, entity in ipairs(object.entities) do
        if DoesEntityExist(entity) then DeleteObject(entity) end
    end
end

---@param now integer
function TacticalAbilities.drawMarkers(now)
    for index = #TacticalAbilities.markers, 1, -1 do
        local marker = TacticalAbilities.markers[index]
        if now >= marker.untilAt then
            table.remove(TacticalAbilities.markers, index)
        else
            local c = marker.coords
            local active = now >= marker.startAt
            local color = marker.kind == 'lockdown' and TacticalAbilities.REVEAL_COLOR or TacticalAbilities.FRIEND_COLOR
            local alpha = marker.kind == 'lockdown' and (active and 70 or 35) or 60
            local size = marker.kind == 'alarm' and 0.5 or marker.radius * 2.0
            DrawMarker(marker.kind == 'alarm' and 27 or 1, c.x, c.y, c.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size,
                marker.kind == 'alarm' and 0.5 or 0.4, color[1], color[2], color[3], alpha, false, false, 2, marker.kind == 'alarm',
                nil, nil, false)
        end
    end
end

---Ennemis révélés : repère rouge sur la carte et flèche au-dessus de la tête, même à travers les murs.
---@param now integer
function TacticalAbilities.drawRevealed(now)
    local color = TacticalAbilities.REVEAL_COLOR
    for id, entry in pairs(TacticalAbilities.revealed) do
        local player = GetPlayerFromServerId(id)
        if now >= entry.untilAt or player == -1 then
            if entry.blip and DoesBlipExist(entry.blip) then RemoveBlip(entry.blip) end
            TacticalAbilities.revealed[id] = nil
        else
            local ped = GetPlayerPed(player)
            if not entry.blip then
                entry.blip = AddBlipForEntity(ped)
                SetBlipColour(entry.blip, 1)
                SetBlipScale(entry.blip, 0.85)
            end
            local coords = GetEntityCoords(ped)
            DrawMarker(2, coords.x, coords.y, coords.z + 1.3, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.3, 0.3, 0.3,
                color[1], color[2], color[3], 220, true, true, 2, false, nil, nil, false)
        end
    end
end

---Aveuglé : écran blanc qui s'estompe.
---@param now integer
function TacticalAbilities.drawFlash(now)
    if now >= TacticalAbilities.flashUntil then return end
    local total = math.max(1, TacticalAbilities.flashUntil - TacticalAbilities.flashAt)
    local left = (TacticalAbilities.flashUntil - now) / total
    local alpha = math.floor(255 * math.min(1.0, left * 1.6))
    DrawRect(0.5, 0.5, 1.0, 1.0, 255, 255, 255, alpha)
end

---Ralenti, course, soin progressif.
---@param now integer
function TacticalAbilities.updateSelf(now)
    local ped = PlayerPedId()
    if now < TacticalAbilities.slowUntil then
        SetPedMoveRateOverride(ped, TacticalAbilities.slowFactor)
        DisableControlAction(0, 21, true) -- pas de sprint
        DisableControlAction(0, 22, true) -- ni de saut
    end
    if TacticalAbilities.sprintUntil ~= 0 and now >= TacticalAbilities.sprintUntil then
        TacticalAbilities.sprintUntil = 0
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    end
    if TacticalAbilities.healLeft > 0 and now >= TacticalAbilities.nextHeal and State.isAlive() then
        TacticalAbilities.nextHeal = now + 250
        local amount = math.min(TacticalAbilities.healLeft, TacticalAbilities.healPerTick)
        TacticalAbilities.healLeft = TacticalAbilities.healLeft - amount
        SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + amount))
    end
end

-- ---------------------------------------------------------------------------
-- Nettoyage
-- ---------------------------------------------------------------------------

---Mort : les effets sur soi s'arrêtent (les fumées et barricades restent pour les autres).
function TacticalAbilities.onDeath()
    TacticalAbilities.flashUntil = 0
    TacticalAbilities.slowUntil = 0
    TacticalAbilities.healLeft = 0
    if TacticalAbilities.sprintUntil ~= 0 then
        TacticalAbilities.sprintUntil = 0
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    end
end

---Nouvelle manche, fin de partie, retour au menu : tout disparaît.
function TacticalAbilities.clear()
    for _, smoke in ipairs(TacticalAbilities.smokes) do TacticalAbilities.stopSmoke(smoke) end
    TacticalAbilities.smokes = {}
    for _, object in ipairs(TacticalAbilities.objects) do TacticalAbilities.deleteObject(object) end
    TacticalAbilities.objects = {}
    TacticalAbilities.markers = {}
    for _, entry in pairs(TacticalAbilities.revealed) do
        if entry.blip and DoesBlipExist(entry.blip) then RemoveBlip(entry.blip) end
    end
    TacticalAbilities.revealed = {}
    TacticalAbilities.onDeath()
end
