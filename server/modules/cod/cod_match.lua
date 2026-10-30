---Une partie du mode Call of Duty : joueurs, équipes, apparitions, kills, XP, fin de partie.
---Le serveur décide de tout (tirs autorisés, kills, scores, réapparitions) ; les règles propres à
---chaque liste de jeu (Match à mort, Domination...) sont dans CodRules, les séries dans CodStreaks.
---@class CodPlayerStats
---@field name string
---@field team string|false 'alpha', 'bravo', false en chacun pour soi
---@field kills integer
---@field deaths integer
---@field assists integer
---@field xp integer XP gagnée dans la partie
---@field alive boolean
---@field deploying boolean encore sur l'écran de choix de classe (pas vivant : caché, sans point de départ réservé)
---@field protectedUntil integer GetGameTimer() de fin de la protection d'apparition
---@field streak integer kills depuis la dernière mort
---@field bestStreak integer
---@field streakItems string[] séries gagnées, pas encore utilisées
---@field class CodClass classe de la vie en cours
---@field lastKillAt integer
---@field multiKill integer
---@field lastKiller integer|nil
---@field damagedBy table<integer, integer> tireur -> GetGameTimer() de sa dernière touche
---@field strikeBy integer|nil dernier joueur dont une série a touché ce joueur
---@field strikeAt integer
---@field strikeLabel string|nil nom de cette série, pour le fil des kills
---@field predatorUntil integer|nil GetGameTimer() de fin du vol de son missile, nil sans missile en vol
---@field pilotUnit integer|nil unité qu'il pilote depuis sa tablette
---@field empUntil integer|nil GetGameTimer() de fin de l'EMP ennemi : ses séries sont bloquées
---@field nextUnitHit integer|nil GetGameTimer() à partir duquel une touche sur une unité compte
---@field holding boolean touche d'objectif maintenue (bombe)
---@field actionProgress number secondes de pose ou de désamorçage
---@field nextResync integer|nil GetGameTimer() à partir duquel une resynchronisation est permise

---@class CodMatchModule
local CodMatch = PVP.define('CodMatch')
local CodRules = PVP.use('CodRules')
local CodStreaks = PVP.use('CodStreaks')
local CodUnits = PVP.use('CodUnits')
local CodCrates = PVP.use('CodCrates')
local CodProfileService = PVP.use('CodProfileService')
local CodService = PVP.use('CodService')
local PlayerService = PVP.use('PlayerService')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CodMatch.__index = CodMatch
CodMatch.TICK = 250 -- ms entre deux passages des règles (drapeaux, bombe, drones)
CodMatch.BROADCAST = 1000 -- ms entre deux envois de l'état aux joueurs
CodMatch.SPAWN_CHOICES = 3 -- tirage parmi les points les plus éloignés des ennemis
CodMatch.RECENT_SPAWN = 5000 -- ms : un point qui vient de servir compte comme occupé
CodMatch.STRIKE_WINDOW = 3000 -- ms : une mort juste après une série revient à celui qui l'a lancée
CodMatch.JOIN_SYNC_DELAY = 2000 -- ms après l'arrivée d'un joueur avant de lui envoyer les unités et colis en jeu
CodMatch.RESYNC_HOP = 500 -- ms hors du bucket de la partie pour recréer les copies des autres joueurs
CodMatch.RESYNC_INTERVAL = 10000 -- ms minimum entre deux resynchronisations d'un joueur
-- Médaille selon le nombre de kills enchaînés (au-delà du dernier : la dernière)
CodMatch.MULTI_KILLS = {
    false,
    { id = 'double', label = 'Doublé' },
    { id = 'triple', label = 'Triplé' },
    { id = 'fury', label = 'Fureur' },
    { id = 'frenzy', label = 'Frénésie' },
    { id = 'massacre', label = 'Massacre' },
}

---@param id integer
---@param playlist table entrée de Config.Cod.playlists
---@param map table entrée de Config.Cod.maps
---@return table
function CodMatch.new(id, playlist, map)
    local settings = Config.Cod
    local now = GetGameTimer()
    local waiting = settings.loadTime + settings.countdown
    local match = setmetatable({
        id = id,
        bucket = settings.bucketBase + id,
        playlist = playlist,
        map = map,
        rules = CodRules.get(playlist.id),
        players = {},
        stats = {},
        scores = { alpha = 0, bravo = 0 },
        sides = { alpha = 'alpha', bravo = 'bravo' },
        recentSpawns = {},
        phase = 'countdown',
        runAt = now + waiting * 1000,
        endAt = now + (waiting + playlist.time) * 1000,
        firstBlood = false,
        lastTick = now,
        nextBroadcast = 0,
    }, CodMatch)
    match.spawnLists = {
        alpha = Config.CodSpawns[map.id .. '_alpha'],
        bravo = Config.CodSpawns[map.id .. '_bravo'],
    }
    match.arena = match:computeArena()
    SetRoutingBucketPopulationEnabled(match.bucket, false)
    CodStreaks.setup(match)
    match.rules.setup(match)
    return match
end

---@return { center: vector3, radius: number } zone de combat (relue à chaque partie : points modifiables en jeu)
function CodMatch:computeArena()
    local center, count = vector3(0.0, 0.0, 0.0), 0
    for _, list in pairs(self.spawnLists) do
        for _, spawn in ipairs(list) do
            center = center + spawn.xyz
            count = count + 1
        end
    end
    return { center = center / math.max(count, 1), radius = self.map.radius }
end

---@param players integer[]
function CodMatch:start(players)
    -- Équipes tirées au sort : un joueur sur deux dans chaque camp
    for index = #players, 2, -1 do
        local other = math.random(index)
        players[index], players[other] = players[other], players[index]
    end
    for _, source in ipairs(players) do
        self:addPlayer(source)
    end
    Logger.info('[cod] partie n°%d : %s sur %s, %d joueurs', self.id, self.playlist.id, self.map.id, #players)

    SetTimeout((Config.Cod.loadTime + Config.Cod.countdown) * 1000, function()
        if self.phase == 'countdown' then self.phase = 'running' end
    end)
    CreateThread(function()
        self:run()
    end)
end

---@return string équipe qui a le moins de joueurs (au moins bon score à égalité)
function CodMatch:smallerTeam()
    local counts = { alpha = 0, bravo = 0 }
    for _, source in ipairs(self.players) do
        local team = self.stats[source].team
        counts[team] = counts[team] + 1
    end
    if counts.alpha ~= counts.bravo then return counts.alpha < counts.bravo and 'alpha' or 'bravo' end
    return self.scores.alpha <= self.scores.bravo and 'alpha' or 'bravo'
end

---Arrivée d'un joueur (au lancement ou en cours de partie).
---@param source integer
function CodMatch:addPlayer(source)
    local settings = Config.Cod
    local now = GetGameTimer()
    local player = PlayerService.get(source)
    local team = self.playlist.teams and self:smallerTeam() or false
    self.stats[source] = {
        name = GetPlayerName(source) or '?',
        team = team,
        kills = 0,
        deaths = 0,
        assists = 0,
        xp = 0,
        alive = false,
        deploying = true,
        protectedUntil = 0,
        streak = 0,
        bestStreak = 0,
        streakItems = {},
        class = CodProfileService.selectedClass(source),
        lastKillAt = 0,
        multiKill = 0,
        damagedBy = {},
        strikeAt = 0,
        holding = false,
        actionProgress = 0,
    }
    self.players[#self.players + 1] = source
    CodService.playerMatch[source] = self.id
    SetPlayerRoutingBucket(source, self.bucket)

    local stats = self.stats[source]
    -- Une partie rejointe en cours passe aussi par l'écran de chargement : bloqué et protégé pendant ce temps
    local countdown = math.max(settings.loadTime, math.ceil((self.runAt - now) / 1000))
    stats.protectedUntil = now + (countdown + settings.spawnProtection) * 1000
    TriggerClientEvent(Events.client.codStart, source, {
        self = source,
        playlist = { id = self.playlist.id, label = self.playlist.label, short = self.playlist.short, scoreLimit = self.playlist.scoreLimit },
        map = { label = self.map.label, place = self.map.place },
        team = team,
        teams = settings.teams,
        arena = self.arena,
        outsideDamage = settings.outsideDamage,
        countdown = countdown,
        remaining = math.max(0, math.ceil((self.endAt - now) / 1000)),
        spawn = self:chooseSpawn(source, true),
        appearance = player and player.appearance,
        objectives = self.rules.objectives(self),
    })
    CodStreaks.sendState(self, source)
    -- Après le fondu d'arrivée : le client ignore les effets tant qu'il n'a pas pris la partie en main
    SetTimeout(CodMatch.JOIN_SYNC_DELAY, function()
        if not self.stats[source] then return end
        CodUnits.sendActive(self, source)
        CodCrates.sendActive(self, source)
    end)
end

---@param a integer
---@param b integer
---@return boolean deux joueurs de la partie qui peuvent se tirer dessus
function CodMatch:areEnemies(a, b)
    if a == b then return false end
    local first, second = self.stats[a], self.stats[b]
    if not first or not second then return false end
    return not self.playlist.teams or first.team ~= second.team
end

---@param source integer
---@return string|integer camp du joueur (équipe, ou lui-même en chacun pour soi)
function CodMatch:sideKey(source)
    return self.stats[source].team or source
end

-- ---------------------------------------------------------------------------
-- Apparitions
-- ---------------------------------------------------------------------------

---Point le plus loin des ennemis (et des apparitions récentes), tiré parmi les meilleurs.
---@param source integer
---@param ownSide boolean seulement les points de son camp (lancement, manche)
---@return vector4
function CodMatch:chooseSpawn(source, ownSide)
    local now = GetGameTimer()
    local taken = {}
    for _, other in ipairs(self.players) do
        local ped = GetPlayerPed(other)
        if self:areEnemies(source, other) and self.stats[other].alive and ped ~= 0 then
            taken[#taken + 1] = GetEntityCoords(ped)
        end
    end
    for index = #self.recentSpawns, 1, -1 do
        local recent = self.recentSpawns[index]
        if now - recent.at < CodMatch.RECENT_SPAWN then
            taken[#taken + 1] = recent.coords
        else
            table.remove(self.recentSpawns, index)
        end
    end

    local team = self.stats[source].team
    local pool = {}
    if ownSide and team then
        for _, spawn in ipairs(self.spawnLists[self.sides[team]]) do pool[#pool + 1] = spawn end
    else
        for _, list in pairs(self.spawnLists) do
            for _, spawn in ipairs(list) do pool[#pool + 1] = spawn end
        end
    end

    local candidates = {}
    for _, spawn in ipairs(pool) do
        local nearest = math.huge
        for _, coords in ipairs(taken) do
            nearest = math.min(nearest, #(spawn.xyz - coords))
        end
        candidates[#candidates + 1] = { spawn = spawn, distance = nearest }
    end
    table.sort(candidates, function(a, b) return a.distance > b.distance end)

    local choice = candidates[math.random(math.min(CodMatch.SPAWN_CHOICES, #candidates))].spawn
    self.recentSpawns[#self.recentSpawns + 1] = { coords = choice.xyz, at = now }
    return choice
end

---Réapparition, avec la classe choisie entre-temps.
---@param source integer
---@param ownSide? boolean
---@param delay? integer secondes à ajouter à la protection (compte à rebours du lancement)
function CodMatch:respawn(source, ownSide, delay)
    if self.phase == 'ended' or CodService.playerMatch[source] ~= self.id then return end
    local stats = self.stats[source]
    local protection = Config.Cod.spawnProtection + (delay or 0)
    stats.alive = true
    stats.deploying = false
    stats.damagedBy = {}
    stats.holding = false
    stats.actionProgress = 0
    stats.predatorUntil = nil
    stats.class = CodProfileService.selectedClass(source)
    stats.protectedUntil = GetGameTimer() + protection * 1000
    TriggerClientEvent(Events.client.codSpawn, source, {
        spawn = self:chooseSpawn(source, ownSide == true),
        class = stats.class,
        protection = protection,
    })
end

---Fin de l'écran de choix de classe : première apparition, de son côté de la carte.
---@param source integer
function CodMatch:deploy(source)
    local stats = self.stats[source]
    if not stats or not stats.deploying then return end
    local countdown = self.phase == 'countdown' and math.max(0, math.ceil((self.runAt - GetGameTimer()) / 1000)) or 0
    self:respawn(source, true, countdown)
end

-- ---------------------------------------------------------------------------
-- Boucle
-- ---------------------------------------------------------------------------

function CodMatch:run()
    while self.phase ~= 'ended' do
        Wait(CodMatch.TICK)
        if self.phase == 'ended' then return end
        local now = GetGameTimer()
        local delta = (now - self.lastTick) / 1000
        self.lastTick = now

        if self.phase == 'running' then
            self.rules.tick(self, now, delta)
            CodStreaks.tick(self, now)
            if self.phase == 'running' and now >= self.endAt then self.rules.onTimeout(self) end
        end
        if self.phase ~= 'ended' and now >= self.nextBroadcast then
            self.nextBroadcast = now + CodMatch.BROADCAST
            self:broadcastState()
        end
    end
end

---Meilleur camp à la fin du temps.
---@return string|integer|nil équipe ou joueur en tête, nil à égalité
function CodMatch:leader()
    if self.playlist.teams then
        if self.scores.alpha == self.scores.bravo then return nil end
        return self.scores.alpha > self.scores.bravo and 'alpha' or 'bravo'
    end
    local board = self:board()
    if not board[1] then return nil end
    if board[2] and board[2].kills == board[1].kills then return nil end
    return board[1].id
end

---@return table[] joueurs de la partie, du meilleur au moins bon
function CodMatch:board()
    local list = {}
    for _, source in ipairs(self.players) do
        local stats = self.stats[source]
        list[#list + 1] = {
            id = source,
            name = stats.name,
            team = stats.team,
            kills = stats.kills,
            deaths = stats.deaths,
            assists = stats.assists,
            score = stats.xp,
            alive = stats.alive,
        }
    end
    local byKills = not self.playlist.teams
    table.sort(list, function(a, b)
        if byKills and a.kills ~= b.kills then return a.kills > b.kills end
        if a.score ~= b.score then return a.score > b.score end
        if a.kills ~= b.kills then return a.kills > b.kills end
        if a.deaths ~= b.deaths then return a.deaths < b.deaths end
        return a.id < b.id
    end)
    return list
end

function CodMatch:broadcastState()
    local data = {
        phase = self.phase,
        remaining = math.max(0, math.ceil((self.endAt - GetGameTimer()) / 1000)),
        scores = self.scores,
        board = self:board(),
        objective = self.rules.describe(self),
    }
    self:broadcast(Events.client.codState, data)
end

---@param event string
function CodMatch:broadcast(event, ...)
    for _, source in ipairs(self.players) do
        TriggerClientEvent(event, source, ...)
    end
end

-- ---------------------------------------------------------------------------
-- Tirs et morts
-- ---------------------------------------------------------------------------

---Seulement pendant la partie et entre ennemis. Une touche annulée désynchronise les deux joueurs
---(le tireur voit sa cible morte, elle reste en vie chez elle) : un joueur qui vient d'apparaître
---n'est donc pas protégé ici mais par son client, qui le rend invincible (Cod.protectedUntil).
---Toucher quelqu'un met fin à sa propre protection d'apparition.
---@param attacker integer
---@param victim integer
---@return boolean
function CodMatch:damageAllowed(attacker, victim)
    if self.phase ~= 'running' or not self:areEnemies(attacker, victim) then return false end
    local target = self.stats[victim]
    local now = GetGameTimer()
    self.stats[attacker].protectedUntil = 0
    if target.alive and now >= target.protectedUntil then target.damagedBy[attacker] = now end
    return true
end

---Le client voit mort un joueur vivant : sa copie locale ne reviendra pas seule. En sortant un instant
---du bucket, le client perd les copies des autres joueurs et le jeu les recrée à leur état réel.
---@param source integer
---@param target any server id du joueur vu mort
function CodMatch:resync(source, target)
    local stats = self.stats[source]
    local other = self.stats[tonumber(target)]
    local now = GetGameTimer()
    if not stats or not other or not other.alive or now < (stats.nextResync or 0) then return end
    stats.nextResync = now + CodMatch.RESYNC_INTERVAL
    Logger.warn('[cod] partie n°%d : %s voit %s mort alors qu\'il est en vie, resynchronisation', self.id, stats.name, other.name)
    SetPlayerRoutingBucket(source, Config.Cod.menuBucketBase + source)
    SetTimeout(CodMatch.RESYNC_HOP, function()
        if CodService.playerMatch[source] == self.id then SetPlayerRoutingBucket(source, self.bucket) end
    end)
end

---@param source integer victime
---@param killerId any server id du tueur, calculé par le client de la victime
---@return integer|nil tueur, s'il est ennemi et assez proche (ou l'auteur d'une série)
---@return boolean tué par une série
function CodMatch:resolveKiller(source, killerId)
    local victim = self.stats[source]
    killerId = tonumber(killerId)
    if killerId and self:areEnemies(source, killerId) then
        local killerPed, victimPed = GetPlayerPed(killerId), GetPlayerPed(source)
        if killerPed ~= 0 and victimPed ~= 0
            and #(GetEntityCoords(killerPed) - GetEntityCoords(victimPed)) <= Config.Cod.killRange then
            return killerId, false
        end
    end
    if victim.strikeBy and self.stats[victim.strikeBy] and GetGameTimer() - victim.strikeAt <= CodMatch.STRIKE_WINDOW then
        return victim.strikeBy, true
    end
    return nil, false
end

---@param source integer
---@param amount integer
---@param label string|table message à traduire (Locale.t)
function CodMatch:award(source, amount, label)
    local stats = self.stats[source]
    if not stats or amount <= 0 then return end
    stats.xp = stats.xp + amount
    TriggerClientEvent(Events.client.codScore, source, { xp = amount, label = label })
end

---Médaille au centre de l'écran du joueur.
---@param source integer
---@param id string
---@param label string nom à traduire
function CodMatch:medal(source, id, label)
    TriggerClientEvent(Events.client.codMedal, source, { id = id, label = label })
end

---Carte à droite de l'écran de toute la partie : exploit ou série déployée par un joueur.
---@param source integer
---@param kind 'medal'|'streak'
---@param id string
---@param label string nom à traduire
function CodMatch:card(source, kind, id, label)
    local key = self:sideKey(source)
    local name = self.stats[source].name
    for _, other in ipairs(self.players) do
        TriggerClientEvent(Events.client.codCard, other, {
            kind = kind,
            id = id,
            label = label,
            name = name,
            friendly = self:sideKey(other) == key,
        })
    end
end

---@param weapon any hash envoyé par le client (signé ou non)
---@return string|nil nom de l'arme à traduire
---@return string|nil id de l'arme, pour sa silhouette dans le fil des kills
function CodMatch.weaponLabel(weapon)
    weapon = tonumber(weapon)
    if not weapon then return nil end
    local hash = math.floor(weapon) & 0xFFFFFFFF
    for _, list in pairs(Config.Cod.weapons) do
        for _, entry in ipairs(list) do
            if (GetHashKey(entry.id) & 0xFFFFFFFF) == hash then return entry.label, entry.id end
        end
    end
    if (GetHashKey(Config.Cod.knife) & 0xFFFFFFFF) == hash then return 'Couteau', Config.Cod.knife end
    if (GetHashKey(Config.Cod.juggernaut.weapon) & 0xFFFFFFFF) == hash then return 'Minigun', Config.Cod.juggernaut.weapon end
    return nil
end

---Mort d'un joueur : score du tueur, XP, série, réapparition.
---@param source integer victime
---@param killerId any
---@param weapon any
---@param headshot any
function CodMatch:onDied(source, killerId, weapon, headshot)
    local victim = self.stats[source]
    if self.phase == 'ended' or not victim or not victim.alive then return end
    victim.alive = false
    victim.deaths = victim.deaths + 1
    victim.holding = false
    victim.actionProgress = 0
    victim.streak = 0
    victim.predatorUntil = nil
    CodUnits.onOwnerDied(self, source)
    CodStreaks.sendState(self, source)

    local running = self.phase == 'running'
    local killer, byStreak = nil, false
    if running then killer, byStreak = self:resolveKiller(source, killerId) end
    local weaponLabel, weaponId, streakId
    if byStreak and victim.strikeLabel then
        weaponLabel, streakId = victim.strikeLabel, CodStreaks.idFromLabel(victim.strikeLabel)
    elseif killer then
        weaponLabel, weaponId = CodMatch.weaponLabel(weapon)
    end
    if killer then
        self:rewardKill(killer, source, headshot == true)
    end
    if running then self:rewardAssists(source, killer) end

    self:broadcast(Events.client.codKill, {
        killer = killer and self.stats[killer].name or nil,
        killerTeam = killer and self.stats[killer].team or nil,
        victim = victim.name,
        victimTeam = victim.team,
        weapon = weaponId,
        streak = streakId,
        headshot = killer ~= nil and headshot == true,
    })

    if running then self.rules.onKill(self, killer, source) end
    if self.phase == 'ended' then return end

    local canRespawn = self.rules.canRespawn(self)
    local revenge = killer and self:hasPerk(source, 'revenge') and GetEntityCoords(GetPlayerPed(killer)) or nil
    TriggerClientEvent(Events.client.codDead, source, {
        killer = killer and self.stats[killer].name or nil,
        weapon = weaponLabel,
        respawn = canRespawn and Config.Cod.respawnDelay or false,
        spectate = killer or self:livingMate(source),
        revenge = revenge,
    })
    if canRespawn then
        SetTimeout(Config.Cod.respawnDelay * 1000, function()
            self:respawn(source)
        end)
    end
end

---@param source integer
---@return integer|nil coéquipier en vie (spectateur en Recherche & Destruction)
function CodMatch:livingMate(source)
    local team = self.stats[source].team
    if not team then return nil end
    for _, other in ipairs(self.players) do
        if other ~= source and self.stats[other].team == team and self.stats[other].alive then return other end
    end
    return nil
end

---@param source integer
---@param perk string
---@return boolean
function CodMatch:hasPerk(source, perk)
    local stats = self.stats[source]
    if not stats then return false end
    for _, id in ipairs(stats.class.perks) do
        if id == perk then return true end
    end
    return false
end

---@param killer integer
---@param source integer victime
---@param headshot boolean
function CodMatch:rewardKill(killer, source, headshot)
    local xp = Config.Cod.xp
    local stats = self.stats[killer]
    local now = GetGameTimer()
    stats.kills = stats.kills + 1
    self:award(killer, xp.kill, Locale.t('Ennemi éliminé'))
    if headshot then self:award(killer, xp.headshot, Locale.t('Tir à la tête')) end

    if not self.firstBlood then
        self.firstBlood = true
        self:award(killer, xp.firstBlood, Locale.t('Premier sang'))
        self:medal(killer, 'first_blood', 'Premier sang')
    end
    if stats.lastKiller == source then
        stats.lastKiller = nil
        self:award(killer, xp.revenge, Locale.t('Revanche'))
        self:medal(killer, 'revenge', 'Revanche')
    end
    self.stats[source].lastKiller = killer

    stats.multiKill = now - stats.lastKillAt <= Config.Cod.multiKillWindow * 1000 and stats.multiKill + 1 or 1
    stats.lastKillAt = now
    local medal = CodMatch.MULTI_KILLS[math.min(stats.multiKill, #CodMatch.MULTI_KILLS)]
    if medal then
        self:award(killer, xp.multiKill * (stats.multiKill - 1), Locale.t(medal.label))
        self:medal(killer, medal.id, medal.label)
        self:card(killer, 'medal', medal.id, medal.label)
    end

    if self:hasPerk(killer, 'scavenger') then TriggerClientEvent(Events.client.codScavenge, killer) end
    CodStreaks.onKill(self, killer)
end

---Touches récentes sur la victime : une assistance pour chaque tireur sauf le tueur.
---@param source integer victime
---@param killer integer|nil
function CodMatch:rewardAssists(source, killer)
    local now = GetGameTimer()
    for shooter, at in pairs(self.stats[source].damagedBy) do
        local stats = self.stats[shooter]
        if shooter ~= killer and stats and now - at <= Config.Cod.assistWindow * 1000 then
            stats.assists = stats.assists + 1
            self:award(shooter, Config.Cod.xp.assist, Locale.t('Assistance'))
        end
    end
    self.stats[source].damagedBy = {}
end

-- ---------------------------------------------------------------------------
-- Départ et fin
-- ---------------------------------------------------------------------------

---Déconnexion, retour au menu ou au lobby : compté comme une défaite, sans bonus de fin.
---@param source integer
function CodMatch:removePlayer(source)
    local stats = self.stats[source]
    CodService.playerMatch[source] = nil
    for position, member in ipairs(self.players) do
        if member == source then table.remove(self.players, position) break end
    end
    if not stats then return end
    CodUnits.onOwnerLeft(self, source)
    self.stats[source] = nil
    if self.phase == 'ended' then return end

    CodProfileService.applyAbandon(source, stats)
    self.rules.onLeave(self, source, stats)
    self:checkPlayers()
end

---Plus assez de joueurs pour continuer : le camp qui reste gagne.
function CodMatch:checkPlayers()
    if self.phase == 'ended' then return end
    if self.playlist.teams then
        local counts = { alpha = 0, bravo = 0 }
        for _, source in ipairs(self.players) do
            local team = self.stats[source].team
            counts[team] = counts[team] + 1
        end
        if counts.alpha == 0 or counts.bravo == 0 then
            self:finish(counts.alpha > 0 and 'alpha' or (counts.bravo > 0 and 'bravo' or nil), Locale.t('Plus assez de joueurs : la partie s\'arrête.'))
        end
    elseif #self.players < 2 then
        self:finish(self.players[1], Locale.t('Plus assez de joueurs : la partie s\'arrête.'))
    end
end

---@param winner string|integer|nil équipe ou joueur gagnant, nil = égalité
---@param reason string|table message à traduire (Locale.t)
function CodMatch:finish(winner, reason)
    if self.phase == 'ended' then return end
    self.phase = 'ended'

    local board = self:board()
    for _, source in ipairs(self.players) do
        local stats = self.stats[source]
        local key = self:sideKey(source)
        local result = winner == nil and 'draw' or (key == winner and 'won' or 'lost')
        local summary = CodProfileService.applyMatch(source, stats, result)
        TriggerClientEvent(Events.client.codEnd, source, {
            result = result,
            reason = reason,
            team = stats.team,
            scores = self.playlist.teams and self.scores or false,
            board = board,
            summary = summary,
            seconds = Config.Cod.endScreen,
        })
    end
    Logger.info('[cod] partie n°%d terminée : %s', self.id, Locale.resolve(reason, Locale.SOURCE))
    SetTimeout(Config.Cod.endScreen * 1000, function()
        CodService.closeMatch(self)
    end)
end

---Ce que le joueur a envoyé pendant l'objectif (touche maintenue).
---@param source integer
---@param holding any
function CodMatch:setHolding(source, holding)
    local stats = self.stats[source]
    if stats then stats.holding = holding == true end
end
