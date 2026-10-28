---Anti-cheat côté serveur (Config.AntiCheat). Détections :
---  weapon    : touche avec une arme absente de l'inventaire (PvP)
---  damage    : dégâts d'une touche au-dessus du maximum
---  explosion : explosion d'arme (grenade, roquette...) en PvP
---  entity    : véhicule créé par un joueur en PvP
---  health    : vie ou armure au-dessus du maximum ; godmode : joueur invincible hors zone safe
---  teleport  : déplacement impossible entre deux relevés de position
---  spam      : requêtes réseau en rafale ; heartbeat : script client arrêté
---Chaque détection est journalisée (console + Discord) ; la sanction tombe au-delà d'un nombre
---d'alertes. Les admins ne sont jamais contrôlés.
---@class AntiCheatServiceModule
local AntiCheatService = PVP.define('AntiCheatService')
local PlayerService = PVP.use('PlayerService')
local AdminService = PVP.use('AdminService')
local BanRepository = PVP.use('BanRepository')
local DiscordService = PVP.use('DiscordService')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')

AntiCheatService.WATCH_INTERVAL = 1000
AntiCheatService.VITALS_INTERVAL = 2000
AntiCheatService.HEARTBEAT_CHECK = 15000

-- Armes toujours permises (mains nues, véhicule) : hashs non signés
AntiCheatService.ALWAYS_ALLOWED = { 'WEAPON_UNARMED', 'WEAPON_RUN_OVER_BY_CAR', 'WEAPON_RAMMED_BY_CAR', 'WEAPON_FALL' }

AntiCheatService.strikes = {} -- [source][détection] = { horodatages }
AntiCheatService.rates = {} -- [source][clé] = { second, count }
AntiCheatService.positions = {} -- [source] = { coords, at }
AntiCheatService.graceUntil = {} -- [source] = GetGameTimer()
AntiCheatService.heartbeats = {} -- [source] = os.time() du dernier signal
AntiCheatService.loadedAt = {} -- [source] = os.time() du chargement du profil

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
end

---Limite de requêtes par seconde : false (requête à ignorer) au-delà de Config.AntiCheat.rateLimits[key].
---@param source integer
---@param key string callback, hit, loot
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
    local list = {}
    local previous = AntiCheatService.strikes[source] and AntiCheatService.strikes[source][detection] or {}
    for _, at in ipairs(previous) do
        if now - at < Config.AntiCheat.strikeWindow then list[#list + 1] = at end
    end
    list[#list + 1] = now
    AntiCheatService.strikes[source] = AntiCheatService.strikes[source] or {}
    AntiCheatService.strikes[source][detection] = list

    Logger.warn('[anti-cheat] %s (ID %d) : %s - %s (%d/%d)', player.name, source, rule.label, details, #list, rule.strikes)
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

---@param sender integer
---@param data table
function AntiCheatService.onWeaponDamage(sender, data)
    local player = AntiCheatService.watched(sender, true)
    if not player or type(data) ~= 'table' then return end

    local weapon = AntiCheatService.unsigned(data.weaponType)
    if weapon ~= 0 and not AntiCheatService.ownedWeapons(player)[weapon] then
        CancelEvent()
        return AntiCheatService.flag(sender, 'weapon', ('arme %d absente de l\'inventaire'):format(weapon))
    end

    local damage = tonumber(data.weaponDamage) or 0
    if damage > Config.AntiCheat.maxWeaponDamage then
        CancelEvent()
        AntiCheatService.flag(sender, 'damage', ('%d dégâts en une touche'):format(math.floor(damage)))
    end
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

---Véhicule créé par un joueur en PvP (le mode n'en donne pas : seuls les admins peuvent).
---Les PNJ ne sont pas contrôlés ici : le personnage d'un joueur est lui aussi créé comme un PNJ
---à chaque réapparition, le bloquer casserait le jeu.
---@param entity integer
function AntiCheatService.onEntityCreating(entity)
    if GetEntityType(entity) ~= 2 then return end
    local owner = NetworkGetEntityOwner(entity)
    if not owner or owner <= 0 or not AntiCheatService.watched(owner, true) then return end

    CancelEvent()
    AntiCheatService.flag(owner, 'entity', ('véhicule (modèle %d)'):format(AntiCheatService.unsigned(GetEntityModel(entity))))
end

-- ---------------------------------------------------------------------------
-- Contrôles réguliers
-- ---------------------------------------------------------------------------

---Déplacements impossibles (téléportation, vitesse) des joueurs PvP vivants.
function AntiCheatService.watchLoop()
    while true do
        Wait(AntiCheatService.WATCH_INTERVAL)
        local now = GetGameTimer()
        for source, player in pairs(PlayerService.all()) do
            if AntiCheatService.watched(source, true) and not player.dead then
                AntiCheatService.checkMovement(source, now)
            else
                AntiCheatService.positions[source] = nil
            end
        end
    end
end

---@param source integer
---@param now integer
function AntiCheatService.checkMovement(source, now)
    local coords = GetEntityCoords(GetPlayerPed(source))
    local last = AntiCheatService.positions[source]
    AntiCheatService.positions[source] = { coords = coords, at = now }
    if not last or now < (AntiCheatService.graceUntil[source] or 0) then return end

    local distance = #(coords.xy - last.coords.xy)
    local speed = distance / math.max(0.001, (now - last.at) / 1000)
    if distance > Config.AntiCheat.minTeleportDistance and speed > Config.AntiCheat.maxSpeed then
        AntiCheatService.flag(source, 'teleport', ('%.0f m en %.1f s (%.0f m/s)'):format(distance, (now - last.at) / 1000, speed))
    end
end

---Vie, armure et invincibilité des joueurs PvP vivants hors zone safe.
function AntiCheatService.vitalsLoop()
    while true do
        Wait(AntiCheatService.VITALS_INTERVAL)
        for source, player in pairs(PlayerService.all()) do
            if AntiCheatService.watched(source, true) and not player.dead then
                AntiCheatService.checkVitals(source, player)
            end
        end
    end
end

---@param source integer
---@param player PvpPlayer
function AntiCheatService.checkVitals(source, player)
    local ped = GetPlayerPed(source)
    local health, armor = GetEntityHealth(ped), GetPedArmour(ped)
    if health > Config.AntiCheat.maxHealth or armor > Config.AntiCheat.maxArmor then
        AntiCheatService.flag(source, 'health', ('vie %d, armure %d'):format(health, armor))
    end
    if GetPlayerInvincible(source) and not player:isInSafeZone() then
        AntiCheatService.flag(source, 'godmode', 'invincible hors zone safe')
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
        return AdminService.reply(source, 'Usage : ban <id | license:xxxx> <jours, 0 = définitif> <raison>')
    end

    local by = source == 0 and 'console' or GetPlayerName(source)
    BanRepository.ban(identifier, name or '', reason, by, days)
    if player then
        DiscordService.sanction(days > 0 and ('Bannissement %d j'):format(days) or 'Bannissement définitif', source, player, reason)
        DropPlayer(player.source, ('7PVP : tu es banni (%s).'):format(reason))
    end
    Logger.info('[ban] %s bannit %s (%s, %s)', by, name or identifier, days > 0 and (days .. ' j') or 'définitif', reason)
    AdminService.reply(source, ('%s banni %s.'):format(name or identifier, days > 0 and ('pour ' .. days .. ' jour(s)') or 'définitivement'))
end

---@param source integer
---@param identifier string|nil
function AntiCheatService.commandUnban(source, identifier)
    if not identifier or not identifier:match('^license:%x+$') then
        return AdminService.reply(source, 'Usage : unban <license:xxxx> (voir la commande bans)')
    end
    if not BanRepository.unban(identifier) then
        return AdminService.reply(source, ('Aucun ban pour %s.'):format(identifier))
    end
    Logger.info('[ban] %s débannit %s', source == 0 and 'console' or GetPlayerName(source), identifier)
    AdminService.reply(source, ('%s débanni.'):format(identifier))
end

---@param source integer
function AntiCheatService.commandList(source)
    local bans = BanRepository.list()
    if #bans == 0 then return AdminService.reply(source, 'Aucun ban en cours.') end
    AdminService.reply(source, ('%d ban(s) en cours :'):format(#bans))
    for _, ban in ipairs(bans) do
        AdminService.reply(source, ('  %s  %s  jusqu\'au %s  (%s, par %s)'):format(ban.name, ban.identifier,
            ban.expires_at or 'définitif', ban.reason, ban.banned_by))
    end
end
