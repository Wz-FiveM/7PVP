---Une salle de donjon : ses joueurs, leurs vies, l'étape en cours et ses zombies.
---Les zombies sont créés côté serveur dans le bucket de la salle et pilotés par le client
---propriétaire, comme ceux des zones PvE (voir client/modules/pve/pve.lua).
---@class DungeonRoom
---@field id integer
---@field bucket integer
---@field leader integer
---@field players table<integer, { lives: integer, out: boolean, leashAt: integer }>
---@field invited table<integer, boolean> invités qui n'ont pas encore confirmé
---@field status 'waiting'|'running'|'exit'
---@field stepIndex integer
---@field endsAt integer GetGameTimer de la fin du compteur
---@field peds table<integer, string> ped -> type de zombie
---@field boss integer|nil
---@field reached boolean un joueur est arrivé à l'étape : ses zombies peuvent apparaître
---@field kills integer zombies tués depuis le début de l'étape
---@field cleared table<string, boolean> étapes dont l'objet (prop) a disparu
---@field blown table<integer, boolean> bonbonnes qui ont sauté
---@field closed boolean|nil salle fermée (DungeonService.close)
---@field spawnAfter integer pas de zombie avant cette date : le temps que les joueurs arrivent
local DungeonRoom = PVP.define('DungeonRoom')
local PlayerService = PVP.use('PlayerService')
local CombatService = PVP.use('CombatService')
local LootService = PVP.use('LootService')
local PveZone = PVP.use('PveZone')
local ChatService = PVP.use('ChatService')
local AntiCheatService = PVP.use('AntiCheatService')
local Utils = PVP.use('Utils')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')
local KillProof = PVP.use('KillProof')

DungeonRoom.__index = DungeonRoom
-- Temps laissé aux joueurs pour arriver sur place avant les premiers zombies
DungeonRoom.ARRIVAL_TIME = 6000
-- Balles comptées par seconde au plus sur une porte (arme la plus rapide du jeu)
DungeonRoom.MAX_WALL_HITS = 25
-- Portée des tirs sur une porte ou une bonbonne
DungeonRoom.SHOT_RANGE = 150.0
DungeonRoom.LEASH_INTERVAL = 6000
-- Temps entre la fin d'une étape et le passage dans la salle suivante
DungeonRoom.WARP_DELAY = 1500
-- Plus bas que ça sous l'étape, on est passé à travers le sol (le tunnel descend : on peut avoir pris de l'avance)
DungeonRoom.FALL_DEPTH = 30.0
-- Écart entre deux caisses de fin quand il y a plus de joueurs que de points (étape chest)
DungeonRoom.CHEST_SPACING = 1.5
-- Un zombie n'apparaît pas sous les yeux d'un joueur, s'il y a un autre point
DungeonRoom.SPAWN_MIN_DISTANCE = 20.0
-- Mort sans que son client l'ait déclaré (déclaration perdue ou refusée) : compté par le serveur après ce délai,
-- le temps que la déclaration du tueur arrive et lui crédite le kill
DungeonRoom.DEATH_GRACE = 5000
-- Zombie bloqué (dans un mur, hors du tube, sans chemin) : ramené sur le chemin du groupe s'il est resté
-- STUCK_TIME sans joueur à ENGAGE_RANGE, ou CLOSE_TIME sans joueur à CLOSE_RANGE
DungeonRoom.ENGAGE_RANGE = 35.0
DungeonRoom.STUCK_TIME = 20000
DungeonRoom.CLOSE_RANGE = 12.0
DungeonRoom.CLOSE_TIME = 45000
-- Chemin du groupe : positions des joueurs relevées en route, sur un sol forcément praticable
DungeonRoom.TRAIL_INTERVAL = 2000
DungeonRoom.TRAIL_SPACING = 4.0
DungeonRoom.TRAIL_SIZE = 80
-- Un zombie ramené l'est à cette distance des joueurs (hors de leur vue si possible)
DungeonRoom.RELOCATE_MIN = 20.0
DungeonRoom.RELOCATE_MAX = 50.0
DungeonRoom.RELOCATE_FALLBACK = 8.0

---@param id integer
---@param leader integer server id
---@return DungeonRoom
function DungeonRoom.new(id, leader)
    return setmetatable({
        id = id,
        bucket = Config.Dungeon.bucketBase + id,
        leader = leader,
        players = {},
        invited = {},
        status = 'waiting',
        stepIndex = 0,
        endsAt = GetGameTimer() + Config.Dungeon.waitingTime * 1000,
        peds = {},
        watch = {}, -- [ped] = { near, close, deadAt } : dernières fois qu'un joueur était proche, mort vue
        trail = {},
        trailAt = 0,
        boss = nil,
        reached = false,
        kills = 0,
        cleared = {},
        blown = {},
        wallHits = {},
        wallHealth = 0,
        wallMax = 0,
        lastBar = nil,
        spawnAfter = 0,
    }, DungeonRoom)
end

-- ---------------------------------------------------------------------------
-- Joueurs
-- ---------------------------------------------------------------------------

---@param source integer
function DungeonRoom:add(source)
    self.players[source] = { lives = Config.Dungeon.lives, out = false, leashAt = 0 }
    self.invited[source] = nil
end

---@return integer
function DungeonRoom:count()
    return Utils.count(self.players)
end

---@param index? integer étape (défaut : en cours)
---@return table|nil
function DungeonRoom:step(index)
    return Config.Dungeon.steps[index or self.stepIndex]
end

---Point où l'on reprend : la dernière étape qui en est un.
---@return vector4
function DungeonRoom:checkpoint()
    local step = self:step(1)
    for index = math.max(1, self.stepIndex), 1, -1 do
        if self:step(index).warp or self:step(index).checkpoint then
            step = self:step(index)
            break
        end
    end
    return vector4(step.coords.x, step.coords.y, step.coords.z, step.heading or 0.0)
end

---Le joueur parti, ce qui reste à tuer ne compte plus que pour les autres.
---@param source integer
function DungeonRoom:removePlayer(source)
    self.players[source] = nil
    self.wallHits[source] = nil
    if self.leader == source then self.leader = next(self.players) end
    if self.status == 'running' and next(self.players) then
        self:scaleWall()
        self:checkKills()
    end
end

-- ---------------------------------------------------------------------------
-- Étapes
-- ---------------------------------------------------------------------------

function DungeonRoom:start()
    self.status = 'running'
    self.invited = {}
    self.endsAt = GetGameTimer() + Config.Dungeon.duration * 1000
    self.spawnAfter = GetGameTimer() + DungeonRoom.ARRIVAL_TIME
    for _, entry in pairs(self.players) do entry.leashAt = self.spawnAfter end
    self:enterStep(1)
end

---@param index integer
function DungeonRoom:enterStep(index)
    local previous = self:step()
    if previous and previous.prop then self.cleared[previous.id] = true end
    self.stepIndex = index
    self.wallHits = {}
    self.kills = 0
    self.lastBar = nil

    local step = self:step()
    -- Une étape amenée par un fondu : le groupe y est déjà
    self.reached = step.type ~= 'kill' or step.warp == true
    if step.warp and index > 1 then self:warpPlayers() end
    if step.type == 'destroy' then
        self.wallMax = 0
        self:scaleWall()
    elseif step.type == 'chest' then
        self:finish()
    end
    self:sync()
end

function DungeonRoom:nextStep()
    if self:step(self.stepIndex + 1) then self:enterStep(self.stepIndex + 1) end
end

---Le groupe passe dans la salle de l'étape (étape à `warp`) : ce qui reste de zombies n'y arriverait pas,
---et les suivants attendent que les joueurs soient là.
function DungeonRoom:warpPlayers()
    self:despawnPeds()
    self.spawnAfter = GetGameTimer() + DungeonRoom.WARP_DELAY + DungeonRoom.ARRIVAL_TIME
    for _, entry in pairs(self.players) do entry.leashAt = self.spawnAfter end
    SetTimeout(DungeonRoom.WARP_DELAY, function()
        if self.closed then return end
        local point = self:checkpoint()
        for source in pairs(self.players) do
            local player = PlayerService.get(source)
            -- Un joueur mort reprendra ici de lui-même
            if player and not player.dead then
                AntiCheatService.grace(source)
                TriggerClientEvent(Events.client.teleport, source, point)
            end
        end
    end)
end

---Vie de la porte selon le nombre de joueurs ; garde la part déjà détruite si quelqu'un part.
function DungeonRoom:scaleWall()
    local step = self:step()
    if not step or step.type ~= 'destroy' then return end
    local max = step.health + (step.healthPerPlayer or 0) * (self:count() - 1)
    local ratio = self.wallMax > 0 and self.wallHealth / self.wallMax or 1.0
    self.wallMax = max
    self.wallHealth = math.ceil(max * ratio)
end

---Caisse de chaque joueur, et récompense immédiate.
function DungeonRoom:finish()
    local reward = Config.Dungeon.reward
    local chest = self:step()
    self.status = 'exit'
    self.endsAt = GetGameTimer() + Config.Dungeon.exitDuration * 1000
    self:despawnPeds()

    local index = 0
    for source in pairs(self.players) do
        local player = PlayerService.get(source)
        if player then
            index = index + 1
            player:addMoney(reward.money)
            player:addXp(reward.xp)
            player:notify(Locale.t('Donjon terminé : +$%d, +%d XP', reward.money, reward.xp), 'success')
            player:sync()
            LootService.drop(DungeonRoom.chestPoint(chest, index),DungeonRoom.rollReward(reward), {
                model = reward.model,
                solid = true,
                browse = true,
                label = Locale.t('Ouvrir ta caisse'),
                title = Locale.t('Butin du donjon'),
                bucket = self.bucket,
                owner = source,
                lifetime = Config.Dungeon.exitDuration,
            })
        end
    end
    local leader = PlayerService.get(self.leader)
    if leader then
        ChatService.announce('pvp', Locale.t('Le groupe de %s a terminé le donjon !', leader:displayName()))
    end
end

---`reward.items` objets par joueur, tirés de la table de butin ; l'argent de la table vient en plus.
---@param reward table
---@return table<string, integer>
function DungeonRoom.rollReward(reward)
    local items = LootService.rollMany(reward.loot, reward.rolls)
    local names = {}
    for name in pairs(items) do
        if name ~= 'money' then names[#names + 1] = name end
    end
    local chosen = { money = items.money }
    for _ = 1, math.min(reward.items, #names) do
        local name = table.remove(names, math.random(#names))
        chosen[name] = items[name]
    end
    return chosen
end

---Caisse du `index`-ième joueur, sur un point fixe de l'étape chest (spawns, déplaçables dans F10 > Positions) :
---au-delà du dernier point, les caisses s'alignent à sa droite.
---@param step table étape chest
---@param index integer
---@return vector3
function DungeonRoom.chestPoint(step, index)
    local spawns = step.spawns or {}
    local point = spawns[index]
    if point then return vector3(point.x, point.y, point.z) end
    local last = spawns[#spawns] or vector4(step.coords.x, step.coords.y, step.coords.z, 0.0)
    local heading = math.rad(last.w or 0.0)
    local offset = (index - #spawns) * DungeonRoom.CHEST_SPACING
    return vector3(last.x + math.cos(heading) * offset, last.y + math.sin(heading) * offset, last.z)
end

---Étape du butin de fin, où se pose aussi celui du boss.
---@return table|nil
function DungeonRoom.chestStep()
    for _, step in ipairs(Config.Dungeon.steps) do
        if step.type == 'chest' then return step end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Tirs des joueurs
-- ---------------------------------------------------------------------------

---Balles d'un joueur sur la porte, regroupées par son client et bornées par le temps écoulé.
---@param player PvpPlayer
---@param hits any
function DungeonRoom:onWallHit(player, hits)
    local step = self:step()
    hits = math.floor(tonumber(hits) or 0)
    if not step or step.type ~= 'destroy' or hits <= 0 or player.dead then return end
    if #(player:getCoords() - step.spawns[1].xyz) > DungeonRoom.SHOT_RANGE then return end

    local now = GetGameTimer()
    local allowed = math.ceil((now - (self.wallHits[player.source] or now - 1000)) / 1000 * DungeonRoom.MAX_WALL_HITS)
    self.wallHits[player.source] = now
    self.wallHealth = self.wallHealth - math.min(hits, allowed) * Config.Dungeon.hitDamage
    if self.wallHealth <= 0 then
        -- La porte saute : aucun dégât, le jeu transmet l'explosion aux autres joueurs de la salle
        TriggerClientEvent(Events.client.dungeonExplosion, player.source, { step.spawns[1].xyz }, 0.0)
        self:nextStep()
    else
        self:sync()
    end
end

---Bonbonne touchée : elle saute, et celles qui sont tout près avec elle. L'explosion part de chez le tireur,
---à qui reviennent les zombies soufflés.
---@param player PvpPlayer
---@param index any
function DungeonRoom:onBarrelHit(player, index)
    index = tonumber(index)
    local point = index and Config.Dungeon.barrels[index]
    if not point or self.blown[index] or player.dead then return end
    if #(player:getCoords() - point) > DungeonRoom.SHOT_RANGE then return end

    self.blown[index] = true
    local points = { point }
    local cursor = 1
    while points[cursor] do
        for other, coords in ipairs(Config.Dungeon.barrels) do
            if not self.blown[other] and #(coords - points[cursor]) <= Config.Dungeon.barrel.chainRadius then
                self.blown[other] = true
                points[#points + 1] = coords
            end
        end
        cursor = cursor + 1
    end
    TriggerClientEvent(Events.client.dungeonExplosion, player.source, points, Config.Dungeon.barrel.explosion.damage)
    self:sync()
end

-- ---------------------------------------------------------------------------
-- Zombies et boss
-- ---------------------------------------------------------------------------

---@param point vector4
---@param model integer
---@return integer|nil ped
function DungeonRoom:createPed(point, model)
    local ped = CreatePed(4, model, point.x, point.y, point.z, point.w, true, true)
    local timeout = GetGameTimer() + 2000
    while not DoesEntityExist(ped) and GetGameTimer() < timeout do Wait(0) end
    if not DoesEntityExist(ped) then return nil end
    if self.closed then
        DeleteEntity(ped)
        return nil
    end

    SetEntityOrphanMode(ped, 2)
    SetEntityRoutingBucket(ped, self.bucket)
    RemoveAllPedWeapons(ped, true)
    Entity(ped).state:set('pvpNpc', Config.Dungeon.zone.id, true)
    Entity(ped).state:set('dungeonRoom', self.id, true)
    return ped
end

---@param point vector4
function DungeonRoom:spawnZombie(point)
    local typeId = PveZone.pickType()
    local zombieType = Config.ZombieTypes[typeId]
    local ped = self:createPed(point, GetHashKey(Utils.pick(zombieType.models or Config.Dungeon.zone.npc.models)))
    if not ped then return end
    Entity(ped).state:set('zombieType', typeId, true)
    self.peds[ped] = typeId
    local now = GetGameTimer()
    self.watch[ped] = { near = now, close = now }
end

---@param step table
function DungeonRoom:spawnBoss(step)
    local settings = Config.Dungeon.boss
    local ped = self:createPed(step.spawns[1], GetHashKey(settings.model))
    -- Modèle refusé : l'étape ne doit pas bloquer le groupe
    if not ped then return self:nextStep() end
    self.bossMax = settings.health + settings.healthPerPlayer * (self:count() - 1)
    Entity(ped).state:set('zombieType', settings.type, true)
    Entity(ped).state:set('dungeonBoss', self.bossMax, true)
    self.boss = ped
    self:sync()
end

---@param ped integer
---@param step table
---@return boolean passé à travers le sol
function DungeonRoom:hasFallen(ped, step)
    return GetEntityCoords(ped).z < step.coords.z - DungeonRoom.FALL_DEPTH
end

---Zombies vivants. Un zombie mort que son client n'a pas déclaré (déclaration perdue, refusée ou
---limitée) compte quand même : sinon il occuperait sa place et le compteur resterait bloqué.
---@return integer zombies vivants
function DungeonRoom:alive()
    local step = self:step()
    local now = GetGameTimer()
    local dead = {}
    for ped in pairs(self.peds) do
        if not DoesEntityExist(ped) then
            self.peds[ped] = nil
            self.watch[ped] = nil
        elseif step and self:hasFallen(ped, step) then
            DeleteEntity(ped)
            self.peds[ped] = nil
            self.watch[ped] = nil
        elseif GetEntityHealth(ped) <= KillProof.DEAD_HEALTH then
            local watch = self.watch[ped] or {}
            self.watch[ped] = watch
            watch.deadAt = watch.deadAt or now
            if now - watch.deadAt >= DungeonRoom.DEATH_GRACE then dead[#dead + 1] = ped end
        end
    end
    for _, ped in ipairs(dead) do
        if self.peds[ped] then self:onNpcDeath(ped, nil) end
    end
    return Utils.count(self.peds)
end

---Positions des joueurs en route : un sol où l'on tient debout, dans le tunnel.
---@param now integer
function DungeonRoom:recordTrail(now)
    if now - self.trailAt < DungeonRoom.TRAIL_INTERVAL then return end
    self.trailAt = now
    for source in pairs(self.players) do
        local player = PlayerService.get(source)
        if player and not player.dead then
            local coords = player:getCoords()
            local known = false
            for index = math.max(1, #self.trail - 10), #self.trail do
                if #(coords - self.trail[index]) < DungeonRoom.TRAIL_SPACING then known = true break end
            end
            if not known then
                self.trail[#self.trail + 1] = coords
                if #self.trail > DungeonRoom.TRAIL_SIZE then table.remove(self.trail, 1) end
            end
        end
    end
end

---@return vector3[] positions des joueurs vivants
function DungeonRoom:livingCoords()
    local list = {}
    for source in pairs(self.players) do
        local player = PlayerService.get(source)
        if player and not player.dead then list[#list + 1] = player:getCoords() end
    end
    return list
end

---@param players vector3[]
---@param coords vector3
---@return number distance au joueur le plus proche
function DungeonRoom.nearest(players, coords)
    local best = math.huge
    for _, point in ipairs(players) do best = math.min(best, #(point - coords)) end
    return best
end

---Point du chemin où ramener un zombie : entre RELOCATE_MIN et RELOCATE_MAX des joueurs, sinon le plus
---éloigné à moins de RELOCATE_MAX (au moins RELOCATE_FALLBACK).
---@param players vector3[]
---@return vector3|nil
function DungeonRoom:trailPoint(players)
    local candidates, fallback, fallbackDistance = {}, nil, DungeonRoom.RELOCATE_FALLBACK
    for _, point in ipairs(self.trail) do
        local distance = DungeonRoom.nearest(players, point)
        if distance >= DungeonRoom.RELOCATE_MIN and distance <= DungeonRoom.RELOCATE_MAX then
            candidates[#candidates + 1] = point
        elseif distance <= DungeonRoom.RELOCATE_MAX and distance >= fallbackDistance then
            fallback, fallbackDistance = point, distance
        end
    end
    if #candidates > 0 then return candidates[math.random(#candidates)] end
    return fallback
end

---Ramène sur le chemin du groupe les zombies qui ne s'approchent de personne : bloqués dans un mur, hors
---du tube ou sans chemin, ils resteraient introuvables et l'étape ne finirait jamais.
---@param now integer
function DungeonRoom:unstick(now)
    local players = self:livingCoords()
    if #players == 0 then return end
    for ped in pairs(self.peds) do
        local watch = self.watch[ped]
        if not watch then
            watch = { near = now, close = now }
            self.watch[ped] = watch
        end
        if DoesEntityExist(ped) and not watch.deadAt and GetEntityHealth(ped) > KillProof.DEAD_HEALTH then
            local distance = DungeonRoom.nearest(players, GetEntityCoords(ped))
            if distance <= DungeonRoom.ENGAGE_RANGE then watch.near = now end
            if distance <= DungeonRoom.CLOSE_RANGE then watch.close = now end
            if now - watch.near >= DungeonRoom.STUCK_TIME or now - watch.close >= DungeonRoom.CLOSE_TIME then
                local point = self:trailPoint(players)
                if point then
                    SetEntityCoords(ped, point.x, point.y, point.z, false, false, false, false)
                    -- Son client le recale sur le sol et dans la pièce du tunnel
                    Entity(ped).state:set('dungeonSettled', false, true)
                    watch.near, watch.close = now, now
                end
            end
        end
    end
end

---@return integer zombies à tuer dans l'étape, selon le nombre de joueurs
function DungeonRoom:quota()
    return self:step().count * self:count()
end

---@return integer zombies qu'il reste à tuer
function DungeonRoom:killsLeft()
    return math.max(0, self:quota() - self.kills)
end

---@param ped integer
---@param killer PvpPlayer|nil
function DungeonRoom:onNpcDeath(ped, killer)
    if ped == self.boss then return self:onBossDeath(ped, killer) end
    local typeId = self.peds[ped]
    if not typeId then return end
    local zombieType = Config.ZombieTypes[typeId] or Config.ZombieTypes.walker
    self.peds[ped] = nil
    self.watch[ped] = nil
    Entity(ped).state:set('pvpNpcDead', true, true)

    if killer then CombatService.rewardNpcKill(killer, Config.Dungeon.zone.id) end
    if zombieType.gasCloud then PveZone.releaseGas(GetEntityCoords(ped), typeId, self.bucket) end

    local rolls = 1 + (zombieType.lootRolls or 0)
    local lootId = LootService.drop(GetEntityCoords(ped), LootService.rollMany(Config.Dungeon.zone.npc.loot, rolls),
        { netId = NetworkGetNetworkIdFromEntity(ped), bucket = self.bucket })
    if not lootId then
        SetTimeout(Config.NpcCorpseTime * 1000, function()
            if DoesEntityExist(ped) then DeleteEntity(ped) end
        end)
    end

    local step = self:step()
    if step and step.type == 'kill' then
        self.kills = self.kills + 1
        if not self:checkKills() then self:sync() end
    end
end

---@return boolean true si l'étape est passée
function DungeonRoom:checkKills()
    local step = self:step()
    if not step or step.type ~= 'kill' or self:killsLeft() > 0 then return false end
    self:nextStep()
    return true
end

---@param ped integer
---@param killer PvpPlayer|nil
function DungeonRoom:onBossDeath(ped, killer)
    local settings = Config.Dungeon.boss
    self.boss = nil
    Entity(ped).state:set('pvpNpcDead', true, true)
    if killer then CombatService.rewardNpcKill(killer, Config.Dungeon.zone.id) end
    -- Sur un point fixe du hangar (centre de l'étape chest), pas sur le corps qui peut finir dans un mur ou sous le sol
    local chest = DungeonRoom.chestStep()
    local items = LootService.rollMany(settings.loot, settings.lootRolls)
    if chest then
        LootService.drop(chest.coords, items, {
            model = settings.lootModel,
            solid = true,
            browse = true,
            label = Locale.t('Fouiller le butin'),
            title = Locale.t('Butin du boss'),
            bucket = self.bucket,
            lifetime = Config.Dungeon.exitDuration,
        })
    else
        LootService.drop(GetEntityCoords(ped), items, { netId = NetworkGetNetworkIdFromEntity(ped), bucket = self.bucket })
    end
    self:nextStep()
end

function DungeonRoom:despawnPeds()
    for ped in pairs(self.peds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    self.peds = {}
    self.watch = {}
end

-- ---------------------------------------------------------------------------
-- Boucle
-- ---------------------------------------------------------------------------

function DungeonRoom:tick()
    local now = GetGameTimer()
    local step = self:step()
    if not step then return end

    self:keepPlayersClose(now, step)
    self:recordTrail(now)
    if now < self.spawnAfter then return end
    self:unstick(now)

    if step.type == 'kill' then
        if not self.reached then return self:checkArrival(step) end
        self:spawnWave(step.spawns, 1, math.min(Config.Dungeon.maxAlive, self:killsLeft()))
    elseif step.type == 'destroy' then
        self:spawnWave(step.spawns, 2, step.adds or 0)
    elseif step.type == 'boss' then
        if self.boss and DoesEntityExist(self.boss) and self:hasFallen(self.boss, step) then
            DeleteEntity(self.boss)
            self.boss = nil
        end
        -- Créé une fois le groupe arrivé ; un modèle refusé fait passer à l'étape suivante
        if not self.boss then return self:spawnBoss(step) end
        self:spawnWave(step.spawns, 2, step.adds or 0)
        self:syncBossBar()
    end
end

---La horde attend le groupe : c'est lui qui avance dans le tunnel. Distance à plat : le sol du tunnel
---peut être bien plus bas que le point de l'étape.
---@param step table
function DungeonRoom:checkArrival(step)
    for source in pairs(self.players) do
        local player = PlayerService.get(source)
        if player and not player.dead and #(player:getCoords().xy - step.coords.xy) <= step.radius then
            self.reached = true
            return self:sync()
        end
    end
end

---@param point vector4
---@return boolean aucun joueur tout près
function DungeonRoom:isHidden(point)
    for source in pairs(self.players) do
        local player = PlayerService.get(source)
        if player and #(player:getCoords() - point.xyz) < DungeonRoom.SPAWN_MIN_DISTANCE then return false end
    end
    return true
end

---@param spawns vector4[]
---@param first integer premier point d'apparition de la liste
---@return vector4 point tiré au sort, de préférence loin des joueurs
function DungeonRoom:pickSpawn(spawns, first)
    local hidden = {}
    for index = first, #spawns do
        if self:isHidden(spawns[index]) then hidden[#hidden + 1] = spawns[index] end
    end
    if #hidden > 0 then return hidden[math.random(#hidden)] end
    return spawns[math.random(first, math.max(first, #spawns))] or spawns[1]
end

---Complète les zombies jusqu'à `wanted`, quelques-uns par tick pour étaler les spawns.
---@param spawns vector4[]
---@param first integer premier point d'apparition de la liste
---@param wanted integer
function DungeonRoom:spawnWave(spawns, first, wanted)
    local missing = wanted - self:alive()
    for _ = 1, math.min(missing, Config.Dungeon.spawnPerTick) do
        self:spawnZombie(self:pickSpawn(spawns, first))
    end
end

---Qui s'éloigne trop ou passe sous le sol est ramené au point de reprise.
---@param now integer
---@param step table
function DungeonRoom:keepPlayersClose(now, step)
    for source, entry in pairs(self.players) do
        local player = PlayerService.get(source)
        if player and not player.dead and now >= entry.leashAt then
            local coords = player:getCoords()
            if #(coords - step.coords) > Config.Dungeon.leashDistance or coords.z < step.coords.z - DungeonRoom.FALL_DEPTH then
                entry.leashAt = now + DungeonRoom.LEASH_INTERVAL
                AntiCheatService.grace(source)
                TriggerClientEvent(Events.client.teleport, source, self:checkpoint(), Config.Dungeon.zone.label)
            end
        end
    end
end

---La barre du boss suit sa vie, lue par le serveur.
function DungeonRoom:syncBossBar()
    local value = self:bossHealth()
    if value ~= self.lastBar then
        self.lastBar = value
        self:sync()
    end
end

---@return integer vie restante du boss
function DungeonRoom:bossHealth()
    if not self.boss or not DoesEntityExist(self.boss) then return 0 end
    -- Sa vie n'est appliquée qu'une fois qu'un client le pilote (voir Dungeon.setupBoss)
    if not Entity(self.boss).state.pvpNpcReady then return self.bossMax end
    return math.max(0, GetEntityHealth(self.boss) - 100)
end

-- ---------------------------------------------------------------------------
-- État envoyé aux clients
-- ---------------------------------------------------------------------------

---@return table[] objets posés sur le parcours
function DungeonRoom:describeProps()
    local props = {}
    local models = Config.Dungeon.barrel.models
    for index, point in ipairs(Config.Dungeon.barrels) do
        if not self.blown[index] then
            props[#props + 1] = {
                key = 'barrel_' .. index,
                barrel = index,
                model = models[(index - 1) % #models + 1],
                coords = vector4(point.x, point.y, point.z, 0.0),
            }
        end
    end
    for _, step in ipairs(Config.Dungeon.steps) do
        if step.prop and not self.cleared[step.id] then
            props[#props + 1] = { key = step.id, model = step.prop, coords = step.spawns[1], wall = step.wall }
        end
    end
    return props
end

---@param step table
---@return { label: string, value: number, max: number }|nil barre en haut de l'écran
function DungeonRoom:describeBar(step)
    if step.type == 'destroy' then
        return { label = step.barLabel, value = math.max(0, self.wallHealth), max = self.wallMax }
    elseif step.type == 'boss' and self.boss then
        return { label = Config.Dungeon.boss.label, value = self:bossHealth(), max = self.bossMax }
    end
    return nil
end

---@param source integer
---@return table
function DungeonRoom:describe(source)
    local entry = self.players[source]
    local data = {
        status = self.status,
        leader = self.leader == source,
        players = self:count(),
        maxPlayers = Config.Dungeon.maxPlayers,
        lives = entry and entry.lives or 0,
        maxLives = Config.Dungeon.lives,
        endsIn = math.max(0, math.ceil((self.endsAt - GetGameTimer()) / 1000)),
    }
    local step = self:step()
    if not step then return data end

    data.bucket = self.bucket
    data.props = self:describeProps()
    -- La porte du donjon cassée : le passage vers la base est libre
    data.doorsOpen = next(self.cleared) ~= nil
    data.step = {
        id = step.id,
        type = step.type,
        objective = step.objective,
        hint = step.hint,
        coords = step.coords,
        hitRadius = step.hitRadius,
        reached = self.reached,
        wall = step.type == 'destroy' and step.spawns[1] or nil,
        bar = self:describeBar(step),
    }
    if step.type == 'kill' then data.step.left = self:killsLeft() end
    return data
end

function DungeonRoom:sync()
    for source in pairs(self.players) do
        TriggerClientEvent(Events.client.dungeonState, source, self:describe(source))
    end
end
