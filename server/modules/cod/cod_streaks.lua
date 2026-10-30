---Séries d'éliminations du mode Call of Duty (Config.Cod.streaks) : gagnées en enchaînant les kills,
---utilisées avec une touche. Le serveur garde la main : il calcule les relevés du drone et applique
---lui-même les dégâts du missile Predator (les clients n'en font que l'effet visuel).
---@class CodStreaksModule
local CodStreaks = PVP.define('CodStreaks')
local CodProfileService = PVP.use('CodProfileService')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CodStreaks.PREDATOR_SLACK = 10 -- secondes de marge sur la durée du vol (saccades, latence)
CodStreaks.PREDATOR_FALLOFF = 0.8 -- part des dégâts perdue au bord de l'explosion

---Séries actives de la partie.
---@param match table
function CodStreaks.setup(match)
    match.uav = {} -- camp -> GetGameTimer() de fin
    match.nextSweep = 0
    match.nuke = false
end

---@param source integer
---@return table[] séries choisies par le joueur
function CodStreaks.chosen(source)
    local profile = CodProfileService.profiles[source]
    local list = {}
    for _, id in ipairs(profile and profile.streaks or Config.Cod.defaultStreaks) do
        list[#list + 1] = CodProfileService.streaks[id]
    end
    return list
end

---@param match table
---@param source integer
---@param streak table
---@return integer kills demandés au joueur (Détermination : un de moins)
function CodStreaks.killsNeeded(match, source, streak)
    return streak.kills - (match:hasPerk(source, 'hardline') and 1 or 0)
end

---Compteur, séries disponibles et prochaine série, pour le HUD.
---@param match table
---@param source integer
function CodStreaks.sendState(match, source)
    local stats = match.stats[source]
    if not stats then return end
    local items = {}
    for index, id in ipairs(stats.streakItems) do
        items[index] = { id = id, label = CodProfileService.streaks[id].label }
    end
    local nextStreak = false
    for _, streak in ipairs(CodStreaks.chosen(source)) do
        local needed = CodStreaks.killsNeeded(match, source, streak)
        if needed > stats.streak and (not nextStreak or needed < nextStreak.kills) then
            nextStreak = { label = streak.label, kills = needed }
        end
    end
    TriggerClientEvent(Events.client.codStreak, source, { streak = stats.streak, items = items, next = nextStreak })
end

---Un kill de plus dans la série : la série atteinte s'ajoute aux disponibles.
---@param match table
---@param source integer
function CodStreaks.onKill(match, source)
    local stats = match.stats[source]
    stats.streak = stats.streak + 1
    stats.bestStreak = math.max(stats.bestStreak, stats.streak)
    for _, streak in ipairs(CodStreaks.chosen(source)) do
        if stats.streak == CodStreaks.killsNeeded(match, source, streak) then
            stats.streakItems[#stats.streakItems + 1] = streak.id
            TriggerClientEvent(Events.client.codEffect, source, { type = 'streakEarned', label = streak.label })
        end
    end
    CodStreaks.sendState(match, source)
end

---Touche des séries : utilise la dernière gagnée.
---@param match table
---@param source integer
function CodStreaks.use(match, source)
    local stats = match.stats[source]
    if match.phase ~= 'running' or not stats or not stats.alive or #stats.streakItems == 0 then return end
    if stats.predatorUntil and GetGameTimer() < stats.predatorUntil then return end
    local id = table.remove(stats.streakItems)
    local streak = CodProfileService.streaks[id]

    if id == 'uav' then
        CodStreaks.startUav(match, source, streak)
    elseif id == 'counter_uav' then
        CodStreaks.startJam(match, source, streak)
    elseif id == 'predator' then
        CodStreaks.startPredator(match, source)
    elseif id == 'juggernaut' then
        TriggerClientEvent(Events.client.codEffect, source, { type = 'juggernaut' })
    elseif id == 'nuke' then
        CodStreaks.startNuke(match, source, streak)
    end
    CodStreaks.announce(match, source, streak)
    CodStreaks.sendState(match, source)
end

---@param match table
---@param source integer
---@param streak table
function CodStreaks.announce(match, source, streak)
    local key = match:sideKey(source)
    for _, other in ipairs(match.players) do
        local friendly = match:sideKey(other) == key
        TriggerClientEvent(Events.client.codNotice, other, {
            text = friendly and Locale.t('%s : %s', match.stats[source].name, Locale.t(streak.label))
                or Locale.t('Ennemi : %s', Locale.t(streak.label)),
            friendly = friendly,
        })
    end
end

-- ---------------------------------------------------------------------------
-- Drone et contre-drone
-- ---------------------------------------------------------------------------

---@param match table
---@param source integer
---@param streak table
function CodStreaks.startUav(match, source, streak)
    match.uav[match:sideKey(source)] = GetGameTimer() + streak.duration * 1000
    match.nextSweep = 0
end

---Carte coupée pour les ennemis.
---@param match table
---@param source integer
---@param streak table
function CodStreaks.startJam(match, source, streak)
    for _, other in ipairs(match.players) do
        if match:areEnemies(source, other) then
            TriggerClientEvent(Events.client.codEffect, other, { type = 'jam', duration = streak.duration })
        end
    end
end

---Relevé du drone pour chaque camp qui en a un : position des ennemis vivants (sauf Fantôme).
---@param match table
---@param now integer
function CodStreaks.sweep(match, now)
    for key, untilAt in pairs(match.uav) do
        if now >= untilAt then
            match.uav[key] = nil
        else
            local points, friends = {}, {}
            for _, source in ipairs(match.players) do
                local ped = GetPlayerPed(source)
                if match:sideKey(source) == key then
                    friends[#friends + 1] = source
                elseif match.stats[source].alive and ped ~= 0 and not match:hasPerk(source, 'ghost') then
                    local coords = GetEntityCoords(ped)
                    points[#points + 1] = { x = coords.x, y = coords.y, z = coords.z }
                end
            end
            for _, source in ipairs(friends) do
                TriggerClientEvent(Events.client.codEffect, source, { type = 'uav', points = points, ttl = Config.Cod.uavSweep })
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Missile Predator
-- ---------------------------------------------------------------------------

---Le pilote a la main sur le missile (client/modules/cod/cod_predator.lua) : il revient avec le point d'impact.
---@param match table
---@param source integer
function CodStreaks.startPredator(match, source)
    local settings = Config.Cod.predator
    local flight = settings.tablet + settings.height / settings.speed + CodStreaks.PREDATOR_SLACK
    match.stats[source].predatorUntil = GetGameTimer() + flight * 1000
    match:broadcast(Events.client.codEffect, { type = 'predatorCall', pilot = source })
end

---@param match table
---@param target any
---@return vector3|nil point d'impact, ramené dans la zone de combat
function CodStreaks.impactPoint(match, target)
    if type(target) ~= 'table' or not tonumber(target.x) or not tonumber(target.y) or not tonumber(target.z) then return nil end
    local point = vector3(tonumber(target.x), tonumber(target.y), tonumber(target.z))
    local offset = point.xy - match.arena.center.xy
    local distance = #offset
    if distance > match.arena.radius then
        local inside = match.arena.center.xy + offset / distance * match.arena.radius
        point = vector3(inside.x, inside.y, point.z)
    end
    return point
end

---Impact annoncé par le pilote : valable une fois, pendant le vol, s'il est toujours en vie.
---@param match table
---@param source integer
---@param target any
function CodStreaks.predatorImpact(match, source, target)
    local stats = match.stats[source]
    if match.phase ~= 'running' or not stats or not stats.alive or not stats.predatorUntil then return end
    local inFlight = GetGameTimer() < stats.predatorUntil
    stats.predatorUntil = nil
    local point = inFlight and CodStreaks.impactPoint(match, target)
    if point then CodStreaks.predatorBlast(match, source, point) end
end

---Effet chez tout le monde (explosion créée par le pilote seul, sans dégâts, pour qu'elle ne soit pas
---multipliée), dégâts appliqués aux ennemis à portée.
---@param match table
---@param source integer
---@param point vector3
function CodStreaks.predatorBlast(match, source, point)
    local settings = Config.Cod.predator
    local now = GetGameTimer()
    for _, other in ipairs(match.players) do
        TriggerClientEvent(Events.client.codEffect, other, {
            type = 'predatorBlast',
            x = point.x, y = point.y, z = point.z,
            owner = other == source,
            explosion = settings.explosionType,
        })
        local stats = match.stats[other]
        local ped = GetPlayerPed(other)
        if match:areEnemies(source, other) and stats.alive and ped ~= 0 and now >= stats.protectedUntil then
            local hit = #(GetEntityCoords(ped) - point)
            if hit <= settings.radius then
                stats.strikeBy = source
                stats.strikeAt = now
                TriggerClientEvent(Events.client.codEffect, other, {
                    type = 'hurt',
                    damage = math.floor(settings.damage * (1 - hit / settings.radius * CodStreaks.PREDATOR_FALLOFF)),
                })
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Frappe nucléaire
-- ---------------------------------------------------------------------------

---@param match table
---@param source integer
---@param streak table
function CodStreaks.startNuke(match, source, streak)
    if match.nuke then return end
    match.nuke = { key = match:sideKey(source), at = GetGameTimer() + streak.duration * 1000, name = match.stats[source].name }
    match:broadcast(Events.client.codEffect, { type = 'nukeCall', seconds = streak.duration })
end

---@param match table
---@param now integer
function CodStreaks.tick(match, now)
    if now >= match.nextSweep and next(match.uav) then
        match.nextSweep = now + Config.Cod.uavSweep * 1000
        CodStreaks.sweep(match, now)
    end
    if match.nuke and now >= match.nuke.at then
        match:broadcast(Events.client.codEffect, { type = 'nukeBlast' })
        match:finish(match.nuke.key, Locale.t('Frappe nucléaire de %s.', match.nuke.name))
    end
end
