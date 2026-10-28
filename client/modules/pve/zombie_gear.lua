---Équipement visible des zombies spéciaux (casque, bouteille de gaz...) et ses effets.
---Les objets sont locaux : chaque client les crée sur les zombies qu'il voit. Le client
---propriétaire du zombie gère les effets (casque qui saute, explosion) et les partage
---par state bag ; les autres clients font tomber ou retirer la pièce en conséquence.
---@class ZombieGearModule
local ZombieGear = PVP.define('ZombieGear')
local PedUtils = PVP.use('PedUtils')

ZombieGear.DROPPED_LIFETIME = 10000 -- ms avant suppression d'une pièce tombée au sol
ZombieGear.MODEL_TIMEOUT = 3000

ZombieGear.attached = {} -- [ped] = { [pieceId] = objet }
ZombieGear.loading = {} -- [ped] = true pendant le chargement des modèles

---Crée l'équipement du zombie (une fois par client) puis retire les pièces perdues.
---@param ped integer
---@param zombieType table entrée de Config.ZombieTypes
function ZombieGear.update(ped, zombieType)
    if not zombieType.gear then return end
    if not ZombieGear.attached[ped] then
        ZombieGear.equip(ped, zombieType)
        return
    end

    local state = Entity(ped).state
    for pieceId, object in pairs(ZombieGear.attached[ped]) do
        local piece = Config.ZombieGear[pieceId]
        if state[piece.dropWhen] then
            ZombieGear.attached[ped][pieceId] = nil
            ZombieGear.drop(object, piece)
        end
    end
end

---@param ped integer
---@param zombieType table
function ZombieGear.equip(ped, zombieType)
    if ZombieGear.loading[ped] then return end
    ZombieGear.loading[ped] = true
    CreateThread(function()
        local objects = {}
        for _, pieceId in ipairs(zombieType.gear) do
            objects[pieceId] = ZombieGear.createPiece(ped, pieceId)
        end
        ZombieGear.loading[ped] = nil
        if DoesEntityExist(ped) then
            ZombieGear.attached[ped] = objects
        else
            ZombieGear.deleteAll(objects)
        end
    end)
end

---Le même modèle est choisi sur tous les clients (d'après l'identifiant réseau du zombie).
---@param ped integer
---@param pieceId string clé de Config.ZombieGear
---@return integer|nil objet attaché
function ZombieGear.createPiece(ped, pieceId)
    local piece = Config.ZombieGear[pieceId]
    if not piece then return nil end
    local option = piece.options[NetworkGetNetworkIdFromEntity(ped) % #piece.options + 1]
    local model = GetHashKey(option.model)
    if not IsModelInCdimage(model) or not PedUtils.loadModel(model, ZombieGear.MODEL_TIMEOUT) then return nil end
    if not DoesEntityExist(ped) then return nil end

    local coords = GetEntityCoords(ped)
    local object = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    -- Sans collision : les balles touchent le zombie, pas l'objet
    AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, option.bone), option.pos.x, option.pos.y, option.pos.z,
        option.rot.x, option.rot.y, option.rot.z, true, true, false, false, 2, true)
    return object
end

---Pièce perdue : elle tombe au sol puis disparaît, ou disparaît tout de suite (`remove`).
---@param object integer
---@param piece table entrée de Config.ZombieGear
function ZombieGear.drop(object, piece)
    if not DoesEntityExist(object) then return end
    if piece.remove then
        DeleteEntity(object)
        return
    end
    DetachEntity(object, true, true)
    SetEntityCollision(object, true, true)
    ApplyForceToEntity(object, 1, 0.0, 0.0, 2.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    SetTimeout(ZombieGear.DROPPED_LIFETIME, function()
        if DoesEntityExist(object) then DeleteEntity(object) end
    end)
end

---@param objects table<string, integer>
function ZombieGear.deleteAll(objects)
    for _, object in pairs(objects) do
        if DoesEntityExist(object) then DeleteEntity(object) end
    end
end

---Supprime l'équipement des zombies qui n'existent plus.
function ZombieGear.cleanup()
    for ped, objects in pairs(ZombieGear.attached) do
        if not DoesEntityExist(ped) then
            ZombieGear.deleteAll(objects)
            ZombieGear.attached[ped] = nil
        end
    end
end

-- ---------------------------------------------------------------------------
-- Effets (client propriétaire du zombie)
-- ---------------------------------------------------------------------------

---Tant que le casque tient, un tir dans la tête ne tue pas d'un coup.
---@param ped integer
---@param zombieType table
function ZombieGear.setupOwned(ped, zombieType)
    if zombieType.helmet and not Entity(ped).state.helmetOff then
        SetPedSuffersCriticalHits(ped, false)
    end
end

---Touche mesurée par le client propriétaire (voir Hits.onZombieDamaged) : le casque
---encaisse les tirs dans la tête puis saute.
---@param ped integer
---@param zombieType table
---@param hit { headshot: boolean, fatal: boolean }
function ZombieGear.onHit(ped, zombieType, hit)
    local state = Entity(ped).state
    if not zombieType.helmet or not hit.headshot or hit.fatal or state.helmetOff then return end

    local hits = (state.helmetHits or 0) + 1
    state:set('helmetHits', hits, true)
    if hits >= zombieType.helmet.hits then
        state:set('helmetOff', true, true)
        SetPedSuffersCriticalHits(ped, true)
    end
end

---La bouteille de gaz explose peu après la mort du zombie (une seule fois, même si le
---corps change de propriétaire).
---@param ped integer
---@param zombieType table
function ZombieGear.onDeath(ped, zombieType)
    local explosion = zombieType.explosion
    if not explosion then return end
    CreateThread(function()
        Wait(explosion.delay)
        if not DoesEntityExist(ped) or Entity(ped).state.gasExploded then return end
        Entity(ped).state:set('gasExploded', true, true)
        local coords = GetEntityCoords(ped)
        AddExplosion(coords.x, coords.y, coords.z, explosion.type, explosion.damage, true, false, explosion.shake)
    end)
end
