---Une partie de Sabotage : deux équipes, manches à une seule vie, phase d'achat, charge à poser ou à
---désamorcer, changement de camp, cote à la fin. Le serveur décide de tout (achats, tirs autorisés,
---kills, argent, manches) ; les capacités des rôles sont dans TacticalAbilities.
---@class TacticalPlayerStats
---@field name string
---@field team 'alpha'|'bravo'
---@field role string
---@field alive boolean
---@field money integer
---@field loadout { primary: string|false, secondary: string|false, armor: integer }
---@field deathLoadout table|nil équipement au moment de la mort (Relève)
---@field diedAt integer GetGameTimer() de la dernière mort
---@field bought table<string, table> achats de la manche, qu'on peut revendre
---@field charges { c: integer, q: integer }
---@field ult integer points d'ultime
---@field kills integer
---@field deaths integer
---@field assists integer
---@field damage number dégâts infligés (avant armure)
---@field firstKills integer
---@field plants integer
---@field defuses integer
---@field holding boolean touche de pose ou de désamorçage maintenue
---@field actionProgress number
---@field damagedBy table<integer, integer> tireur -> GetGameTimer() de sa dernière touche
---@field report table<integer, { dealt: number, dealtHits: integer, taken: number, takenHits: integer }> rapport de combat de la manche, par ennemi
---@field spawn vector4|nil point de départ de la manche

---@class TacticalMatchModule
local TacticalMatch = PVP.define('TacticalMatch')
local TacticalAbilities = PVP.use('TacticalAbilities')
local TacticalProfileService = PVP.use('TacticalProfileService')
local TacticalService = PVP.use('TacticalService')
local AntiCheatService = PVP.use('AntiCheatService')
local KillProof = PVP.use('KillProof')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

TacticalMatch.__index = TacticalMatch
TacticalMatch.TICK = 250 -- ms entre deux passages (pose, charge, capacités)
TacticalMatch.BROADCAST = 1000 -- ms entre deux envois de l'état aux joueurs
TacticalMatch.SPAWN_SPREAD = 1.5 -- m entre deux joueurs qui partagent un point de départ
TacticalMatch.LETTERS = { 'A', 'B' }

---@type table<string, table> arme -> entrée de Config.Tactical.weapons
TacticalMatch.weapons = {}
---@type table<string, table> gilet -> entrée de Config.Tactical.armor
TacticalMatch.armors = {}
for _, entry in ipairs(Config.Tactical.weapons) do TacticalMatch.weapons[entry.id] = entry end
for _, entry in ipairs(Config.Tactical.armor) do TacticalMatch.armors[entry.id] = entry end

---@param team string
---@return string
function TacticalMatch.otherTeam(team)
    return team == 'alpha' and 'bravo' or 'alpha'
end

---@param id integer
---@param map table entrée de Config.Cod.maps
---@return table
function TacticalMatch.new(id, map)
    local match = setmetatable({
        id = id,
        bucket = Config.Tactical.bucketBase + id,
        map = map,
        players = {},
        stats = {},
        scores = { alpha = 0, bravo = 0 },
        lossStreak = { alpha = 0, bravo = 0 },
        attackers = 'alpha',
        -- Liste de points de départ de chaque équipe : elles s'échangent au changement de camp
        sides = { alpha = 'alpha', bravo = 'bravo' },
        round = 0,
        phase = 'loading',
        phaseEndsAt = 0,
        bomb = false,
        firstKill = false,
        overtime = false,
        lastTick = GetGameTimer(),
        nextBroadcast = 0,
    }, TacticalMatch)
    match.spawnLists = {
        alpha = Config.CodSpawns[map.id .. '_alpha'] or {},
        bravo = Config.CodSpawns[map.id .. '_bravo'] or {},
    }
    match.sites = {}
    for index, point in ipairs(Config.CodSpawns[map.id .. '_sites'] or {}) do
        if index > #TacticalMatch.LETTERS then break end
        match.sites[index] = { id = TacticalMatch.LETTERS[index], x = point.x, y = point.y, z = point.z }
    end
    match.arena = match:computeArena()
    SetRoutingBucketPopulationEnabled(match.bucket, false)
    TacticalAbilities.setup(match)
    return match
end

---@return { center: vector3, radius: number } zone de jeu : cercle autour du milieu des points de la carte
function TacticalMatch:computeArena()
    local center, count = vector3(0.0, 0.0, 0.0), 0
    for _, list in pairs(self.spawnLists) do
        for _, spawn in ipairs(list) do
            center = center + spawn.xyz
            count = count + 1
        end
    end
    for _, site in ipairs(self.sites) do
        center = center + vector3(site.x, site.y, site.z)
        count = count + 1
    end
    return { center = center / math.max(count, 1), radius = self.map.radius }
end

---@param players integer[]
function TacticalMatch:start(players)
    for index = #players, 2, -1 do
        local other = math.random(index)
        players[index], players[other] = players[other], players[index]
    end
    for index, source in ipairs(players) do
        self:addPlayer(source, index % 2 == 1 and 'alpha' or 'bravo')
    end
    self:broadcastLineup()
    Logger.info('[sabotage] partie n°%d sur %s, %d joueurs', self.id, self.map.id, #players)
    SetTimeout(Config.Tactical.loadTime * 1000, function()
        if self.phase == 'loading' then self:startRound() end
    end)
    CreateThread(function()
        self:run()
    end)
end

---@param source integer
---@param team string
function TacticalMatch:addPlayer(source, team)
    local settings = Config.Tactical
    self.stats[source] = {
        name = GetPlayerName(source) or '?',
        team = team,
        role = TacticalProfileService.roleOf(source),
        alive = false,
        money = settings.economy.start,
        loadout = { primary = false, secondary = false, armor = 0 },
        diedAt = 0,
        bought = {},
        charges = { c = 0, q = 0 },
        ult = 0,
        kills = 0,
        deaths = 0,
        assists = 0,
        damage = 0,
        firstKills = 0,
        plants = 0,
        defuses = 0,
        holding = false,
        actionProgress = 0,
        damagedBy = {},
        report = {},
    }
    self.players[#self.players + 1] = source
    TacticalService.playerMatch[source] = self.id
    SetPlayerRoutingBucket(source, self.bucket)
    TriggerClientEvent(Events.client.tacStart, source, {
        self = source,
        team = team,
        role = self.stats[source].role,
        map = { label = self.map.label, place = self.map.place },
        arena = self.arena,
        sites = self.sites,
        siteRadius = settings.siteRadius,
        roundsToWin = settings.roundsToWin,
        loadTime = settings.loadTime,
    })
end

---@param source integer
---@return integer, string cote et division du joueur
function TacticalMatch.rankOf(source)
    local profile = TacticalProfileService.get(source)
    local rating = profile and profile.rating or Config.Tactical.rating.start
    return rating, TacticalProfileService.division(rating)
end

---Écran de présentation (les deux équipes face à face) pendant le chargement.
function TacticalMatch:broadcastLineup()
    local players = {}
    for _, source in ipairs(self.players) do
        local stats = self.stats[source]
        local rating, division = TacticalMatch.rankOf(source)
        players[#players + 1] = { id = source, name = stats.name, team = stats.team, role = stats.role, rating = rating, division = division }
    end
    self:broadcast(Events.client.tacLineup, {
        map = { label = self.map.label, place = self.map.place },
        attackers = self.attackers,
        players = players,
    })
end

---@param a integer
---@param b integer
---@return boolean
function TacticalMatch:areEnemies(a, b)
    local first, second = self.stats[a], self.stats[b]
    return a ~= b and first ~= nil and second ~= nil and first.team ~= second.team
end

---@param team string
---@return integer[] joueurs de cette équipe
function TacticalMatch:teamPlayers(team)
    local list = {}
    for _, source in ipairs(self.players) do
        if self.stats[source].team == team then list[#list + 1] = source end
    end
    return list
end

---@param team string
---@return integer
function TacticalMatch:aliveCount(team)
    local count = 0
    for _, source in ipairs(self.players) do
        local stats = self.stats[source]
        if stats.team == team and stats.alive then count = count + 1 end
    end
    return count
end

---@param source integer
---@return vector4 point de départ de la manche, dans la liste du camp de son équipe
function TacticalMatch:spawnFor(source)
    local team = self.stats[source].team
    local list = self.spawnLists[self.sides[team]]
    local position = 1
    for index, member in ipairs(self:teamPlayers(team)) do
        if member == source then position = index break end
    end
    local spawn = list[(position - 1) % #list + 1]
    -- Plus de joueurs que de points : les suivants se décalent sur le côté
    local round = math.floor((position - 1) / #list)
    if round == 0 then return spawn end
    local heading = math.rad(spawn.w)
    local offset = TacticalMatch.SPAWN_SPREAD * round
    return vector4(spawn.x + math.cos(heading) * offset, spawn.y + math.sin(heading) * offset, spawn.z, spawn.w)
end

-- ---------------------------------------------------------------------------
-- Manches
-- ---------------------------------------------------------------------------

function TacticalMatch:startRound()
    if self.phase == 'ended' then return end
    local settings = Config.Tactical
    local now = GetGameTimer()
    self.round = self.round + 1
    local notice = nil

    if self.round == settings.swapAfter + 1 then
        self.attackers = TacticalMatch.otherTeam(self.attackers)
        self.sides.alpha, self.sides.bravo = self.sides.bravo, self.sides.alpha
        self.lossStreak = { alpha = 0, bravo = 0 }
        for _, source in ipairs(self.players) do
            local stats = self.stats[source]
            stats.money = settings.economy.start
            stats.loadout = { primary = false, secondary = false, armor = 0 }
            stats.charges = { c = 0, q = 0 }
        end
        notice = Locale.t('Changement de camp')
    end
    local last = settings.roundsToWin - 1
    if not self.overtime and self.scores.alpha == last and self.scores.bravo == last then
        self.overtime = true
        for _, source in ipairs(self.players) do
            self.stats[source].money = math.max(self.stats[source].money, settings.economy.overtime)
        end
        notice = Locale.t('Manche décisive')
    end

    self.phase = 'buy'
    self.phaseEndsAt = now + settings.buyTime * 1000
    self.bomb = false
    self.firstKill = false
    TacticalAbilities.resetRound(self)
    for _, source in ipairs(self.players) do
        local stats = self.stats[source]
        stats.alive = true
        stats.holding = false
        stats.actionProgress = 0
        stats.damagedBy = {}
        stats.report = {}
        stats.bought = {}
        stats.deathLoadout = nil
        if not stats.loadout.secondary then stats.loadout.secondary = settings.defaultPistol end
        local role = TacticalProfileService.role(stats.role)
        for _, slot in ipairs({ 'c', 'q' }) do
            local ability = role and role.abilities[slot]
            if ability and ability.free then stats.charges[slot] = math.max(stats.charges[slot], ability.free) end
        end
        stats.spawn = self:spawnFor(source)
    end
    -- Deuxième passage : tacSelf montre l'argent et l'arme des coéquipiers, tous à jour
    for _, source in ipairs(self.players) do
        local stats = self.stats[source]
        TriggerClientEvent(Events.client.tacRound, source, {
            round = self.round,
            attackers = self.attackers,
            attacking = stats.team == self.attackers,
            spawn = stats.spawn,
            buyTime = settings.buyTime,
            buyRadius = settings.buyRadius,
            scores = self.scores,
            overtime = self.overtime,
        })
        self:sendSelf(source)
    end
    if notice then self:broadcast(Events.client.tacNotice, { text = notice }) end
    self:broadcastState()

    local round = self.round
    SetTimeout(settings.buyTime * 1000, function()
        if self.phase ~= 'buy' or self.round ~= round then return end
        self.phase = 'running'
        self.phaseEndsAt = GetGameTimer() + settings.roundTime * 1000
        self:broadcast(Events.client.tacEffect, { type = 'roundStart' })
        self:broadcastState()
    end)
end

---@param winner string
---@param reason string|table message à traduire
function TacticalMatch:endRound(winner, reason)
    if self.phase ~= 'running' then return end
    local economy = Config.Tactical.economy
    self.phase = 'round_end'
    self.scores[winner] = self.scores[winner] + 1
    local loser = TacticalMatch.otherTeam(winner)
    self.lossStreak[winner] = 0
    self.lossStreak[loser] = self.lossStreak[loser] + 1
    local lossMoney = economy.loss[math.min(self.lossStreak[loser], #economy.loss)]
    TacticalAbilities.resetRound(self)

    for _, source in ipairs(self.players) do
        local stats = self.stats[source]
        stats.holding = false
        if stats.actionProgress > 0 then
            stats.actionProgress = 0
            TriggerClientEvent(Events.client.tacAction, source, false)
        end
        self:addMoney(source, stats.team == winner and economy.win or lossMoney)
        TriggerClientEvent(Events.client.tacRoundEnd, source, {
            result = stats.team == winner and 'won' or 'lost',
            reason = reason,
            scores = self.scores,
            round = self.round,
        })
        self:sendSelf(source)
    end
    self:broadcastState()

    if self.scores[winner] >= Config.Tactical.roundsToWin then
        return self:finish(winner, Locale.t('Score atteint.'))
    end
    SetTimeout(Config.Tactical.roundPause * 1000, function()
        if self.phase == 'round_end' then self:startRound() end
    end)
end

---Une équipe éliminée perd la manche (sauf les attaquants après la pose : la charge tourne encore).
function TacticalMatch:checkElimination()
    if self.phase ~= 'running' then return end
    local defenders = TacticalMatch.otherTeam(self.attackers)
    if self:aliveCount(defenders) == 0 then
        return self:endRound(self.attackers, Locale.t('Les défenseurs sont éliminés.'))
    end
    if not self.bomb and self:aliveCount(self.attackers) == 0 then
        self:endRound(defenders, Locale.t('Les attaquants sont éliminés.'))
    end
end

-- ---------------------------------------------------------------------------
-- Boucle, pose et désamorçage
-- ---------------------------------------------------------------------------

function TacticalMatch:run()
    while self.phase ~= 'ended' do
        Wait(TacticalMatch.TICK)
        if self.phase == 'ended' then return end
        local now = GetGameTimer()
        local delta = (now - self.lastTick) / 1000
        self.lastTick = now

        if self.phase == 'running' then
            self:tickObjective(delta)
            if self.phase == 'running' then TacticalAbilities.tick(self, now) end
            if self.phase == 'running' then
                if self.bomb and now >= self.bomb.at then
                    self:explode()
                    self:endRound(self.attackers, Locale.t('La charge a explosé.'))
                elseif not self.bomb and now >= self.phaseEndsAt then
                    self:endRound(TacticalMatch.otherTeam(self.attackers), Locale.t('Temps écoulé : la charge n\'a pas été posée.'))
                end
            end
        end
        if self.phase ~= 'ended' and now >= self.nextBroadcast then
            self.nextBroadcast = now + TacticalMatch.BROADCAST
            self:broadcastState()
        end
    end
end

---@param source integer
---@return table|nil site à portée du joueur
function TacticalMatch:siteAt(source)
    local ped = GetPlayerPed(source)
    if ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    for _, site in ipairs(self.sites) do
        if #(coords - vector3(site.x, site.y, site.z)) <= Config.Tactical.siteRadius then return site end
    end
    return nil
end

---@param source integer
---@return string|nil 'plant' ou 'defuse' si le joueur peut le faire maintenant
---@return number|nil secondes nécessaires
function TacticalMatch:actionFor(source)
    local stats = self.stats[source]
    if not stats.holding or not stats.alive then return nil end
    local site = self:siteAt(source)
    if not site then return nil end
    if stats.team == self.attackers then
        if not self.bomb then return 'plant', Config.Tactical.plantTime end
    elseif self.bomb and self.bomb.site == site.id then
        return 'defuse', Config.Tactical.defuseTime
    end
    return nil
end

---@param delta number secondes depuis le dernier passage
function TacticalMatch:tickObjective(delta)
    for _, source in ipairs(self.players) do
        local stats = self.stats[source]
        local kind, needed = self:actionFor(source)
        if kind then
            if stats.actionProgress == 0 then
                TriggerClientEvent(Events.client.tacAction, source, { kind = kind, seconds = needed })
            end
            stats.actionProgress = stats.actionProgress + delta
            if stats.actionProgress >= needed then
                stats.actionProgress = 0
                stats.holding = false
                TriggerClientEvent(Events.client.tacAction, source, false)
                if kind == 'plant' then self:plant(source) else self:defuse(source) end
                if self.phase ~= 'running' then return end
            end
        elseif stats.actionProgress > 0 then
            stats.actionProgress = 0
            TriggerClientEvent(Events.client.tacAction, source, false)
        end
    end
end

---@param source integer
function TacticalMatch:plant(source)
    local site = self:siteAt(source)
    if not site then return end
    local stats = self.stats[source]
    self.bomb = { site = site.id, x = site.x, y = site.y, z = site.z, at = GetGameTimer() + Config.Tactical.bombTime * 1000 }
    stats.plants = stats.plants + 1
    self:addUltimate(source, 1)
    for _, member in ipairs(self:teamPlayers(self.attackers)) do
        self:addMoney(member, Config.Tactical.economy.plant)
        self:sendSelf(member)
    end
    self:broadcast(Events.client.tacNotice, { text = Locale.t('Charge posée sur le site %s', site.id), team = self.attackers })
    self:broadcast(Events.client.tacEffect, { type = 'bombPlanted', site = site.id, x = site.x, y = site.y, z = site.z, seconds = Config.Tactical.bombTime })
    self:broadcastState()
end

---@param source integer
function TacticalMatch:defuse(source)
    local stats = self.stats[source]
    stats.defuses = stats.defuses + 1
    self:addUltimate(source, 1)
    self:sendSelf(source)
    self:broadcast(Events.client.tacEffect, { type = 'bombDefused' })
    self:endRound(stats.team, Locale.t('La charge a été désamorcée.'))
end

---Explosion sans dégâts, créée par un seul client (voir TacticalAbilities client, bombBlast).
function TacticalMatch:explode()
    local bomb = self.bomb
    for index, source in ipairs(self.players) do
        TriggerClientEvent(Events.client.tacEffect, source, { type = 'bombBlast', x = bomb.x, y = bomb.y, z = bomb.z, owner = index == 1 })
    end
end

---@param source integer
---@param holding any
function TacticalMatch:setHolding(source, holding)
    local stats = self.stats[source]
    if stats then stats.holding = holding == true end
end

-- ---------------------------------------------------------------------------
-- État envoyé aux joueurs
-- ---------------------------------------------------------------------------

---@return table[] joueurs de la partie, du meilleur au moins bon
function TacticalMatch:board()
    local list = {}
    local rounds = math.max(self.round, 1)
    for _, source in ipairs(self.players) do
        local stats = self.stats[source]
        list[#list + 1] = {
            id = source,
            name = stats.name,
            team = stats.team,
            role = stats.role,
            alive = stats.alive,
            kills = stats.kills,
            deaths = stats.deaths,
            assists = stats.assists,
            damage = math.floor(stats.damage / rounds),
            firstKills = stats.firstKills,
            plants = stats.plants,
            defuses = stats.defuses,
            score = TacticalMatch.scoreOf(stats),
            ult = stats.ult,
            division = select(2, TacticalMatch.rankOf(source)),
        }
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.kills ~= b.kills then return a.kills > b.kills end
        return a.id < b.id
    end)
    return list
end

---@param stats TacticalPlayerStats
---@return integer points du tableau des scores (et du MVP)
function TacticalMatch.scoreOf(stats)
    return stats.kills * 150 + stats.assists * 50 + stats.firstKills * 50 + stats.plants * 100 + stats.defuses * 150
        + math.floor(stats.damage)
end

function TacticalMatch:broadcastState()
    local now = GetGameTimer()
    local remaining = 0
    if self.bomb then
        remaining = math.max(0, math.ceil((self.bomb.at - now) / 1000))
    elseif self.phase == 'buy' or self.phase == 'running' then
        remaining = math.max(0, math.ceil((self.phaseEndsAt - now) / 1000))
    end
    self:broadcast(Events.client.tacState, {
        phase = self.phase,
        round = self.round,
        remaining = remaining,
        attackers = self.attackers,
        scores = self.scores,
        bomb = self.bomb and { site = self.bomb.site } or false,
        board = self:board(),
    })
end

---@param event string
function TacticalMatch:broadcast(event, ...)
    for _, source in ipairs(self.players) do
        TriggerClientEvent(event, source, ...)
    end
end

---@param team string
---@param event string
function TacticalMatch:broadcastTeam(team, event, ...)
    for _, source in ipairs(self:teamPlayers(team)) do
        TriggerClientEvent(event, source, ...)
    end
end

---Argent, équipement, charges et ultime du joueur : seulement à lui (les ennemis ne voient pas son argent).
---@param source integer
function TacticalMatch:sendSelf(source)
    local stats = self.stats[source]
    if not stats then return end
    local role = TacticalProfileService.role(stats.role)
    local bought = {}
    for key in pairs(stats.bought) do bought[#bought + 1] = key end
    -- Coéquipiers pour le menu d'achat : argent et arme principale (jamais envoyés aux ennemis)
    local mates = {}
    for _, other in ipairs(self:teamPlayers(stats.team)) do
        if other ~= source then
            local mate = self.stats[other]
            mates[#mates + 1] = { id = other, name = mate.name, role = mate.role, money = mate.money, primary = mate.loadout.primary, alive = mate.alive }
        end
    end
    TriggerClientEvent(Events.client.tacSelf, source, {
        mates = mates,
        alive = stats.alive,
        money = stats.money,
        loadout = stats.loadout,
        bought = bought,
        charges = stats.charges,
        ult = stats.ult,
        ultCost = role and role.abilities.x.cost or 0,
        role = stats.role,
    })
end

---@param source integer
---@param amount integer
function TacticalMatch:addMoney(source, amount)
    local stats = self.stats[source]
    if stats then stats.money = math.min(Config.Tactical.economy.max, stats.money + amount) end
end

---@param source integer
---@param amount integer
function TacticalMatch:addUltimate(source, amount)
    local stats = self.stats[source]
    if stats then stats.ult = math.min(Config.Tactical.maxUltimate, stats.ult + amount) end
end

-- ---------------------------------------------------------------------------
-- Achats (pendant la phase d'achat seulement)
-- ---------------------------------------------------------------------------

---@param source integer
---@param item any arme, 'armor:<id>' ou 'ability:c|q'
---@return { ok: boolean, message?: string }
function TacticalMatch:buy(source, item)
    local stats = self.stats[source]
    if not stats or self.phase ~= 'buy' or not stats.alive or type(item) ~= 'string' then
        return { ok = false, message = Locale.t('Les achats se font pendant la phase d\'achat.') }
    end

    local weapon = TacticalMatch.weapons[item]
    if weapon then
        local slot = weapon.slot
        if stats.loadout[slot] == item then return { ok = false, message = Locale.t('Tu as déjà cette arme.') } end
        -- Une arme achetée dans la manche est revendue avant d'en prendre une autre au même emplacement
        local refund = stats.bought[slot] and stats.bought[slot].price or 0
        if stats.money + refund < weapon.price then return { ok = false, message = Locale.t('Pas assez d\'argent.') } end
        local previous = stats.bought[slot] and stats.bought[slot].previous or stats.loadout[slot]
        stats.money = stats.money + refund - weapon.price
        stats.loadout[slot] = item
        stats.bought[slot] = { price = weapon.price, previous = previous }
        return self:afterPurchase(source)
    end

    local armorId = item:match('^armor:(%w+)$')
    local armor = armorId and TacticalMatch.armors[armorId]
    if armor then
        if stats.loadout.armor >= armor.value then return { ok = false, message = Locale.t('Tu as déjà ce gilet.') } end
        local refund = stats.bought.armor and stats.bought.armor.price or 0
        if stats.money + refund < armor.price then return { ok = false, message = Locale.t('Pas assez d\'argent.') } end
        local previous = stats.bought.armor and stats.bought.armor.previous or stats.loadout.armor
        stats.money = stats.money + refund - armor.price
        stats.loadout.armor = armor.value
        stats.bought.armor = { price = armor.price, previous = previous }
        return self:afterPurchase(source)
    end

    local slot = item:match('^ability:([cq])$')
    local role = TacticalProfileService.role(stats.role)
    local ability = slot and role and role.abilities[slot]
    if ability and ability.price then
        if stats.charges[slot] >= ability.max then return { ok = false, message = Locale.t('Charges au maximum.') } end
        if stats.money < ability.price then return { ok = false, message = Locale.t('Pas assez d\'argent.') } end
        stats.money = stats.money - ability.price
        stats.charges[slot] = stats.charges[slot] + 1
        local key = 'ability:' .. slot
        local entry = stats.bought[key] or { price = 0, count = 0 }
        entry.price, entry.count = ability.price, entry.count + 1
        stats.bought[key] = entry
        return self:afterPurchase(source)
    end
    return { ok = false }
end

---Revend un achat de la manche, au prix payé.
---@param source integer
---@param key any 'primary', 'secondary', 'armor', 'ability:c' ou 'ability:q'
---@return { ok: boolean, message?: string }
function TacticalMatch:sell(source, key)
    local stats = self.stats[source]
    local entry = stats and type(key) == 'string' and stats.bought[key]
    if not entry or self.phase ~= 'buy' or not stats.alive then return { ok = false } end

    if key == 'primary' or key == 'secondary' then
        stats.loadout[key] = entry.previous
        if key == 'secondary' and not stats.loadout.secondary then stats.loadout.secondary = Config.Tactical.defaultPistol end
        stats.money = stats.money + entry.price
        stats.bought[key] = nil
    elseif key == 'armor' then
        stats.loadout.armor = entry.previous
        stats.money = stats.money + entry.price
        stats.bought[key] = nil
    else
        local slot = key:match('^ability:([cq])$')
        if not slot or stats.charges[slot] <= 0 then return { ok = false } end
        stats.charges[slot] = stats.charges[slot] - 1
        stats.money = stats.money + entry.price
        entry.count = entry.count - 1
        if entry.count <= 0 then stats.bought[key] = nil end
    end
    return self:afterPurchase(source)
end

---@param source integer
---@return { ok: boolean }
function TacticalMatch:afterPurchase(source)
    -- Les coéquipiers voient l'argent et l'arme du joueur dans leur menu d'achat
    for _, member in ipairs(self:teamPlayers(self.stats[source].team)) do self:sendSelf(member) end
    return { ok = true }
end

-- ---------------------------------------------------------------------------
-- Tirs et morts
-- ---------------------------------------------------------------------------

---Seulement pendant la manche, entre ennemis vivants. Les dégâts comptent pour le tableau des scores.
---@param attacker integer
---@param victim integer
---@param damage number
---@return boolean
function TacticalMatch:damageAllowed(attacker, victim, damage)
    if self.phase ~= 'running' or not self:areEnemies(attacker, victim) then return false end
    local target, shooter = self.stats[victim], self.stats[attacker]
    if not target.alive or not shooter.alive then return false end
    target.damagedBy[attacker] = GetGameTimer()
    local amount = math.max(0, math.min(tonumber(damage) or 0, 100))
    shooter.damage = shooter.damage + amount
    TacticalMatch.addReport(shooter, victim, 'dealt', amount)
    TacticalMatch.addReport(target, attacker, 'taken', amount)
    return true
end

---@param stats TacticalPlayerStats
---@param other integer ennemi
---@param key 'dealt'|'taken'
---@param amount number
function TacticalMatch.addReport(stats, other, key, amount)
    local entry = stats.report[other]
    if not entry then
        entry = { dealt = 0, dealtHits = 0, taken = 0, takenHits = 0 }
        stats.report[other] = entry
    end
    entry[key] = entry[key] + amount
    entry[key .. 'Hits'] = entry[key .. 'Hits'] + 1
end

---Rapport de combat montré à la mort : dégâts donnés et reçus face à chaque ennemi touché ou tireur, le tueur en premier.
---@param source integer
---@param killer integer|nil
---@return table[]
function TacticalMatch:reportFor(source, killer)
    local list = {}
    for other, entry in pairs(self.stats[source].report) do
        local enemy = self.stats[other]
        if enemy then
            list[#list + 1] = {
                id = other, name = enemy.name, role = enemy.role, killer = other == killer,
                dealt = math.floor(entry.dealt), dealtHits = entry.dealtHits,
                taken = math.floor(entry.taken), takenHits = entry.takenHits,
            }
        end
    end
    table.sort(list, function(a, b)
        if a.killer ~= b.killer then return a.killer end
        return a.taken + a.dealt > b.taken + b.dealt
    end)
    return list
end

---@param source integer victime
---@param killerId any server id du tueur, calculé par le client de la victime
---@return integer|nil tueur, s'il est ennemi, assez proche et prouvé par une touche
function TacticalMatch:resolveKiller(source, killerId)
    killerId = tonumber(killerId)
    if not killerId or not self:areEnemies(source, killerId) then return nil end
    local killerPed, victimPed = GetPlayerPed(killerId), GetPlayerPed(source)
    if killerPed == 0 or victimPed == 0 or #(GetEntityCoords(killerPed) - GetEntityCoords(victimPed)) > Config.Tactical.killRange then
        return nil
    end
    if KillProof.confirm(source, killerId) and self.stats[killerId] then return killerId end
    if AntiCheatService.watched(source) then
        AntiCheatService.flag(source, 'kill', ('Sabotage, tueur annoncé : ID %d'):format(killerId))
    end
    return nil
end

---@param weapon any hash envoyé par le client
---@return string|nil nom de l'arme à traduire
function TacticalMatch.weaponLabel(weapon)
    weapon = tonumber(weapon)
    if not weapon then return nil end
    local hash = math.floor(weapon) & 0xFFFFFFFF
    for _, entry in ipairs(Config.Tactical.weapons) do
        if (GetHashKey(entry.id) & 0xFFFFFFFF) == hash then return entry.label end
    end
    if (GetHashKey(Config.Tactical.knife) & 0xFFFFFFFF) == hash then return 'Couteau' end
    return nil
end

---Mort d'un joueur : il ne revient qu'à la manche suivante (ou par une Relève) et perd ses armes.
---@param source integer victime
---@param killerId any
---@param weapon any
---@param headshot any
function TacticalMatch:onDied(source, killerId, weapon, headshot)
    local victim = self.stats[source]
    if not victim or not victim.alive or self.phase == 'ended' then return end

    -- Mort pendant l'achat (chute) : il revient à son point de départ
    if self.phase == 'buy' then
        TriggerClientEvent(Events.client.tacRound, source, {
            round = self.round, attackers = self.attackers, attacking = victim.team == self.attackers,
            spawn = victim.spawn or self:spawnFor(source), buyTime = math.max(1, math.ceil((self.phaseEndsAt - GetGameTimer()) / 1000)),
            buyRadius = Config.Tactical.buyRadius, scores = self.scores, overtime = self.overtime,
        })
        return self:sendSelf(source)
    end
    victim.alive = false
    victim.holding = false
    victim.actionProgress = 0
    -- Entre deux manches (explosion, chute) : rien ne compte, il revient à la suivante avec ses armes
    if self.phase ~= 'running' then return end

    victim.deaths = victim.deaths + 1
    victim.diedAt = GetGameTimer()
    victim.deathLoadout = { primary = victim.loadout.primary, secondary = victim.loadout.secondary, armor = victim.loadout.armor }
    victim.loadout = { primary = false, secondary = false, armor = 0 }
    self:addUltimate(source, 1)

    local killer = self:resolveKiller(source, killerId)
    -- La vérification du kill peut durer : le joueur a pu partir ou la manche finir entre-temps
    if not self.stats[source] then return end
    if self.phase ~= 'running' then killer = nil end
    local weaponLabel = killer and TacticalMatch.weaponLabel(weapon) or nil
    if killer then
        local stats = self.stats[killer]
        stats.kills = stats.kills + 1
        self:addMoney(killer, Config.Tactical.economy.kill)
        self:addUltimate(killer, 1)
        if not self.firstKill then
            self.firstKill = true
            stats.firstKills = stats.firstKills + 1
        end
        self:sendSelf(killer)
    end
    self:rewardAssists(source, killer)
    self:sendSelf(source)

    self:broadcast(Events.client.tacKill, {
        killer = killer and self.stats[killer].name or nil,
        killerTeam = killer and self.stats[killer].team or nil,
        victim = victim.name,
        victimTeam = victim.team,
        weapon = weaponLabel,
        headshot = killer ~= nil and headshot == true,
    })
    TriggerClientEvent(Events.client.tacDead, source, {
        killer = killer and self.stats[killer].name or nil,
        killerRole = killer and self.stats[killer].role or nil,
        weapon = weaponLabel,
        report = self:reportFor(source, killer),
        spectate = self:livingMate(source) or killer,
    })
    self:checkElimination()
end

---@param source integer victime
---@param killer integer|nil
function TacticalMatch:rewardAssists(source, killer)
    local now = GetGameTimer()
    local window = Config.Tactical.assistWindow * 1000
    for attacker, at in pairs(self.stats[source].damagedBy) do
        local stats = self.stats[attacker]
        if attacker ~= killer and stats and now - at <= window and self:areEnemies(source, attacker) then
            stats.assists = stats.assists + 1
        end
    end
end

---@param source integer
---@return integer|nil coéquipier vivant à regarder
function TacticalMatch:livingMate(source)
    local team = self.stats[source].team
    for _, other in ipairs(self.players) do
        local stats = self.stats[other]
        if other ~= source and stats.team == team and stats.alive then return other end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Départs et fin
-- ---------------------------------------------------------------------------

---Déconnexion, retour au menu ou au lobby : compté comme une défaite.
---@param source integer
function TacticalMatch:removePlayer(source)
    local stats = self.stats[source]
    TacticalService.playerMatch[source] = nil
    for position, member in ipairs(self.players) do
        if member == source then table.remove(self.players, position) break end
    end
    if not stats then return end
    self.stats[source] = nil
    if self.phase == 'ended' then return end

    TacticalProfileService.applyAbandon(source, stats)
    local alpha, bravo = #self:teamPlayers('alpha'), #self:teamPlayers('bravo')
    if alpha == 0 or bravo == 0 then
        local winner = alpha > 0 and 'alpha' or (bravo > 0 and 'bravo' or nil)
        return self:finish(winner, Locale.t('Plus assez de joueurs : la partie s\'arrête.'))
    end
    self:checkElimination()
end

---@param winner string|nil équipe gagnante, nil = égalité
---@param reason string|table message à traduire
function TacticalMatch:finish(winner, reason)
    if self.phase == 'ended' then return end
    self.phase = 'ended'
    TacticalAbilities.resetRound(self)

    local board = self:board()
    local mvp = board[1] and board[1].id or nil
    for _, source in ipairs(self.players) do
        local stats = self.stats[source]
        local result = winner == nil and 'draw' or (stats.team == winner and 'won' or 'lost')
        TriggerClientEvent(Events.client.tacEnd, source, {
            result = result,
            reason = reason,
            team = stats.team,
            scores = self.scores,
            board = board,
            mvp = mvp,
            summary = TacticalProfileService.applyMatch(source, stats, result, source == mvp),
            seconds = Config.Tactical.endScreen,
        })
    end
    Logger.info('[sabotage] partie n°%d terminée : %d - %d', self.id, self.scores.alpha, self.scores.bravo)
    SetTimeout(Config.Tactical.endScreen * 1000, function()
        TacticalService.closeMatch(self)
    end)
end
