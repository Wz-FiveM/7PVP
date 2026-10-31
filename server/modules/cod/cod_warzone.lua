---Listes de jeu Warzone du mode Call of Duty : Battle Royale et Résurgence (config/cod_warzone.lua).
---Une partie reste une CodMatch ; ce module en fournit les règles (voir CodRules) : escouades, avion, zone qui rétrécit,
---butin, argent, stations d'achat, goulag, réapparitions. Le serveur valide chaque ramassage et chaque achat.
---@class CodWarzoneInventory
---@field cash integer
---@field plates integer
---@field state 'alive'|'gulag'|'respawning'|'out'
---@field deployed boolean déjà sorti de l'avion
---@field gulagUsed boolean
---@field duel table|nil duel en cours
---@field nextPlate integer

---@class CodWarzoneModule
local CodWarzone = PVP.define('CodWarzone')
local CodRules = PVP.use('CodRules')
local CodStreaks = PVP.use('CodStreaks')
local CodProfileService = PVP.use('CodProfileService')
local CodParty = PVP.use('CodParty')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CodWarzone.Rules = {}
local Rules = CodWarzone.Rules
CodWarzone.GULAG_BUCKET_OFFSET = 5000

function CodWarzone.init()
    CodRules.handlers.wz_br = Rules
    CodRules.handlers.wz_res = Rules
end

---@param match table
---@return table réglages de la liste de jeu : phases de la zone
function CodWarzone.modeOf(match)
    return Config.CodWarzone[match.playlist.warzone]
end

---@param match table
---@param source integer
---@return CodWarzoneInventory
function CodWarzone.inventory(match, source)
    local stats = match.stats[source]
    if not stats.wz then
        local settings = Config.CodWarzone
        stats.wz = { cash = settings.startCash, plates = settings.startPlates, state = 'alive', deployed = false, gulagUsed = false, nextPlate = 0 }
        CodWarzone.resetGear(stats.wz)
    end
    return stats.wz
end

---Équipement d'une vie qui commence.
---@param wz CodWarzoneInventory
function CodWarzone.resetGear(wz)
    local start = Config.CodWarzone.start
    wz.primary, wz.secondary = start.primary, false
    wz.primaryMods, wz.secondaryMods = nil, nil
    wz.equipment, wz.tactical = false, false
    wz.perks = start.perks
end

---@param match table
---@param source integer
function CodWarzone.sendState(match, source)
    local stats = match.stats[source]
    if not stats or not stats.wz then return end
    TriggerClientEvent(Events.client.codWz, source, { type = 'state', cash = stats.wz.cash, plates = stats.wz.plates, state = stats.wz.state })
end

-- ---------------------------------------------------------------------------
-- Partie
-- ---------------------------------------------------------------------------

---@param match table
function Rules.setup(match)
    local radius = match.map.radius
    match.wz = {
        squads = {},
        squadCount = 0,
        queue = {},
        duels = {},
        loot = {},
        nextLoot = 0,
        vehicles = {},
        entities = {},
        stations = {},
        phase = 1,
        state = 'wait',
        zone = { x = match.map.center.x, y = match.map.center.y, r = radius },
        gulagBucket = Config.Cod.bucketBase + CodWarzone.GULAG_BUCKET_OFFSET + match.id,
    }
    SetRoutingBucketPopulationEnabled(match.wz.gulagBucket, false)
    local phase = CodWarzone.modeOf(match).phases[1]
    match.wz.target = CodWarzone.nextCircle(match, phase)
    match.wz.stateUntil = match.runAt + phase.wait * 1000
    match.wz.plane = CodWarzone.planePath(match)
    CodWarzone.placeWorld(match)
end

---@param match table
---@return table trajet de l'avion : une droite qui passe près du milieu de la carte
function CodWarzone.planePath(match)
    local settings = Config.CodWarzone.plane
    local center = match.map.center
    local angle = math.random() * math.pi * 2
    local reach = match.map.radius * settings.overshoot
    local dx, dy = math.cos(angle), math.sin(angle)
    return {
        fromX = center.x - dx * reach,
        fromY = center.y - dy * reach,
        dirX = dx,
        dirY = dy,
        length = reach * 2,
        height = center.z + settings.height,
        speed = settings.speed,
        model = settings.model,
    }
end

---@param match table
---@param phase table
---@return { x: number, y: number, r: number } prochaine zone : entièrement dans la zone actuelle
function CodWarzone.nextCircle(match, phase)
    local zone = match.wz.zone
    local radius = match.map.radius * phase.radius
    local room = math.max(0.0, zone.r - radius)
    local angle = math.random() * math.pi * 2
    local distance = math.random() * room * 0.85
    return { x = zone.x + math.cos(angle) * distance, y = zone.y + math.sin(angle) * distance, r = radius }
end

---@param match table
---@param now integer
function Rules.tick(match, now)
    CodWarzone.updateCircle(match, now)
    CodWarzone.updateGulag(match, now)
end

---@param match table
---@param now integer
function CodWarzone.updateCircle(match, now)
    local wz = match.wz
    local phases = CodWarzone.modeOf(match).phases
    if wz.state == 'wait' and now >= wz.stateUntil then
        wz.state = 'shrink'
        wz.from = { x = wz.zone.x, y = wz.zone.y, r = wz.zone.r }
        wz.stateFrom = now
        wz.stateUntil = now + phases[wz.phase].shrink * 1000
    end
    if wz.state ~= 'shrink' then return end

    local t = math.min(1.0, (now - wz.stateFrom) / (wz.stateUntil - wz.stateFrom))
    wz.zone.x = wz.from.x + (wz.target.x - wz.from.x) * t
    wz.zone.y = wz.from.y + (wz.target.y - wz.from.y) * t
    wz.zone.r = wz.from.r + (wz.target.r - wz.from.r) * t
    if t < 1.0 then return end

    local following = phases[wz.phase + 1]
    if following then
        wz.phase = wz.phase + 1
        wz.target = CodWarzone.nextCircle(match, following)
        wz.state = 'wait'
        wz.stateUntil = now + following.wait * 1000
    else
        wz.state = 'final'
    end
end

---@param match table
---@return table
function Rules.describe(match)
    local wz = match.wz
    local alive, squads = 0, 0
    for _, source in ipairs(match.players) do
        if match.stats[source].wz and match.stats[source].wz.state ~= 'out' then alive = alive + 1 end
    end
    for _, squad in pairs(wz.squads) do
        if not squad.out then squads = squads + 1 end
    end
    local phase = CodWarzone.modeOf(match).phases[wz.phase]
    return {
        kind = 'wz',
        x = wz.zone.x, y = wz.zone.y, r = wz.zone.r,
        nx = wz.target.x, ny = wz.target.y, nr = wz.target.r,
        state = wz.state,
        seconds = wz.state == 'final' and 0 or math.max(0, math.ceil((wz.stateUntil - GetGameTimer()) / 1000)),
        phase = wz.phase,
        damage = phase.damage,
        alive = alive,
        squads = squads,
    }
end

---@param match table
function Rules.objectives() return nil end

---Temps écoulé (rare : la zone finit par tuer) : l'escouade qui compte le plus de membres debout gagne.
---@param match table
function Rules.onTimeout(match)
    local best, top = nil, 0
    for team, squad in pairs(match.wz.squads) do
        local standing = 0
        for _, source in ipairs(squad.members) do
            if match.stats[source] and match.stats[source].alive then standing = standing + 1 end
        end
        if standing > top then best, top = team, standing end
    end
    match:finish(best, Locale.t('Temps écoulé.'))
end

---Départ d'un joueur, quel qu'il soit : il n'était peut-être pas seul dans son duel.
---@param match table
---@param source integer
---@param stats table
function Rules.onLeave(match, source, stats)
    local squad = match.wz.squads[stats.team]
    if squad then
        for index, member in ipairs(squad.members) do
            if member == source then table.remove(squad.members, index) break end
        end
    end
    CodWarzone.dropFromQueue(match, source)
    if stats.wz and stats.wz.duel then
        local duel = stats.wz.duel
        CodWarzone.endDuel(match, duel, duel.a == source and duel.b or duel.a, true)
    end
    CodWarzone.checkSquads(match)
end

-- ---------------------------------------------------------------------------
-- Escouades
-- ---------------------------------------------------------------------------

---Peu de joueurs : des escouades plus petites, pour qu'il y ait toujours des ennemis.
---@param match table
---@param players integer[]
function Rules.onStart(match, players)
    match.wz.squadSize = math.max(1, math.min(Config.CodWarzone.squadSize, math.floor(#players / 2)))
end

---Une escouade du groupe reste ensemble, les joueurs seuls complètent les escouades.
---@param match table
---@param source integer
---@return string
function Rules.teamFor(match, source)
    local wz = match.wz
    local party = not match.splitParties and CodParty.of(source)
    local team = party and match.partyTeams[party.id]
    if not team and not party then
        for id, squad in pairs(wz.squads) do
            if not squad.party and #squad.members < (wz.squadSize or Config.CodWarzone.squadSize) then team = id break end
        end
    end
    if not team then
        wz.squadCount = wz.squadCount + 1
        team = 'sq' .. wz.squadCount
        wz.squads[team] = { members = {}, party = party and party.id or nil }
        if party then match.partyTeams[party.id] = team end
    end
    local members = wz.squads[team].members
    members[#members + 1] = source
    return team
end

---@param match table
---@param source integer
---@return integer|nil coéquipier debout
function CodWarzone.standingMate(match, source)
    local squad = match.wz.squads[match.stats[source].team]
    for _, member in ipairs(squad and squad.members or {}) do
        local stats = match.stats[member]
        if member ~= source and stats and stats.alive and not (stats.wz and stats.wz.duel) then return member end
    end
    return nil
end

---Une escouade sans personne encore en course est éliminée. Battle Royale : le goulag compte encore ; Résurgence :
---seuls les joueurs debout comptent. La dernière escouade gagne.
---@param match table
function CodWarzone.checkSquads(match)
    if match.phase == 'ended' then return end
    local resurgence = match.playlist.warzone == 'resurgence'
    local remaining, last = 0, nil
    for team, squad in pairs(match.wz.squads) do
        local standing = false
        for _, source in ipairs(squad.members) do
            local stats = match.stats[source]
            if stats and stats.wz and (stats.alive or (not resurgence and stats.wz.state == 'gulag')) then standing = true end
        end
        if not standing and not squad.out then CodWarzone.eliminate(match, squad) end
        if not squad.out then
            remaining = remaining + 1
            last = team
        end
    end
    if remaining == 0 or (remaining == 1 and match.wz.squadCount > 1) then
        match:finish(last, last and Locale.t('Dernière escouade en vie.') or Locale.t('Plus aucune escouade en vie.'), remaining == 0)
    end
end

---@param match table
---@param squad table
function CodWarzone.eliminate(match, squad)
    squad.out = true
    local place = 1
    for _, other in pairs(match.wz.squads) do
        if not other.out then place = place + 1 end
    end
    for _, source in ipairs(squad.members) do
        local stats = match.stats[source]
        if stats and stats.wz then
            stats.wz.state = 'out'
            CodWarzone.sendState(match, source)
            match:award(source, math.max(0, 6 - place) * Config.CodWarzone.placementXp, Locale.t('Classement : %d', place))
            TriggerClientEvent(Events.client.codNotice, source, { text = Locale.t('Escouade éliminée : %de place', place), friendly = false })
        end
    end
end

-- ---------------------------------------------------------------------------
-- Classe et apparitions
-- ---------------------------------------------------------------------------

---@param match table
---@param source integer
---@return CodClass ce que le joueur a trouvé ou acheté, le pistolet du goulag pendant un duel
function Rules.classOf(match, source)
    local wz = CodWarzone.inventory(match, source)
    if wz.duel then
        return { name = 'Goulag', primary = Config.CodWarzone.gulag.weapon, secondary = false, equipment = false, tactical = false, perks = {} }
    end
    return {
        name = 'Warzone',
        primary = wz.primary,
        secondary = wz.secondary,
        primaryMods = wz.primaryMods,
        secondaryMods = wz.secondaryMods,
        equipment = wz.equipment,
        tactical = wz.tactical,
        perks = wz.perks,
    }
end

---@param match table
---@return vector4 point de départ avant l'avion : le milieu de la carte
function Rules.firstSpawn(match)
    local center = match.map.center
    return vector4(center.x, center.y, center.z, 0.0)
end

---@param match table
---@param source integer
---@return table où et comment apparaître : spawn, plane (premier saut), air (parachute), gulag
function Rules.placement(match, source)
    local stats = match.stats[source]
    local wz = CodWarzone.inventory(match, source)
    if wz.duel then
        return { spawn = wz.duel.points[source], gulag = true }
    end
    if not wz.deployed then
        wz.deployed = true
        return { spawn = Rules.firstSpawn(match), plane = match.wz.plane }
    end

    wz.state = 'alive'
    CodWarzone.sendState(match, source)
    -- Parachute au-dessus d'un coéquipier, sinon au hasard dans la zone
    local mate = CodWarzone.standingMate(match, source)
    local ped = mate and GetPlayerPed(mate) or 0
    local x, y
    if ped ~= 0 then
        local coords = GetEntityCoords(ped)
        x, y = coords.x + math.random(-40, 40), coords.y + math.random(-40, 40)
    else
        local zone = match.wz.zone
        local angle = math.random() * math.pi * 2
        local distance = math.random() * zone.r * 0.7
        x, y = zone.x + math.cos(angle) * distance, zone.y + math.sin(angle) * distance
    end
    stats.protectedUntil = 0
    return { spawn = vector4(x, y, match.map.center.z, 0.0), air = Config.CodWarzone.airDropHeight }
end

---@param match table
---@param source integer|nil
---@return boolean réapparition après cette mort
function Rules.canRespawn(match, source)
    if not source or not match.stats[source] or not match.stats[source].wz then return false end
    return match.stats[source].wz.state == 'respawning'
end

---@param match table
---@return integer secondes avant de réapparaître
function Rules.respawnDelay(match)
    return CodWarzone.modeOf(match).phases[match.wz.phase].delay or 0
end

---@param match table
---@param source integer
---@return boolean le temps de réapparition a pu s'écouler alors que l'escouade est tombée entre-temps
function Rules.mayRespawn(match, source)
    local wz = match.stats[source].wz
    return not wz or wz.state ~= 'out'
end

-- ---------------------------------------------------------------------------
-- Morts
-- ---------------------------------------------------------------------------

---@param match table
---@param killer integer|nil
---@param victim integer
function Rules.onKill(match, killer, victim)
    local stats = match.stats[victim]
    local wz = CodWarzone.inventory(match, victim)
    if wz.duel then return CodWarzone.endDuel(match, wz.duel, wz.duel.a == victim and wz.duel.b or wz.duel.a) end

    if killer then
        local killerWz = CodWarzone.inventory(match, killer)
        killerWz.cash = killerWz.cash + Config.CodWarzone.killCash
        CodWarzone.sendState(match, killer)
    end
    CodWarzone.dropBag(match, victim, wz)
    CodWarzone.resetGear(wz)
    stats.class = Rules.classOf(match, victim)

    if match.playlist.warzone == 'br' then
        if not wz.gulagUsed and match.wz.phase <= Config.CodWarzone.gulag.maxPhase then
            wz.state = 'gulag'
            match.wz.queue[#match.wz.queue + 1] = { source = victim, readyAt = GetGameTimer() + Config.CodWarzone.gulag.delay * 1000, joinedAt = GetGameTimer() }
            TriggerClientEvent(Events.client.codNotice, victim, { text = Locale.t('Direction le goulag : gagne ton duel pour revenir'), friendly = true })
        else
            wz.state = 'out'
        end
    else
        local open = CodWarzone.modeOf(match).phases[match.wz.phase].delay
        wz.state = open and CodWarzone.standingMate(match, victim) and 'respawning' or 'out'
    end
    CodWarzone.sendState(match, victim)
    CodWarzone.checkSquads(match)
end

---L'argent et l'arme principale d'un joueur tombent à sa mort.
---@param match table
---@param victim integer
---@param wz CodWarzoneInventory
function CodWarzone.dropBag(match, victim, wz)
    local ped = GetPlayerPed(victim)
    if ped == 0 then return end
    local coords = GetEntityCoords(ped)
    local share = math.floor(wz.cash * Config.CodWarzone.deathDropShare)
    if share > 0 then
        wz.cash = wz.cash - share
        CodWarzone.addLoot(match, coords.x, coords.y, { kind = 'cash', amount = share }, true)
    end
    if wz.primary ~= Config.CodWarzone.start.primary then
        CodWarzone.addLoot(match, coords.x + 1.5, coords.y, { kind = 'weapon', item = wz.primary, mods = wz.primaryMods, rarity = 'common' }, true)
    end
end

-- ---------------------------------------------------------------------------
-- Goulag
-- ---------------------------------------------------------------------------

---@param match table
---@param source integer
function CodWarzone.dropFromQueue(match, source)
    for index, entry in ipairs(match.wz.queue) do
        if entry.source == source then table.remove(match.wz.queue, index) return end
    end
end

---Associe les joueurs qui attendent. Sans adversaire au bout de maxWait : retour gratuit.
---@param match table
---@param now integer
function CodWarzone.updateGulag(match, now)
    local settings = Config.CodWarzone.gulag
    local queue = match.wz.queue
    for firstIndex = #queue, 1, -1 do
        local first = queue[firstIndex]
        if first and now >= first.readyAt then
            for secondIndex = firstIndex - 1, 1, -1 do
                local second = queue[secondIndex]
                if now >= second.readyAt and match.stats[first.source].team ~= match.stats[second.source].team then
                    table.remove(queue, firstIndex)
                    table.remove(queue, secondIndex)
                    CodWarzone.startDuel(match, first.source, second.source, now)
                    break
                end
            end
        end
    end
    for index = #queue, 1, -1 do
        local entry = queue[index]
        if now - entry.joinedAt >= settings.maxWait * 1000 then
            table.remove(queue, index)
            CodWarzone.redeploy(match, entry.source)
        end
    end
    for index = #match.wz.duels, 1, -1 do
        local duel = match.wz.duels[index]
        if now >= duel.endAt then CodWarzone.endDuel(match, duel, CodWarzone.healthiest(duel)) end
    end
end

---@param match table
---@param a integer
---@param b integer
---@param now integer
function CodWarzone.startDuel(match, a, b, now)
    local settings = Config.CodWarzone.gulag
    local duel = { a = a, b = b, endAt = now + settings.duel * 1000, points = { [a] = settings.points[1], [b] = settings.points[2] } }
    match.wz.duels[#match.wz.duels + 1] = duel
    for _, source in ipairs({ a, b }) do
        match.stats[source].wz.duel = duel
        SetPlayerRoutingBucket(source, match.wz.gulagBucket)
        match:respawn(source)
    end
end

---@param duel table
---@return integer joueur le plus en forme (le premier à égalité)
function CodWarzone.healthiest(duel)
    local function health(source)
        local ped = GetPlayerPed(source)
        return ped ~= 0 and GetEntityHealth(ped) or 0
    end
    return health(duel.a) >= health(duel.b) and duel.a or duel.b
end

---@param match table
---@param duel table
---@param winner integer
---@param loserLeft boolean|nil le perdant a quitté la partie
function CodWarzone.endDuel(match, duel, winner, loserLeft)
    for index, entry in ipairs(match.wz.duels) do
        if entry == duel then table.remove(match.wz.duels, index) break end
    end
    local loser = duel.a == winner and duel.b or duel.a

    local loserStats = match.stats[loser]
    if loserStats and not loserLeft then
        local wz = loserStats.wz
        wz.duel, wz.gulagUsed, wz.state = nil, true, 'out'
        SetPlayerRoutingBucket(loser, match.bucket)
        if loserStats.alive then
            -- Temps écoulé : il est encore debout, son client le met à terre
            loserStats.alive = false
            TriggerClientEvent(Events.client.codWz, loser, { type = 'gulagLost' })
        end
        CodWarzone.sendState(match, loser)
        TriggerClientEvent(Events.client.codNotice, loser, { text = Locale.t('Duel perdu : seul un coéquipier peut te racheter'), friendly = false })
    end
    if match.stats[winner] then CodWarzone.redeploy(match, winner) end
    CodWarzone.checkSquads(match)
end

---Retour dans la partie, en parachute.
---@param match table
---@param source integer
function CodWarzone.redeploy(match, source)
    local stats = match.stats[source]
    if not stats or match.phase == 'ended' then return end
    local wz = stats.wz
    wz.duel, wz.gulagUsed, wz.state = nil, true, 'alive'
    SetPlayerRoutingBucket(source, match.bucket)
    match:respawn(source)
    CodWarzone.sendState(match, source)
end

-- ---------------------------------------------------------------------------
-- Butin, stations, véhicules
-- ---------------------------------------------------------------------------

---@param weights table<string, number>
---@return string
function CodWarzone.weightedKey(weights)
    local total, keys = 0, {}
    for key, weight in pairs(weights) do
        total = total + weight
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local roll = math.random() * total
    for _, key in ipairs(keys) do
        roll = roll - weights[key]
        if roll <= 0 then return key end
    end
    return keys[#keys]
end

---@param weapon string
---@param count integer
---@return table accessoires tirés au sort, un par emplacement
function CodWarzone.randomMods(weapon, count)
    local components = Config.CodGunsmith.weapons[weapon] or {}
    local pool = {}
    for _, entry in ipairs(Config.CodGunsmith.attachments) do
        if components[entry.id] then pool[#pool + 1] = entry end
    end
    for index = #pool, 2, -1 do
        local other = math.random(index)
        pool[index], pool[other] = pool[other], pool[index]
    end
    local attachments, taken = {}, {}
    for _, entry in ipairs(pool) do
        if #attachments >= count then break end
        if not taken[entry.slot] then
            taken[entry.slot] = true
            attachments[#attachments + 1] = entry.id
        end
    end
    return { attachments = attachments, camo = false }
end

---@return table contenu d'une caisse
function CodWarzone.rollLoot()
    local settings = Config.CodWarzone.loot
    local kind = CodWarzone.weightedKey(settings.weights)
    if kind == 'cash' then return { kind = kind, amount = settings.cash[math.random(#settings.cash)] } end
    if kind == 'plates' then return { kind = kind, amount = settings.plates[math.random(#settings.plates)] } end
    if kind == 'ammo' then return { kind = kind } end
    if kind == 'equipment' then
        local list = Config.Cod.weapons.equipment
        return { kind = kind, item = list[math.random(#list)].id }
    end

    local weights = {}
    for _, rarity in ipairs(settings.rarities) do weights[rarity.id] = rarity.weight end
    local rarityId = CodWarzone.weightedKey(weights)
    local count = 0
    for _, rarity in ipairs(settings.rarities) do
        if rarity.id == rarityId then count = rarity.attachments end
    end
    local lists = { Config.Cod.weapons.primary, Config.Cod.weapons.primary, Config.Cod.weapons.secondary }
    local list = lists[math.random(#lists)]
    local weapon = list[math.random(#list)].id
    return { kind = kind, item = weapon, rarity = rarityId, mods = CodWarzone.randomMods(weapon, count) }
end

---@param match table
---@param x number
---@param y number
---@param content table
---@param announce boolean|nil partie en cours : les clients l'apprennent tout de suite
function CodWarzone.addLoot(match, x, y, content, announce)
    match.wz.nextLoot = match.wz.nextLoot + 1
    local id = match.wz.nextLoot
    content.id, content.x, content.y = id, x, y
    -- Lâché à une mort : il reste là où le joueur est tombé, sans se caler sur la route
    content.exact = announce == true
    match.wz.loot[id] = content
    if announce then match:broadcast(Events.client.codWz, { type = 'lootAdd', loot = content }) end
end

---@param match table
function CodWarzone.placeWorld(match)
    local settings = Config.CodWarzone
    local center, radius = match.map.center, match.map.radius
    local index = 0
    for _, point in ipairs(settings.points) do
        local dx, dy = point[1] - center.x, point[2] - center.y
        if dx * dx + dy * dy <= radius * radius then
            index = index + 1
            for _ = 1, settings.loot.perPoint do
                local spread = settings.loot.spread
                CodWarzone.addLoot(match, point[1] + (math.random() * 2 - 1) * spread, point[2] + (math.random() * 2 - 1) * spread, CodWarzone.rollLoot())
            end
            if index % settings.stations.everyPoints == 0 then
                match.wz.stations[#match.wz.stations + 1] = { id = #match.wz.stations + 1, x = point[1], y = point[2] }
            end
            if index % settings.vehicles.everyPoints == 0 then
                local models = settings.vehicles.models
                match.wz.vehicles[#match.wz.vehicles + 1] = {
                    id = #match.wz.vehicles + 1,
                    x = point[1] + 20.0,
                    y = point[2] - 20.0,
                    model = models[math.random(#models)],
                }
            end
        end
    end
end

---Après l'arrivée : le monde de la partie, en envoi différé car la liste est longue.
---@param match table
---@param source integer
function Rules.onJoin(match, source)
    local loot = {}
    for _, entry in pairs(match.wz.loot) do loot[#loot + 1] = entry end
    TriggerLatentClientEvent(Events.client.codWzWorld, source, 100000, { loot = loot, stations = match.wz.stations, vehicles = match.wz.vehicles })
    CodWarzone.sendState(match, source)
end

---@param match table
---@param source integer
---@param x number
---@param y number
---@param range number
---@return boolean joueur debout, hors goulag, assez près de ce point
function CodWarzone.isNear(match, source, x, y, range)
    local stats = match.stats[source]
    local ped = GetPlayerPed(source)
    if match.phase ~= 'running' or not stats or not stats.alive or not stats.wz or stats.wz.duel or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    local dx, dy = coords.x - x, coords.y - y
    return dx * dx + dy * dy <= range * range
end

---@param match table
---@param source integer
---@param id any
function CodWarzone.take(match, source, id)
    local loot = match.wz.loot[tonumber(id)]
    if not loot or not CodWarzone.isNear(match, source, loot.x, loot.y, Config.CodWarzone.takeRange) then return end
    local wz = match.stats[source].wz
    if loot.kind == 'plates' and wz.plates >= Config.CodWarzone.maxPlates then return end

    match.wz.loot[loot.id] = nil
    match:broadcast(Events.client.codWz, { type = 'lootGone', id = loot.id })
    if loot.kind == 'cash' then
        wz.cash = wz.cash + loot.amount
    elseif loot.kind == 'plates' then
        wz.plates = math.min(Config.CodWarzone.maxPlates, wz.plates + loot.amount)
    elseif loot.kind == 'ammo' then
        TriggerClientEvent(Events.client.codScavenge, source)
    elseif loot.kind == 'equipment' then
        wz.equipment = loot.item
        CodWarzone.refreshClass(match, source)
    elseif loot.kind == 'weapon' then
        CodWarzone.equipWeapon(wz, loot.item, loot.mods)
        CodWarzone.refreshClass(match, source)
    end
    CodWarzone.sendState(match, source)
end

---Le pistolet de départ passe en seconde arme. Une arme de poing remplace la seconde arme, les autres la principale.
---@param wz CodWarzoneInventory
---@param weapon string
---@param mods table|nil
function CodWarzone.equipWeapon(wz, weapon, mods)
    local handgun = CodProfileService.secondary[weapon] ~= nil
    if not wz.secondary and CodProfileService.secondary[wz.primary] and not handgun then
        wz.secondary, wz.secondaryMods = wz.primary, wz.primaryMods
        wz.primary, wz.primaryMods = weapon, mods
    elseif handgun and wz.secondary then
        wz.secondary, wz.secondaryMods = weapon, mods
    else
        wz.primary, wz.primaryMods = weapon, mods
    end
end

---Change les armes en pleine vie, sans toucher à la santé.
---@param match table
---@param source integer
function CodWarzone.refreshClass(match, source)
    local stats = match.stats[source]
    stats.class = Rules.classOf(match, source)
    TriggerClientEvent(Events.client.codClass, source, stats.class)
end

---@param match table
---@param source integer
---@param stationId any
---@param itemId any
---@return { ok: boolean, message?: string }
function CodWarzone.buy(match, source, stationId, itemId)
    local station = match.wz.stations[tonumber(stationId)]
    if not station or not CodWarzone.isNear(match, source, station.x, station.y, Config.CodWarzone.takeRange) then
        return { ok = false, message = Locale.t('Trop loin de la station d\'achat.') }
    end
    local item
    for _, entry in ipairs(Config.CodWarzone.shop) do
        if entry.id == itemId then item = entry end
    end
    if not item then return { ok = false } end
    local wz = match.stats[source].wz
    if wz.cash < item.price then return { ok = false, message = Locale.t('Pas assez d\'argent.') } end

    local refused = CodWarzone.SHOP[item.id](match, source, wz, item)
    if refused then return { ok = false, message = refused } end
    wz.cash = wz.cash - item.price
    CodWarzone.sendState(match, source)
    return { ok = true, message = Locale.t('Acheté : %s', Locale.t(item.label)) }
end

-- Ce que fait chaque article : renvoie un message si l'achat est refusé
CodWarzone.SHOP = {
    plates = function(_, _, wz, item)
        if wz.plates >= Config.CodWarzone.maxPlates then return Locale.t('Tu as déjà le maximum de plaques.') end
        wz.plates = math.min(Config.CodWarzone.maxPlates, wz.plates + item.amount)
    end,
    uav = function(match, source, _, item)
        CodStreaks.startUav(match, source, { duration = item.duration })
    end,
    loadout = function(match, source, wz)
        local class = CodProfileService.selectedClass(source)
        wz.primary, wz.secondary = class.primary, class.secondary
        wz.primaryMods, wz.secondaryMods = class.primaryMods, class.secondaryMods
        wz.equipment, wz.tactical = class.equipment, class.tactical
        wz.perks = class.perks
        CodWarzone.refreshClass(match, source)
    end,
    buyback = function(match, source)
        local squad = match.wz.squads[match.stats[source].team]
        for _, member in ipairs(squad.members) do
            local stats = match.stats[member]
            if member ~= source and stats and stats.wz and stats.wz.state == 'out' then
                CodWarzone.redeploy(match, member)
                return nil
            end
        end
        return Locale.t('Aucun coéquipier à racheter.')
    end,
}

---@param match table
---@param source integer
function CodWarzone.usePlate(match, source)
    local stats = match.stats[source]
    local wz = stats and stats.wz
    local now = GetGameTimer()
    local ped = GetPlayerPed(source)
    if match.phase ~= 'running' or not wz or not stats.alive or wz.plates < 1 or now < wz.nextPlate or ped == 0 then return end
    if GetPedArmour(ped) >= 100 then return end
    wz.plates = wz.plates - 1
    wz.nextPlate = now + Config.CodWarzone.plateCooldown
    TriggerClientEvent(Events.client.codWz, source, { type = 'plate', armor = Config.CodWarzone.plateArmor })
    CodWarzone.sendState(match, source)
end

---Le premier joueur à portée fait apparaître le véhicule : le client connaît le sol, pas le serveur.
---@param match table
---@param source integer
---@param id any
function CodWarzone.claimVehicle(match, source, id)
    local vehicle = match.wz.vehicles[tonumber(id)]
    if not vehicle or vehicle.claimed then return end
    if not CodWarzone.isNear(match, source, vehicle.x, vehicle.y, Config.CodWarzone.vehicles.claimRange + 50.0) then return end
    vehicle.claimed = true
    TriggerClientEvent(Events.client.codWz, source, { type = 'vehicleSpawn', id = vehicle.id, model = vehicle.model, x = vehicle.x, y = vehicle.y })
    match:broadcast(Events.client.codWz, { type = 'vehicleClaimed', id = vehicle.id })
end

---@param match table
---@param netId any
function CodWarzone.vehicleSpawned(match, netId)
    netId = tonumber(netId)
    if netId then match.wz.entities[#match.wz.entities + 1] = netId end
end

---Fin de partie : les véhicules restent sinon dans le bucket, sans joueur pour les retirer.
---@param match table
function Rules.cleanup(match)
    for _, netId in ipairs(match.wz.entities) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
    end
end
