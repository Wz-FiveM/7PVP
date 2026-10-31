---Règles de chaque liste de jeu du mode Call of Duty. Chaque règle définit :
---    setup(match)                    état propre à la règle, au lancement
---    objectives(match)               positions envoyées aux clients (drapeaux, sites)
---    describe(match)                 état de l'objectif, envoyé chaque seconde
---    tick(match, now, delta)         drapeaux, bombe...
---    onKill(match, killer, victim, weapon)   après chaque mort (killer nil : pas de tueur ; weapon nil : tué par une série)
---    canRespawn(match)               réapparition après une mort
---    onTimeout(match)                fin du temps
---    onLeave(match, source, stats)   un joueur est parti
---    classOf(match, source)          facultatif : classe imposée au lieu de celle du joueur
---    points(stats)                   facultatif : score d'un joueur en chacun pour soi, ses kills sinon
---@class CodRulesModule
local CodRules = PVP.define('CodRules')
local CodUnits = PVP.use('CodUnits')
local CodCrates = PVP.use('CodCrates')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

---@param id string clé de Config.Cod.playlists
---@return table
function CodRules.get(id)
    return CodRules.handlers[id]
end

---@param coords vector4[]
---@return { id: string, x: number, y: number, z: number }[] positions nommées A, B, C...
function CodRules.lettered(coords)
    local list = {}
    for index, point in ipairs(coords) do
        list[index] = { id = string.char(64 + index), x = point.x, y = point.y, z = point.z }
    end
    return list
end

---Fin du temps : le camp en tête gagne.
---@param match table
function CodRules.finishByScore(match)
    local winner = match:leader()
    if winner == nil then
        return match:finish(nil, Locale.t('Temps écoulé : égalité.'))
    end
    match:finish(winner, Locale.t('Temps écoulé.'))
end

function CodRules.noop() end
function CodRules.always() return true end

-- ---------------------------------------------------------------------------
-- Match à mort par équipe
-- ---------------------------------------------------------------------------

CodRules.Tdm = {
    setup = CodRules.noop,
    objectives = CodRules.noop,
    describe = CodRules.noop,
    tick = CodRules.noop,
    canRespawn = CodRules.always,
    onTimeout = CodRules.finishByScore,
    onLeave = CodRules.noop,
}

---@param match table
---@param killer integer|nil
function CodRules.Tdm.onKill(match, killer)
    if not killer then return end
    local team = match.stats[killer].team
    match.scores[team] = match.scores[team] + 1
    if match.scores[team] >= match.playlist.scoreLimit then
        match:finish(team, Locale.t('Score atteint.'))
    end
end

-- ---------------------------------------------------------------------------
-- Mêlée générale
-- ---------------------------------------------------------------------------

CodRules.Ffa = {
    setup = CodRules.noop,
    objectives = CodRules.noop,
    describe = CodRules.noop,
    tick = CodRules.noop,
    canRespawn = CodRules.always,
    onTimeout = CodRules.finishByScore,
    onLeave = CodRules.noop,
}

---@param match table
---@param killer integer|nil
function CodRules.Ffa.onKill(match, killer)
    if not killer then return end
    local stats = match.stats[killer]
    if stats.kills >= match.playlist.scoreLimit then
        match:finish(killer, Locale.t('%s a atteint le score.', stats.name))
    end
end

-- ---------------------------------------------------------------------------
-- Élimination confirmée
-- ---------------------------------------------------------------------------

CodRules.Kc = {
    canRespawn = CodRules.always,
    onTimeout = CodRules.finishByScore,
    onLeave = CodRules.noop,
}

---@param match table
function CodRules.Kc.setup(match)
    match.tags = {}
    match.nextTag = 0
end

---@return table les plaques arrivent ensuite avec l'état de la partie (describe)
function CodRules.Kc.objectives()
    return { kind = 'tags', radius = Config.Cod.killConfirmed.radius, points = {} }
end

---@param match table
---@return table
function CodRules.Kc.describe(match)
    local tags = {}
    for index, tag in ipairs(match.tags) do
        tags[index] = { id = tag.id, team = tag.team, x = tag.coords.x, y = tag.coords.y, z = tag.coords.z }
    end
    return { kind = 'tags', tags = tags }
end

---La plaque tombe à l'endroit de la mort, sans attendre l'envoi régulier de l'état.
---@param match table
---@param killer integer|nil
---@param victim integer
function CodRules.Kc.onKill(match, killer, victim)
    local ped = GetPlayerPed(victim)
    if not killer or ped == 0 then return end
    match.nextTag = match.nextTag + 1
    match.tags[#match.tags + 1] = {
        id = match.nextTag,
        team = match.stats[victim].team,
        coords = GetEntityCoords(ped),
        expires = GetGameTimer() + Config.Cod.killConfirmed.lifetime * 1000,
    }
    match.nextBroadcast = 0
end

---@param match table
---@param now integer
function CodRules.Kc.tick(match, now)
    local radius = Config.Cod.killConfirmed.radius
    for index = #match.tags, 1, -1 do
        local tag = match.tags[index]
        local taker = now < tag.expires and CodRules.Kc.takerOf(match, tag, radius)
        if taker or now >= tag.expires then
            table.remove(match.tags, index)
            match.nextBroadcast = 0
            if taker then CodRules.Kc.take(match, tag, taker) end
            if match.phase ~= 'running' then return end
        end
    end
end

---@param match table
---@param tag table
---@param radius number
---@return integer|nil joueur vivant sur la plaque
function CodRules.Kc.takerOf(match, tag, radius)
    for _, source in ipairs(match.players) do
        local ped = GetPlayerPed(source)
        if match.stats[source].alive and ped ~= 0 and #(GetEntityCoords(ped) - tag.coords) <= radius then return source end
    end
    return nil
end

---Plaque d'un ennemi : un point pour le camp du joueur. Plaque d'un allié : le point est refusé.
---@param match table
---@param tag table
---@param source integer
function CodRules.Kc.take(match, tag, source)
    local team = match.stats[source].team
    if team == tag.team then
        return match:award(source, Config.Cod.xp.tagDenied, Locale.t('Élimination refusée'))
    end
    match:award(source, Config.Cod.xp.tagConfirmed, Locale.t('Élimination confirmée'))
    match.scores[team] = match.scores[team] + 1
    if match.scores[team] >= match.playlist.scoreLimit then
        match:finish(team, Locale.t('Score atteint.'))
    end
end

-- ---------------------------------------------------------------------------
-- Course aux armes
-- ---------------------------------------------------------------------------

CodRules.Gun = {
    setup = CodRules.noop,
    objectives = CodRules.noop,
    tick = CodRules.noop,
    canRespawn = CodRules.always,
    onTimeout = CodRules.finishByScore,
    onLeave = CodRules.noop,
}

---@return table
function CodRules.Gun.describe()
    return { kind = 'gun', levels = #Config.Cod.gunGame.ladder }
end

---@param stats table
---@return integer armes déjà passées
function CodRules.Gun.points(stats)
    return (stats.gunLevel or 1) - 1
end

---@param match table
---@param source integer
---@return CodClass
function CodRules.Gun.classOf(match, source)
    local settings = Config.Cod.gunGame
    return {
        name = 'Course aux armes',
        primary = settings.ladder[match.stats[source].gunLevel or 1],
        secondary = false,
        equipment = false,
        perks = settings.perks,
    }
end

---@param match table
---@param killer integer|nil
---@param victim integer
---@param weapon string|nil
function CodRules.Gun.onKill(match, killer, victim, weapon)
    if not killer or not weapon then return end
    local settings = Config.Cod.gunGame
    local stats = match.stats[killer]
    local level = stats.gunLevel or 1
    local current = settings.ladder[level]
    if weapon == Config.Cod.knife and current ~= weapon then return CodRules.Gun.humiliate(match, killer, victim) end

    local previous = weapon == stats.gunPrevious and GetGameTimer() < (stats.gunPreviousUntil or 0)
    if weapon ~= current and not previous then return end
    if level >= #settings.ladder then
        return match:finish(killer, Locale.t('%s a terminé la course.', stats.name))
    end

    stats.gunLevel = level + 1
    stats.gunPrevious = current
    stats.gunPreviousUntil = GetGameTimer() + settings.previousWindow
    stats.class = CodRules.Gun.classOf(match, killer)
    match:award(killer, Config.Cod.xp.gunLevel, Locale.t('Arme suivante'))
    if stats.alive then TriggerClientEvent(Events.client.codClass, killer, stats.class) end
end

---Tué au couteau : la victime recule d'une arme, à sa prochaine apparition.
---@param match table
---@param killer integer
---@param victim integer
function CodRules.Gun.humiliate(match, killer, victim)
    local stats = match.stats[victim]
    match:award(killer, Config.Cod.xp.humiliation, Locale.t('Humiliation'))
    match:medal(killer, 'humiliation', 'Humiliation')
    if (stats.gunLevel or 1) > 1 then
        stats.gunLevel = stats.gunLevel - 1
        TriggerClientEvent(Events.client.codNotice, victim, { text = Locale.t('Humilié : tu recules d\'une arme'), friendly = false })
    end
end

-- ---------------------------------------------------------------------------
-- Domination
-- ---------------------------------------------------------------------------

CodRules.Dom = {
    canRespawn = CodRules.always,
    onKill = CodRules.noop,
    onTimeout = CodRules.finishByScore,
    onLeave = CodRules.noop,
}

---@param match table
function CodRules.Dom.setup(match)
    match.flags = {}
    for index, point in ipairs(Config.CodSpawns[match.map.id .. '_flags']) do
        match.flags[index] = {
            id = string.char(64 + index),
            coords = point.xyz,
            owner = false,
            capturing = false,
            progress = 0.0,
        }
    end
    match.nextScore = 0
end

---@param match table
---@return table
function CodRules.Dom.objectives(match)
    local list = {}
    for index, flag in ipairs(match.flags) do
        list[index] = { id = flag.id, x = flag.coords.x, y = flag.coords.y, z = flag.coords.z }
    end
    return { kind = 'flags', radius = Config.Cod.domination.captureRadius, points = list }
end

---@param match table
---@return table
function CodRules.Dom.describe(match)
    local flags = {}
    for index, flag in ipairs(match.flags) do
        flags[index] = { id = flag.id, owner = flag.owner, capturing = flag.capturing, progress = flag.progress }
    end
    return { kind = 'flags', flags = flags }
end

---@param match table
---@param now integer
---@param delta number secondes
function CodRules.Dom.tick(match, now, delta)
    for _, flag in ipairs(match.flags) do
        CodRules.Dom.updateFlag(match, flag, delta)
    end

    if now < match.nextScore then return end
    match.nextScore = now + Config.Cod.domination.scoreInterval * 1000
    for _, flag in ipairs(match.flags) do
        if flag.owner then
            match.scores[flag.owner] = match.scores[flag.owner] + 1
            for _, source in ipairs(CodRules.Dom.presentOn(match, flag)[flag.owner]) do
                match:award(source, Config.Cod.xp.flagTick, Locale.t('Drapeau tenu'))
            end
        end
    end
    for _, team in ipairs({ 'alpha', 'bravo' }) do
        if match.scores[team] >= match.playlist.scoreLimit then
            return match:finish(team, Locale.t('Score atteint.'))
        end
    end
end

---@param match table
---@param flag table
---@return { alpha: integer[], bravo: integer[] } joueurs vivants sur le drapeau
function CodRules.Dom.presentOn(match, flag)
    local present = { alpha = {}, bravo = {} }
    local radius = Config.Cod.domination.captureRadius
    for _, source in ipairs(match.players) do
        local stats = match.stats[source]
        local ped = GetPlayerPed(source)
        if stats.alive and ped ~= 0 and #(GetEntityCoords(ped).xy - flag.coords.xy) <= radius then
            local list = present[stats.team]
            list[#list + 1] = source
        end
    end
    return present
end

---Un seul camp sur le drapeau : il le capture ; deux camps : tout s'arrête ; personne : la progression retombe.
---@param match table
---@param flag table
---@param delta number
function CodRules.Dom.updateFlag(match, flag, delta)
    local settings = Config.Cod.domination
    local present = CodRules.Dom.presentOn(match, flag)
    local alpha, bravo = #present.alpha, #present.bravo
    if alpha > 0 and bravo > 0 then return end

    local team = alpha > 0 and 'alpha' or (bravo > 0 and 'bravo' or nil)
    if not team or team == flag.owner then
        flag.progress = math.max(0.0, flag.progress - delta / settings.captureTime)
        if flag.progress == 0.0 then flag.capturing = false end
        return
    end

    if flag.capturing ~= team then
        flag.capturing = team
        flag.progress = 0.0
    end
    local count = #present[team]
    flag.progress = flag.progress + delta / settings.captureTime * (1 + settings.captureBonus * (count - 1))
    if flag.progress < 1.0 then return end

    flag.owner = team
    flag.capturing = false
    flag.progress = 0.0
    for _, source in ipairs(present[team]) do
        match:award(source, Config.Cod.xp.capture, Locale.t('Drapeau capturé'))
    end
    match:broadcast(Events.client.codNotice, {
        text = Locale.t('Drapeau %s capturé', flag.id),
        team = team,
    })
end

-- ---------------------------------------------------------------------------
-- Point stratégique
-- ---------------------------------------------------------------------------

CodRules.Hp = {
    canRespawn = CodRules.always,
    onKill = CodRules.noop,
    onTimeout = CodRules.finishByScore,
    onLeave = CodRules.noop,
}

---@param match table
function CodRules.Hp.setup(match)
    CodRules.Dom.setup(match)
    match.zoneIndex = 1
    match.zoneOwner = false
    match.zoneContested = false
    match.zoneTicks = 0
    match.nextZoneMove = match.runAt + Config.Cod.hardpoint.rotate * 1000
end

---@param match table
---@return table
function CodRules.Hp.objectives(match)
    local objectives = CodRules.Dom.objectives(match)
    objectives.kind = 'zone'
    return objectives
end

---@param match table
---@return table
function CodRules.Hp.describe(match)
    return {
        kind = 'zone',
        active = match.flags[match.zoneIndex].id,
        owner = match.zoneOwner,
        contested = match.zoneContested,
        moveIn = math.max(0, math.ceil((match.nextZoneMove - GetGameTimer()) / 1000)),
    }
end

---@param match table
---@param now integer
function CodRules.Hp.tick(match, now)
    local settings = Config.Cod.hardpoint
    if now >= match.nextZoneMove then
        match.zoneIndex = match.zoneIndex % #match.flags + 1
        match.nextZoneMove = match.nextZoneMove + settings.rotate * 1000
        match.nextBroadcast = 0
        match:broadcast(Events.client.codNotice, { text = Locale.t('Le point se déplace en %s', match.flags[match.zoneIndex].id) })
    end
    if now < match.nextScore then return end
    match.nextScore = now + settings.scoreInterval * 1000

    local present = CodRules.Dom.presentOn(match, match.flags[match.zoneIndex])
    local alpha, bravo = #present.alpha, #present.bravo
    local team = alpha > 0 and bravo == 0 and 'alpha' or (bravo > 0 and alpha == 0 and 'bravo') or false
    match.zoneOwner = team
    match.zoneContested = alpha > 0 and bravo > 0
    if team then CodRules.Hp.score(match, team, present[team]) end
end

---@param match table
---@param team string
---@param present integer[] joueurs de l'équipe sur la zone
function CodRules.Hp.score(match, team, present)
    match.scores[team] = match.scores[team] + 1
    match.zoneTicks = match.zoneTicks + 1
    if match.zoneTicks % Config.Cod.hardpoint.xpEvery == 0 then
        for _, source in ipairs(present) do
            match:award(source, Config.Cod.xp.zoneTick, Locale.t('Point tenu'))
        end
    end
    if match.scores[team] >= match.playlist.scoreLimit then
        match:finish(team, Locale.t('Score atteint.'))
    end
end

-- ---------------------------------------------------------------------------
-- Recherche & Destruction
-- ---------------------------------------------------------------------------

CodRules.Snd = {}

---@param match table
function CodRules.Snd.setup(match)
    local settings = Config.Cod.searchDestroy
    match.sites = CodRules.lettered(Config.CodSpawns[match.map.id .. '_sites'])
    match.round = 1
    match.attackers = 'alpha'
    match.bomb = false
    match.endAt = match.runAt + settings.roundTime * 1000
end

---@param match table
---@return table
function CodRules.Snd.objectives(match)
    return { kind = 'sites', radius = Config.Cod.searchDestroy.siteRadius, points = match.sites }
end

---@param match table
---@return table
function CodRules.Snd.describe(match)
    return {
        kind = 'sites',
        round = match.round,
        attackers = match.attackers,
        bomb = match.bomb and { site = match.bomb.site, remaining = math.max(0, math.ceil((match.bomb.at - GetGameTimer()) / 1000)) } or false,
    }
end

---@param match table
---@param source integer
---@return string|nil site à portée
function CodRules.Snd.siteAt(match, source)
    local ped = GetPlayerPed(source)
    if ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    local radius = Config.Cod.searchDestroy.siteRadius
    for _, site in ipairs(match.sites) do
        if #(coords.xy - vector2(site.x, site.y)) <= radius then return site.id end
    end
    return nil
end

---@param match table
---@param now integer
---@param delta number
function CodRules.Snd.tick(match, now, delta)
    local settings = Config.Cod.searchDestroy
    for _, source in ipairs(match.players) do
        local stats = match.stats[source]
        local kind, needed = CodRules.Snd.actionFor(match, source, stats)
        if kind then
            if stats.actionProgress == 0 then
                TriggerClientEvent(Events.client.codAction, source, { kind = kind, seconds = needed })
            end
            stats.actionProgress = stats.actionProgress + delta
            if stats.actionProgress >= needed then
                stats.actionProgress = 0
                stats.holding = false
                TriggerClientEvent(Events.client.codAction, source, false)
                if kind == 'plant' then
                    CodRules.Snd.plant(match, source, settings)
                else
                    CodRules.Snd.defuse(match, source)
                end
                if match.phase ~= 'running' then return end
            end
        elseif stats.actionProgress > 0 then
            stats.actionProgress = 0
            TriggerClientEvent(Events.client.codAction, source, false)
        end
    end

    if match.bomb and now >= match.bomb.at then
        CodRules.Snd.explode(match)
        CodRules.Snd.endRound(match, match.attackers, Locale.t('La bombe a explosé.'))
    end
end

---Effet de l'explosion (créée par un seul client, voir CodEffects.explode).
---@param match table
function CodRules.Snd.explode(match)
    for _, site in ipairs(match.sites) do
        if site.id == match.bomb.site then
            for index, source in ipairs(match.players) do
                TriggerClientEvent(Events.client.codEffect, source, {
                    type = 'bombBlast', x = site.x, y = site.y, z = site.z, owner = index == 1,
                })
            end
        end
    end
end

---@param match table
---@param source integer
---@param stats table
---@return string|nil 'plant' ou 'defuse' si le joueur peut le faire maintenant, number durée
function CodRules.Snd.actionFor(match, source, stats)
    if not stats.holding or not stats.alive then return nil end
    local settings = Config.Cod.searchDestroy
    local site = CodRules.Snd.siteAt(match, source)
    if not site then return nil end
    if stats.team == match.attackers then
        if not match.bomb then return 'plant', settings.plantTime end
    elseif match.bomb and match.bomb.site == site then
        return 'defuse', settings.defuseTime
    end
    return nil
end

---@param match table
---@param source integer
---@param settings table
function CodRules.Snd.plant(match, source, settings)
    local site = CodRules.Snd.siteAt(match, source)
    match.bomb = { site = site, at = GetGameTimer() + settings.bombTime * 1000 }
    match:award(source, Config.Cod.xp.plant, Locale.t('Bombe posée'))
    match:broadcast(Events.client.codNotice, { text = Locale.t('Bombe posée sur le site %s', site), team = match.attackers })
    match:broadcast(Events.client.codEffect, { type = 'bombPlanted', site = site })
end

---@param match table
---@param source integer
function CodRules.Snd.defuse(match, source)
    match:award(source, Config.Cod.xp.defuse, Locale.t('Bombe désamorcée'))
    CodRules.Snd.endRound(match, match.stats[source].team, Locale.t('La bombe a été désamorcée.'))
end

---@param match table
---@param team string
---@return integer joueurs vivants de cette équipe
function CodRules.Snd.aliveCount(match, team)
    local count = 0
    for _, source in ipairs(match.players) do
        local stats = match.stats[source]
        if stats.team == team and stats.alive then count = count + 1 end
    end
    return count
end

---@param team string
---@return string
function CodRules.Snd.otherTeam(team)
    return team == 'alpha' and 'bravo' or 'alpha'
end

---Une équipe éliminée perd la manche (sauf les attaquants après la pose : la bombe tourne encore).
---@param match table
function CodRules.Snd.checkElimination(match)
    if match.phase ~= 'running' then return end
    local defenders = CodRules.Snd.otherTeam(match.attackers)
    if CodRules.Snd.aliveCount(match, defenders) == 0 then
        return CodRules.Snd.endRound(match, match.attackers, Locale.t('Les défenseurs sont éliminés.'))
    end
    if not match.bomb and CodRules.Snd.aliveCount(match, match.attackers) == 0 then
        CodRules.Snd.endRound(match, defenders, Locale.t('Les attaquants sont éliminés.'))
    end
end

---@param match table
function CodRules.Snd.onKill(match)
    CodRules.Snd.checkElimination(match)
end

---@return boolean
function CodRules.Snd.canRespawn()
    return false
end

---Temps écoulé sans pose : les défenseurs gagnent. Bombe posée : c'est elle qui décide.
---@param match table
function CodRules.Snd.onTimeout(match)
    if match.bomb then return end
    CodRules.Snd.endRound(match, CodRules.Snd.otherTeam(match.attackers), Locale.t('Temps écoulé : la bombe n\'a pas été posée.'))
end

---@param match table
function CodRules.Snd.onLeave(match)
    CodRules.Snd.checkElimination(match)
end

---@param match table
---@param winner string
---@param reason string|table message à traduire
function CodRules.Snd.endRound(match, winner, reason)
    if match.phase ~= 'running' then return end
    match.phase = 'round_end'
    match.scores[winner] = match.scores[winner] + 1
    for _, source in ipairs(match.players) do
        local stats = match.stats[source]
        stats.holding = false
        if stats.actionProgress > 0 then
            stats.actionProgress = 0
            TriggerClientEvent(Events.client.codAction, source, false)
        end
        if stats.team == winner then match:award(source, Config.Cod.xp.roundWin, Locale.t('Manche gagnée')) end
        TriggerClientEvent(Events.client.codRoundEnd, source, {
            result = stats.team == winner and 'won' or 'lost',
            reason = reason,
            scores = match.scores,
        })
    end

    if match.scores[winner] >= match.playlist.scoreLimit then
        return match:finish(winner, Locale.t('Score atteint.'))
    end
    SetTimeout(Config.Cod.searchDestroy.roundPause * 1000, function()
        CodRules.Snd.startRound(match)
    end)
end

---Manche suivante : tout le monde revit de son côté, les rôles s'échangent à la mi-temps.
---@param match table
function CodRules.Snd.startRound(match)
    if match.phase ~= 'round_end' then return end
    local settings = Config.Cod.searchDestroy
    local countdown = 5
    local now = GetGameTimer()
    match.round = match.round + 1
    if match.round == settings.swapAfter + 1 then
        match.attackers = CodRules.Snd.otherTeam(match.attackers)
        match.sides.alpha, match.sides.bravo = match.sides.bravo, match.sides.alpha
        match:broadcast(Events.client.codNotice, { text = Locale.t('Changement de camp') })
    end
    match.bomb = false
    match.lastKill = nil
    CodUnits.clear(match)
    CodCrates.clear(match)
    match.phase = 'countdown'
    match.runAt = now + countdown * 1000
    match.endAt = match.runAt + settings.roundTime * 1000
    match:broadcast(Events.client.codEffect, { type = 'roundStart', countdown = countdown })
    for _, source in ipairs(match.players) do
        match:respawn(source, true)
        match.stats[source].protectedUntil = match.runAt
    end

    local round = match.round
    SetTimeout(countdown * 1000, function()
        if match.phase == 'countdown' and match.round == round then match.phase = 'running' end
    end)
end

-- Clés de Config.Cod.playlists
CodRules.handlers = {
    tdm = CodRules.Tdm,
    ffa = CodRules.Ffa,
    kc = CodRules.Kc,
    gun = CodRules.Gun,
    hctdm = CodRules.Tdm,
    hp = CodRules.Hp,
    dom = CodRules.Dom,
    snd = CodRules.Snd,
}
