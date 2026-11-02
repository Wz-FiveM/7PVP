---Anti-cheat côté serveur (Config.AntiCheat). Détections :
---  weapon    : touche avec une arme absente de l'inventaire (PvP)
---  heldWeapon : arme en main absente de l'inventaire, retirée aussitôt (PvP)
---  damage    : plusieurs touches sur des joueurs au-dessus du maximum de l'arme (la touche passe toujours)
---  damageModifier : multiplicateur de dégâts du joueur au-dessus de ce que permet sa classe
---  explosion : explosion d'arme (grenade, roquette...) en PvP
---  entity    : véhicule créé par un joueur en PvP ou au lobby
---  health    : vie ou armure au-dessus du maximum ; godmode : joueur invincible et qui le reste hors zone safe
---  immunity  : touches encaissées d'affilée sans perdre de vie (godmode que le serveur ne voit pas directement)
---  aimbot    : presque que des tirs à la tête, ou touches sur un joueur que la caméra ne regarde pas
---  teleport  : déplacement impossible entre deux relevés de position (à pied, le joueur est ramené d'où il vient)
---  noclip    : à pied, vol rapide, montée continue ou déplacement d'un personnage figé
---  collision : à pied, collisions coupées et qui le restent
---  freecam   : caméra envoyée par le jeu loin du personnage, et qui y reste
---  spam      : requêtes réseau en rafale ; heartbeat : script client arrêté
---  kill      : tueur annoncé par la victime sans que le serveur ait vu ce kill (voir KillProof)
---Chaque détection est journalisée (console + Discord) ; la sanction tombe au-delà d'un nombre
---d'alertes. Les admins ne sont jamais contrôlés.
---@class AntiCheatServiceModule
local AntiCheatService = PVP.define('AntiCheatService')
local PlayerService = PVP.use('PlayerService')
local AdminService = PVP.use('AdminService')
local BanRepository = PVP.use('BanRepository')
local DiscordService = PVP.use('DiscordService')
local ReportService = PVP.use('ReportService')
local ClassService = PVP.use('ClassService')
local GroupService = PVP.use('GroupService')
local PveWorldService = PVP.use('PveWorldService')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')
local DungeonService = PVP.use('DungeonService')

AntiCheatService.WATCH_INTERVAL = 1000
AntiCheatService.VITALS_INTERVAL = 2000
AntiCheatService.HEARTBEAT_CHECK = 15000

-- Armes toujours permises (mains nues, véhicule) : hashs non signés.
-- WEAPON_EXPLOSION : souffle d'une explosion permise (véhicule ou pompe touchés par balle, arme possédée) ;
-- les explosions interdites sont contrôlées par onExplosion.
AntiCheatService.ALWAYS_ALLOWED = { 'WEAPON_UNARMED', 'WEAPON_RUN_OVER_BY_CAR', 'WEAPON_RAMMED_BY_CAR', 'WEAPON_FALL', 'WEAPON_EXPLOSION' }
-- Ce qu'un joueur peut tenir en main sans objet dans son inventaire
AntiCheatService.ALWAYS_HELD = { 'WEAPON_UNARMED', 'GADGET_PARACHUTE' }

AntiCheatService.strikes = {} -- [source][détection] = { horodatages }
AntiCheatService.heldWeapons = {} -- [source] = arme non possédée vue en main au dernier relevé
AntiCheatService.immunity = {} -- [source] = { hits, life, at } touches encaissées sans perte de vie
AntiCheatService.aimSamples = {} -- [source] = { { at, head, offAim }, ... } touches récentes sur des joueurs
AntiCheatService.damageHits = {} -- [source] = { os.time() des touches récentes au-dessus du maximum }
---@type table<integer, string>|nil [hash non signé] = objet de l'arme, rempli au premier besoin
AntiCheatService.weaponItems = nil
---@type table<integer, table>|nil [hash non signé] = ligne de Config.AntiCheat.weaponDamage, rempli au premier besoin
AntiCheatService.weaponStats = nil
AntiCheatService.rates = {} -- [source][clé] = { second, count }
AntiCheatService.positions = {} -- [source] = { coords, at, moving }
AntiCheatService.streaks = {} -- [source][signal] = relevés de suite où le signal est présent
AntiCheatService.vehicleAt = {} -- [source] = GetGameTimer() du dernier relevé en véhicule ou accroché à un véhicule
AntiCheatService.graceUntil = {} -- [source] = GetGameTimer()
AntiCheatService.heartbeats = {} -- [source] = os.time() du dernier signal
AntiCheatService.loadedAt = {} -- [source] = os.time() du chargement du profil
AntiCheatService.invincibleSince = {} -- [source] = os.time() du premier relevé invincible hors zone safe
-- Véhicule qu'un joueur a le droit de créer (objet véhicule utilisé) : [source] = { model, expires }
AntiCheatService.allowedVehicles = {}
-- Véhicule créé avec cette autorisation, tant que le client ne l'a pas fait accepter : [source] = entité
AntiCheatService.createdVehicles = {}
AntiCheatService.VEHICLE_ALLOW_TIME = 10000
-- Type de population d'une entité créée par un script (CreateVehicle) : POPTYPE_MISSION
AntiCheatService.POPTYPE_MISSION = 7

function AntiCheatService.init()
    -- Commandes console (et admins en jeu via command.<nom>), même si l'anti-cheat est coupé
    RegisterCommand('ban', function(source, args)
        AntiCheatService.commandBan(source, args)
    end, true)
    RegisterCommand('unban', function(source, args)
        AntiCheatService.commandUnban(source, args[1])
    end, true)
    RegisterCommand('bans', function(source)
        AntiCheatService.commandList(source)
    end, true)

    if not Config.AntiCheat.enabled then return end

    AddEventHandler('weaponDamageEvent', function(sender, data)
        AntiCheatService.onWeaponDamage(sender, data)
    end)
    AddEventHandler('explosionEvent', function(sender, data)
        AntiCheatService.onExplosion(sender, data)
    end)
    AddEventHandler('entityCreating', function(entity)
        AntiCheatService.onEntityCreating(entity)
    end)
    RegisterNetEvent(Events.server.heartbeat, function()
        AntiCheatService.heartbeats[source] = os.time()
    end)
    AddEventHandler(Events.internal.playerLoaded, function(playerSource)
        AntiCheatService.loadedAt[playerSource] = os.time()
        AntiCheatService.grace(playerSource)
    end)
    AddEventHandler('playerDropped', function()
        AntiCheatService.forget(source)
    end)

    CreateThread(AntiCheatService.watchLoop)
    CreateThread(AntiCheatService.vitalsLoop)
    CreateThread(AntiCheatService.heartbeatLoop)
end

-- ---------------------------------------------------------------------------
-- Outils
-- ---------------------------------------------------------------------------

---Joueur à contrôler : chargé, en PvP (si demandé) et pas admin.
---@param source integer
---@param pvpOnly? boolean
---@return PvpPlayer|nil
function AntiCheatService.watched(source, pvpOnly)
    local player = PlayerService.get(source)
    if not player or AdminService.isAdmin(source) then return nil end
    if pvpOnly and player.mode ~= 'pvp' then return nil end
    return player
end

---@param hash any
---@return integer hash non signé (les natives renvoient parfois un entier signé)
function AntiCheatService.unsigned(hash)
    return math.floor(tonumber(hash) or 0) % 4294967296
end

---Pas de contrôle de position pendant un moment (réapparition, téléportation par un admin...).
---@param source integer
---@param seconds? integer
function AntiCheatService.grace(source, seconds)
    AntiCheatService.graceUntil[source] = GetGameTimer() + (seconds or Config.AntiCheat.teleportGrace) * 1000
    AntiCheatService.positions[source] = nil
    AntiCheatService.streaks[source] = nil
end

---Limite de requêtes par seconde : false (requête à ignorer) au-delà de Config.AntiCheat.rateLimits[key].
---@param source integer
---@param key string callback, hit, npcHit, zombieAttack, npcDeath, loot
---@return boolean
function AntiCheatService.allow(source, key)
    local limit = Config.AntiCheat.rateLimits[key]
    if not Config.AntiCheat.enabled or not limit or source <= 0 then return true end

    local rates = AntiCheatService.rates[source] or {}
    AntiCheatService.rates[source] = rates
    local second = os.time()
    local rate = rates[key]
    if not rate or rate.second ~= second then
        rate = { second = second, count = 0 }
        rates[key] = rate
    end
    rate.count = rate.count + 1
    if rate.count <= limit then return true end

    -- Une seule alerte par seconde de dépassement
    if rate.count == limit + 1 and AntiCheatService.watched(source) then
        AntiCheatService.flag(source, 'spam', ('%s : plus de %d requêtes/s'):format(key, limit))
    end
    return false
end

---@param source integer
function AntiCheatService.forget(source)
    for _, map in ipairs({
        AntiCheatService.strikes, AntiCheatService.rates, AntiCheatService.positions,
        AntiCheatService.graceUntil, AntiCheatService.heartbeats, AntiCheatService.loadedAt,
        AntiCheatService.allowedVehicles, AntiCheatService.createdVehicles, AntiCheatService.invincibleSince,
        AntiCheatService.heldWeapons, AntiCheatService.immunity, AntiCheatService.aimSamples,
        AntiCheatService.streaks, AntiCheatService.vehicleAt, AntiCheatService.damageHits,
    }) do
        map[source] = nil
    end
end

-- ---------------------------------------------------------------------------
-- Alertes et sanctions
-- ---------------------------------------------------------------------------

---@param source integer
---@param detection string clé de Config.AntiCheat.detections
---@param details string
function AntiCheatService.flag(source, detection, details)
    local rule = Config.AntiCheat.detections[detection]
    local player = PlayerService.get(source)
    if not rule or not player then return end

    local now = os.time()
    local window = rule.window or Config.AntiCheat.strikeWindow
    local list = {}
    local previous = AntiCheatService.strikes[source] and AntiCheatService.strikes[source][detection] or {}
    for _, at in ipairs(previous) do
        if now - at < window then list[#list + 1] = at end
    end
    list[#list + 1] = now
    AntiCheatService.strikes[source] = AntiCheatService.strikes[source] or {}
    AntiCheatService.strikes[source][detection] = list

    Logger.warn('[anti-cheat] %s (ID %d) : %s - %s (%d/%d)', player.name, source, rule.label, details, #list, rule.strikes)
    ReportService.recordAlert(player, rule.label, details)
    DiscordService.send('sanctions', {
        title = '🛡️ Anti-cheat : ' .. rule.label,
        color = DiscordService.COLORS.critique,
        fields = {
            { name = 'Joueur', value = ('%s\n`%s`'):format(DiscordService.playerTag(source, player.name), player.identifier) },
            { name = 'Détail', value = DiscordService.escape(details), inline = true },
            { name = 'Alertes', value = ('%d / %d'):format(#list, rule.strikes), inline = true },
        },
    })

    if #list >= rule.strikes and rule.action ~= 'log' then
        AntiCheatService.strikes[source][detection] = {}
        AntiCheatService.punish(player, rule)
    end
end

---@param player PvpPlayer
---@param rule table
function AntiCheatService.punish(player, rule)
    local reason = ('Anti-cheat : %s'):format(rule.label)
    if rule.action == 'ban' then
        local days = rule.banDays or 0
        BanRepository.ban(player.identifier, player.name, reason, 'anti-cheat', days)
        DiscordService.sanction(days > 0 and ('Bannissement %d j'):format(days) or 'Bannissement définitif', 0, player, reason)
        DropPlayer(player.source, ('7PVP : tu es banni (%s).'):format(rule.label))
    else
        DiscordService.sanction('Expulsion', 0, player, reason)
        DropPlayer(player.source, ('7PVP : expulsé par l\'anti-cheat (%s).'):format(rule.label))
    end
end

-- ---------------------------------------------------------------------------
-- Détections sur les événements du jeu
-- ---------------------------------------------------------------------------

---Armes possédées (sac + conteneur protégé), en hashs non signés.
---@param player PvpPlayer
---@return table<integer, boolean>
function AntiCheatService.ownedWeapons(player)
    local owned = {}
    for _, name in ipairs(AntiCheatService.ALWAYS_ALLOWED) do
        owned[AntiCheatService.unsigned(GetHashKey(name))] = true
    end
    for name, item in pairs(Config.Items) do
        if item.weapon and AntiCheatService.hasWeapon(player, name) then
            owned[AntiCheatService.unsigned(GetHashKey(item.weapon))] = true
        end
    end
    return owned
end

---Objet possédé, ou arme de jet lancée il y a peu (la grenade a quitté l'inventaire avant d'exploser).
---@param player PvpPlayer
---@param name string
---@return boolean
function AntiCheatService.hasWeapon(player, name)
    if player.inventory:count(name) > 0 then return true end
    local thrown = player.recentThrows and player.recentThrows[name]
    return thrown ~= nil and os.time() - thrown <= Config.AntiCheat.throwGrace
end

---@param player PvpPlayer
---@param explosionType integer
---@return boolean
function AntiCheatService.explosionAllowed(player, explosionType)
    for _, name in ipairs(Config.AntiCheat.explosionWeapons[explosionType] or {}) do
        if AntiCheatService.hasWeapon(player, name) then return true end
    end
    return false
end

---@param sender integer|string le jeu l'envoie en texte, les relevés sont indexés par nombre
---@param data table
function AntiCheatService.onWeaponDamage(sender, data)
    sender = tonumber(sender)
    if not sender or type(data) ~= 'table' then return end
    -- Tir du boss de donjon, piloté par ce client : l'arme n'est pas la sienne
    if DungeonService.isBossShot(sender, data) then return end
    local player = AntiCheatService.watched(sender, true)
    local weapon = AntiCheatService.unsigned(data.weaponType)
    if player and weapon ~= 0 and not AntiCheatService.ownedWeapons(player)[weapon] then
        CancelEvent()
        return AntiCheatService.flag(sender, 'weapon', ('arme %d absente de l\'inventaire'):format(weapon))
    end

    AntiCheatService.observeHit(sender, player, weapon, data)
    if player then AntiCheatService.checkDamage(sender, player, weapon, data) end
end

---@param player PvpPlayer tireur
---@param weapon integer hash non signé
---@param isHead boolean
---@return number dégâts les plus hauts d'une touche normale sur un joueur
function AntiCheatService.damageCap(player, weapon, isHead)
    if not AntiCheatService.weaponStats then
        AntiCheatService.weaponStats = {}
        for name, stats in pairs(Config.AntiCheat.weaponDamage) do
            AntiCheatService.weaponStats[AntiCheatService.unsigned(GetHashKey(name))] = stats
        end
    end
    local stats = AntiCheatService.weaponStats[weapon]
    if not stats then return Config.AntiCheat.maxWeaponDamage end
    local limit = ClassService.damageLimits(player)
    return stats.damage * (stats.pellets or 1) * (isHead and stats.head or 1) * limit * Config.AntiCheat.damageMargin
end

---Damage boost vu sur les touches. Jamais annulée : une touche annulée désynchronise les deux joueurs (le tireur
---voit sa cible mourir, elle reste en vie chez elle et ne reçoit plus ses tirs). Les touches sur les zombies et les
---véhicules n'ont pas les mêmes multiplicateurs : elles ne comptent pas.
---@param sender integer
---@param player PvpPlayer tireur
---@param weapon integer hash non signé
---@param data table
function AntiCheatService.checkDamage(sender, player, weapon, data)
    local damage = tonumber(data.weaponDamage) or 0
    local component = tonumber(data.hitComponent)
    local cap = AntiCheatService.damageCap(player, weapon, component == Config.AntiCheat.aimbot.headComponent)
    if damage <= cap or not AntiCheatService.playerHitBy(sender, data) then return end

    local now = os.time()
    local hits = {}
    for _, at in ipairs(AntiCheatService.damageHits[sender] or {}) do
        if now - at < Config.AntiCheat.damageWindow then hits[#hits + 1] = at end
    end
    hits[#hits + 1] = now
    AntiCheatService.damageHits[sender] = hits
    if #hits < Config.AntiCheat.damageHits then return end

    -- Une alerte par série de touches, pas une par balle
    AntiCheatService.damageHits[sender] = nil
    AntiCheatService.flag(sender, 'damage', ('%d touches en %d s au-dessus du maximum, dernière : %d dégâts pour %d permis (%s, partie %s%s)'):format(
        #hits, Config.AntiCheat.damageWindow, math.floor(damage), math.floor(cap), AntiCheatService.weaponLabel(weapon),
        tostring(data.hitComponent), data.willKill and ', mortelle' or ''))
end

---Multiplicateur réglé par un menu de triche : le jeu l'envoie au serveur, qui le compare à celui de la classe.
---@param source integer
---@param player PvpPlayer
function AntiCheatService.checkDamageModifier(source, player)
    local rules = Config.AntiCheat.damageModifier
    local weaponLimit, meleeLimit = ClassService.damageLimits(player)
    local weapon, melee = GetPlayerWeaponDamageModifier(source), GetPlayerMeleeWeaponDamageModifier(source)
    local boosted = GetGameTimer() >= (AntiCheatService.graceUntil[source] or 0)
        and (weapon > weaponLimit + rules.weaponTolerance or melee > meleeLimit + rules.meleeTolerance)
    if AntiCheatService.sustained(source, 'damageModifier', boosted, rules.readings) then
        AntiCheatService.flag(source, 'damageModifier', ('armes x%.2f pour x%.2f permis, corps à corps x%.2f pour x%.2f permis'):format(
            weapon, weaponLimit, melee, meleeLimit))
    end
end

---@param weapon integer hash non signé
---@return string|nil objet de Config.Items
function AntiCheatService.itemOfWeapon(weapon)
    if not AntiCheatService.weaponItems then
        AntiCheatService.weaponItems = {}
        for name, item in pairs(Config.Items) do
            if item.weapon then AntiCheatService.weaponItems[AntiCheatService.unsigned(GetHashKey(item.weapon))] = name end
        end
    end
    return AntiCheatService.weaponItems[weapon]
end

---@param sender integer
---@param data table hitGlobalId ou hitGlobalIds (selon la version du serveur)
---@return integer|nil victime, integer|nil son personnage
function AntiCheatService.playerHitBy(sender, data)
    for _, netId in ipairs(data.hitGlobalIds or { data.hitGlobalId }) do
        local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
        if entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) == 1 then
            local owner = NetworkGetEntityOwner(entity)
            if owner and owner > 0 and owner ~= sender and GetPlayerPed(owner) == entity then return owner, entity end
        end
    end
    return nil, nil
end

---Touche d'une arme à feu sur un joueur : ce qu'elle dit de la victime (godmode) et du tireur (aimbot).
---@param sender integer
---@param player PvpPlayer|nil tireur, s'il est contrôlé
---@param weapon integer hash non signé
---@param data table
function AntiCheatService.observeHit(sender, player, weapon, data)
    local item = Config.Items[AntiCheatService.itemOfWeapon(weapon) or '']
    local tracked = item and Config.AntiCheat.trackedAmmo[item.ammo]
    if not tracked then return end
    local victim, victimPed = AntiCheatService.playerHitBy(sender, data)
    if not victim then return end

    AntiCheatService.trackImmunity(sender, victim, victimPed)
    if player then AntiCheatService.trackAim(sender, victimPed, tracked.head, data.hitComponent) end
end

---Godmode invisible pour le serveur (dégâts bloqués ou vie remise à chaque image) : les touches
---arrivent et la vie ne baisse jamais. Une seule baisse remet le compte à zéro.
---@param sender integer
---@param victim integer
---@param ped integer
function AntiCheatService.trackImmunity(sender, victim, ped)
    -- Ces touches-là n'ont pas à blesser : annulées par le jeu ou par les autres modules
    if GroupService.areAllies(sender, victim) or PveWorldService.isInside(victim) then return end

    local player = AntiCheatService.watched(victim, true)
    if not player or player.dead or player:isInSafeZone() or GetVehiclePedIsIn(ped, false) ~= 0
        or GetPlayerInvincible(victim) or GetGameTimer() < (AntiCheatService.graceUntil[victim] or 0) then
        AntiCheatService.immunity[victim] = nil
        return
    end

    local now, life = GetGameTimer(), GetEntityHealth(ped) + GetPedArmour(ped)
    local state = AntiCheatService.immunity[victim]
    if not state or life < state.life or now - state.at > Config.AntiCheat.immunityGap * 1000 then
        state = { hits = 0 }
        AntiCheatService.immunity[victim] = state
    end
    state.hits, state.life, state.at = state.hits + 1, life, now
    if state.hits >= Config.AntiCheat.immunityHits then
        AntiCheatService.immunity[victim] = nil
        AntiCheatService.flag(victim, 'immunity', ('%d touches encaissées sans perdre de vie (vie + armure : %d)'):format(state.hits, life))
    end
end

---Écart entre là où regarde la caméra du joueur et une cible.
---@param source integer
---@param from vector3
---@param to vector3
---@return number|nil degrés, nil sans caméra exploitable
function AntiCheatService.aimOffset(source, from, to)
    if IsPlayerInFreeCamMode(source) then return nil end
    -- En radians, dans le monde (x : tangage, z : lacet)
    local rotation = GetPlayerCameraRotation(source)
    if rotation.x == 0.0 and rotation.z == 0.0 then return nil end

    local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length == 0.0 then return nil end
    local flat = math.cos(rotation.x)
    local dot = (-math.sin(rotation.z) * flat * dx + math.cos(rotation.z) * flat * dy + math.sin(rotation.x) * dz) / length
    return math.deg(math.acos(math.max(-1.0, math.min(1.0, dot))))
end

---@param sender integer
---@param victimPed integer
---@param countsHead boolean
---@param hitComponent any partie du corps touchée
function AntiCheatService.trackAim(sender, victimPed, countsHead, hitComponent)
    local rules = Config.AntiCheat.aimbot
    local ped = GetPlayerPed(sender)
    -- En véhicule, la caméra ne suit plus le tir et la position relevée a du retard sur la vitesse
    if GetVehiclePedIsIn(ped, false) ~= 0 or GetVehiclePedIsIn(victimPed, false) ~= 0 then return end
    local from, to = GetEntityCoords(ped), GetEntityCoords(victimPed)
    if #(to - from) < rules.minDistance then return end

    local now = os.time()
    local samples = {}
    for _, sample in ipairs(AntiCheatService.aimSamples[sender] or {}) do
        if now - sample.at <= rules.window then samples[#samples + 1] = sample end
    end
    local offset = AntiCheatService.aimOffset(sender, from, to)
    samples[#samples + 1] = {
        at = now,
        head = countsHead and tonumber(hitComponent) == rules.headComponent or nil,
        countsHead = countsHead,
        offAim = offset ~= nil and offset >= rules.offAimAngle,
    }
    AntiCheatService.aimSamples[sender] = samples
    AntiCheatService.judgeAim(sender, samples)
end

---@param sender integer
---@param samples table[]
function AntiCheatService.judgeAim(sender, samples)
    local rules = Config.AntiCheat.aimbot
    local heads, headTotal, offAim = 0, 0, 0
    for _, sample in ipairs(samples) do
        if sample.countsHead then headTotal = headTotal + 1 end
        if sample.head then heads = heads + 1 end
        if sample.offAim then offAim = offAim + 1 end
    end

    local details
    if headTotal >= rules.headSamples and heads / headTotal >= rules.headRatio then
        details = ('%d tirs à la tête sur %d touches à plus de %d m'):format(heads, headTotal, math.floor(rules.minDistance))
    elseif offAim >= rules.offAimHits and offAim / #samples >= rules.offAimRatio then
        details = ('%d touches sur %d sans regarder la cible (silent aim)'):format(offAim, #samples)
    end
    if not details then return end
    -- Les relevés repartent de zéro : l'alerte suivante repose sur de nouvelles touches
    AntiCheatService.aimSamples[sender] = nil
    AntiCheatService.flag(sender, 'aimbot', details)
end

---@param weapon integer hash non signé
---@return string nom de l'objet de l'arme, sinon le hash
function AntiCheatService.weaponLabel(weapon)
    for _, name in ipairs(AntiCheatService.ALWAYS_ALLOWED) do
        if AntiCheatService.unsigned(GetHashKey(name)) == weapon then return name end
    end
    for _, item in pairs(Config.Items) do
        if item.weapon and AntiCheatService.unsigned(GetHashKey(item.weapon)) == weapon then return item.label end
    end
    return tostring(weapon)
end

---@param sender integer
---@param data table
function AntiCheatService.onExplosion(sender, data)
    local player = AntiCheatService.watched(sender, true)
    if not player or type(data) ~= 'table' then return end
    local explosionType = tonumber(data.explosionType)
    if explosionType and Config.AntiCheat.blockedExplosions[explosionType]
        and not AntiCheatService.explosionAllowed(player, explosionType) then
        CancelEvent()
        AntiCheatService.flag(sender, 'explosion', ('explosion de type %d'):format(explosionType))
    end
end

---Véhicule créé par un joueur en PvP (le mode n'en donne pas : seuls les admins peuvent) ou au lobby
---(rien n'y crée de véhicule en réseau). Le Freeroam et Call of Duty créent les leurs, ils ne sont pas contrôlés.
---Les PNJ ne sont pas contrôlés ici : le personnage d'un joueur est lui aussi créé comme un PNJ
---à chaque réapparition, le bloquer casserait le jeu.
---Seuls les véhicules créés par un script comptent comme triche : ceux que GTA fait apparaître
---lui-même (hélicoptères garés sur les héliports, véhicules de scénario...) appartiennent au
---joueur le plus proche, qui n'y est pour rien. Ils sont refusés sans alerte (monde PvP vide).
---@param entity integer
function AntiCheatService.onEntityCreating(entity)
    if GetEntityType(entity) ~= 2 then return end
    local owner = NetworkGetEntityOwner(entity)
    local player = owner and owner > 0 and AntiCheatService.watched(owner)
    if not player or (player.mode and player.mode ~= 'pvp') then return end
    if AntiCheatService.consumeVehicleAllowance(owner, GetEntityModel(entity)) then
        AntiCheatService.createdVehicles[owner] = entity
        return
    end

    CancelEvent()
    if GetEntityPopulationType(entity) ~= AntiCheatService.POPTYPE_MISSION then return end
    AntiCheatService.flag(owner, 'entity', ('véhicule (modèle %d)'):format(AntiCheatService.unsigned(GetEntityModel(entity))))
end

-- ---------------------------------------------------------------------------
-- Contrôles réguliers
-- ---------------------------------------------------------------------------

---Autorise un joueur à créer ce véhicule pendant quelques secondes (objet véhicule utilisé).
---@param source integer
---@param model string
function AntiCheatService.allowVehicle(source, model)
    AntiCheatService.allowedVehicles[source] = {
        model = AntiCheatService.unsigned(GetHashKey(model)),
        expires = GetGameTimer() + AntiCheatService.VEHICLE_ALLOW_TIME,
    }
end

---Une autorisation ne sert qu'une fois.
---@param source integer
---@param model integer
---@return boolean
function AntiCheatService.consumeVehicleAllowance(source, model)
    local allowed = AntiCheatService.allowedVehicles[source]
    if not allowed or GetGameTimer() > allowed.expires or allowed.model ~= AntiCheatService.unsigned(model) then
        return false
    end
    AntiCheatService.allowedVehicles[source] = nil
    return true
end

---Le véhicule créé a été accepté par VehicleService.
---@param source integer
function AntiCheatService.keepVehicle(source)
    AntiCheatService.createdVehicles[source] = nil
end

---Objet rendu au joueur : l'autorisation tombe, et le véhicule déjà créé ne reste pas en jeu.
---@param source integer
function AntiCheatService.discardVehicle(source)
    AntiCheatService.allowedVehicles[source] = nil
    local entity = AntiCheatService.createdVehicles[source]
    AntiCheatService.createdVehicles[source] = nil
    if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
end

---Déplacements impossibles (téléportation, vitesse, noclip) et caméra des joueurs PvP vivants.
function AntiCheatService.watchLoop()
    while true do
        Wait(AntiCheatService.WATCH_INTERVAL)
        local now = GetGameTimer()
        for source, player in pairs(PlayerService.all()) do
            if AntiCheatService.watched(source, true) and not player.dead then
                AntiCheatService.checkMovement(source, now)
            else
                AntiCheatService.positions[source] = nil
                AntiCheatService.streaks[source] = nil
            end
        end
    end
end

---Compte les relevés de suite où un signal est présent : vrai quand il y en a assez, et le compte repart de zéro.
---@param source integer
---@param signal string
---@param present boolean
---@param readings integer
---@return boolean
function AntiCheatService.sustained(source, signal, present, readings)
    local streaks = AntiCheatService.streaks[source] or {}
    AntiCheatService.streaks[source] = streaks
    local count = present and (streaks[signal] or 0) + 1 or 0
    streaks[signal] = count < readings and count or 0
    return count >= readings
end

---@param source integer
---@param now integer
function AntiCheatService.checkMovement(source, now)
    local ped = GetPlayerPed(source)
    -- Personnage en cours de remplacement (résurrection, changement de modèle) : rien à comparer
    if ped == 0 or not DoesEntityExist(ped) then
        AntiCheatService.positions[source] = nil
        return
    end

    local coords = GetEntityCoords(ped)
    local last = AntiCheatService.positions[source]
    -- Position figée alors que le joueur bougeait : le réseau n'a rien transmis. Le temps continue de compter
    -- depuis le dernier vrai relevé, sinon tout le trajet parcouru arrive d'un coup et ressemble à un saut.
    if last and last.moving and #(coords - last.coords) < 0.01
        and now - last.at < Config.AntiCheat.lagCredit * 1000 then
        return
    end

    local current = { coords = coords, at = now, moving = #GetEntityVelocity(ped) > 1.0 }
    AntiCheatService.positions[source] = current
    if not last or now < (AntiCheatService.graceUntil[source] or 0) then
        AntiCheatService.streaks[source] = nil
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    -- Debout sur le toit d'un véhicule, le joueur est accroché et avance à sa vitesse (voir VehicleRoof)
    local onFoot = vehicle == 0 and GetEntityAttachedTo(ped) == 0
    if not onFoot then AntiCheatService.vehicleAt[source] = now end
    -- Juste après un véhicule, le joueur garde son élan
    local settled = onFoot and now - (AntiCheatService.vehicleAt[source] or 0) >= Config.AntiCheat.vehicleExitGrace * 1000

    local elapsed = math.max(0.001, (now - last.at) / 1000)
    AntiCheatService.checkJump(source, ped, current, last, elapsed, onFoot, settled, vehicle)
    AntiCheatService.checkNoclip(source, ped, current, last, elapsed, settled)
    AntiCheatService.checkFreecam(source, coords, vehicle)
end

---Saut de position entre deux relevés. À pied, le joueur est ramené d'où il vient : la téléportation ne lui sert à rien.
---En véhicule, non : remettre le personnage en place le ferait descendre en pleine route.
---@param source integer
---@param ped integer
---@param current table relevé en cours
---@param last table relevé précédent
---@param elapsed number secondes entre les deux
---@param onFoot boolean
---@param settled boolean à pied, et plus sous l'élan d'un véhicule
---@param vehicle integer
function AntiCheatService.checkJump(source, ped, current, last, elapsed, onFoot, settled, vehicle)
    local settings = Config.AntiCheat
    local distance = #(current.coords - last.coords)
    local flat = #(current.coords.xy - last.coords.xy)
    local jumped = distance > settings.minTeleportDistance and distance / elapsed > settings.maxSpeed
        or settled and flat > settings.minTeleportDistance and flat / elapsed > settings.maxFootJumpSpeed
    if not jumped then return end

    local where = onFoot and 'à pied, ramené' or ('en véhicule, modèle %d'):format(AntiCheatService.unsigned(GetEntityModel(vehicle)))
    if onFoot then
        SetEntityCoords(ped, last.coords.x, last.coords.y, last.coords.z, false, false, false, false)
        current.coords = last.coords
    end
    AntiCheatService.flag(source, 'teleport', ('%.0f m en %.1f s (%.0f m/s, %s)'):format(distance, elapsed, distance / elapsed, where))
end

---Ce qu'un personnage à pied ne peut pas faire. Le serveur ne connaît pas le sol : un joueur immobile en l'air,
---ou qui vole lentement sans couper ses collisions, ne se voit pas ici.
---@param source integer
---@param ped integer
---@param current table relevé en cours
---@param last table relevé précédent
---@param elapsed number secondes entre les deux
---@param settled boolean à pied, et plus sous l'élan d'un véhicule
function AntiCheatService.checkNoclip(source, ped, current, last, elapsed, settled)
    local rules = Config.AntiCheat.noclip
    local flat = #(current.coords.xy - last.coords.xy) / elapsed
    local climb = (current.coords.z - last.coords.z) / elapsed
    local moved = #(current.coords - last.coords)

    -- En chute ou en parachute, le joueur va vite à l'horizontale : seul ce qui ne descend pas compte
    if AntiCheatService.sustained(source, 'fast', settled and flat > rules.maxSpeed and climb > -rules.fallSpeed, rules.fastReadings) then
        AntiCheatService.flag(source, 'noclip', ('%.0f m/s à pied sans tomber'):format(flat))
    end
    if AntiCheatService.sustained(source, 'climb', settled and climb > rules.maxClimb, rules.climbReadings) then
        AntiCheatService.flag(source, 'noclip', ('monte à %.0f m/s à pied'):format(climb))
    end
    if AntiCheatService.sustained(source, 'frozen', settled and IsEntityPositionFrozen(ped) and moved > rules.frozenDistance, rules.frozenReadings) then
        AntiCheatService.flag(source, 'noclip', ('personnage figé qui avance de %.0f m par relevé'):format(moved))
    end
    if AntiCheatService.sustained(source, 'collision', settled and GetEntityCollisionDisabled(ped), rules.collisionReadings) then
        AntiCheatService.flag(source, 'collision', ('collisions coupées depuis %d relevés'):format(rules.collisionReadings))
    end
end

---La caméra d'un joueur est envoyée par le jeu : une freecam la montre loin du personnage. Les caméras du PvP
---(tenue, custom des véhicules et des armes) restent à quelques mètres. En véhicule, le seuil est plus haut :
---la caméra cinématique de GTA peut filmer de loin.
---@param source integer
---@param coords vector3
---@param vehicle integer
function AntiCheatService.checkFreecam(source, coords, vehicle)
    local rules = Config.AntiCheat.freecam
    local distance = 0.0
    if IsPlayerInFreeCamMode(source) then distance = #(GetPlayerFocusPos(source) - coords) end
    local limit = vehicle ~= 0 and rules.vehicleDistance or rules.distance
    if AntiCheatService.sustained(source, 'freecam', distance > limit, rules.readings) then
        AntiCheatService.flag(source, 'freecam', ('caméra à %.0f m du personnage depuis %d relevés (%s)'):format(
            distance, rules.readings, vehicle ~= 0 and 'en véhicule' or 'à pied'))
    end
end

---Vie, armure, invincibilité et arme en main des joueurs PvP vivants.
function AntiCheatService.vitalsLoop()
    while true do
        Wait(AntiCheatService.VITALS_INTERVAL)
        for source, player in pairs(PlayerService.all()) do
            if AntiCheatService.watched(source, true) and not player.dead then
                AntiCheatService.checkVitals(source, player)
                AntiCheatService.checkHeldWeapon(source, player)
                AntiCheatService.checkDamageModifier(source, player)
            else
                AntiCheatService.invincibleSince[source] = nil
                AntiCheatService.heldWeapons[source] = nil
            end
        end
    end
end

---@param weapon integer hash non signé
---@param player PvpPlayer
---@return boolean
function AntiCheatService.mayHold(weapon, player)
    for _, name in ipairs(AntiCheatService.ALWAYS_HELD) do
        if AntiCheatService.unsigned(GetHashKey(name)) == weapon then return true end
    end
    local name = AntiCheatService.itemOfWeapon(weapon)
    return name ~= nil and AntiCheatService.hasWeapon(player, name)
end

---En PvP, le client ne donne que les armes de l'inventaire (Loadout) : toute autre vient d'un menu de triche.
---Vue sur deux relevés de suite : quand un objet quitte l'inventaire (vente, coffre, mort), le serveur le sait
---avant que le client ait retiré l'arme. Pas de contrôle en véhicule : l'arme relevée peut être celle du véhicule.
---@param source integer
---@param player PvpPlayer
function AntiCheatService.checkHeldWeapon(source, player)
    local ped = GetPlayerPed(source)
    local weapon = AntiCheatService.unsigned(GetSelectedPedWeapon(ped))
    if weapon == 0 or GetVehiclePedIsIn(ped, false) ~= 0 or GetGameTimer() < (AntiCheatService.graceUntil[source] or 0)
        or AntiCheatService.mayHold(weapon, player) then
        AntiCheatService.heldWeapons[source] = nil
        return
    end

    if AntiCheatService.heldWeapons[source] ~= weapon then
        AntiCheatService.heldWeapons[source] = weapon
        return
    end
    AntiCheatService.heldWeapons[source] = nil
    RemoveWeaponFromPed(ped, weapon)
    AntiCheatService.flag(source, 'heldWeapon', ('%s en main, absente de l\'inventaire (retirée)'):format(AntiCheatService.weaponLabel(weapon)))
end

---@param source integer
---@param player PvpPlayer
function AntiCheatService.checkVitals(source, player)
    local ped = GetPlayerPed(source)
    local health, armor = GetEntityHealth(ped), GetPedArmour(ped)
    if health > math.max(Config.AntiCheat.maxHealth, ClassService.healthLimit(player)) or armor > Config.AntiCheat.maxArmor then
        AntiCheatService.flag(source, 'health', ('vie %d, armure %d'):format(health, armor))
    end
    AntiCheatService.checkInvincible(source, player)
end

---Seule une invincibilité qui dure est signalée. Le jeu en donne de courtes hors zone safe : mode passif
---(Config.PassiveMode), même après une zone traversée entre deux relevés, et personnage du lobby tant que
---l'apparition n'est pas finie (couverte par AntiCheatService.grace).
---@param source integer
---@param player PvpPlayer
function AntiCheatService.checkInvincible(source, player)
    if player:isInSafeZone() or GetGameTimer() < (AntiCheatService.graceUntil[source] or 0)
        or not GetPlayerInvincible(source) then
        AntiCheatService.invincibleSince[source] = nil
        return
    end

    local now = os.time()
    local since = AntiCheatService.invincibleSince[source]
    if not since then
        AntiCheatService.invincibleSince[source] = now
        return
    end
    local seconds = now - since
    if seconds >= Config.PassiveMode.duration + Config.AntiCheat.godmodeMargin then
        AntiCheatService.invincibleSince[source] = now
        AntiCheatService.flag(source, 'godmode', ('invincible hors zone safe depuis %d s'):format(seconds))
    end
end

---Script client arrêté : plus de signal depuis Config.AntiCheat.heartbeatTimeout secondes.
function AntiCheatService.heartbeatLoop()
    while true do
        Wait(AntiCheatService.HEARTBEAT_CHECK)
        local now = os.time()
        for source in pairs(PlayerService.all()) do
            local last = AntiCheatService.heartbeats[source] or AntiCheatService.loadedAt[source]
            if last and now - last > Config.AntiCheat.heartbeatTimeout and AntiCheatService.watched(source) then
                AntiCheatService.heartbeats[source] = now
                AntiCheatService.flag(source, 'heartbeat', ('aucun signal depuis %d s'):format(now - last))
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Commandes : ban <id | license:xxxx> <jours (0 = définitif)> <raison>, unban <license:xxxx>, bans
-- ---------------------------------------------------------------------------

---@param source integer 0 = console
---@param args string[]
function AntiCheatService.commandBan(source, args)
    local identifier, name, player = AdminService.resolveTarget(args[1])
    local days = math.floor(tonumber(args[2]) or -1)
    local reason = table.concat(args, ' ', 3)
    if not identifier or days < 0 or reason == '' then
        return AdminService.reply(source, Locale.t('Usage : ban <id | license:xxxx> <jours, 0 = définitif> <raison>'))
    end

    local by = source == 0 and 'console' or GetPlayerName(source)
    BanRepository.ban(identifier, name or '', reason, by, days)
    if player then
        DiscordService.sanction(days > 0 and ('Bannissement %d j'):format(days) or 'Bannissement définitif', source, player, reason)
        DropPlayer(player.source, ('7PVP : tu es banni (%s).'):format(reason))
    end
    Logger.info('[ban] %s bannit %s (%s, %s)', by, name or identifier, days > 0 and (days .. ' j') or 'définitif', reason)
    AdminService.reply(source, days > 0 and Locale.t('%s banni pour %d jour(s).', name or identifier, days)
        or Locale.t('%s banni définitivement.', name or identifier))
end

---@param source integer
---@param identifier string|nil
function AntiCheatService.commandUnban(source, identifier)
    if not identifier or not identifier:match('^license:%x+$') then
        return AdminService.reply(source, Locale.t('Usage : unban <license:xxxx> (voir la commande bans)'))
    end
    if not BanRepository.unban(identifier) then
        return AdminService.reply(source, Locale.t('Aucun ban pour %s.', identifier))
    end
    Logger.info('[ban] %s débannit %s', source == 0 and 'console' or GetPlayerName(source), identifier)
    AdminService.reply(source, Locale.t('%s débanni.', identifier))
end

---@param source integer
function AntiCheatService.commandList(source)
    local bans = BanRepository.list()
    if #bans == 0 then return AdminService.reply(source, Locale.t('Aucun ban en cours.')) end
    AdminService.reply(source, Locale.t('%d ban(s) en cours :', #bans))
    for _, ban in ipairs(bans) do
        AdminService.reply(source, Locale.t('  %s  %s  jusqu\'au %s  (%s, par %s)', ban.name, ban.identifier,
            ban.expires_at or Locale.t('définitif'), ban.reason, ban.banned_by))
    end
end
