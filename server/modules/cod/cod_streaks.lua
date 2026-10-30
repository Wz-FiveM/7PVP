---Séries d'éliminations du mode Call of Duty (Config.Cod.streaks) : gagnées en enchaînant les kills,
---utilisées avec une touche. Le serveur garde la main : il calcule les relevés du drone et applique
---lui-même tous les dégâts (les clients n'en font que l'effet visuel).
---Les unités (tourelle, hélicoptères, AC-130) sont dans CodUnits, les colis dans CodCrates.
---@class CodStreaksModule
local CodStreaks = PVP.define('CodStreaks')
local CodProfileService = PVP.use('CodProfileService')
local CodUnits = PVP.use('CodUnits')
local CodCrates = PVP.use('CodCrates')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CodStreaks.PREDATOR_SLACK = 10 -- secondes de marge sur la durée du vol (saccades, latence)
CodStreaks.BLAST_FALLOFF = 0.8 -- part des dégâts perdue au bord d'une explosion

---Séries actives de la partie.
---@param match table
function CodStreaks.setup(match)
    match.uav = {} -- camp -> GetGameTimer() de fin
    match.nextSweep = 0
    match.nuke = false
    CodUnits.setup(match)
    CodCrates.setup(match)
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

---Compteur, séries disponibles et séries choisies (les cases du HUD).
---@param match table
---@param source integer
function CodStreaks.sendState(match, source)
    local stats = match.stats[source]
    if not stats then return end
    local items = {}
    for index, id in ipairs(stats.streakItems) do
        items[index] = { id = id, label = CodProfileService.streaks[id].label }
    end
    local slots = {}
    for index, streak in ipairs(CodStreaks.chosen(source)) do
        slots[index] = { id = streak.id, label = streak.label, kills = CodStreaks.killsNeeded(match, source, streak) }
    end
    table.sort(slots, function(a, b) return a.kills < b.kills end)
    TriggerClientEvent(Events.client.codStreak, source, { streak = stats.streak, items = items, slots = slots })
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
            CodStreaks.give(match, source, streak)
        end
    end
    CodStreaks.sendState(match, source)
end

---@param match table
---@param source integer
---@param streak table
function CodStreaks.give(match, source, streak)
    local stats = match.stats[source]
    stats.streakItems[#stats.streakItems + 1] = streak.id
    TriggerClientEvent(Events.client.codEffect, source, { type = 'streakEarned', label = streak.label })
end

---Touche des séries : utilise la dernière gagnée.
---@param match table
---@param source integer
---@param target any point visé { x, y, z, heading }, pour les séries qui en ont besoin
function CodStreaks.use(match, source, target)
    local stats = match.stats[source]
    if match.phase ~= 'running' or not stats or not stats.alive or #stats.streakItems == 0 then return end
    local now = GetGameTimer()
    if stats.pilotUnit or (stats.predatorUntil and now < stats.predatorUntil) then return end
    if stats.empUntil and now < stats.empUntil then
        TriggerClientEvent(Events.client.codNotice, source, { text = Locale.t('Séries bloquées par l\'EMP'), friendly = false })
        return
    end

    local id = table.remove(stats.streakItems)
    local streak = CodProfileService.streaks[id]
    CodStreaks.STARTERS[id](match, source, streak, target)
    match:card(source, 'streak', streak.id, streak.label)
    CodStreaks.sendState(match, source)
end

-- ---------------------------------------------------------------------------
-- Dégâts
-- ---------------------------------------------------------------------------

---@param match table
---@param target any
---@return vector3|nil point, ramené dans la zone de combat
function CodStreaks.arenaPoint(match, target)
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

---@param match table
---@param source integer
---@param target any
---@return vector3 point visé par le joueur, ou sa position
---@return number cap du regard du joueur
function CodStreaks.aimedPoint(match, source, target)
    local point = CodStreaks.arenaPoint(match, target)
    if not point then
        local ped = GetPlayerPed(source)
        local coords = ped ~= 0 and GetEntityCoords(ped) or match.arena.center
        point = CodStreaks.arenaPoint(match, { x = coords.x, y = coords.y, z = coords.z })
    end
    return point, type(target) == 'table' and tonumber(target.heading) or 0.0
end

---@param match table
---@param source integer
---@param other integer
---@param now integer
---@return boolean un ennemi vivant qui n'est plus protégé
function CodStreaks.canHurt(match, source, other, now)
    local stats = match.stats[other]
    return match:areEnemies(source, other) and stats.alive and GetPlayerPed(other) ~= 0 and now >= stats.protectedUntil
end

---La mort qui suit revient à l'auteur (CodMatch:resolveKiller), avec ce nom d'arme.
---@param match table
---@param source integer
---@param other integer
---@param damage number
---@param label string
function CodStreaks.hurtPlayer(match, source, other, damage, label)
    local stats = match.stats[other]
    stats.strikeBy = source
    stats.strikeAt = GetGameTimer()
    stats.strikeLabel = label
    TriggerClientEvent(Events.client.codEffect, other, { type = 'hurt', damage = math.floor(damage) })
end

---@param label string nom donné à hurtPlayer
---@return string|nil série de ce nom, pour son pictogramme dans le fil des kills
function CodStreaks.idFromLabel(label)
    for _, streak in ipairs(Config.Cod.streaks) do
        if streak.label == label then return streak.id end
    end
    return nil
end

---Effet chez tout le monde (explosion créée par l'auteur seul, sans dégâts, pour qu'elle ne soit pas
---multipliée), dégâts appliqués aux ennemis à portée.
---@param match table
---@param source integer
---@param point vector3
---@param settings { radius: number, damage: number, explosion: integer|nil }
---@param label string arme affichée dans le fil des kills
---@param flat? boolean bombe larguée : le client la pose au sol et la hauteur des joueurs ne compte pas
function CodStreaks.blast(match, source, point, settings, label, flat)
    local now = GetGameTimer()
    for _, other in ipairs(match.players) do
        if settings.explosion then
            TriggerClientEvent(Events.client.codEffect, other, {
                type = 'blast',
                x = point.x, y = point.y, z = point.z,
                owner = other == source,
                explosion = settings.explosion,
                snap = flat == true,
            })
        end
        if CodStreaks.canHurt(match, source, other, now) then
            local coords = GetEntityCoords(GetPlayerPed(other))
            local hit = flat and #(coords.xy - point.xy) or #(coords - point)
            if hit <= settings.radius then
                local ratio = 1 - hit / settings.radius * CodStreaks.BLAST_FALLOFF
                CodStreaks.hurtPlayer(match, source, other, settings.damage * ratio, label)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Drone, contre-drone, EMP
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

---Ennemis : carte coupée, séries bloquées, tourelles et appareils détruits.
---@param match table
---@param source integer
---@param streak table
function CodStreaks.startEmp(match, source, streak)
    local untilAt = GetGameTimer() + streak.duration * 1000
    for _, other in ipairs(match.players) do
        local enemy = match:areEnemies(source, other)
        if enemy then
            match.stats[other].empUntil = untilAt
            TriggerClientEvent(Events.client.codEffect, other, { type = 'jam', duration = streak.duration })
        end
        TriggerClientEvent(Events.client.codEffect, other, { type = 'empBlast', enemy = enemy })
    end
    CodUnits.destroyEnemiesOf(match, source)
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
-- Bombardements en ligne
-- ---------------------------------------------------------------------------

---Des avions passent au-dessus du point visé, dans la direction du regard, et larguent leurs bombes en ligne.
---@param match table
---@param source integer
---@param settings table Config.Cod.precision, stealth ou harrierBombing
---@param point vector3
---@param heading number
---@param label string
function CodStreaks.bombLine(match, source, settings, point, heading, label)
    match:broadcast(Events.client.codEffect, {
        type = 'flyby',
        x = point.x, y = point.y, z = point.z,
        heading = heading,
        model = settings.plane,
        planes = settings.planes,
        delay = settings.delay,
        warn = settings.warn,
    })
    local yaw = math.rad(heading)
    local direction = vector3(-math.sin(yaw), math.cos(yaw), 0.0)
    CreateThread(function()
        Wait(settings.delay * 1000)
        for index = 1, settings.bombs do
            if match.phase ~= 'running' or not match.stats[source] then return end
            local along = settings.length * ((index - 1) / math.max(settings.bombs - 1, 1) - 0.5)
            CodStreaks.blast(match, source, point + direction * along, settings, label, true)
            Wait(settings.interval)
        end
    end)
end

---@param match table
---@param source integer
---@param streak table
---@param target any
function CodStreaks.startPrecision(match, source, streak, target)
    local point, heading = CodStreaks.aimedPoint(match, source, target)
    CodStreaks.bombLine(match, source, Config.Cod.precision, point, heading, streak.label)
end

---@param match table
---@param source integer
---@param streak table
---@param target any
function CodStreaks.startStealth(match, source, streak, target)
    local point, heading = CodStreaks.aimedPoint(match, source, target)
    CodStreaks.bombLine(match, source, Config.Cod.stealth, point, heading, streak.label)
end

---Bombes, puis un Harrier reste en vol stationnaire au-dessus du point et tire sur les ennemis.
---@param match table
---@param source integer
---@param streak table
---@param target any
function CodStreaks.startHarrier(match, source, streak, target)
    local settings = Config.Cod.harrierBombing
    local point, heading = CodStreaks.aimedPoint(match, source, target)
    CodStreaks.bombLine(match, source, settings, point, heading, streak.label)
    SetTimeout(settings.delay * 1000 + settings.bombs * settings.interval, function()
        if match.phase == 'running' and match.stats[source] then
            CodUnits.start(match, source, 'harrier', point, heading)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Missile Predator
-- ---------------------------------------------------------------------------

---Le pilote a la main sur le missile (client/modules/cod/cod_predator.lua) : il revient avec le point d'impact.
---@param match table
---@param source integer
function CodStreaks.startPredator(match, source)
    local settings = Config.Cod.predator
    local flight = Config.Cod.tabletTime + settings.height / settings.speed + CodStreaks.PREDATOR_SLACK
    match.stats[source].predatorUntil = GetGameTimer() + flight * 1000
    match:broadcast(Events.client.codEffect, { type = 'predatorCall', pilot = source })
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
    local point = inFlight and CodStreaks.arenaPoint(match, target)
    if point then CodStreaks.blast(match, source, point, Config.Cod.predator, 'Missile Predator') end
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
    CodUnits.tick(match, now)
    CodCrates.tick(match, now)
    if match.nuke and now >= match.nuke.at then
        match:broadcast(Events.client.codEffect, { type = 'nukeBlast' })
        match:finish(match.nuke.key, Locale.t('Frappe nucléaire de %s.', match.nuke.name))
    end
end

-- Série -> fonction de lancement : function(match, source, streak, target)
CodStreaks.STARTERS = {
    uav = CodStreaks.startUav,
    counter_uav = CodStreaks.startJam,
    predator = CodStreaks.startPredator,
    precision = CodStreaks.startPrecision,
    stealth = CodStreaks.startStealth,
    harrier = CodStreaks.startHarrier,
    emp = CodStreaks.startEmp,
    nuke = CodStreaks.startNuke,
    care_package = function(match, source, _, target)
        CodCrates.drop(match, source, CodStreaks.aimedPoint(match, source, target), 1)
    end,
    airdrop = function(match, source, _, target)
        CodCrates.drop(match, source, CodStreaks.aimedPoint(match, source, target), Config.Cod.crates.airdropCount)
    end,
    sentry = function(match, source, _, target)
        CodUnits.start(match, source, 'sentry', CodStreaks.aimedPoint(match, source, target))
    end,
    helicopter = function(match, source) CodUnits.start(match, source, 'helicopter') end,
    pave_low = function(match, source) CodUnits.start(match, source, 'pave_low') end,
    chopper_gunner = function(match, source) CodUnits.start(match, source, 'chopper_gunner') end,
    ac130 = function(match, source) CodUnits.start(match, source, 'ac130') end,
    juggernaut = function(_, source)
        TriggerClientEvent(Events.client.codEffect, source, { type = 'juggernaut' })
    end,
}
