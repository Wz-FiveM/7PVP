---Administration : chaque action est vérifiée ici (admin en base ou permission ACE) et journalisée.
---Le client ne fait qu'afficher le panneau et exécuter ce que le serveur lui demande.
---@class AdminServiceModule
local AdminService = PVP.define('AdminService')
local PlayerService = PVP.use('PlayerService')
local PlayerRepository = PVP.use('PlayerRepository')
local LobbyService = PVP.use('LobbyService')
local ModeRegistry = PVP.use('ModeRegistry')
local ChatService = PVP.use('ChatService')
local LootService = PVP.use('LootService')
local AntiCheatService = PVP.use('AntiCheatService')
local AirdropService = PVP.use('AirdropService')
local PveService = PVP.use('PveService')
local HordeService = PVP.use('HordeService')
local SpectateService = PVP.use('SpectateService')
local Items = PVP.use('Items')
local Callback = PVP.use('Callback')
local DiscordService = PVP.use('DiscordService')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

-- Actions disponibles : méthode à appeler et besoin d'un joueur cible
AdminService.ACTIONS = {
    giveItem = { method = 'giveItem', target = true },
    giveMoney = { method = 'giveMoney', target = true },
    heal = { method = 'heal', target = true },
    revive = { method = 'revive', target = true },
    kill = { method = 'kill', target = true },
    freeze = { method = 'freeze', target = true },
    gotoPlayer = { method = 'gotoPlayer', target = true },
    bringPlayer = { method = 'bringPlayer', target = true },
    sendToLobby = { method = 'sendToLobby', target = true },
    kick = { method = 'kick', target = true },
    spectate = { method = 'spectate', target = true },
    spectateStop = { method = 'spectateStop', target = false },
    announce = { method = 'announce', target = false },
    clearLoot = { method = 'clearLoot', target = false },
    airdrop = { method = 'airdrop', target = false },
    horde = { method = 'horde', target = false },
}

function AdminService.init()
    Callback.register(Events.callbacks.adminPlayers, AdminService.listPlayers)
    Callback.register(Events.callbacks.adminAction, AdminService.handleAction)

    -- Le client apprend s'il est admin (pour afficher ou non le panneau), une fois son profil
    -- chargé : le statut enregistré en base (is_admin) n'est connu qu'à ce moment-là
    AddEventHandler(Events.internal.playerLoaded, function(playerSource)
        AdminService.sendStatus(playerSource)
    end)
    -- Profil déjà chargé (reconnexion du client sans redémarrage du serveur)
    RegisterNetEvent(Events.server.ready, function()
        if PlayerService.get(source) then AdminService.sendStatus(source) end
    end)

    -- Commandes console (et admins en jeu, via la permission command.<nom>)
    RegisterCommand('setadmin', function(source, args)
        AdminService.commandSetAdmin(source, args[1], true)
    end, true)
    RegisterCommand('removeadmin', function(source, args)
        AdminService.commandSetAdmin(source, args[1], false)
    end, true)
    RegisterCommand('admins', function(source)
        AdminService.commandListAdmins(source)
    end, true)
end

-- ---------------------------------------------------------------------------
-- Droits admin persistants (colonne is_admin), sans dépendre des ACE du server.cfg
-- ---------------------------------------------------------------------------

---Réponse d'une commande : console du serveur ou chat du joueur.
---@param source integer 0 = console
---@param text string|table message à traduire (Locale.t), en français dans la console
function AdminService.reply(source, text)
    if source == 0 then
        Logger.info('%s', Locale.resolve(text, Locale.SOURCE))
    else
        ChatService.system(source, text)
    end
end

---Retrouve un joueur par ID en ligne ou par licence (même hors ligne).
---@param arg string|nil
---@return string|nil identifier, string|nil name, PvpPlayer|nil player
function AdminService.resolveTarget(arg)
    if not arg then return nil end

    local online = tonumber(arg) and PlayerService.get(tonumber(arg))
    if online then
        return online.identifier, online.name, online
    end

    if arg:match('^license:%x+$') then
        local row = PlayerRepository.findByIdentifier(arg)
        for _, player in pairs(PlayerService.all()) do
            if player.identifier == arg then return arg, player.name, player end
        end
        return arg, row and row.name or nil, nil
    end
    return nil
end

---setadmin / removeadmin <id ou license:xxxx>
---@param source integer
---@param arg string|nil
---@param isAdmin boolean
function AdminService.commandSetAdmin(source, arg, isAdmin)
    local command = isAdmin and 'setadmin' or 'removeadmin'
    local identifier, name, player = AdminService.resolveTarget(arg)
    if not identifier then
        return AdminService.reply(source, Locale.t('Usage : %s <id du joueur | license:xxxx>', command))
    end

    if not PlayerRepository.setAdmin(identifier, isAdmin) then
        return AdminService.reply(source, Locale.t('Aucun joueur avec la licence %s en base.', identifier))
    end

    local label = name or identifier
    if player then
        player.isAdmin = isAdmin
        AdminService.sendStatus(player.source)
        player:notify(isAdmin and Locale.t('Tu es maintenant admin (F10).') or Locale.t('Tes droits admin ont été retirés.'), 'info')
        if not isAdmin and AdminService.isAdmin(player.source) then
            AdminService.reply(source, Locale.t('%s reste admin via server.cfg (ACE %s).', label, Config.Admin.Ace))
        end
    end

    local by = source == 0 and 'console' or GetPlayerName(source)
    Logger.info('[admin] %s : %s %s', by, command, label)
    DiscordService.adminCommand(source, command, label)
    AdminService.reply(source, isAdmin and Locale.t('%s est maintenant admin.', label) or Locale.t('%s n\'est plus admin.', label))
end

---admins : liste des admins enregistrés en base
---@param source integer
function AdminService.commandListAdmins(source)
    local admins = PlayerRepository.listAdmins()
    if #admins == 0 then
        return AdminService.reply(source, Locale.t('Aucun admin enregistré en base (les admins de server.cfg ne sont pas listés).'))
    end

    local online = {}
    for _, player in pairs(PlayerService.all()) do online[player.identifier] = player.source end

    AdminService.reply(source, Locale.t('%d admin(s) :', #admins))
    for _, admin in ipairs(admins) do
        local id = online[admin.identifier]
        if id then
            AdminService.reply(source, Locale.t('  %s  %s  [en ligne, ID %s]', admin.name, admin.identifier, id))
        else
            AdminService.reply(source, ('  %s  %s  '):format(admin.name, admin.identifier))
        end
    end
end

---Admin enregistré en base (setadmin) ou via l'ACE du server.cfg.
---@param source integer
---@return boolean
function AdminService.isAdmin(source)
    local player = PlayerService.get(source)
    if player and player.isAdmin then return true end
    return IsPlayerAceAllowed(source, Config.Admin.Ace)
end

---@param source integer
function AdminService.sendStatus(source)
    TriggerClientEvent(Events.client.adminStatus, source, AdminService.isAdmin(source))
end

---@param source integer
---@return table[]|nil
function AdminService.listPlayers(source)
    if not AdminService.isAdmin(source) then return nil end

    local list = {}
    for id, player in pairs(PlayerService.all()) do
        list[#list + 1] = {
            id = id,
            name = player.name,
            mode = player.mode or false,
            dead = player.dead,
            money = player:getMoney(),
            level = player:getLevel(),
        }
    end
    table.sort(list, AdminService.compareById)
    return list
end

---@return boolean
function AdminService.compareById(a, b)
    return a.id < b.id
end

---@param source integer
---@param data table { action, target?, ... }
---@return { ok: boolean, message?: string }
function AdminService.handleAction(source, data)
    if not AdminService.isAdmin(source) then
        Logger.warn('[admin] %s (%s) a tenté une action admin sans permission', GetPlayerName(source), source)
        DiscordService.adminDenied(source)
        return { ok = false, message = Locale.t('Accès refusé.') }
    end
    if type(data) ~= 'table' then return { ok = false } end

    local action = AdminService.ACTIONS[data.action]
    if not action then return { ok = false, message = Locale.t('Action inconnue.') } end

    local target = data.target and PlayerService.get(data.target)
    if action.target and not target then
        return { ok = false, message = Locale.t('Joueur introuvable.') }
    end

    -- Un admin peut déplacer ou soigner un joueur : pas d'alerte anti-cheat juste après
    if target then AntiCheatService.grace(target.source) end
    local ok, message = AdminService[action.method](source, target, data)
    -- Journal et Discord en français ; l'admin reçoit le message traduit dans sa langue
    local logged = message and Locale.resolve(message, Locale.SOURCE)
    Logger.info('[admin] %s : %s%s%s', GetPlayerName(source), data.action,
        target and (' -> ' .. target.name) or '', logged and (' (' .. logged .. ')') or '')
    if ok then DiscordService.adminAction(source, data.action, target, data, logged) end
    return { ok = ok, message = message }
end

---@param source integer
---@param target PvpPlayer
---@return boolean même mode de jeu (donc même bucket)
function AdminService.sameMode(source, target)
    local admin = PlayerService.get(source)
    return admin ~= nil and admin.mode ~= nil and admin.mode == target.mode
end

---@param target PvpPlayer
---@param command string
function AdminService.command(target, command, ...)
    TriggerClientEvent(Events.client.adminCommand, target.source, command, ...)
end

-- ---------------------------------------------------------------------------
-- Actions sur un joueur
-- ---------------------------------------------------------------------------

---@param target PvpPlayer
function AdminService.giveItem(_, target, data)
    if not Items.exists(data.item) then return false, Locale.t('Objet inconnu.') end
    local count = math.floor(tonumber(data.count) or 0)
    if count < 1 or count > Config.Admin.MaxGiveCount then return false, Locale.t('Quantité invalide.') end
    local container = data.container == 'protected' and 'protected' or 'bag'

    local added = target:giveItem(data.item, count, container)
    target:sync()
    if added < count then
        return added > 0, Locale.t('%d / %d donné(s) : conteneur trop lourd.', added, count)
    end
    return true, Locale.t('%s donné à %s.', Items.describeText({ [data.item] = count }), target.name)
end

---@param target PvpPlayer
function AdminService.giveMoney(_, target, data)
    local amount = math.floor(tonumber(data.amount) or 0)
    if amount < 1 or amount > Config.Admin.MaxGiveMoney then return false, Locale.t('Montant invalide.') end
    target:addMoney(amount)
    target:sync()
    return true, Locale.t('$%d donné à %s.', amount, target.name)
end

---@param target PvpPlayer
function AdminService.heal(_, target)
    AdminService.command(target, 'heal')
    return true, Locale.t('%s soigné.', target.name)
end

---@param target PvpPlayer
function AdminService.revive(_, target)
    if not target.dead then
        AdminService.command(target, 'heal')
        return true, Locale.t('%s n\'était pas mort : soigné.', target.name)
    end
    -- Annule la réapparition automatique en zone safe (voir SpawnService.scheduleRespawn)
    target.dead = false
    AdminService.command(target, 'revive')
    return true, Locale.t('%s réanimé.', target.name)
end

---@param target PvpPlayer
function AdminService.kill(_, target)
    AdminService.command(target, 'kill')
    return true, Locale.t('%s tué.', target.name)
end

---@param target PvpPlayer
function AdminService.freeze(_, target, data)
    local frozen = data.state == true
    AdminService.command(target, 'freeze', frozen)
    return true, frozen and Locale.t('%s gelé.', target.name) or Locale.t('%s dégelé.', target.name)
end

---@param target PvpPlayer
function AdminService.gotoPlayer(source, target)
    if not AdminService.sameMode(source, target) then return false, Locale.t('Ce joueur est dans un autre mode.') end
    TriggerClientEvent(Events.client.adminCommand, source, 'teleport', target:getCoords())
    return true, Locale.t('Téléporté sur %s.', target.name)
end

---@param target PvpPlayer
function AdminService.bringPlayer(source, target)
    if not AdminService.sameMode(source, target) then return false, Locale.t('Ce joueur est dans un autre mode.') end
    AdminService.command(target, 'teleport', GetEntityCoords(GetPlayerPed(source)))
    return true, Locale.t('%s ramené.', target.name)
end

---Mode spectateur (voir SpectateService) : la caméra de l'admin suit le joueur, même en partie.
---@param target PvpPlayer
function AdminService.spectate(source, target)
    return SpectateService.start(source, target)
end

function AdminService.spectateStop(source)
    return SpectateService.stop(source)
end

---@param target PvpPlayer
function AdminService.sendToLobby(_, target)
    if not target.mode then return false, Locale.t('Ce joueur est déjà au lobby.') end
    ModeRegistry.get(target.mode).leave(target)
    LobbyService.open(target)
    target:notify(Locale.t('Un admin t\'a renvoyé au lobby.'), 'info')
    return true, Locale.t('%s renvoyé au lobby.', target.name)
end

---@param target PvpPlayer
function AdminService.kick(_, target, data)
    local reason = type(data.reason) == 'string' and data.reason:sub(1, 120) or ''
    local given = reason ~= ''
    if not given then reason = 'Aucune raison' end
    DropPlayer(target.source, ('Expulsé par un admin : %s'):format(reason))
    return true, Locale.t('%s expulsé (%s).', target.name, given and reason or Locale.t('Aucune raison'))
end

-- ---------------------------------------------------------------------------
-- Actions serveur
-- ---------------------------------------------------------------------------

function AdminService.announce(_, _, data)
    local text = ChatService.sanitize(data.text)
    if not text then return false, Locale.t('Message vide.') end

    if data.mode == 'all' then
        for _, mode in ipairs(Config.Lobby.Modes) do
            ChatService.announce(mode.id, '[ADMIN] ' .. text)
        end
    elseif ModeRegistry.getConfig(data.mode) then
        ChatService.announce(data.mode, '[ADMIN] ' .. text)
    else
        return false, Locale.t('Mode inconnu.')
    end
    return true, Locale.t('Annonce envoyée.')
end

---Largage immédiat, au point de l'admin s'il est en PvP, sinon à un point de la config.
---@param source integer
function AdminService.airdrop(source)
    local admin = PlayerService.get(source)
    local coords = admin and admin.mode == 'pvp' and admin:getCoords() or nil
    AirdropService.spawn(coords)
    return true, Locale.t('Largage lancé.')
end

---Horde immédiate dans la zone PvE la plus proche de l'admin.
---@param source integer
function AdminService.horde(source)
    local admin = PlayerService.get(source)
    if not admin or admin.mode ~= 'pvp' then return false, Locale.t('Rejoins le PvP pour lancer une horde.') end
    local closest, best = nil, math.huge
    for _, zone in pairs(PveService.zones) do
        local distance = #(admin:getCoords() - zone.zone.coords)
        if distance < best then closest, best = zone, distance end
    end
    if not HordeService.start(closest) then return false, Locale.t('Une horde est déjà en cours.') end
    return true, Locale.t('Horde lancée : %s.', Locale.t(closest.zone.label))
end

function AdminService.clearLoot()
    local count = LootService.clearAll()
    return true, Locale.t('%d sac(s) de butin supprimé(s).', count)
end
