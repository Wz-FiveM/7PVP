---Administration : chaque action est vérifiée ici (permission ACE) et journalisée.
---Le client ne fait qu'afficher le panneau et exécuter ce que le serveur lui demande.
---@class AdminServiceModule
local AdminService = PVP.define('AdminService')
local PlayerService = PVP.use('PlayerService')
local LobbyService = PVP.use('LobbyService')
local ModeRegistry = PVP.use('ModeRegistry')
local ChatService = PVP.use('ChatService')
local LootService = PVP.use('LootService')
local Items = PVP.use('Items')
local Callback = PVP.use('Callback')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')

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
    announce = { method = 'announce', target = false },
    clearLoot = { method = 'clearLoot', target = false },
}

function AdminService.init()
    Callback.register(Events.callbacks.adminPlayers, AdminService.listPlayers)
    Callback.register(Events.callbacks.adminAction, AdminService.handleAction)

    -- Le client apprend s'il est admin (pour afficher ou non le panneau)
    RegisterNetEvent(Events.server.ready, function()
        AdminService.sendStatus(source)
    end)
end

---@param source integer
---@return boolean
function AdminService.isAdmin(source)
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
        return { ok = false, message = 'Accès refusé.' }
    end
    if type(data) ~= 'table' then return { ok = false } end

    local action = AdminService.ACTIONS[data.action]
    if not action then return { ok = false, message = 'Action inconnue.' } end

    local target = data.target and PlayerService.get(data.target)
    if action.target and not target then
        return { ok = false, message = 'Joueur introuvable.' }
    end

    local ok, message = AdminService[action.method](source, target, data)
    Logger.info('[admin] %s : %s%s%s', GetPlayerName(source), data.action,
        target and (' -> ' .. target.name) or '', message and (' (' .. message .. ')') or '')
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
    if not Items.exists(data.item) then return false, 'Objet inconnu.' end
    local count = math.floor(tonumber(data.count) or 0)
    if count < 1 or count > Config.Admin.MaxGiveCount then return false, 'Quantité invalide.' end
    local container = data.container == 'protected' and 'protected' or 'bag'

    local added = target:giveItem(data.item, count, container)
    target:sync()
    if added < count then
        return added > 0, ('%d / %d donné(s) : conteneur trop lourd.'):format(added, count)
    end
    return true, ('%s donné à %s.'):format(Items.describe({ [data.item] = count }), target.name)
end

---@param target PvpPlayer
function AdminService.giveMoney(_, target, data)
    local amount = math.floor(tonumber(data.amount) or 0)
    if amount < 1 or amount > Config.Admin.MaxGiveMoney then return false, 'Montant invalide.' end
    target:addMoney(amount)
    target:sync()
    return true, ('$%d donné à %s.'):format(amount, target.name)
end

---@param target PvpPlayer
function AdminService.heal(_, target)
    AdminService.command(target, 'heal')
    return true, ('%s soigné.'):format(target.name)
end

---@param target PvpPlayer
function AdminService.revive(_, target)
    if not target.dead then
        AdminService.command(target, 'heal')
        return true, ('%s n\'était pas mort : soigné.'):format(target.name)
    end
    -- Annule la réapparition automatique en zone safe (voir SpawnService.scheduleRespawn)
    target.dead = false
    AdminService.command(target, 'revive')
    return true, ('%s réanimé.'):format(target.name)
end

---@param target PvpPlayer
function AdminService.kill(_, target)
    AdminService.command(target, 'kill')
    return true, ('%s tué.'):format(target.name)
end

---@param target PvpPlayer
function AdminService.freeze(_, target, data)
    local frozen = data.state == true
    AdminService.command(target, 'freeze', frozen)
    return true, ('%s %s.'):format(target.name, frozen and 'gelé' or 'dégelé')
end

---@param target PvpPlayer
function AdminService.gotoPlayer(source, target)
    if not AdminService.sameMode(source, target) then return false, 'Ce joueur est dans un autre mode.' end
    TriggerClientEvent(Events.client.adminCommand, source, 'teleport', target:getCoords())
    return true, ('Téléporté sur %s.'):format(target.name)
end

---@param target PvpPlayer
function AdminService.bringPlayer(source, target)
    if not AdminService.sameMode(source, target) then return false, 'Ce joueur est dans un autre mode.' end
    AdminService.command(target, 'teleport', GetEntityCoords(GetPlayerPed(source)))
    return true, ('%s ramené.'):format(target.name)
end

---@param target PvpPlayer
function AdminService.sendToLobby(_, target)
    if not target.mode then return false, 'Ce joueur est déjà au lobby.' end
    ModeRegistry.get(target.mode).leave(target)
    LobbyService.open(target)
    target:notify('Un admin t\'a renvoyé au lobby.', 'info')
    return true, ('%s renvoyé au lobby.'):format(target.name)
end

---@param target PvpPlayer
function AdminService.kick(_, target, data)
    local reason = type(data.reason) == 'string' and data.reason:sub(1, 120) or ''
    if reason == '' then reason = 'Aucune raison' end
    DropPlayer(target.source, ('Expulsé par un admin : %s'):format(reason))
    return true, ('%s expulsé (%s).'):format(target.name, reason)
end

-- ---------------------------------------------------------------------------
-- Actions serveur
-- ---------------------------------------------------------------------------

function AdminService.announce(_, _, data)
    local text = ChatService.sanitize(data.text)
    if not text then return false, 'Message vide.' end

    if data.mode == 'all' then
        for _, mode in ipairs(Config.Lobby.Modes) do
            ChatService.announce(mode.id, '[ADMIN] ' .. text)
        end
    elseif ModeRegistry.getConfig(data.mode) then
        ChatService.announce(data.mode, '[ADMIN] ' .. text)
    else
        return false, 'Mode inconnu.'
    end
    return true, 'Annonce envoyée.'
end

function AdminService.clearLoot()
    local count = LootService.clearAll()
    return true, ('%d sac(s) de butin supprimé(s).'):format(count)
end
