---Unités des séries du mode Call of Duty (Config.Cod.units), côté client. Chaque client affiche sa propre copie,
---sans entité réseau, et calcule sa position à partir des données du serveur (server/modules/cod/cod_units.lua).
---Le client du propriétaire cherche les cibles en vue (le serveur ne sait pas tester une ligne de vue) ;
---celui d'un ennemi signale ses tirs qui touchent l'unité.
---@class CodUnitsModule
local CodUnits = PVP.define('CodUnits')
local Cod = PVP.use('Cod')
local CodEffects = PVP.use('CodEffects')
local CodGunner = PVP.use('CodGunner')
local Nui = PVP.use('Nui')
local PedUtils = PVP.use('PedUtils')
local Events = PVP.use('Events')

CodUnits.SEARCH_INTERVAL = 200 -- ms entre deux recherches de cible
CodUnits.HIT_INTERVAL = 80 -- ms entre deux tests d'un tir du joueur sur une unité
CodUnits.HIT_DISTANCE = 500.0 -- m
CodUnits.SIGHT_FLAGS = 1 + 16 -- carte, objets
CodUnits.HIT_FLAGS = 1 + 2 + 16 -- carte, véhicules, objets
CodUnits.BULLET = GetHashKey('WEAPON_MINIGUN')
CodUnits.MUZZLE_OFFSET = 2.5 -- m entre l'unité et le départ de la balle
CodUnits.TARGET_HEIGHT = 0.4 -- m au-dessus du centre du personnage visé
CodUnits.TARGET_MISS = 1.5 -- m à côté du joueur visé pour la balle tirée chez lui
CodUnits.BARREL_YAW = 270.0 -- cap du canon d'un modèle d'arme quand le modèle a le cap 0 (axe X), sans os de bouche
CodUnits.BARREL_MIN = 0.1 -- m : en dessous, la position de l'os de bouche ne donne pas de direction
CodUnits.MUZZLE_BONE = 'gun_muzzle'
CodUnits.MUZZLE_FLASH = 'muz_minigun'
CodUnits.FLASH_SCALE = 1.5
CodUnits.TRACER_TIME = 70 -- ms d'affichage d'une traçante
CodUnits.GUN_RANGE = 250.0 -- m : au-delà, le tir ne s'entend plus
CodUnits.DESTROYED_EXPLOSION = 5
CodUnits.COLOR_FRIEND = 3
CodUnits.COLOR_ENEMY = 1

---@type table<integer, table> id -> unité (données du serveur, born, entity, blip, nextShot)
CodUnits.units = {}
CodUnits.nextHitCheck = 0
---@type { from: vector3, to: vector3, untilAt: integer }[]
CodUnits.tracers = {}

function CodUnits.init()
    CodEffects.EXTERNAL.unitStart = CodUnits.onStart
    CodEffects.EXTERNAL.unitEnd = CodUnits.onEnd
    CodEffects.EXTERNAL.unitShot = CodUnits.onShot
end

---@param data table voir CodUnits.describe côté serveur
function CodUnits.onStart(data)
    local unit = data
    unit.settings = Config.Cod.units[data.kind]
    unit.born = GetGameTimer() - data.elapsed * 1000
    unit.owned = data.owner == Cod.match.self
    unit.nextShot = 0
    CodUnits.units[data.id] = unit
    CreateThread(function()
        CodUnits.createModels(unit)
    end)
    RequestWeaponAsset(CodUnits.BULLET, 31, 0)
    RequestNamedPtfxAsset('core')
    if unit.owned and unit.settings.piloted then CodGunner.launch(unit) end
end

---@param unit table
function CodUnits.createModels(unit)
    local settings = unit.settings
    local name = settings.aircraft or settings.model
    local model = GetHashKey(name)
    if not PedUtils.loadModel(model) or CodUnits.units[unit.id] ~= unit then return end

    local coords = CodUnits.position(unit, GetGameTimer())
    if settings.aircraft then
        unit.entity = CreateVehicle(model, coords.x, coords.y, coords.z, unit.heading, false, false)
        SetVehicleEngineOn(unit.entity, true, true, false)
        SetHeliBladesFullSpeed(unit.entity)
        ControlLandingGear(unit.entity, 3)
    else
        unit.entity = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
        PlaceObjectOnGroundProperly(unit.entity)
        CodUnits.findBarrel(unit)
        CodUnits.aimGun(unit)
    end
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(unit.entity, true)
    SetEntityInvincible(unit.entity, true)

    if settings.blip then
        unit.blip = AddBlipForEntity(unit.entity)
        SetBlipSprite(unit.blip, settings.blip)
        SetBlipColour(unit.blip, unit.friendly and CodUnits.COLOR_FRIEND or CodUnits.COLOR_ENEMY)
    end
end

---Le canon d'un modèle d'arme n'est pas dans l'axe du cap de l'objet : on le mesure sur son os de bouche.
---@param unit table
function CodUnits.findBarrel(unit)
    unit.barrelYaw = unit.settings.barrelYaw or CodUnits.BARREL_YAW
    local bone = GetEntityBoneIndexByName(unit.entity, CodUnits.MUZZLE_BONE)
    if bone == -1 then return end
    unit.muzzleBone = bone
    local offset = GetOffsetFromEntityGivenWorldCoords(unit.entity, GetWorldPositionOfEntityBone(unit.entity, bone))
    if #offset.xy >= CodUnits.BARREL_MIN then
        unit.barrelYaw = GetHeadingFromVector_2d(offset.x, offset.y)
    end
end

---Tourne le canon vers le cap de l'unité.
---@param unit table
function CodUnits.aimGun(unit)
    if unit.entity and DoesEntityExist(unit.entity) then
        SetEntityHeading(unit.entity, unit.heading - (unit.barrelYaw or 0.0))
    end
end

---@param unit table
---@param now integer
---@return vector3 position, number cap
function CodUnits.position(unit, now)
    if not unit.radius then return vector3(unit.x, unit.y, unit.z), unit.heading end
    local angle = unit.angle + unit.speed * (now - unit.born) / 1000
    -- Le cap suit la tangente du cercle, dans le sens de rotation
    local heading = math.deg(angle) + (unit.speed < 0 and 180.0 or 0.0)
    return vector3(unit.x + math.cos(angle) * unit.radius, unit.y + math.sin(angle) * unit.radius, unit.z), heading
end

---@param data { id: integer, by: integer|false }
function CodUnits.onEnd(data)
    local unit = CodUnits.units[data.id]
    if not unit then return end
    if data.by then
        local coords = CodUnits.position(unit, GetGameTimer())
        CodEffects.explode(coords.x, coords.y, coords.z, data.by == Cod.match.self, CodUnits.DESTROYED_EXPLOSION, 1.0)
    end
    CodUnits.remove(unit)
end

---@param unit table
function CodUnits.remove(unit)
    CodUnits.units[unit.id] = nil
    if unit.blip and DoesBlipExist(unit.blip) then RemoveBlip(unit.blip) end
    if unit.entity and DoesEntityExist(unit.entity) then DeleteEntity(unit.entity) end
end

function CodUnits.clear()
    for _, unit in pairs(CodUnits.units) do CodUnits.remove(unit) end
    CodUnits.nextHitCheck = 0
    CodUnits.tracers = {}
end

---Balle sans dégâts ni tireur, pour le bruit et l'impact : les dégâts sont appliqués par le serveur. Chez le joueur
---visé, elle passe à côté de lui : le jeu pourrait lui compter ses propres dégâts en plus de ceux du serveur.
---@param data { id: integer, x: number, y: number, z: number, target: integer|nil, gunfire: boolean|nil }
function CodUnits.onShot(data)
    local unit = CodUnits.units[data.id]
    if not unit then return end
    local from = CodUnits.position(unit, GetGameTimer())
    local to = vector3(data.x, data.y, data.z + CodUnits.TARGET_HEIGHT)
    if not unit.radius then
        unit.heading = GetHeadingFromVector_2d(to.x - from.x, to.y - from.y)
        CodUnits.aimGun(unit)
    end
    local line = to - from
    local distance = #line
    if distance <= CodUnits.MUZZLE_OFFSET then return end
    local direction = line / distance
    local muzzle = from + direction * CodUnits.MUZZLE_OFFSET
    if not unit.settings.aircraft then muzzle = muzzle + vector3(0.0, 0.0, unit.settings.gunHeight) end
    local aim = to
    if data.target == Cod.match.self then aim = to + vector3(-direction.y, direction.x, 0.0) * CodUnits.TARGET_MISS end
    ShootSingleBulletBetweenCoords(muzzle.x, muzzle.y, muzzle.z, aim.x, aim.y, aim.z, 0, true, CodUnits.BULLET, 0, true, false, -1.0)
    -- La balle part loin du modèle pour ne pas le toucher ; la flamme, elle, reste au bout du canon
    local tip = muzzle
    if unit.settings.barrelLength then
        tip = from + direction * unit.settings.barrelLength + vector3(0.0, 0.0, unit.settings.gunHeight)
    end
    CodUnits.showShot(unit, tip, direction, to, data.gunfire)
end

---Une balle du jeu se voit à peine : flamme à la bouche du canon et traçante jusqu'au point visé.
---@param unit table
---@param muzzle vector3 départ de la balle
---@param direction vector3
---@param to vector3
---@param gunfire boolean|nil arme d'un pilote qui tire des balles (pas d'obus explosifs)
function CodUnits.showShot(unit, muzzle, direction, to, gunfire)
    local start = unit.gunMuzzle or unit.muzzleBone and GetWorldPositionOfEntityBone(unit.entity, unit.muzzleBone) or muzzle
    if HasNamedPtfxAssetLoaded('core') then
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedAtCoord(CodUnits.MUZZLE_FLASH, start.x, start.y, start.z,
            0.0, 0.0, GetHeadingFromVector_2d(direction.x, direction.y) + 90.0,
            unit.gunMuzzle and unit.settings.doorGun.flashScale or CodUnits.FLASH_SCALE, false, false, false)
    end
    CodUnits.tracers[#CodUnits.tracers + 1] = { from = start, to = to, untilAt = GetGameTimer() + CodUnits.TRACER_TIME }
    if unit.gunMuzzle then
        Nui.send('codGunfire', { id = unit.id, volume = unit.settings.doorGun.volume })
    elseif gunfire or not unit.settings.piloted then
        -- Depuis la caméra : un pilote entend son appareil, pas ce qui entoure son personnage
        local proximity = 1.0 - #(GetFinalRenderedCamCoord() - start) / CodUnits.GUN_RANGE
        if proximity > 0.0 then Nui.send('codGunfire', { id = unit.id, volume = proximity * proximity }) end
    end
end

---@param now integer
function CodUnits.drawTracers(now)
    for index = #CodUnits.tracers, 1, -1 do
        local tracer = CodUnits.tracers[index]
        if now >= tracer.untilAt then
            table.remove(CodUnits.tracers, index)
        else
            DrawLine(tracer.from.x, tracer.from.y, tracer.from.z, tracer.to.x, tracer.to.y, tracer.to.z, 255, 214, 130, 230)
        end
    end
end

-- ---------------------------------------------------------------------------
-- À chaque image
-- ---------------------------------------------------------------------------

---@param now integer
function CodUnits.frame(now)
    CodUnits.drawTracers(now)
    if not next(CodUnits.units) then return end
    for _, unit in pairs(CodUnits.units) do
        if unit.radius and unit.entity and DoesEntityExist(unit.entity) then
            local coords, heading = CodUnits.position(unit, now)
            SetEntityCoordsNoOffset(unit.entity, coords.x, coords.y, coords.z, false, false, false)
            SetEntityHeading(unit.entity, heading)
        end
        if unit.owned and not unit.settings.piloted and not Cod.ended and now >= unit.nextShot then
            CodUnits.updateTarget(unit, now)
        end
    end
    CodUnits.checkPlayerShots(now)
end

---@param unit table
---@param now integer
function CodUnits.updateTarget(unit, now)
    local target = CodUnits.findTarget(unit, now)
    unit.nextShot = now + (target and unit.settings.interval or CodUnits.SEARCH_INTERVAL)
    if target then TriggerServerEvent(Events.server.codUnitFire, unit.id, target) end
end

---@param unit table
---@param now integer
---@return integer|nil server id de l'ennemi visible le plus proche
function CodUnits.findTarget(unit, now)
    local settings = unit.settings
    local from = CodUnits.position(unit, now)
    if not settings.aircraft then from = from + vector3(0.0, 0.0, settings.gunHeight + 0.3) end

    local mates = {}
    for _, id in ipairs(Cod.mates) do mates[id] = true end
    local me = PlayerId()
    local best, bestDistance = nil, settings.range or math.huge
    for _, player in ipairs(GetActivePlayers()) do
        local id = GetPlayerServerId(player)
        local ped = GetPlayerPed(player)
        if player ~= me and not mates[id] and not IsPedDeadOrDying(ped, true) then
            local coords = GetEntityCoords(ped)
            local distance = #(coords - from)
            if distance < bestDistance and CodUnits.canSee(unit, from, coords) then
                best, bestDistance = id, distance
            end
        end
    end
    return best
end

---@param unit table
---@param from vector3
---@param to vector3
---@return boolean
function CodUnits.canSee(unit, from, to)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, CodUnits.SIGHT_FLAGS, unit.entity or 0, 7)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    return hit == 0 or entity == unit.entity
end

---Le joueur tire : le rayon de sa caméra touche-t-il une unité ennemie ? Un test de rayon plutôt que les dégâts
---du jeu : la copie locale de l'unité est invincible, et rien de local ne doit pouvoir l'abîmer ou la détruire.
---@param now integer
function CodUnits.checkPlayerShots(now)
    if now < CodUnits.nextHitCheck then return end
    local ped = PlayerPedId()
    if not IsPedShooting(ped) then return end
    CodUnits.nextHitCheck = now + CodUnits.HIT_INTERVAL

    local from = GetGameplayCamCoord()
    local to = from + CodEffects.camDirection() * CodUnits.HIT_DISTANCE
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, CodUnits.HIT_FLAGS, ped, 7)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    if hit ~= 1 then return end
    for _, unit in pairs(CodUnits.units) do
        if not unit.friendly and entity == unit.entity then
            TriggerServerEvent(Events.server.codUnitHit, unit.id)
            return
        end
    end
end
