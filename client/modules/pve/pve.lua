---Zombies des zones PvE. Seul le client propriétaire (au sens réseau) d'un zombie
---le pilote : poursuite du joueur le plus proche, vomissement au contact, signalement de sa mort.
---Le vomi est validé par le serveur puis joué chez tous les joueurs proches ; la cible subit les dégâts.
---@class PveModule
local Pve = PVP.define('Pve')
local State = PVP.use('State')
local Zones = PVP.use('Zones')
local PedUtils = PVP.use('PedUtils')
local Hits = PVP.use('Hits')
local Clock = PVP.use('Clock')
local Effects = PVP.use('Effects')
local Events = PVP.use('Events')

Pve.SCAN_INTERVAL = 250
Pve.RETASK_INTERVAL = 2000 -- relance la poursuite pour suivre une cible qui bouge
Pve.ASSET_TIMEOUT = 3000
Pve.HEAD_BONE = 31086 -- SKEL_Head
Pve.SCREEN_EFFECT_TIME = 1200

Pve.npcGroup = 0
Pve.configured = {} -- [ped] = true quand le comportement zombie a été appliqué sur ce client
Pve.reported = {} -- [ped] = true quand la mort a été signalée
Pve.wandering = {} -- [ped] = true quand le zombie erre sans cible
Pve.chasing = {} -- [ped] = { target = ped du joueur, at = ms } poursuite en cours
Pve.lastAttack = {} -- [ped] = ms du dernier vomissement lancé par ce client
Pve.decorated = {} -- [ped] = true quand les blessures visuelles sont appliquées

function Pve.init()
    Pve.setupRelationships()
    RegisterNetEvent(Events.client.zombieVomit, function(netId, targetId, damage)
        Pve.onVomit(netId, targetId, damage)
    end)
    CreateThread(Pve.loop)
end

function Pve.setupRelationships()
    local _, group = AddRelationshipGroup('PVP_ZOMBIE')
    local playerGroup = GetHashKey('PLAYER')
    Pve.npcGroup = group
    SetRelationshipBetweenGroups(5, group, playerGroup)
    SetRelationshipBetweenGroups(5, playerGroup, group)
    SetRelationshipBetweenGroups(0, group, group)
end

function Pve.loop()
    Pve.loadAssets()
    while true do
        Wait(Pve.SCAN_INTERVAL)
        Pve.scan()
        Pve.cleanup()
    end
end

---Démarche et animation, chargées une fois pour toutes.
function Pve.loadAssets()
    RequestClipSet(Config.Zombie.walkStyle)
    RequestAnimDict(Config.Zombie.anim.dict)
    local limit = GetGameTimer() + Pve.ASSET_TIMEOUT
    while (not HasClipSetLoaded(Config.Zombie.walkStyle) or not HasAnimDictLoaded(Config.Zombie.anim.dict))
        and GetGameTimer() < limit do
        Wait(0)
    end
end

function Pve.scan()
    local myId = PlayerId()
    for _, ped in ipairs(GetGamePool('CPed')) do
        if NetworkGetEntityIsNetworked(ped) and not IsPedAPlayer(ped) then
            local zone = Zones.byId(Entity(ped).state.pvpNpc)
            if zone then
                Pve.decorate(ped)
                if NetworkGetEntityOwner(ped) == myId then
                    Pve.updatePed(ped, zone)
                end
            end
        end
    end
end

function Pve.cleanup()
    for _, tracked in ipairs({ Pve.configured, Pve.reported, Pve.wandering, Pve.chasing, Pve.lastAttack, Pve.decorated }) do
        for ped in pairs(tracked) do
            if not DoesEntityExist(ped) then tracked[ped] = nil end
        end
    end
    Hits.pruneZombies()
end

---Sang et blessures : purement visuel, appliqué par chaque client qui voit le zombie.
---@param ped integer
function Pve.decorate(ped)
    if Pve.decorated[ped] then return end
    Pve.decorated[ped] = true
    for _, pack in ipairs(Config.Zombie.damagePacks) do
        ApplyPedDamagePack(ped, pack, 0.0, 1.0)
    end
end

---@param ped integer
---@param zone table
function Pve.updatePed(ped, zone)
    if IsEntityDead(ped) then
        Pve.reportDeath(ped)
        return
    end

    if not Pve.configured[ped] then
        Pve.setupPed(ped, zone.npc)
        Pve.configured[ped] = true
    end
    -- Vie suivie ici pour afficher les dégâts infligés au tireur (hitmarker)
    Hits.watchZombie(ped)

    if Pve.isAttacking(ped) then return end
    Pve.updateBehaviour(ped, zone)
end

---@param ped integer
function Pve.reportDeath(ped)
    if Pve.reported[ped] then return end
    Pve.reported[ped] = true
    TriggerServerEvent(Events.server.npcDied, NetworkGetNetworkIdFromEntity(ped), PedUtils.getKillerServerId(ped))
end

---@param ped integer
---@return table entrée de Config.ZombieTypes
function Pve.getType(ped)
    return Config.ZombieTypes[Entity(ped).state.zombieType] or Config.ZombieTypes.walker
end

---@param ped integer
---@param npc table bloc `npc` de la zone
function Pve.setupPed(ped, npc)
    local state = Entity(ped).state
    local zombieType = Pve.getType(ped)

    -- La vie n'est appliquée qu'une fois, sinon un changement de propriétaire la remettrait au max.
    -- Elle compte au-dessus du seuil de mort (100) : un zombie à 200 a 100 points de vie.
    if not state.pvpNpcReady then
        local night = Clock.isNight() and Config.Night.healthMultiplier or 1.0
        local health = 100 + math.floor((npc.health - 100) * zombieType.health * night)
        SetPedMaxHealth(ped, health)
        SetEntityHealth(ped, health)
        state:set('pvpNpcReady', true, true)
    end
    if zombieType == Config.ZombieTypes.tank then
        -- Le colosse ne tombe pas et encaisse les tirs à la tête
        SetPedCanRagdoll(ped, false)
        SetPedSuffersCriticalHits(ped, false)
    end

    SetPedRelationshipGroupHash(ped, Pve.npcGroup)
    RemoveAllPedWeapons(ped, true)
    SetPedCanSwitchWeapon(ped, false)
    SetPedDropsWeaponsWhenDead(ped, false)
    -- Ignore les tirs, les cris et la peur : le zombie ne fait que poursuivre
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedKeepTask(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedConfigFlag(ped, 281, true) -- pas d'agonie au sol : il tombe d'un coup
    StopPedSpeaking(ped, true)
    DisablePedPainAudio(ped, true)
    if HasClipSetLoaded(Config.Zombie.walkStyle) then
        SetPedMovementClipset(ped, Config.Zombie.walkStyle, 1.0)
    end
end

---Poursuit le joueur le plus proche et vomit à son contact, sinon erre dans la zone.
---@param ped integer
---@param zone table
function Pve.updateBehaviour(ped, zone)
    local target, distance = Pve.findTarget(ped)
    if not target then
        Pve.chasing[ped] = nil
        if not Pve.wandering[ped] then
            Pve.wandering[ped] = true
            TaskWanderInArea(ped, zone.coords.x, zone.coords.y, zone.coords.z, zone.radius * 0.6, 2.0, 5.0)
        end
        return
    end

    Pve.wandering[ped] = nil
    local zombieType = Pve.getType(ped)
    local range = zombieType.range or Config.Zombie.attackRange
    -- Le cracheur vomit de loin, mais seulement s'il voit sa cible
    if distance <= range and (distance <= Config.Zombie.attackRange or HasEntityClearLosToEntity(ped, target.ped, 17)) then
        Pve.tryAttack(ped, target, zombieType)
    else
        Pve.chase(ped, target, Pve.getSpeed(zombieType, zone), range)
    end
end

---La nuit, les zombies vont plus vite (3.0 = sprint au maximum).
---@param zombieType table
---@param zone table
---@return number
function Pve.getSpeed(zombieType, zone)
    local speed = zombieType.speed or zone.npc.speed or 1.0
    if Clock.isNight() then speed = speed + Config.Night.speedBonus end
    return math.min(3.0, speed)
end

---Joueur vivant et visible le plus proche, à portée de détection.
---@param ped integer
---@return { ped: integer, serverId: integer }|nil target, number distance
function Pve.findTarget(ped)
    local coords = GetEntityCoords(ped)
    local best, bestDistance = nil, Config.Zombie.aggroRange
    for _, player in ipairs(GetActivePlayers()) do
        local playerPed = GetPlayerPed(player)
        -- Les admins invisibles (noclip) ne sont pas repérés
        if not IsPedDeadOrDying(playerPed, true) and IsEntityVisible(playerPed) then
            local distance = #(GetEntityCoords(playerPed) - coords)
            if distance <= bestDistance then
                best = { ped = playerPed, serverId = GetPlayerServerId(player) }
                bestDistance = distance
            end
        end
    end
    return best, bestDistance
end

---@param ped integer
---@param target { ped: integer }
---@param speed number 1.0 marche, 2.0 course, 3.0 sprint
---@param range number distance d'attaque : le zombie s'arrête un peu avant
function Pve.chase(ped, target, speed, range)
    local now = GetGameTimer()
    local current = Pve.chasing[ped]
    if current and current.target == target.ped and now - current.at < Pve.RETASK_INTERVAL then return end

    Pve.chasing[ped] = { target = target.ped, at = now }
    TaskGoToEntity(ped, target.ped, -1, range * 0.6, speed, 1073741824, 0)
end

---@param ped integer
---@return boolean animation de vomi en cours
function Pve.isAttacking(ped)
    local last = Pve.lastAttack[ped]
    return last ~= nil and GetGameTimer() - last < Config.Zombie.vomitDuration
end

---Se tourne vers la cible, joue l'animation et demande au serveur de valider l'attaque.
---@param ped integer
---@param target { ped: integer, serverId: integer }
---@param zombieType table
function Pve.tryAttack(ped, target, zombieType)
    local now = GetGameTimer()
    if now - (Pve.lastAttack[ped] or 0) < (zombieType.cooldown or Config.Zombie.attackCooldown) then return end
    Pve.lastAttack[ped] = now
    Pve.chasing[ped] = nil

    local offset = GetEntityCoords(target.ped) - GetEntityCoords(ped)
    ClearPedTasks(ped)
    SetEntityHeading(ped, GetHeadingFromVector_2d(offset.x, offset.y))
    TaskPlayAnim(ped, Config.Zombie.anim.dict, Config.Zombie.anim.name, 8.0, -8.0, Config.Zombie.vomitDuration,
        0, 0.0, false, false, false)

    TriggerServerEvent(Events.server.zombieAttack, NetworkGetNetworkIdFromEntity(ped), target.serverId)
end

-- ---------------------------------------------------------------------------
-- Vomi validé par le serveur (reçu par tous les joueurs proches)
-- ---------------------------------------------------------------------------

---@param netId integer
---@param targetId integer server id du joueur touché
---@param damage integer dégâts calculés par le serveur selon le type de zombie
function Pve.onVomit(netId, targetId, damage)
    if NetworkDoesNetworkIdExist(netId) then
        local ped = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(ped) then
            CreateThread(function()
                Pve.playVomitEffect(ped)
            end)
        end
    end

    if targetId == GetPlayerServerId(PlayerId()) then
        CreateThread(function()
            Pve.receiveVomit(tonumber(damage) or Config.Zombie.damage)
        end)
    end
end

---Jet de vomi depuis la tête du zombie (particules locales à ce client).
---@param ped integer
function Pve.playVomitEffect(ped)
    local particle = Config.Zombie.particle
    RequestNamedPtfxAsset(particle.asset)
    local limit = GetGameTimer() + Pve.ASSET_TIMEOUT
    while not HasNamedPtfxAssetLoaded(particle.asset) and GetGameTimer() < limit do Wait(0) end
    if not HasNamedPtfxAssetLoaded(particle.asset) or not DoesEntityExist(ped) then return end

    UseParticleFxAssetNextCall(particle.asset)
    local effect = StartParticleFxLoopedOnEntityBone(particle.name, ped, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        GetPedBoneIndex(ped, Pve.HEAD_BONE), 1.0, false, false, false)
    Wait(Config.Zombie.vomitDuration)
    StopParticleFxLooped(effect, false)
end

---Le joueur local a été touché : dégâts (l'armure encaisse d'abord) et effet d'écran.
---@param damage integer
function Pve.receiveVomit(damage)
    Wait(Config.Zombie.damageDelay)
    if not State.isAlive() or State.isInSafeZone() or State.godmode then return end
    -- Antizin : immunisé contre le vomi tant que l'effet dure
    if Effects.isActive('antizin') then return end

    ApplyDamageToPed(PlayerPedId(), damage, true, 0)
    ShakeGameplayCam('DRUNK_SHAKE', 0.6)
    AnimpostfxPlay(Config.Zombie.screenEffect, 0, false)
    Wait(Pve.SCREEN_EFFECT_TIME)
    AnimpostfxStop(Config.Zombie.screenEffect)
    StopGameplayCamShaking(false)
end
