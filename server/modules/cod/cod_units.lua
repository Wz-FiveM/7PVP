---Unités des séries du mode Call of Duty (Config.Cod.units) : tourelle, hélicoptères, Harrier, et ceux que le
---joueur pilote depuis sa tablette (hélico mitrailleur, AC-130). Aucune entité réseau : chaque client affiche sa
---copie locale et calcule sa position (client/modules/cod/cod_units.lua). Le serveur ne sait pas tester une
---ligne de vue : le client du propriétaire choisit la cible, le serveur vérifie et applique les dégâts.
---@class CodUnitsModule
local CodUnits = PVP.define('CodUnits')
local CodStreaks = PVP.use('CodStreaks')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CodUnits.SHOT_SLACK = 50 -- ms de tolérance sur la cadence (latence)
CodUnits.RANGE_SLACK = 5.0 -- m de tolérance sur la portée
CodUnits.MISS_OFFSET = 3.0 -- m autour de la cible pour un tir manqué
CodUnits.HIT_INTERVAL = 80 -- ms minimum entre deux touches d'un joueur sur une unité

---@param match table
function CodUnits.setup(match)
    match.units = {}
    match.nextUnit = 1
end

---@param match table
---@param unit table
---@param other integer joueur qui reçoit l'unité
---@param now integer
---@return table
function CodUnits.describe(match, unit, other, now)
    return {
        type = 'unitStart',
        id = unit.id,
        kind = unit.kind,
        owner = unit.owner,
        friendly = not match:areEnemies(unit.owner, other),
        x = unit.x, y = unit.y, z = unit.z,
        radius = unit.radius,
        angle = unit.angle,
        speed = unit.speed,
        heading = unit.heading,
        elapsed = (now - unit.born) / 1000,
        remaining = (unit.endsAt - now) / 1000,
    }
end

---@param match table
---@param source integer
---@param kind string clé de Config.Cod.units
---@param point vector3|nil position d'une unité fixe (les autres tournent autour du milieu de la carte)
---@param heading number|nil
function CodUnits.start(match, source, kind, point, heading)
    local settings = Config.Cod.units[kind]
    local now = GetGameTimer()
    local unit = {
        id = match.nextUnit,
        kind = kind,
        owner = source,
        born = now,
        endsAt = now + settings.duration * 1000,
        hits = settings.hits,
        nextShot = 0,
        shots = 0,
        ready = {},
        heading = heading or 0.0,
    }
    match.nextUnit = match.nextUnit + 1
    if settings.orbit then
        local center = match.arena.center
        unit.x, unit.y, unit.z = center.x, center.y, center.z + settings.height
        unit.radius = match.arena.radius * settings.orbit
        unit.angle = math.random() * 2 * math.pi
        unit.speed = settings.orbitSpeed * (math.random(2) == 1 and 1 or -1)
    else
        unit.x, unit.y, unit.z = point.x, point.y, point.z + (settings.height or 0.0)
    end
    match.units[unit.id] = unit
    if settings.piloted then match.stats[source].pilotUnit = unit.id end
    for _, other in ipairs(match.players) do
        TriggerClientEvent(Events.client.codEffect, other, CodUnits.describe(match, unit, other, now))
    end
end

---@param match table
---@param id integer
---@param by integer|nil joueur qui l'a détruite
function CodUnits.finish(match, id, by)
    local unit = match.units[id]
    if not unit then return end
    match.units[id] = nil
    local stats = match.stats[unit.owner]
    if stats and stats.pilotUnit == id then stats.pilotUnit = nil end
    match:broadcast(Events.client.codEffect, { type = 'unitEnd', id = id, by = by or false })
end

---@param match table
---@param now integer
function CodUnits.tick(match, now)
    for id, unit in pairs(match.units) do
        if now >= unit.endsAt then CodUnits.finish(match, id) end
    end
end

---@param match table
function CodUnits.clear(match)
    for id in pairs(match.units) do CodUnits.finish(match, id) end
end

---@param match table
---@param source integer
function CodUnits.onOwnerLeft(match, source)
    for id, unit in pairs(match.units) do
        if unit.owner == source then CodUnits.finish(match, id) end
    end
end

---Le pilote est mort : il lâche son appareil. Les tourelles et hélicoptères, eux, continuent.
---@param match table
---@param source integer
function CodUnits.onOwnerDied(match, source)
    local id = match.stats[source] and match.stats[source].pilotUnit
    if id then CodUnits.finish(match, id) end
end

---EMP : tout ce qui appartient aux ennemis de ce joueur.
---@param match table
---@param source integer
function CodUnits.destroyEnemiesOf(match, source)
    for id, unit in pairs(match.units) do
        if match:areEnemies(source, unit.owner) then CodUnits.finish(match, id, source) end
    end
end

---Partie rejointe en cours : les unités déjà en jeu.
---@param match table
---@param source integer
function CodUnits.sendActive(match, source)
    local now = GetGameTimer()
    for _, unit in pairs(match.units) do
        TriggerClientEvent(Events.client.codEffect, source, CodUnits.describe(match, unit, source, now))
    end
end

---@param match table
---@param id any
---@return table|nil unit, table|nil settings
function CodUnits.get(match, id)
    local unit = match.units[tonumber(id)]
    if match.phase ~= 'running' or not unit then return nil, nil end
    return unit, Config.Cod.units[unit.kind]
end

---Tir automatique : le client du propriétaire a trouvé une cible en vue.
---@param match table
---@param source integer
---@param id any
---@param targetId any server id de la cible
function CodUnits.fire(match, source, id, targetId)
    local unit, settings = CodUnits.get(match, id)
    if not unit or unit.owner ~= source or settings.piloted then return end
    local now = GetGameTimer()
    local target = tonumber(targetId)
    if now < unit.nextShot or not match.stats[target] or not CodStreaks.canHurt(match, source, target, now) then return end

    local coords = GetEntityCoords(GetPlayerPed(target))
    if settings.range and #(coords - vector3(unit.x, unit.y, unit.z)) > settings.range + CodUnits.RANGE_SLACK then return end
    unit.shots = unit.shots + 1
    if settings.burst and unit.shots % settings.burst == 0 then
        unit.nextShot = now + settings.burstPause
    else
        unit.nextShot = now + settings.interval - CodUnits.SHOT_SLACK
    end

    local hit = math.random() <= settings.accuracy
    local offset = hit and 0.0 or CodUnits.MISS_OFFSET
    match:broadcast(Events.client.codEffect, {
        type = 'unitShot',
        id = unit.id,
        x = coords.x + (math.random() - 0.5) * 2 * offset,
        y = coords.y + (math.random() - 0.5) * 2 * offset,
        z = coords.z,
        target = target,
    })
    if hit then CodStreaks.hurtPlayer(match, source, target, settings.damage, settings.label) end
end

---Tir du pilote : le serveur ne laisse passer que la cadence de l'arme et ramène le point dans la zone de combat.
---@param match table
---@param source integer
---@param id any
---@param index any arme de Config.Cod.units[kind].weapons
---@param target any { x, y, z }
function CodUnits.pilotFire(match, source, id, index, target)
    local unit, settings = CodUnits.get(match, id)
    if not unit or unit.owner ~= source or not settings.piloted then return end
    local weapon = settings.weapons[tonumber(index)]
    local point = CodStreaks.arenaPoint(match, target)
    local now = GetGameTimer()
    if not weapon or not point or now < (unit.ready[tonumber(index)] or 0) then return end
    unit.ready[tonumber(index)] = now + weapon.cooldown - CodUnits.SHOT_SLACK

    match:broadcast(Events.client.codEffect, { type = 'unitShot', id = unit.id, x = point.x, y = point.y, z = point.z })
    CodStreaks.blast(match, source, point, weapon, settings.label)
end

---Un ennemi a touché l'unité (détecté par son client) : elle a un nombre de touches à encaisser.
---@param match table
---@param source integer
---@param id any
function CodUnits.hit(match, source, id)
    local unit = CodUnits.get(match, id)
    local stats = match.stats[source]
    if not unit or not stats or not stats.alive or not match:areEnemies(source, unit.owner) then return end
    local now = GetGameTimer()
    if now < (stats.nextUnitHit or 0) then return end
    stats.nextUnitHit = now + CodUnits.HIT_INTERVAL

    unit.hits = unit.hits - 1
    if unit.hits > 0 then return end
    CodUnits.finish(match, unit.id, source)
    match:award(source, Config.Cod.xp.unitDestroyed, Locale.t('Série ennemie détruite'))
end
