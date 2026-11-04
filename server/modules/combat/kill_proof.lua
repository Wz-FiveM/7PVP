---Preuves qu'un joueur en a vraiment touché ou tué un autre. C'est la victime qui désigne son tueur :
---sans ce contrôle, deux complices pourraient se déclarer des kills à distance pour gagner argent et XP.
---Les preuves viennent de ce que le serveur voit passer (touches et explosions du tireur, vie de la victime).
---@class KillProofModule
local KillProof = PVP.define('KillProof')

-- GTA : un personnage meurt à cette santé
KillProof.DEAD_HEALTH = 100
-- La mort annoncée peut arriver avant la vie synchronisée de la victime (ms)
KillProof.SYNC_TIMEOUT = 2000
KillProof.SYNC_INTERVAL = 100
-- Une touche prouve un kill pendant ce temps (ms) : feu, saignement, chute juste après
KillProof.HIT_WINDOW = 20000
KillProof.EXPLOSION_RANGE = 30.0
-- Un véhicule qui percute ne passe pas par les touches : le hitmarker est relayé à cette distance (m)
KillProof.VEHICLE_RANGE = 15.0
KillProof.VEHICLE_FIRST_SEAT = -1
KillProof.VEHICLE_LAST_SEAT = 6
KillProof.VEHICLE_WEAPONS = { 'WEAPON_RUN_OVER_BY_CAR', 'WEAPON_RAMMED_BY_CAR' }

---@type table<integer, table<integer, { at: integer, weapon: any }>> [victime][tireur] = dernière touche
KillProof.hits = {}
---@type table<integer, { at: integer, coords: vector3 }[]> explosions récentes par joueur
KillProof.explosions = {}

function KillProof.init()
    AddEventHandler('weaponDamageEvent', function(sender, data)
        KillProof.onWeaponDamage(sender, data)
    end)
    AddEventHandler('explosionEvent', function(sender, data)
        KillProof.onExplosion(sender, data)
    end)
    AddEventHandler('playerDropped', function()
        KillProof.forget(source)
    end)
end

---@param source integer
function KillProof.forget(source)
    KillProof.hits[source] = nil
    KillProof.explosions[source] = nil
    for _, attackers in pairs(KillProof.hits) do attackers[source] = nil end
end

-- ---------------------------------------------------------------------------
-- Ce que le serveur voit passer
-- ---------------------------------------------------------------------------

---@param attacker integer
---@param ped integer
---@param weapon any
function KillProof.recordPed(attacker, ped, weapon)
    local victim = NetworkGetEntityOwner(ped)
    if not victim or victim == attacker or GetPlayerPed(victim) ~= ped then return end
    KillProof.hits[victim] = KillProof.hits[victim] or {}
    KillProof.hits[victim][attacker] = { at = GetGameTimer(), weapon = weapon }
end

---Une touche sur un véhicule compte pour ses occupants : il peut exploser avec eux dedans.
---@param sender integer|string le jeu l'envoie en texte, les preuves sont indexées par nombre
---@param data table hitGlobalId ou hitGlobalIds (selon la version du serveur), weaponType
function KillProof.onWeaponDamage(sender, data)
    sender = tonumber(sender)
    if not sender or type(data) ~= 'table' then return end
    for _, netId in ipairs(data.hitGlobalIds or { data.hitGlobalId }) do
        local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
        if entity ~= 0 and DoesEntityExist(entity) then
            local entityType = GetEntityType(entity)
            if entityType == 1 then
                KillProof.recordPed(sender, entity, data.weaponType)
            elseif entityType == 2 then
                for seat = KillProof.VEHICLE_FIRST_SEAT, KillProof.VEHICLE_LAST_SEAT do
                    local ped = GetPedInVehicleSeat(entity, seat)
                    if ped ~= 0 then KillProof.recordPed(sender, ped, data.weaponType) end
                end
            end
        end
    end
end

---@param sender integer|string le jeu l'envoie en texte, les preuves sont indexées par nombre
---@param data table posX, posY, posZ
function KillProof.onExplosion(sender, data)
    sender = tonumber(sender)
    if not sender or type(data) ~= 'table' or not tonumber(data.posX) or not tonumber(data.posY) or not tonumber(data.posZ) then return end
    local now = GetGameTimer()
    local kept = {}
    for _, explosion in ipairs(KillProof.explosions[sender] or {}) do
        if now - explosion.at <= KillProof.HIT_WINDOW then kept[#kept + 1] = explosion end
    end
    kept[#kept + 1] = { at = now, coords = vector3(tonumber(data.posX), tonumber(data.posY), tonumber(data.posZ)) }
    KillProof.explosions[sender] = kept
end

-- ---------------------------------------------------------------------------
-- Contrôles
-- ---------------------------------------------------------------------------

---Attend que le serveur voie l'entité morte. À appeler depuis un thread.
---@param entity integer
---@return boolean false si elle est encore en vie à la fin du délai, ou a disparu
function KillProof.awaitDeath(entity)
    local limit = GetGameTimer() + KillProof.SYNC_TIMEOUT
    while DoesEntityExist(entity) do
        if GetEntityHealth(entity) <= KillProof.DEAD_HEALTH then return true end
        if GetGameTimer() >= limit then return false end
        Wait(KillProof.SYNC_INTERVAL)
    end
    return false
end

---@param attacker integer
---@param victim integer
---@return boolean le serveur a vu une explosion de ce joueur près de la victime
function KillProof.hasExplosion(attacker, victim)
    local coords = GetEntityCoords(GetPlayerPed(victim))
    local now = GetGameTimer()
    for _, explosion in ipairs(KillProof.explosions[attacker] or {}) do
        if now - explosion.at <= KillProof.HIT_WINDOW and #(explosion.coords - coords) <= KillProof.EXPLOSION_RANGE then
            return true
        end
    end
    return false
end

---@param attacker integer
---@param victim integer
---@return { at: integer, weapon: any }|nil dernière touche récente
function KillProof.recentHit(attacker, victim)
    local hit = KillProof.hits[victim] and KillProof.hits[victim][attacker]
    return hit and GetGameTimer() - hit.at <= KillProof.HIT_WINDOW and hit or nil
end

---@param hash any
---@return integer hash non signé (les natives renvoient parfois un entier signé)
function KillProof.unsigned(hash)
    return math.floor(tonumber(hash) or 0) & 0xFFFFFFFF
end

---@param ped integer victime
---@return boolean sa mort synchronisée vient d'un véhicule (écrasée ou percutée)
function KillProof.isVehicleDeath(ped)
    local cause = KillProof.unsigned(GetPedCauseOfDeath(ped))
    for _, name in ipairs(KillProof.VEHICLE_WEAPONS) do
        if KillProof.unsigned(GetHashKey(name)) == cause then return true end
    end
    return false
end

---La victime a été écrasée par ce joueur : c'est ce qu'indique la cause de sa mort synchronisée.
---@param ped integer victime
---@param killerPed integer
---@return boolean
function KillProof.isRunOver(ped, killerPed)
    if not KillProof.isVehicleDeath(ped) then return false end

    local origin = GetPedSourceOfDeath(ped)
    if origin == 0 then return false end
    return origin == killerPed or origin == GetVehiclePedIsIn(killerPed, false) or origin == GetVehiclePedIsIn(killerPed, true)
end

---Le kill annoncé par la victime est-il réel ? À appeler depuis un thread : attend la mort synchronisée.
---@param victim integer
---@param killer integer
---@return { weapon: any }|nil preuve, avec l'arme vue par le serveur
function KillProof.confirm(victim, killer)
    local ped, killerPed = GetPlayerPed(victim), GetPlayerPed(killer)
    if ped == 0 or killerPed == 0 or not KillProof.awaitDeath(ped) then return nil end

    local hit = KillProof.recentHit(killer, victim)
    if hit then return { weapon = hit.weapon } end
    if KillProof.hasExplosion(killer, victim) or KillProof.isRunOver(ped, killerPed) then
        return { weapon = GetPedCauseOfDeath(ped) }
    end
    return nil
end

---Le joueur touché signale son tireur (hitmarker, statut « en combat ») : il ne peut pas en accuser un autre.
---@param attacker integer
---@param victim integer
---@return boolean
function KillProof.canReportHit(attacker, victim)
    if KillProof.recentHit(attacker, victim) or KillProof.hasExplosion(attacker, victim) then return true end
    local attackerPed = GetPlayerPed(attacker)
    return GetVehiclePedIsIn(attackerPed, false) ~= 0
        and #(GetEntityCoords(attackerPed) - GetEntityCoords(GetPlayerPed(victim))) <= KillProof.VEHICLE_RANGE
end
