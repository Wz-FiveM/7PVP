---Une salle de donjon : ses joueurs, leurs vies, l'étape en cours et ses zombies.
---Les zombies sont créés côté serveur dans le bucket de la salle et pilotés par le client
---propriétaire, comme ceux des zones PvE (voir client/modules/pve/pve.lua).
---@class DungeonRoom
---@field id integer
---@field bucket integer
---@field leader integer
---@field players table<integer, { lives: integer, kills: integer, out: boolean, leashAt: integer }>
---@field status 'waiting'|'running'|'exit'
---@field stepIndex integer
---@field endsAt integer GetGameTimer de la fin du compteur
---@field peds table<integer, string> ped -> type de zombie
---@field boss integer|nil
---@field dark boolean courant coupé
---@field cleared table<string, boolean> étapes dont l'objet (prop) a disparu
---@field charges table<integer, boolean> charges posées (étape plant)
---@field holds table<integer, { index: integer, at: integer }> action maintenue par joueur
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

DungeonRoom.__index = DungeonRoom
-- Le joueur lance son action puis le serveur la valide : petite tolérance sur le temps maintenu
DungeonRoom.HOLD_TOLERANCE = 500
-- Les positions vues par le serveur ont un léger retard sur celles du client
DungeonRoom.REACH_TOLERANCE = 2.5
-- Temps laissé aux joueurs pour arriver sur place avant les premiers zombies
DungeonRoom.ARRIVAL_TIME = 6000
-- Balles comptées par seconde au plus sur un mur (arme la plus rapide du jeu)
DungeonRoom.MAX_WALL_HITS = 25
DungeonRoom.WALL_RANGE = 150.0
DungeonRoom.LEASH_INTERVAL = 6000
-- Temps entre la fin d'une étape et le passage dans la salle suivante
DungeonRoom.WARP_DELAY = 1500
-- Plus bas que ça sous l'étape, un zombie est passé à travers le sol
DungeonRoom.FALL_DEPTH = 15.0
-- Distance du coffre de fin devant le joueur
DungeonRoom.CHEST_OFFSET = 1.2

---@param id integer
---@param leader integer server id
---@return DungeonRoom
function DungeonRoom.new(id, leader)
    return setmetatable({
        id = id,
        bucket = Config.Dungeon.bucketBase + id,
        leader = leader,
        players = {},
        status = 'waiting',
        stepIndex = 0,
        endsAt = GetGameTimer() + Config.Dungeon.waitingTime * 1000,
        peds = {},
        boss = nil,
        dark = true,
        cleared = {},
        charges = {},
        holds = {},
        wallHits = {},
        hidden = nil,
        revealAt = nil,
        revealed = false,
        wallHealth = 0,
        wallMax = 0,
        fuseAt = nil,
        lastBar = nil,
        spawnAfter = 0,
    }, DungeonRoom)
end

-- ---------------------------------------------------------------------------
-- Joueurs
-- ---------------------------------------------------------------------------

---@param source integer
function DungeonRoom:add(source)
    self.players[source] = { lives = Config.Dungeon.lives, kills = 0, out = false, leashAt = 0 }
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

---Point où l'on reprend : l'arrivée dans la salle en cours (dernière étape `warp`).
---@return vector4
function DungeonRoom:checkpoint()
    local step = self:step(1)
    for index = math.max(1, self.stepIndex), 1, -1 do
        if self:step(index).warp then
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
    self.holds[source] = nil
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
    self.endsAt = GetGameTimer() + Config.Dungeon.duration * 1000
    self.spawnAfter = GetGameTimer() + DungeonRoom.ARRIVAL_TIME
    for _, entry in pairs(self.players) do entry.leashAt = self.spawnAfter end
    self:enterStep(1)
end

---@param index integer
function DungeonRoom:enterStep(index)
    local previous = self:step()
    if previous and not previous.keep then self.cleared[previous.id] = true end
    self.stepIndex = index
    self.holds = {}
    self.wallHits = {}
    self.charges = {}
    self.hidden = nil
    self.revealAt = nil
    self.revealed = false
    self.fuseAt = nil
    self.lastBar = nil
    for _, entry in pairs(self.players) do entry.kills = 0 end

    local step = self:step()
    if step.warp and index > 1 then self:warpPlayers() end
    if step.type == 'fetch' then
        self.hidden = Utils.pick(step.spawns)
        self.revealAt = GetGameTimer() + Config.Dungeon.revealAfter * 1000
    elseif step.type == 'destroy' then
        self.wallMax = 0
        self:scaleWall()
    elseif step.type == 'plant' and #step.spawns < 2 then
        -- Toutes les charges retirées dans le panneau : l'étape ne doit pas bloquer le groupe
        return self:nextStep()
    elseif step.type == 'chest' then
        self:finish(step)
    end
    self:sync()
end

function DungeonRoom:nextStep()
    if self:step(self.stepIndex + 1) then self:enterStep(self.stepIndex + 1) end
end

---Le groupe passe dans la salle de l'étape : les étages ne sont pas reliés dans le jeu.
---Ce qui reste de zombies n'y arriverait pas, et les suivants attendent que les joueurs soient là.
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

---Vie du mur selon le nombre de joueurs ; garde la part déjà détruite si quelqu'un part.
function DungeonRoom:scaleWall()
    local step = self:step()
    if not step or step.type ~= 'destroy' then return end
    local max = step.health + (step.healthPerPlayer or 0) * (self:count() - 1)
    local ratio = self.wallMax > 0 and self.wallHealth / self.wallMax or 1.0
    self.wallMax = max
    self.wallHealth = math.ceil(max * ratio)
end

---Coffre de chaque joueur, et récompense immédiate.
---@param step table
function DungeonRoom:finish(step)
    local reward = Config.Dungeon.reward
    self.status = 'exit'
    self.endsAt = GetGameTimer() + Config.Dungeon.exitDuration * 1000
    self:despawnPeds()

    for source in pairs(self.players) do
        local player = PlayerService.get(source)
        if player then
            player:addMoney(reward.money)
            player:addXp(reward.xp)
            player:notify(Locale.t('Donjon terminé : +$%d, +%d XP', reward.money, reward.xp), 'success')
            player:sync()
            LootService.drop(self:chestPoint(player), LootService.roll(reward.loot), {
                model = reward.model,
                solid = true,
                browse = true,
                label = Locale.t('Ouvrir ton coffre'),
                title = Locale.t('Coffre du donjon'),
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

---Devant le joueur : là où il se tient, le sol existe forcément.
---@param player PvpPlayer
---@return vector3
function DungeonRoom:chestPoint(player)
    local coords = player:getCoords()
    local heading = math.rad(GetEntityHeading(GetPlayerPed(player.source)))
    return vector3(coords.x - math.sin(heading) * DungeonRoom.CHEST_OFFSET, coords.y + math.cos(heading) * DungeonRoom.CHEST_OFFSET, coords.z)
end

-- ---------------------------------------------------------------------------
-- Actions des joueurs
-- ---------------------------------------------------------------------------

---@param index any numéro de la cible dans l'étape
---@return vector4|nil cible de l'étape en cours
function DungeonRoom:target(index)
    local step = self:step()
    index = tonumber(index)
    if not step or not index then return nil end
    if step.type == 'fetch' then return index == 1 and self.hidden or nil end
    if step.type == 'use' or step.type == 'repair' then return index == 1 and step.spawns[1] or nil end
    if step.type == 'plant' then
        if self.charges[index] or self.fuseAt then return nil end
        return step.spawns[index + 1]
    end
    return nil
end

---@param player PvpPlayer
---@param target vector4
---@return boolean
function DungeonRoom:inReach(player, target)
    return #(player:getCoords() - target.xyz) <= Config.Dungeon.interactDistance + DungeonRoom.REACH_TOLERANCE
end

---Début d'une action maintenue (réparer, poser une charge).
---@param player PvpPlayer
---@param index any
---@return table { ok, message? }
function DungeonRoom:startHold(player, index)
    local target = self:target(index)
    if not target then return { ok = false } end
    if not self:inReach(player, target) then return { ok = false, message = Locale.t('Approche-toi.') } end
    self.holds[player.source] = { index = tonumber(index), at = GetGameTimer() }
    return { ok = true }
end

---Fin d'une action : le serveur vérifie la distance et le temps maintenu.
---@param player PvpPlayer
---@param index any
---@return table { ok, message? }
function DungeonRoom:finishAction(player, index)
    local step = self:step()
    local target = self:target(index)
    if not step or not target then return { ok = false } end
    if not self:inReach(player, target) then return { ok = false, message = Locale.t('Approche-toi.') } end

    local hold = step.hold or 0
    if hold > 0 then
        local started = self.holds[player.source]
        if not started or started.index ~= tonumber(index) or GetGameTimer() - started.at < hold * 1000 - DungeonRoom.HOLD_TOLERANCE then
            return { ok = false }
        end
        self.holds[player.source] = nil
    end

    if step.type == 'plant' then
        self:plantCharge(step, tonumber(index))
    else
        if step.type == 'repair' then self.dark = false end
        self:nextStep()
    end
    return { ok = true }
end

---@param step table
---@param index integer
function DungeonRoom:plantCharge(step, index)
    self.charges[index] = true
    for charge = 1, #step.spawns - 1 do
        if not self.charges[charge] then return self:sync() end
    end
    self.fuseAt = GetGameTimer() + Config.Dungeon.fuse * 1000
    self:sync()
end

---La porte saute : explosions chez un seul joueur (le jeu les transmet aux autres de la salle).
---@param step table
function DungeonRoom:detonate(step)
    self.fuseAt = nil
    local points = {}
    for charge = 2, #step.spawns do points[#points + 1] = step.spawns[charge].xyz end
    if next(self.players) then
        TriggerClientEvent(Events.client.dungeonExplosion, next(self.players), points)
    end
    self:nextStep()
end

---Balles d'un joueur sur le mur, regroupées par son client et bornées par le temps écoulé.
---@param player PvpPlayer
---@param hits any
function DungeonRoom:onWallHit(player, hits)
    local step = self:step()
    hits = math.floor(tonumber(hits) or 0)
    if not step or step.type ~= 'destroy' or hits <= 0 or player.dead then return end
    if #(player:getCoords() - step.spawns[1].xyz) > DungeonRoom.WALL_RANGE then return end

    local now = GetGameTimer()
    local allowed = math.ceil((now - (self.wallHits[player.source] or now - 1000)) / 1000 * DungeonRoom.MAX_WALL_HITS)
    self.wallHits[player.source] = now
    self.wallHealth = self.wallHealth - math.min(hits, allowed) * Config.Dungeon.hitDamage
    if self.wallHealth <= 0 then
        self:nextStep()
    else
        self:sync()
    end
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
end

---@param step table
function DungeonRoom:spawnBoss(step)
    local settings = Config.Dungeon.boss
    local ped = self:createPed(step.spawns[1], GetHashKey(settings.model))
    -- Modèle refusé : l'étape ne doit pas bloquer le groupe
    if not ped then return self:nextStep() end
    self.bossMax = settings.health + settings.healthPerPlayer * (self:count() - 1)
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

---@return integer zombies vivants
function DungeonRoom:alive()
    local step = self:step()
    for ped in pairs(self.peds) do
        if not DoesEntityExist(ped) then
            self.peds[ped] = nil
        elseif step and self:hasFallen(ped, step) then
            DeleteEntity(ped)
            self.peds[ped] = nil
        end
    end
    return Utils.count(self.peds)
end

---@return integer kills qu'il reste à faire
function DungeonRoom:killsLeft()
    local step = self:step()
    local left = 0
    for _, entry in pairs(self.players) do
        left = left + math.max(0, step.count - entry.kills)
    end
    return left
end

---@return integer source du joueur à qui il manque le plus de kills
function DungeonRoom:neediest()
    local best, bestKills
    for source, entry in pairs(self.players) do
        if not bestKills or entry.kills < bestKills then best, bestKills = source, entry.kills end
    end
    return best
end

---@param ped integer
---@param killer PvpPlayer|nil
function DungeonRoom:onNpcDeath(ped, killer)
    if ped == self.boss then return self:onBossDeath(ped, killer) end
    local typeId = self.peds[ped]
    if not typeId then return end
    local zombieType = Config.ZombieTypes[typeId] or Config.ZombieTypes.walker
    self.peds[ped] = nil
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

    self:creditKill(killer)
end

---Un kill compte pour son tueur ; au-delà de sa part (ou sans tueur connu), pour celui qui en a le moins.
---@param killer PvpPlayer|nil
function DungeonRoom:creditKill(killer)
    local step = self:step()
    if not step or step.type ~= 'kill' then return end
    local entry = killer and self.players[killer.source]
    if not entry or entry.kills >= step.count then entry = self.players[self:neediest()] end
    if entry then entry.kills = entry.kills + 1 end
    if not self:checkKills() then self:sync() end
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
    LootService.drop(GetEntityCoords(ped), LootService.rollMany(settings.loot, settings.lootRolls),
        { netId = NetworkGetNetworkIdFromEntity(ped), bucket = self.bucket })
    self:nextStep()
end

function DungeonRoom:despawnPeds()
    for ped in pairs(self.peds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    self.peds = {}
end

-- ---------------------------------------------------------------------------
-- Boucle
-- ---------------------------------------------------------------------------

function DungeonRoom:tick()
    local now = GetGameTimer()
    local step = self:step()
    if not step then return end

    self:keepPlayersClose(now, step)
    if now < self.spawnAfter then return end

    if step.type == 'kill' then
        self:spawnWave(step.spawns, 1, math.min(Config.Dungeon.maxAlive, self:killsLeft()))
    elseif step.type == 'boss' then
        if self.boss and DoesEntityExist(self.boss) and self:hasFallen(self.boss, step) then
            DeleteEntity(self.boss)
            self.boss = nil
        end
        -- Créé une fois le groupe arrivé ; un modèle refusé fait passer à l'étape suivante
        if not self.boss then return self:spawnBoss(step) end
        self:spawnWave(step.spawns, 2, Config.Dungeon.boss.adds)
        self:syncBossBar()
    elseif step.type == 'fetch' and not self.revealed and now >= self.revealAt then
        self.revealed = true
        self:sync()
    elseif step.type == 'plant' and self.fuseAt and now >= self.fuseAt then
        self:detonate(step)
    end
end

---Complète les zombies jusqu'à `wanted`, quelques-uns par tick pour étaler les spawns.
---@param spawns vector4[]
---@param first integer premier point d'apparition de la liste
---@param wanted integer
function DungeonRoom:spawnWave(spawns, first, wanted)
    local missing = wanted - self:alive()
    for _ = 1, math.min(missing, Config.Dungeon.spawnPerTick) do
        self:spawnZombie(spawns[math.random(first, math.max(first, #spawns))] or spawns[1])
    end
end

---Qui s'éloigne trop (chute sous la carte, passage dans le mur) est ramené au point de reprise.
---@param now integer
---@param step table
function DungeonRoom:keepPlayersClose(now, step)
    for source, entry in pairs(self.players) do
        local player = PlayerService.get(source)
        if player and not player.dead and now >= entry.leashAt
            and #(player:getCoords() - step.coords) > Config.Dungeon.leashDistance then
            entry.leashAt = now + DungeonRoom.LEASH_INTERVAL
            AntiCheatService.grace(source)
            TriggerClientEvent(Events.client.teleport, source, self:checkpoint(), Config.Dungeon.zone.label)
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
    -- Sa vie n'est appliquée qu'une fois qu'un client le pilote (voir Dungeon.driveBoss)
    if not Entity(self.boss).state.pvpNpcReady then return self.bossMax end
    return math.max(0, GetEntityHealth(self.boss) - 100)
end

-- ---------------------------------------------------------------------------
-- État envoyé aux clients
-- ---------------------------------------------------------------------------

---@return table[] objets posés sur le parcours
function DungeonRoom:describeProps()
    local props = {}
    for _, chest in ipairs(Config.Dungeon.chests) do
        props[#props + 1] = { key = 'chest_' .. #props, model = Config.Dungeon.chestModel, coords = vector4(chest.x, chest.y, chest.z, 0.0) }
    end
    for _, step in ipairs(Config.Dungeon.steps) do
        if step.prop and not self.cleared[step.id] then
            props[#props + 1] = { key = step.id, model = step.prop, coords = step.spawns[1] }
        end
    end
    local step = self:step()
    if not step then return props end
    if step.type == 'fetch' and self.hidden then
        props[#props + 1] = { key = step.id .. '_item', model = step.item, coords = self.hidden, small = true }
    elseif step.type == 'plant' then
        for charge in pairs(self.charges) do
            props[#props + 1] = { key = 'charge_' .. charge, model = step.item, coords = step.spawns[charge + 1], small = true }
        end
    end
    return props
end

---@return table[] ce sur quoi on peut agir dans l'étape en cours
function DungeonRoom:describeTargets(step)
    local targets = {}
    if step.type == 'fetch' then
        targets[1] = { index = 1, coords = self.hidden, hidden = not self.revealed }
    elseif step.type == 'use' or step.type == 'repair' then
        targets[1] = { index = 1, coords = step.spawns[1] }
    elseif step.type == 'plant' and not self.fuseAt then
        for charge = 1, #step.spawns - 1 do
            if not self.charges[charge] then
                targets[#targets + 1] = { index = charge, coords = step.spawns[charge + 1] }
            end
        end
    end
    return targets
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

    data.dark = self.dark
    data.bucket = self.bucket
    data.props = self:describeProps()
    data.chests = Config.Dungeon.chests
    data.fuseIn = self.fuseAt and math.max(0, math.ceil((self.fuseAt - GetGameTimer()) / 1000)) or nil
    data.step = {
        id = step.id,
        type = step.type,
        objective = step.objective,
        hint = step.hint,
        coords = step.coords,
        hold = step.hold,
        hitRadius = step.hitRadius,
        wall = step.type == 'destroy' and step.spawns[1] or nil,
        targets = self:describeTargets(step),
        bar = self:describeBar(step),
    }
    if step.type == 'kill' then
        local done = 0
        for _, other in pairs(self.players) do
            if other.kills >= step.count then done = done + 1 end
        end
        data.step.kills = entry and entry.kills or 0
        data.step.quota = step.count
        data.step.done = done
    end
    return data
end

function DungeonRoom:sync()
    for source in pairs(self.players) do
        TriggerClientEvent(Events.client.dungeonState, source, self:describe(source))
    end
end
