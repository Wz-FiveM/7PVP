---Hitmarker et dégâts infligés. Seul le propriétaire de la victime connaît ses dégâts exacts :
---le joueur touché (ou le client qui pilote le zombie touché) mesure la vie et l'armure perdues,
---les attribue au joueur qui a tiré et les signale au serveur, qui prévient le tireur.
---Le tireur affiche alors le hitmarker et le nombre.
---@class HitsModule
local Hits = PVP.define('Hits')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Events = PVP.use('Events')
local Pve = PVP.use('Pve')

Hits.HEAD_BONE = 31086 -- SKEL_Head
-- Écart max (ms) entre la baisse de vie et l'événement de dégâts du jeu pour les associer
-- (les deux n'arrivent pas toujours dans la même image)
Hits.ATTRIBUTION_WINDOW = 250

Hits.health = 0
Hits.armor = 0
-- Dégâts mesurés pas encore attribués : { health, armor, at }
Hits.pendingDamage = nil
-- Dernier joueur qui nous a touchés : { serverId, headshot, fatal, at }
Hits.pendingAttacker = nil
-- Vie et gilet connus des zombies dont ce client est propriétaire : [ped] = { health, armor }
Hits.zombieHealth = {}

function Hits.init()
    AddEventHandler('gameEventTriggered', function(name, args)
        if name == 'CEventNetworkEntityDamage' then
            Hits.onDamageEvent(args)
        end
    end)
    RegisterNetEvent(Events.client.hitConfirm, function(hit)
        Hits.onConfirm(hit)
    end)
    -- Statut « en combat » (server/modules/combat/combat_tag_service.lua), 0 = terminé
    RegisterNetEvent(Events.client.combatTag, function(seconds)
        Nui.send('combat', { seconds = tonumber(seconds) or 0 })
    end)
    CreateThread(Hits.trackLoop)
end

-- ---------------------------------------------------------------------------
-- Joueur touché
-- ---------------------------------------------------------------------------

---Vie (au-dessus du seuil de mort) et armure, relevées à chaque image.
function Hits.trackLoop()
    Hits.snapshot()
    while true do
        Wait(0)
        Hits.measure()
        Hits.flush()
    end
end

function Hits.snapshot()
    local ped = PlayerPedId()
    Hits.health = math.max(0, GetEntityHealth(ped) - 100)
    Hits.armor = GetPedArmour(ped)
end

---Ajoute aux dégâts en attente ce qui a été perdu depuis la dernière image.
function Hits.measure()
    local health, armor = Hits.health, Hits.armor
    Hits.snapshot()
    local lostHealth = math.max(0, health - Hits.health)
    local lostArmor = math.max(0, armor - Hits.armor)
    if lostHealth + lostArmor == 0 then return end

    local pending = Hits.pendingDamage or { health = 0, armor = 0 }
    pending.health = pending.health + lostHealth
    pending.armor = pending.armor + lostArmor
    pending.at = GetGameTimer()
    Hits.pendingDamage = pending
end

---@param args table victime, attaquant, ..., [6] mortel, [7] arme
function Hits.onDamageEvent(args)
    if not State.mode then return end
    local victim = args[1]
    local attacker = Hits.resolveAttacker(args[2])
    if not attacker or attacker == victim then return end

    if victim == PlayerPedId() then
        Hits.onPlayerDamaged(victim, attacker, args[6] == 1)
    elseif Hits.zombieHealth[victim] ~= nil then
        -- Zombie dont ce client est propriétaire : lui seul connaît sa vie exacte
        CreateThread(function()
            Hits.onZombieDamaged(victim, attacker, args[6] == 1)
        end)
    end
end

---Joueur à l'origine des dégâts (conducteur si c'est un véhicule), ou nil.
---@param entity integer
---@return integer|nil ped du joueur
function Hits.resolveAttacker(entity)
    if entity ~= 0 and IsEntityAVehicle(entity) then
        entity = GetPedInVehicleSeat(entity, -1)
    end
    if entity == 0 or not IsPedAPlayer(entity) then return nil end
    return entity
end

---@param ped integer
---@return boolean
function Hits.isHeadshot(ped)
    local hasBone, bone = GetPedLastDamageBone(ped)
    return hasBone and bone == Hits.HEAD_BONE
end

---@param ped integer ped local
---@param attacker integer ped du joueur
---@param fatal boolean
function Hits.onPlayerDamaged(ped, attacker, fatal)
    Hits.pendingAttacker = {
        serverId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(attacker)),
        headshot = Hits.isHeadshot(ped),
        fatal = fatal or IsEntityDead(ped),
        at = GetGameTimer(),
    }
    Hits.flush()
end

---Associe les dégâts mesurés au dernier attaquant, ou les oublie (chute, zombie...).
function Hits.flush()
    local damage, attacker = Hits.pendingDamage, Hits.pendingAttacker
    local now = GetGameTimer()

    if damage and attacker and math.abs(damage.at - attacker.at) <= Hits.ATTRIBUTION_WINDOW then
        TriggerServerEvent(Events.server.hitReport, attacker.serverId, {
            health = damage.health,
            armor = damage.armor,
            headshot = attacker.headshot,
            fatal = attacker.fatal or IsEntityDead(PlayerPedId()),
        })
        Hits.pendingDamage, Hits.pendingAttacker = nil, nil
        return
    end

    if damage and now - damage.at > Hits.ATTRIBUTION_WINDOW then Hits.pendingDamage = nil end
    if attacker and now - attacker.at > Hits.ATTRIBUTION_WINDOW then Hits.pendingAttacker = nil end
end

-- ---------------------------------------------------------------------------
-- Zombies (mesurés par le client propriétaire, voir client/modules/pve/pve.lua)
-- ---------------------------------------------------------------------------

---@param ped integer
---@return integer vie au-dessus du seuil de mort
function Hits.effectiveHealth(ped)
    return math.max(0, GetEntityHealth(ped) - 100)
end

---@param ped integer
---@return { health: integer, armor: integer }
function Hits.zombieSnapshot(ped)
    return { health = Hits.effectiveHealth(ped), armor = GetPedArmour(ped) }
end

---Commence à suivre la vie (et le gilet) d'un zombie dont ce client vient de devenir propriétaire.
---@param ped integer
function Hits.watchZombie(ped)
    if Hits.zombieHealth[ped] == nil then
        Hits.zombieHealth[ped] = Hits.zombieSnapshot(ped)
    end
end

function Hits.pruneZombies()
    for ped in pairs(Hits.zombieHealth) do
        if not DoesEntityExist(ped) or NetworkGetEntityOwner(ped) ~= PlayerId() then
            Hits.zombieHealth[ped] = nil
        end
    end
end

---La vie est relue une image plus tard : selon l'ordre de traitement, l'événement peut
---arriver avant que les dégâts soient appliqués. Les plombs d'une même décharge ne comptent
---qu'une fois (les suivants voient une vie déjà à jour).
---@param ped integer zombie
---@param attacker integer ped du joueur
---@param fatal boolean
function Hits.onZombieDamaged(ped, attacker, fatal)
    Wait(0)
    if not DoesEntityExist(ped) or Hits.zombieHealth[ped] == nil then return end

    local known, current = Hits.zombieHealth[ped], Hits.zombieSnapshot(ped)
    Hits.zombieHealth[ped] = current
    local lost = math.max(0, known.health - current.health)
    local lostArmor = math.max(0, known.armor - current.armor)
    if lost + lostArmor == 0 then return end

    local hit = {
        damage = lost,
        armor = lostArmor,
        headshot = Hits.isHeadshot(ped),
        fatal = fatal or IsEntityDead(ped),
    }
    -- Casque des zombies équipés
    Pve.onZombieHit(ped, hit)
    if attacker == PlayerPedId() then
        -- C'est nous qui avons tiré : pas besoin de passer par le serveur
        Nui.send('hit', hit)
    else
        TriggerServerEvent(Events.server.npcHitReport, GetPlayerServerId(NetworkGetPlayerIndexFromPed(attacker)),
            NetworkGetNetworkIdFromEntity(ped), hit)
    end
end

-- ---------------------------------------------------------------------------
-- Tireur
-- ---------------------------------------------------------------------------

---@param hit table { damage, armor, headshot, fatal } validé par le serveur
function Hits.onConfirm(hit)
    if type(hit) ~= 'table' then return end
    Nui.send('hit', hit)
end
