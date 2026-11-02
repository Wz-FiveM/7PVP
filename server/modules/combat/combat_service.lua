---Morts des joueurs, récompenses de kill et killfeed.
---@class CombatServiceModule
local CombatService = PVP.define('CombatService')
local PlayerService = PVP.use('PlayerService')
local SpawnService = PVP.use('SpawnService')
local LootService = PVP.use('LootService')
local ModeRegistry = PVP.use('ModeRegistry')
local CombatTagService = PVP.use('CombatTagService')
local BountyService = PVP.use('BountyService')
local RivalryService = PVP.use('RivalryService')
local GroupService = PVP.use('GroupService')
local AchievementService = PVP.use('AchievementService')
local AntiCheatService = PVP.use('AntiCheatService')
local KillProof = PVP.use('KillProof')
local Items = PVP.use('Items')
local ContractService = PVP.use('ContractService')
local ConflictService = PVP.use('ConflictService')
local CrewStatsService = PVP.use('CrewStatsService')
local DiscordService = PVP.use('DiscordService')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

function CombatService.init()
    RegisterNetEvent(Events.server.died, function(killerId, cause)
        CombatService.onPlayerDied(source, killerId, cause)
    end)

    -- Envoyé par le joueur touché : dégâts reçus, transmis au tireur (hitmarker)
    RegisterNetEvent(Events.server.hitReport, function(attackerId, hit)
        CombatService.onHitReport(source, attackerId, hit)
    end)

    -- Envoyé par le client propriétaire de zombies touchés par d'autres joueurs : un paquet de touches
    RegisterNetEvent(Events.server.npcHitReport, function(reports)
        CombatService.onNpcHitReports(source, reports)
    end)
end

-- Bornes des dégâts acceptés dans un signalement (vie au-dessus du seuil de mort, armure)
CombatService.MAX_HIT_HEALTH = 200
CombatService.MAX_HIT_ARMOR = 100
-- Les zombies peuvent avoir plus de vie qu'un joueur (bloc `npc` des zones)
CombatService.MAX_NPC_HIT_HEALTH = 1000
-- Touches lues par paquet (Hits.MAX_ZOMBIE_REPORTS côté client)
CombatService.MAX_NPC_HIT_REPORTS = 32

---@param value any
---@param max integer
---@return integer
function CombatService.clampDamage(value, max)
    return math.floor(math.min(math.max(tonumber(value) or 0, 0), max))
end

---@param source integer propriétaire des zombies
---@param reports any liste de { attackerId, netId, hit }
function CombatService.onNpcHitReports(source, reports)
    if type(reports) ~= 'table' or not AntiCheatService.allow(source, 'npcHit') then return end
    for i = 1, math.min(#reports, CombatService.MAX_NPC_HIT_REPORTS) do
        local report = reports[i]
        if type(report) == 'table' then
            CombatService.onNpcHitReport(source, report.attackerId, report.netId, report.hit)
        end
    end
end

---Zombie touché : seul son propriétaire réseau peut le signaler, le tireur doit être proche.
---@param source integer propriétaire du zombie
---@param attackerId any
---@param netId any
---@param hit any { damage, headshot, fatal }
function CombatService.onNpcHitReport(source, attackerId, netId, hit)
    if type(hit) ~= 'table' then return end
    netId = tonumber(netId)
    local ped = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if ped == 0 or not DoesEntityExist(ped) or not Entity(ped).state.pvpNpc then return end
    if NetworkGetEntityOwner(ped) ~= source then return end

    local attacker = PlayerService.get(tonumber(attackerId))
    if not attacker or attacker.mode ~= 'pvp' then return end
    if not CombatService.isWithinKillRange(attacker:getCoords(), GetEntityCoords(ped)) then return end

    local damage = CombatService.clampDamage(hit.damage, CombatService.MAX_NPC_HIT_HEALTH)
    local armor = CombatService.clampDamage(hit.armor, CombatService.MAX_HIT_ARMOR) -- gilet des zombies du SWAT
    if damage + armor == 0 then return end

    TriggerClientEvent(Events.client.hitConfirm, attacker.source, {
        damage = damage,
        armor = armor,
        headshot = hit.headshot == true,
        fatal = hit.fatal == true,
    })
end

---Le serveur ne fait que relayer : le hitmarker est purement visuel, mais on vérifie que
---les deux joueurs existent, sont dans le même mode et assez proches.
---@param source integer joueur touché
---@param attackerId any
---@param hit any { health, armor, headshot, fatal }
function CombatService.onHitReport(source, attackerId, hit)
    if type(hit) ~= 'table' or not AntiCheatService.allow(source, 'hit') then return end
    local victim = PlayerService.get(source)
    local attacker = PlayerService.get(tonumber(attackerId))
    if not victim or not attacker or attacker == victim then return end
    if not attacker.mode or attacker.mode ~= victim.mode then return end
    if not CombatService.isWithinKillRange(attacker:getCoords(), victim:getCoords()) then return end
    if not KillProof.canReportHit(attacker.source, victim.source) then return end

    local health = CombatService.clampDamage(hit.health, CombatService.MAX_HIT_HEALTH)
    local armor = CombatService.clampDamage(hit.armor, CombatService.MAX_HIT_ARMOR)
    if health + armor == 0 then return end
    CombatTagService.onPlayerHit(attacker, victim)
    CombatService.recordHit(attacker, victim, health + armor, hit.headshot == true)

    TriggerClientEvent(Events.client.hitConfirm, attacker.source, {
        damage = health + armor,
        armor = armor,
        headshot = hit.headshot == true,
        fatal = hit.fatal == true,
    })
end

---@param source integer
---@param killerId integer|nil server id du tueur, calculé par le client
---@param cause any { weapon: hash, zombie: boolean } cause de la mort vue par le client
function CombatService.onPlayerDied(source, killerId, cause)
    local victim = PlayerService.get(source)
    if not victim or victim.dead then return end

    victim.dead = true
    victim:incrementStat('deaths')
    CombatTagService.clear(victim)

    CombatService.dropVictimLoot(victim)

    local killer = CombatService.resolveKiller(victim, killerId)
    -- Parti pendant la vérification du kill : profil déjà sauvegardé, rien à lui envoyer
    if PlayerService.get(source) ~= victim then return end
    local recap = CombatService.buildRecap(victim, killer, type(cause) == 'table' and cause or {})
    if killer then
        if type(cause) == 'table' and cause.headshot == true then AchievementService.track(killer, 'headshots', 1) end
        CombatService.rewardPlayerKill(killer, victim)
    end
    CombatService.broadcastKill(killer and killer:displayName(), victim:displayName(), nil, recap, {
        weapon = CombatService.weaponItem(cause and cause.weapon),
        headshot = type(cause) == 'table' and cause.headshot == true,
        killerId = killer and killer.source,
        victimId = victim.source,
        killerColors = killer and killer:displayColors(),
        victimColors = victim:displayColors(),
        background = killer and killer.killfeedBackground,
    })
    BountyService.reset(victim)

    victim:sync()
    TriggerClientEvent(Events.client.dead, victim.source, Config.RespawnDelay, recap)
    SpawnService.scheduleRespawn(victim, Config.RespawnDelay)
end

---Le contenu du sac (argent compris) tombe au sol, le conteneur protégé est conservé.
---@param victim PvpPlayer
---@param coords? vector3 position du sac (défaut : position du joueur)
function CombatService.dropVictimLoot(victim, coords)
    LootService.drop(coords or victim:getCoords(), victim:takeBag(), {
        bucket = GetPlayerRoutingBucket(victim.source),
        -- Ouvert comme un coffre : on glisse dans son sac ce qu'on veut garder
        browse = true,
        label = Locale.t('Fouiller le butin'),
        title = Locale.t('Butin de %s', victim:displayName()),
    })
end

---Tueur annoncé par la victime, s'il est dans le même monde et que le serveur a vu ce kill.
---Peut attendre la vie synchronisée de la victime (voir KillProof.confirm).
---@param victim PvpPlayer
---@param killerId any
---@return PvpPlayer|nil
function CombatService.resolveKiller(victim, killerId)
    killerId = tonumber(killerId)
    if not killerId or killerId == victim.source or victim.mode ~= 'pvp' then return nil end

    local killer = PlayerService.get(killerId)
    if not killer or killer.mode ~= victim.mode or GetPlayerRoutingBucket(killerId) ~= GetPlayerRoutingBucket(victim.source)
        or not CombatService.isWithinKillRange(killer:getCoords(), victim:getCoords()) then
        return nil
    end
    if not KillProof.confirm(victim.source, killerId) then
        if AntiCheatService.watched(victim.source) then
            AntiCheatService.flag(victim.source, 'kill', ('tueur annoncé : %s (ID %d)'):format(killer.name, killerId))
        end
        return nil
    end
    return PlayerService.get(killerId) == killer and killer or nil
end

---@param a vector3
---@param b vector3
---@return boolean
function CombatService.isWithinKillRange(a, b)
    return #(a - b) <= Config.MaxKillDistance
end

---@param killer PvpPlayer
---@param victim PvpPlayer
---@param message? string|table texte de la notification, message à traduire (défaut : « Tu as tué X »)
function CombatService.rewardPlayerKill(killer, victim, message)
    local reward = Config.Rewards.playerKill
    killer:incrementStat('kills')
    killer:addMoney(reward.money)
    killer:addXp(reward.xp)
    killer:notify(Locale.t('%s (+$%d)', message or Locale.t('Tu as tué %s', victim:displayName()), reward.money), 'success')
    BountyService.onPlayerKill(killer, victim)
    ConflictService.onPlayerKill(killer, victim)
    CrewStatsService.onPlayerKill(killer, victim)
    RivalryService.onPlayerKill(killer, victim)
    CombatService.rewardAssists(killer, victim)
    ContractService.track(killer, 'playerKill', 1)
    AchievementService.track(killer, 'bestStreak', killer.streak)
    AchievementService.track(killer, 'longShot', math.floor(#(killer:getCoords() - victim:getCoords())))
    killer:sync()
end

---Ceux qui ont fait assez de dégâts à la victime peu avant sa mort touchent une part du kill (Config.Assists).
---@param killer PvpPlayer
---@param victim PvpPlayer
function CombatService.rewardAssists(killer, victim)
    local settings, now = Config.Assists, GetGameTimer()
    local money = math.floor(Config.Rewards.playerKill.money * settings.share)
    local xp = math.floor(Config.Rewards.playerKill.xp * settings.share)
    for source, entry in pairs(victim.combatLog.taken) do
        local helper = source ~= killer.source and PlayerService.get(source)
        if helper and helper.mode == 'pvp' and entry.damage >= settings.minDamage and now - entry.lastAt <= settings.window * 1000
            and not GroupService.areAllies(source, victim.source) then
            helper.assists = helper.assists + 1
            AchievementService.track(helper, 'assists', 1)
            helper:addMoney(money)
            helper:addXp(xp)
            helper:notify(Locale.t('Assistance sur %s (+$%d)', victim:displayName(), money), 'success')
            helper:sync()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Récapitulatif de mort
-- ---------------------------------------------------------------------------

---Note une touche confirmée dans le journal des deux joueurs (vie en cours).
---@param attacker PvpPlayer
---@param victim PvpPlayer
---@param damage integer
---@param headshot boolean
function CombatService.recordHit(attacker, victim, damage, headshot)
    CombatService.addToLog(victim.combatLog.taken, attacker.source, damage, headshot)
    CombatService.addToLog(attacker.combatLog.dealt, victim.source, damage, headshot)
end

---@param log table<integer, table>
---@param other integer server id de l'autre joueur
---@param damage integer
---@param headshot boolean
function CombatService.addToLog(log, other, damage, headshot)
    local entry = log[other] or { damage = 0, hits = 0, headshots = 0 }
    entry.damage = entry.damage + damage
    entry.hits = entry.hits + 1
    entry.lastAt = GetGameTimer()
    if headshot then entry.headshots = entry.headshots + 1 end
    log[other] = entry
end

---Qui t'a tué, avec quoi, d'où, et les dégâts échangés avec lui pendant cette vie.
---@param victim PvpPlayer
---@param killer PvpPlayer|nil
---@param cause table { weapon: hash, zombie: boolean }
---@return table
function CombatService.buildRecap(victim, killer, cause)
    local recap = { weapon = CombatService.weaponLabel(cause.weapon), zombie = cause.zombie == true }
    if not killer then return recap end

    local taken = victim.combatLog.taken[killer.source] or {}
    local dealt = victim.combatLog.dealt[killer.source] or {}
    local ped = GetPlayerPed(killer.source)
    recap.killer = killer:displayName()
    recap.killerId = killer.source
    recap.distance = math.floor(#(killer:getCoords() - victim:getCoords()) + 0.5)
    recap.killerHealth = math.max(0, GetEntityHealth(ped) - 100)
    recap.killerArmor = GetPedArmour(ped)
    recap.taken = { damage = taken.damage or 0, hits = taken.hits or 0, headshots = taken.headshots or 0 }
    recap.dealt = { damage = dealt.damage or 0, hits = dealt.hits or 0, headshots = dealt.headshots or 0 }
    return recap
end

---@param hash any hash d'arme (GetPedCauseOfDeath côté client)
---@return string|nil objet de Config.Items correspondant (pour son image)
function CombatService.weaponItem(hash)
    hash = tonumber(hash)
    if not hash or hash == 0 then return nil end
    for name, item in pairs(Config.Items) do
        if item.weapon and GetHashKey(item.weapon) == hash then return name end
    end
    return nil
end

---@param hash any hash d'arme (GetPedCauseOfDeath côté client)
---@return string|nil
function CombatService.weaponLabel(hash)
    hash = tonumber(hash)
    if not hash or hash == 0 then return nil end
    for name, item in pairs(Config.Items) do
        if item.weapon and GetHashKey(item.weapon) == hash then return Items.label(name) end
    end
    if hash == GetHashKey('WEAPON_UNARMED') then return 'Mains nues' end
    if hash == GetHashKey('WEAPON_RUN_OVER_BY_CAR') or hash == GetHashKey('WEAPON_RAMMED_BY_CAR') then return 'Véhicule' end
    if hash == GetHashKey('WEAPON_FALL') then return 'Chute' end
    return nil
end

---@param killer PvpPlayer
---@param zoneId? string zone PvE du zombie (contrats)
function CombatService.rewardNpcKill(killer, zoneId)
    local reward = Config.Rewards.npcKill
    killer:incrementStat('npcKills')
    ContractService.track(killer, 'npcKill', 1, zoneId)
    killer:addMoney(reward.money)
    killer:addXp(reward.xp)
    killer:sync()
end

---@param killerName string|nil
---@param victimName string
---@param reason? 'disconnect' déconnexion en plein combat
---@param recap? table récapitulatif de mort (arme, distance) pour le killfeed Discord
---@param extra? { weapon: string|nil, headshot: boolean, killerId: integer|nil, victimId: integer|nil, killerColors: string|nil, victimColors: string|nil, background: string|nil } affichage du killfeed (background : fond choisi par le tueur)
function CombatService.broadcastKill(killerName, victimName, reason, recap, extra)
    extra = extra or {}
    ModeRegistry.broadcast('pvp', Events.client.killfeed, {
        killer = killerName,
        victim = victimName,
        reason = reason,
        weapon = extra.weapon,
        headshot = extra.headshot == true,
        killerId = extra.killerId,
        victimId = extra.victimId,
        killerColors = extra.killerColors,
        victimColors = extra.victimColors,
        background = extra.background,
    })
    DiscordService.killfeed(killerName, victimName, reason, recap)
end
