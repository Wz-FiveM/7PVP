---Capacités des rôles de Sabotage (Config.Tactical.roles) : le serveur vérifie la charge, la portée et la cible,
---puis envoie l'effet aux clients de la partie (fumée, flash, barricade...). Ce qui révèle ou ralentit des ennemis
---(capteur, alarme, balayage, verrou) est calculé ici, à partir des positions vues par le serveur.
---@class TacticalAbilitiesModule
local TacticalAbilities = PVP.define('TacticalAbilities')
local TacticalProfileService = PVP.use('TacticalProfileService')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

TacticalAbilities.COOLDOWN = 600 -- ms entre deux capacités d'un joueur (touches en rafale)
TacticalAbilities.RANGE_MARGIN = 4.0 -- m acceptés au-delà de la portée (décalage entre le client et le serveur)
TacticalAbilities.PULSE = 1000 -- ms entre deux révélations d'un capteur
TacticalAbilities.REVIVE_DISTANCE = 1.5 -- m devant le soigneur
TacticalAbilities.SLOTS = { c = true, q = true, x = true }

---@param match table
function TacticalAbilities.setup(match)
    match.sensors = {}
    match.traps = {}
    match.nextEffectId = 0
end

---Nouvelle manche ou fin de manche : capteurs et pièges disparaissent (les clients effacent leurs effets).
---@param match table
function TacticalAbilities.resetRound(match)
    match.sensors = {}
    match.traps = {}
end

---@param match table
---@return integer identifiant d'un effet, pour le retirer chez les clients
function TacticalAbilities.nextId(match)
    match.nextEffectId = match.nextEffectId + 1
    return match.nextEffectId
end

---@param value any
---@return vector3|nil point envoyé par le client
function TacticalAbilities.point(value)
    if type(value) ~= 'table' then return nil end
    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return nil end
    return vector3(x, y, z)
end

---@param match table
---@param source integer
---@param slot any 'c', 'q' ou 'x'
---@param data any { target?: {x,y,z}, mate?: integer }
function TacticalAbilities.use(match, source, slot, data)
    local stats = match.stats[source]
    if not stats or not stats.alive or match.phase ~= 'running' or not TacticalAbilities.SLOTS[slot] then return end
    local now = GetGameTimer()
    if now < (stats.nextAbility or 0) then return end
    stats.nextAbility = now + TacticalAbilities.COOLDOWN

    local role = TacticalProfileService.role(stats.role)
    local ability = role and role.abilities[slot]
    if not ability then return end
    if slot == 'x' then
        if stats.ult < ability.cost then return end
    elseif stats.charges[slot] <= 0 then
        return
    end

    local ped = GetPlayerPed(source)
    if ped == 0 then return end
    local origin = GetEntityCoords(ped)
    data = type(data) == 'table' and data or {}
    local target = nil
    if ability.target == 'aim' then
        target = TacticalAbilities.point(data.target)
        if not target or #(target - origin) > ability.range + TacticalAbilities.RANGE_MARGIN then
            return TriggerClientEvent(Events.client.tacNotice, source, { text = Locale.t('Trop loin.'), private = true })
        end
    end

    local handler = TacticalAbilities.handlers[ability.id]
    if not handler or handler(match, source, ability, origin, target, data, ped) == false then return end

    if slot == 'x' then
        stats.ult = stats.ult - ability.cost
    else
        stats.charges[slot] = stats.charges[slot] - 1
    end
    match:sendSelf(source)
end

-- ---------------------------------------------------------------------------
-- Révéler et ralentir
-- ---------------------------------------------------------------------------

---@param match table
---@param team string équipe qui voit les ennemis
---@param ids integer[]
---@param seconds number
function TacticalAbilities.reveal(match, team, ids, seconds)
    if #ids == 0 then return end
    match:broadcastTeam(team, Events.client.tacReveal, { ids = ids, seconds = seconds })
    -- Les ennemis révélés le savent (comme un bip de détection)
    for _, id in ipairs(ids) do
        TriggerClientEvent(Events.client.tacEffect, id, { type = 'revealed', seconds = seconds })
    end
end

---@param match table
---@param team string équipe qui cherche
---@param center vector3|nil nil = toute la carte
---@param radius number|nil
---@return integer[] ennemis vivants dans la zone
function TacticalAbilities.enemiesNear(match, team, center, radius)
    local found = {}
    for _, source in ipairs(match.players) do
        local stats = match.stats[source]
        if stats.team ~= team and stats.alive then
            local ped = GetPlayerPed(source)
            if ped ~= 0 and (not center or #(GetEntityCoords(ped) - center) <= radius) then found[#found + 1] = source end
        end
    end
    return found
end

---@param match table
---@param ids integer[]
---@param seconds number
function TacticalAbilities.slow(match, ids, seconds)
    for _, id in ipairs(ids) do
        TriggerClientEvent(Events.client.tacEffect, id, { type = 'slow', seconds = seconds, factor = Config.Tactical.slowFactor })
    end
end

---Capteurs et alarmes posés : relus à chaque passage de la partie.
---@param match table
---@param now integer
function TacticalAbilities.tick(match, now)
    for index = #match.sensors, 1, -1 do
        local sensor = match.sensors[index]
        if now >= sensor.untilAt then
            table.remove(match.sensors, index)
        elseif now >= sensor.nextPulse then
            sensor.nextPulse = now + TacticalAbilities.PULSE
            TacticalAbilities.reveal(match, sensor.team, TacticalAbilities.enemiesNear(match, sensor.team, sensor.pos, sensor.radius), 1.2)
        end
    end
    for index = #match.traps, 1, -1 do
        local trap = match.traps[index]
        local caught = TacticalAbilities.enemiesNear(match, trap.team, trap.pos, trap.radius)
        if #caught > 0 then
            table.remove(match.traps, index)
            TacticalAbilities.reveal(match, trap.team, caught, trap.reveal)
            TacticalAbilities.slow(match, caught, trap.slow)
            match:broadcastTeam(trap.team, Events.client.tacEffect, { type = 'remove', id = trap.id })
            match:broadcastTeam(trap.team, Events.client.tacNotice, { text = Locale.t('Alarme déclenchée'), private = true })
        end
    end
end

---@param match table
---@param round integer
---@return boolean la manche est toujours celle-là et en cours (effets retardés)
function TacticalAbilities.stillRunning(match, round)
    return match.phase == 'running' and match.round == round
end

---@param match table
---@param source integer
---@param data table
---@param range number
---@return integer cible du soin ou du bouclier : l'allié visé (vivant, à portée), sinon soi-même
function TacticalAbilities.mateTarget(match, source, data, range)
    local mate = tonumber(data.mate)
    local stats = mate and match.stats[mate]
    if not stats or mate == source or not stats.alive or stats.team ~= match.stats[source].team then return source end
    local mine, theirs = GetPlayerPed(source), GetPlayerPed(mate)
    if mine == 0 or theirs == 0 or #(GetEntityCoords(mine) - GetEntityCoords(theirs)) > range + TacticalAbilities.RANGE_MARGIN then
        return source
    end
    return mate
end

-- ---------------------------------------------------------------------------
-- Effets : renvoient false pour ne pas consommer la charge
-- ---------------------------------------------------------------------------

TacticalAbilities.handlers = {}

function TacticalAbilities.handlers.sensor(match, source, ability, _, target)
    local team = match.stats[source].team
    match.sensors[#match.sensors + 1] = {
        team = team, pos = target, radius = ability.radius, nextPulse = 0, untilAt = GetGameTimer() + ability.seconds * 1000,
    }
    match:broadcastTeam(team, Events.client.tacEffect, {
        type = 'sensor', x = target.x, y = target.y, z = target.z, radius = ability.radius, seconds = ability.seconds,
    })
end

function TacticalAbilities.handlers.sprint(_, source, ability)
    TriggerClientEvent(Events.client.tacEffect, source, { type = 'sprint', seconds = ability.seconds, multiplier = ability.multiplier })
end

function TacticalAbilities.handlers.scan(match, source, ability)
    local team = match.stats[source].team
    local round = match.round
    for pulse = 0, ability.pulses - 1 do
        SetTimeout(math.floor(pulse * ability.interval * 1000), function()
            if TacticalAbilities.stillRunning(match, round) then
                TacticalAbilities.reveal(match, team, TacticalAbilities.enemiesNear(match, team), ability.seconds)
            end
        end)
    end
    match:broadcast(Events.client.tacNotice, { text = Locale.t('Balayage de %s', match.stats[source].name), team = team })
end

function TacticalAbilities.handlers.smoke(match, _, ability, _, target)
    match:broadcast(Events.client.tacEffect, {
        type = 'smoke', x = target.x, y = target.y, z = target.z, radius = ability.radius, seconds = ability.seconds,
    })
end

function TacticalAbilities.handlers.flash(match, _, ability, _, target)
    match:broadcast(Events.client.tacEffect, {
        type = 'flash', x = target.x, y = target.y, z = target.z, delay = ability.delay, seconds = ability.seconds,
    })
end

function TacticalAbilities.handlers.curtain(match, _, ability, origin, target)
    -- En travers de la ligne de vue du lanceur
    local direction = target.xy - origin.xy
    local length = #direction
    local side = length > 0.01 and vector2(-direction.y / length, direction.x / length) or vector2(1.0, 0.0)
    for index = 1, ability.count do
        local offset = (index - (ability.count + 1) / 2) * ability.spacing
        match:broadcast(Events.client.tacEffect, {
            type = 'smoke', x = target.x + side.x * offset, y = target.y + side.y * offset, z = target.z,
            radius = ability.radius, seconds = ability.seconds,
        })
    end
end

function TacticalAbilities.handlers.alarm(match, source, ability, origin)
    local team = match.stats[source].team
    local id = TacticalAbilities.nextId(match)
    match.traps[#match.traps + 1] = {
        id = id, team = team, pos = origin, radius = ability.radius, reveal = ability.reveal, slow = ability.slow,
    }
    match:broadcastTeam(team, Events.client.tacEffect, {
        type = 'alarm', id = id, x = origin.x, y = origin.y, z = origin.z, radius = ability.radius,
    })
end

function TacticalAbilities.handlers.barrier(match, _, ability, origin, _, _, ped)
    local heading = GetEntityHeading(ped)
    local angle = math.rad(heading)
    local forward = vector2(-math.sin(angle), math.cos(angle))
    local right = vector2(math.cos(angle), math.sin(angle))
    local center = origin.xy + forward * ability.distance
    local points = {}
    for index = 1, ability.panels do
        local offset = (index - (ability.panels + 1) / 2) * ability.spacing
        local point = center + right * offset
        points[index] = { x = point.x, y = point.y, z = origin.z }
    end
    match:broadcast(Events.client.tacEffect, {
        type = 'barrier', id = TacticalAbilities.nextId(match), points = points, heading = heading,
        model = ability.model, seconds = ability.seconds,
    })
end

function TacticalAbilities.handlers.lockdown(match, source, ability, _, target)
    local team = match.stats[source].team
    local round = match.round
    match:broadcast(Events.client.tacEffect, {
        type = 'lockdown', x = target.x, y = target.y, z = target.z, radius = ability.radius, delay = ability.delay,
        seconds = ability.seconds,
    })
    SetTimeout(math.floor(ability.delay * 1000), function()
        if not TacticalAbilities.stillRunning(match, round) then return end
        local caught = TacticalAbilities.enemiesNear(match, team, target, ability.radius)
        TacticalAbilities.reveal(match, team, caught, ability.seconds)
        TacticalAbilities.slow(match, caught, ability.seconds)
    end)
end

function TacticalAbilities.handlers.heal(match, source, ability, _, _, data)
    local target = TacticalAbilities.mateTarget(match, source, data, ability.range)
    TriggerClientEvent(Events.client.tacEffect, target, { type = 'heal', amount = ability.amount, seconds = ability.seconds })
    if target ~= source then
        TriggerClientEvent(Events.client.tacNotice, target, { text = Locale.t('%s te soigne', match.stats[source].name), private = true })
    end
end

function TacticalAbilities.handlers.shield(match, source, ability, _, _, data)
    local target = TacticalAbilities.mateTarget(match, source, data, ability.range)
    TriggerClientEvent(Events.client.tacEffect, target, { type = 'armor', amount = ability.amount })
    if target ~= source then
        TriggerClientEvent(Events.client.tacNotice, target, { text = Locale.t('%s te donne un bouclier', match.stats[source].name), private = true })
    end
end

---Le dernier allié tombé revient à côté du soigneur, avec l'équipement qu'il avait.
function TacticalAbilities.handlers.revive(match, source, _, origin, _, _, ped)
    local team = match.stats[source].team
    local chosen, latest = nil, 0
    for _, other in ipairs(match.players) do
        local stats = match.stats[other]
        if stats.team == team and not stats.alive and stats.deathLoadout and stats.diedAt > latest then
            chosen, latest = other, stats.diedAt
        end
    end
    if not chosen then
        TriggerClientEvent(Events.client.tacNotice, source, { text = Locale.t('Aucun allié à relever.'), private = true })
        return false
    end

    local stats = match.stats[chosen]
    local angle = math.rad(GetEntityHeading(ped))
    local spot = origin.xy + vector2(-math.sin(angle), math.cos(angle)) * TacticalAbilities.REVIVE_DISTANCE
    stats.alive = true
    stats.loadout = stats.deathLoadout
    stats.deathLoadout = nil
    stats.damagedBy = {}
    match:sendSelf(chosen)
    TriggerClientEvent(Events.client.tacEffect, chosen, {
        type = 'revive', spawn = vector4(spot.x, spot.y, origin.z, GetEntityHeading(ped)), loadout = stats.loadout,
    })
    match:broadcastTeam(team, Events.client.tacNotice, { text = Locale.t('%s relève %s', match.stats[source].name, stats.name), private = true })
    match:broadcastState()
end
