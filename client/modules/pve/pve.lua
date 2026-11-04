---Zombies des zones PvE. Seul le client propriétaire (au sens réseau) d'un zombie
---le pilote : poursuite du joueur le plus proche, vomissement au contact, signalement de sa mort.
---Le vomi est validé par le serveur puis joué chez tous les joueurs proches ; la cible subit les dégâts.
---Les humains armés (prison) se battent avec l'IA de GTA ; leurs touches sont tirées par le serveur.
---@class PveModule
local Pve = PVP.define('Pve')
local State = PVP.use('State')
local Zones = PVP.use('Zones')
local PedUtils = PVP.use('PedUtils')
local Hits = PVP.use('Hits')
local Clock = PVP.use('Clock')
local Effects = PVP.use('Effects')
local Events = PVP.use('Events')
local ZombieGear = PVP.use('ZombieGear')
local Dungeon = PVP.use('Dungeon')
local Horde = PVP.use('Horde')

Pve.SCAN_INTERVAL = 250
Pve.RETASK_INTERVAL = 2000 -- relance la poursuite pour suivre une cible qui bouge
Pve.ASSET_TIMEOUT = 3000
Pve.HEAD_BONE = 31086 -- SKEL_Head
Pve.SCREEN_EFFECT_TIME = 1200
-- Causes de chute bloquées (SET_RAGDOLL_BLOCKING_FLAGS) : balles 1, choc d'un joueur 16, obstacle 64,
-- bousculades 8192 + 16384 + 32768. Un zombie à terre est presque impossible à viser ; les explosions,
-- les véhicules et l'étourdissement des classes le font encore tomber.
Pve.RAGDOLL_BLOCKING_FLAGS = 57425
-- Morts et vomis signalés par scan : ce client peut piloter toute une horde, le reste attend le scan suivant
-- (Config.AntiCheat.rateLimits : 40 requêtes/s, et 4 scans par seconde)
Pve.REQUESTS_PER_SCAN = 6
-- Précision de l'IA de GTA (0-100) : visuelle seulement, la touche est tirée par le serveur
Pve.HUMAN_ACCURACY = 40

Pve.deathBudget = 0
Pve.attackBudget = 0
Pve.npcGroup = 0
Pve.configured = {} -- [ped] = true quand le comportement zombie a été appliqué sur ce client
Pve.reported = {} -- [ped] = true quand la mort a été signalée
Pve.wandering = {} -- [ped] = true quand le zombie erre sans cible
Pve.chasing = {} -- [ped] = { target = ped du joueur, at = ms } poursuite en cours
Pve.lastAttack = {} -- [ped] = ms du dernier vomissement lancé par ce client
Pve.decorated = {} -- [ped] = true quand les blessures visuelles sont appliquées
Pve.stunned = {} -- [ped] = ms de fin de l'étourdissement (compétences de classe)
Pve.lastShot = {} -- [ped] = ms du dernier tir d'un humain armé envoyé au serveur
Pve.roomCheckedAt = {} -- [ped] = ms du dernier contrôle de la pièce d'un zombie du donjon
Pve.ROOM_CHECK_INTERVAL = 1500

function Pve.init()
    Pve.setupRelationships()
    RegisterNetEvent(Events.client.zombieVomit, function(netId, targetId, damage)
        Pve.onVomit(netId, targetId, damage)
    end)
    RegisterNetEvent(Events.client.npcShot, function(damage)
        Pve.receiveShot(tonumber(damage) or 0)
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
    -- Les balles et les coups des PNJ ne blessent personne : les touches des humains armés sont tirées
    -- par le serveur (Pve.tryShoot), sinon ils feraient mal à leur propriétaire et pas aux autres
    SetAiWeaponDamageModifier(0.0)
    SetAiMeleeWeaponDamageModifier(0.0)
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
    Pve.deathBudget = Pve.REQUESTS_PER_SCAN
    Pve.attackBudget = Pve.REQUESTS_PER_SCAN
    local myId = PlayerId()
    for _, ped in ipairs(GetGamePool('CPed')) do
        if NetworkGetEntityIsNetworked(ped) and not IsPedAPlayer(ped) then
            local zone = Zones.byId(Entity(ped).state.pvpNpc)
            if zone then
                Pve.decorate(ped)
                Pve.checkRoom(ped)
                ZombieGear.update(ped, Pve.getType(ped))
                if NetworkGetEntityOwner(ped) == myId then
                    Pve.updatePed(ped, zone)
                end
            end
        end
    end
end

function Pve.cleanup()
    for _, tracked in ipairs({ Pve.configured, Pve.reported, Pve.wandering, Pve.chasing, Pve.lastAttack, Pve.decorated, Pve.stunned, Pve.lastShot, Pve.roomCheckedAt }) do
        for ped in pairs(tracked) do
            if not DoesEntityExist(ped) then tracked[ped] = nil end
        end
    end
    Hits.pruneZombies()
    ZombieGear.cleanup()
end

---Un zombie du donjon qui sort de la pièce du tunnel (créé dedans, ramené par le serveur, passé d'un tronçon
---à l'autre sans ouverture) disparaîtrait : sa pièce est revue de temps en temps, par chaque client qui le voit.
---@param ped integer
function Pve.checkRoom(ped)
    if not Entity(ped).state.dungeonRoom then return end
    local now = GetGameTimer()
    if now - (Pve.roomCheckedAt[ped] or 0) < Pve.ROOM_CHECK_INTERVAL then return end
    Pve.roomCheckedAt[ped] = now
    PedUtils.enterRoom(ped)
end

---Sang et blessures, et pas de chute sous les balles : appliqué par chaque client qui voit le
---zombie, la copie locale d'un zombie piloté par un autre joueur réagit aussi aux tirs.
---@param ped integer
function Pve.decorate(ped)
    if Pve.decorated[ped] then return end
    Pve.decorated[ped] = true
    if not Pve.getType(ped).human then
        for _, pack in ipairs(Config.Zombie.damagePacks) do
            ApplyPedDamagePack(ped, pack, 0.0, 1.0)
        end
    end
    SetRagdollBlockingFlags(ped, Pve.RAGDOLL_BLOCKING_FLAGS)
    -- Créé sous terre par le serveur, un zombie du donjon resterait invisible dans le tunnel
    if Entity(ped).state.dungeonRoom then PedUtils.enterRoom(ped) end
end

---@param ped integer
---@param zone table
function Pve.updatePed(ped, zone)
    if IsEntityDead(ped) then
        Pve.reportDeath(ped)
        return
    end

    if Entity(ped).state.dungeonRoom then Dungeon.settlePed(ped) end

    if Entity(ped).state.dungeonBoss then Dungeon.setupBoss(ped) end

    if Entity(ped).state.hordeBoss then Horde.setupBoss(ped) end

    if not Pve.configured[ped] then
        Pve.setupPed(ped, zone.npc)
        Pve.configured[ped] = true
    end
    -- Vie suivie ici pour afficher les dégâts infligés au tireur (hitmarker)
    Hits.watchZombie(ped)

    if Pve.isAttacking(ped) or Pve.isStunned(ped) then return end
    if Pve.getType(ped).human then
        Pve.updateHuman(ped, zone)
    else
        Pve.updateBehaviour(ped, zone)
    end
end

---@param ped integer
---@return boolean
function Pve.isStunned(ped)
    return (Pve.stunned[ped] or 0) > GetGameTimer()
end

---Étourdit les zombies vivants de la zone dont ce client est propriétaire (les autres clients font de même
---pour les leurs). Ceux qui ne tombent pas (colosse) restent simplement immobiles.
---@param coords vector3
---@param radius number
---@param duration integer ms
---@param push number force qui repousse le zombie depuis le centre, 0.0 = aucune
function Pve.stunArea(coords, radius, duration, push)
    local myId = PlayerId()
    for _, ped in ipairs(GetGamePool('CPed')) do
        if NetworkGetEntityIsNetworked(ped) and not IsPedAPlayer(ped) and Entity(ped).state.pvpNpc
            and NetworkGetEntityOwner(ped) == myId and not IsPedDeadOrDying(ped, true) and not Pve.isStunned(ped) then
            local offset = GetEntityCoords(ped) - coords
            if #offset <= radius then Pve.stun(ped, offset, duration, push) end
        end
    end
end

---@param ped integer
---@param offset vector3 position du zombie par rapport au centre
---@param duration integer ms
---@param push number
function Pve.stun(ped, offset, duration, push)
    Pve.stunned[ped] = GetGameTimer() + duration
    Pve.chasing[ped] = nil
    Pve.wandering[ped] = nil
    ClearPedTasks(ped)
    if not CanPedRagdoll(ped) then
        TaskStandStill(ped, duration)
        return
    end
    SetPedToRagdoll(ped, duration, duration, 0, false, false, false)
    if push > 0.0 and #offset.xy > 0.0 then
        local direction = offset.xy / #offset.xy * push
        ApplyForceToEntity(ped, 1, direction.x, direction.y, push * 0.25, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    end
end

---Un corps dont la mort est déjà comptée n'est pas signalé : il change de propriétaire avec tout le tas
---quand un joueur s'approche ou quitte le serveur.
---@param ped integer
function Pve.reportDeath(ped)
    if Pve.reported[ped] then return end
    if not Entity(ped).state.pvpNpcDead then
        if Pve.deathBudget <= 0 then return end
        Pve.deathBudget = Pve.deathBudget - 1
        TriggerServerEvent(Events.server.npcDied, NetworkGetNetworkIdFromEntity(ped), PedUtils.getKillerServerId(ped))
    end
    Pve.reported[ped] = true
    ZombieGear.onDeath(ped, Pve.getType(ped))
end

---Touche mesurée par Hits sur un zombie dont ce client est propriétaire.
---@param ped integer
---@param hit { headshot: boolean, fatal: boolean }
function Pve.onZombieHit(ped, hit)
    ZombieGear.onHit(ped, Pve.getType(ped), hit)
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
        -- Gilet pare-balles du SWAT
        if zombieType.armour then SetPedArmour(ped, zombieType.armour) end
        state:set('pvpNpcReady', true, true)
    end
    if zombieType == Config.ZombieTypes.tank or zombieType == Config.ZombieTypes.dungeonBoss or zombieType == Config.ZombieTypes.hordeBoss then
        -- Le colosse ne tombe pas et encaisse les tirs à la tête
        SetPedCanRagdoll(ped, false)
        SetPedSuffersCriticalHits(ped, false)
    end
    ZombieGear.setupOwned(ped, zombieType)

    SetPedRelationshipGroupHash(ped, Pve.npcGroup)
    if zombieType.human then
        Pve.arm(ped, zombieType)
    else
        RemoveAllPedWeapons(ped, true)
    end
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
    if not zombieType.human and HasClipSetLoaded(Config.Zombie.walkStyle) then
        SetPedMovementClipset(ped, Config.Zombie.walkStyle, 1.0)
    end
end

---Poursuit le joueur le plus proche et vomit à son contact, sinon erre dans la zone.
---@param ped integer
---@param zone table
function Pve.updateBehaviour(ped, zone)
    local target, distance = Pve.findTarget(ped)
    if not target then return Pve.wander(ped, zone) end

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

---@param ped integer
---@param zone table
function Pve.wander(ped, zone)
    Pve.chasing[ped] = nil
    if not Pve.wandering[ped] then
        Pve.wandering[ped] = true
        TaskWanderInArea(ped, zone.coords.x, zone.coords.y, zone.coords.z, zone.radius * 0.6, 2.0, 5.0)
    end
end

-- ---------------------------------------------------------------------------
-- Humains armés (prison)
-- ---------------------------------------------------------------------------

---Arme et réglages de combat de GTA. Il ne lâche pas son arme en mourant : personne ne doit la ramasser.
---@param ped integer
---@param npcType table entrée humaine de Config.ZombieTypes
function Pve.arm(ped, npcType)
    local weapon = GetHashKey(npcType.weapon)
    GiveWeaponToPed(ped, weapon, 9999, false, true)
    SetCurrentPedWeapon(ped, weapon, true)
    SetPedInfiniteAmmoClip(ped, true)
    SetPedAccuracy(ped, Pve.HUMAN_ACCURACY)
    SetPedCombatAbility(ped, 2) -- professionnel
    SetPedCombatMovement(ped, 2) -- offensif
    SetPedCombatRange(ped, 1) -- moyenne distance
    SetPedCombatAttributes(ped, 46, true) -- se bat jusqu'au bout
    SetPedCombatAttributes(ped, 5, true) -- attaque même un joueur mieux armé
    SetPedSeeingRange(ped, Config.Zombie.aggroRange)
    SetPedHearingRange(ped, Config.Zombie.aggroRange)
end

---Attaque le joueur le plus proche avec l'IA de combat de GTA, sinon erre dans la zone. Tant qu'il le voit
---à portée, chaque tir est envoyé au serveur, qui décide s'il touche.
---@param ped integer
---@param zone table
function Pve.updateHuman(ped, zone)
    local target, distance = Pve.findTarget(ped)
    if not target then return Pve.wander(ped, zone) end

    Pve.wandering[ped] = nil
    local now = GetGameTimer()
    local current = Pve.chasing[ped]
    if not current or current.target ~= target.ped or now - current.at >= Pve.RETASK_INTERVAL * 2 then
        Pve.chasing[ped] = { target = target.ped, at = now }
        TaskCombatPed(ped, target.ped, 0, 16)
    end

    local npcType = Pve.getType(ped)
    if distance <= npcType.range and HasEntityClearLosToEntity(ped, target.ped, 17) then
        Pve.tryShoot(ped, target, npcType)
    end
end

---@param ped integer
---@param target { ped: integer, serverId: integer }
---@param npcType table
function Pve.tryShoot(ped, target, npcType)
    local now = GetGameTimer()
    if now - (Pve.lastShot[ped] or 0) < npcType.cooldown or Pve.attackBudget <= 0 then return end
    Pve.attackBudget = Pve.attackBudget - 1
    Pve.lastShot[ped] = now
    TriggerServerEvent(Events.server.npcShot, NetworkGetNetworkIdFromEntity(ped), target.serverId)
end

---Touche d'un humain armé, tirée par le serveur (l'armure encaisse d'abord).
---@param damage integer
function Pve.receiveShot(damage)
    if damage <= 0 or not State.isAlive() or State.isInSafeZone() or State.godmode then return end
    ApplyDamageToPed(PlayerPedId(), damage, true, 0)
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
    if Pve.attackBudget <= 0 then return end
    Pve.attackBudget = Pve.attackBudget - 1
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
    local ped = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0
    if DoesEntityExist(ped) then
        CreateThread(function()
            Pve.playVomitEffect(ped)
        end)
    end

    if targetId == GetPlayerServerId(PlayerId()) then
        CreateThread(function()
            Pve.receiveVomit(ped, tonumber(damage) or Config.Zombie.damage)
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

---Le zombie reste sur place pendant son animation : le joueur a le temps de s'écarter,
---et un zombie tué avant le jet ne touche plus.
---@param ped integer
---@return boolean
function Pve.vomitReaches(ped)
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return false end
    local range = Pve.getType(ped).range or Config.Zombie.attackRange
    return #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ped)) <= range + Config.Zombie.dodgeMargin
end

---Le joueur local est visé : dégâts (l'armure encaisse d'abord) et effet d'écran, sauf s'il a esquivé.
---@param ped integer zombie qui vomit, 0 s'il n'existe pas sur ce client
---@param damage integer
function Pve.receiveVomit(ped, damage)
    Wait(Config.Zombie.damageDelay)
    if not State.isAlive() or State.isInSafeZone() or State.godmode then return end
    -- Antizin : immunisé contre le vomi tant que l'effet dure
    if Effects.isActive('antizin') then return end
    if not Pve.vomitReaches(ped) then return end

    ApplyDamageToPed(PlayerPedId(), damage, true, 0)
    ShakeGameplayCam('DRUNK_SHAKE', 0.6)
    AnimpostfxPlay(Config.Zombie.screenEffect, 0, false)
    Wait(Pve.SCREEN_EFFECT_TIME)
    AnimpostfxStop(Config.Zombie.screenEffect)
    StopGameplayCamShaking(false)
end
