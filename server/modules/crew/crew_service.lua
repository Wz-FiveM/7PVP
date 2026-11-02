---Crews du mode PvP : groupes permanents, reconnus à leur label de 3 lettres (« MGZ »).
---Contrairement à une équipe (GroupService), un crew reste en base, garde ses membres hors ligne
---et ne change rien au combat. Tous les crews sont gardés en mémoire : aucune action n'attend la base.
---@class PvpCrewMember
---@field key integer numéro envoyé aux clients à la place de la licence
---@field identifier string
---@field name string

---@class PvpCrew
---@field tag string
---@field name string
---@field leader string licence du chef
---@field members PvpCrewMember[] dans l'ordre d'arrivée

---@class CrewServiceModule
local CrewService = PVP.define('CrewService')
local CrewRepository = PVP.use('CrewRepository')
local PlayerService = PVP.use('PlayerService')
local GroupService = PVP.use('GroupService')
local AdminService = PVP.use('AdminService')
local DiscordService = PVP.use('DiscordService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')
local Logger = PVP.use('Logger')

-- Lu par les clients (gamertags, menu d'interaction) : voir client/modules/crew
CrewService.STATE_KEY = 'crewTag'

---@type table<string, PvpCrew> label -> crew
CrewService.crews = {}
---@type table<string, string> licence -> label du crew
CrewService.memberOf = {}
---@type table<integer, { tag: string, from: integer, expires: integer }> invitation reçue par joueur
CrewService.invites = {}
CrewService.nextKey = 0

function CrewService.init()
    Callback.register(Events.callbacks.crewCreate, CrewService.create)
    Callback.register(Events.callbacks.crewInvite, CrewService.invite)
    Callback.register(Events.callbacks.crewRespond, CrewService.respond)
    Callback.register(Events.callbacks.crewLeave, CrewService.leave)
    Callback.register(Events.callbacks.crewKick, CrewService.kick)
    Callback.register(Events.callbacks.crewTransfer, CrewService.transfer)
    Callback.register(Events.callbacks.crewDisband, CrewService.disband)

    AddEventHandler(Events.internal.playerLoaded, function(playerSource)
        CrewService.onPlayerLoaded(playerSource)
    end)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        CrewService.onPlayerUnloading(playerSource)
    end)

    -- Commande console (et admins en jeu, via la permission command.crewdissoudre) : label injurieux...
    RegisterCommand('crewdissoudre', function(source, args)
        CrewService.commandDisband(source, args[1])
    end, true)

    MySQL.ready(CrewService.load)
end

function CrewService.load()
    local crews, members = CrewRepository.loadAll()
    for _, row in ipairs(crews) do
        CrewService.crews[row.tag] = { tag = row.tag, name = row.name, leader = row.leader, members = {} }
    end
    for _, row in ipairs(members) do
        local crew = CrewService.crews[row.crew_tag]
        if crew then CrewService.attach(crew, row.identifier, row.name) end
    end
    Logger.info('Crews chargés : %d', #crews)

    -- Joueurs arrivés avant la fin du chargement (redémarrage de la ressource)
    for _, player in pairs(PlayerService.all()) do
        CrewService.onPlayerLoaded(player.source)
    end
end

-- ---------------------------------------------------------------------------
-- Lecture
-- ---------------------------------------------------------------------------

---@param identifier string
---@return string|nil label du crew de ce joueur
function CrewService.tagOf(identifier)
    return CrewService.memberOf[identifier]
end

---@param identifier string
---@param name string
---@return string nom précédé du label du crew : « [MGZ] Nom »
function CrewService.label(identifier, name)
    local tag = CrewService.memberOf[identifier]
    return tag and ('[%s] %s'):format(tag, name) or name
end

---@param identifier string
---@return PvpPlayer|nil joueur connecté avec cette licence
function CrewService.findOnline(identifier)
    for _, player in pairs(PlayerService.all()) do
        if player.identifier == identifier then return player end
    end
    return nil
end

---@param source integer
---@return PvpCrew|nil
function CrewService.crewOf(source)
    local player = PlayerService.get(source)
    return player and CrewService.crews[CrewService.memberOf[player.identifier]] or nil
end

---@param crew PvpCrew
---@param key any
---@return PvpCrewMember|nil
function CrewService.findMember(crew, key)
    key = tonumber(key)
    for _, member in ipairs(crew.members) do
        if member.key == key then return member end
    end
    return nil
end

---@param crew PvpCrew
---@param gone? integer joueur en train de partir : déjà compté hors ligne
---@return table données envoyées aux clients (jamais les licences)
function CrewService.serialize(crew, gone)
    local online = {}
    for _, player in pairs(PlayerService.all()) do
        if player.source ~= gone then online[player.identifier] = player.source end
    end

    local members = {}
    for _, member in ipairs(crew.members) do
        members[#members + 1] = {
            key = member.key,
            name = member.name,
            id = online[member.identifier] or false,
            leader = member.identifier == crew.leader,
        }
    end
    return { tag = crew.tag, name = crew.name, members = members }
end

---Renvoie le crew à jour à ses membres connectés.
---@param crew PvpCrew
---@param gone? integer
function CrewService.sync(crew, gone)
    local data = CrewService.serialize(crew, gone)
    for _, member in ipairs(data.members) do
        if member.id then TriggerClientEvent(Events.client.crewSync, member.id, data) end
    end
end

---@param crew PvpCrew
---@param text table message à traduire (Locale.t)
---@param except? string licence d'un membre à ne pas prévenir
function CrewService.notifyMembers(crew, text, except)
    for _, member in ipairs(crew.members) do
        local player = member.identifier ~= except and CrewService.findOnline(member.identifier)
        if player then player:notify(text, 'info') end
    end
end

---Le label d'un joueur vient de changer : tout ce qui affiche son nom est remis à jour.
---@param identifier string
function CrewService.refreshPlayer(identifier)
    local player = CrewService.findOnline(identifier)
    if not player then return end
    Player(player.source).state:set(CrewService.STATE_KEY, CrewService.memberOf[identifier] or false, true)
    player:sync()
    local group = GroupService.getGroupOf(player.source)
    if group then GroupService.sync(group) end
end

-- ---------------------------------------------------------------------------
-- Actions (callbacks du menu Crew et commandes du chat)
-- ---------------------------------------------------------------------------

---@param tag any
---@return string|nil label en majuscules, nil s'il n'a pas 3 lettres
function CrewService.cleanTag(tag)
    if type(tag) ~= 'string' then return nil end
    tag = tag:upper()
    return tag:match('^[A-Z][A-Z][A-Z]$')
end

---@param name any
---@return string|nil nom nettoyé, nil si sa longueur ne convient pas
function CrewService.cleanName(name)
    if type(name) ~= 'string' or not utf8.len(name) then return nil end
    -- ~ : codes couleur de GTA ; < > : balises
    name = name:gsub('[%c~<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    local length = utf8.len(name)
    if length < Config.Crews.nameMinLength or length > Config.Crews.nameMaxLength then return nil end
    return name
end

---@param source integer
---@param data any { tag, name }
---@return { ok: boolean, message?: string }
function CrewService.create(source, data)
    local player = PlayerService.get(source)
    if not player or player.mode ~= 'pvp' then return { ok = false, message = Locale.t('Disponible seulement en PvP.') } end
    if CrewService.memberOf[player.identifier] then return { ok = false, message = Locale.t('Quitte d\'abord ton crew.') } end
    if type(data) ~= 'table' then return { ok = false } end

    local tag = CrewService.cleanTag(data.tag)
    if not tag then return { ok = false, message = Locale.t('Le label doit faire 3 lettres.') } end
    if Config.Crews.reservedTags[tag] then return { ok = false, message = Locale.t('Ce label est interdit.') } end
    if CrewService.crews[tag] then return { ok = false, message = Locale.t('Le label %s est déjà pris.', tag) } end

    local name = CrewService.cleanName(data.name)
    if not name then
        return { ok = false, message = Locale.t('Le nom du crew doit faire de %d à %d caractères.', Config.Crews.nameMinLength, Config.Crews.nameMaxLength) }
    end
    if Config.Crews.createPrice > 0 and not player:removeMoney(Config.Crews.createPrice) then
        return { ok = false, message = Locale.t('Il te faut $%d sur toi.', Config.Crews.createPrice) }
    end

    local crew = { tag = tag, name = name, leader = player.identifier, members = {} }
    CrewService.crews[tag] = crew
    CrewService.attach(crew, player.identifier, player.name)
    CrewRepository.create(tag, name, player.identifier)
    CrewRepository.addMember(player.identifier, tag, player.name)
    Logger.info('[crew] %s crée [%s] %s', player.name, tag, name)

    CrewService.refreshPlayer(player.identifier)
    CrewService.sync(crew)
    return { ok = true, message = Locale.t('Crew [%s] créé.', tag) }
end

---@param source integer chef
---@param targetId any server id du joueur invité
---@return { ok: boolean, message?: string }
function CrewService.invite(source, targetId)
    local player = PlayerService.get(source)
    local crew = CrewService.crewOf(source)
    if not player or player.mode ~= 'pvp' then return { ok = false, message = Locale.t('Disponible seulement en PvP.') } end
    if not crew then return { ok = false, message = Locale.t('Tu n\'es dans aucun crew.') } end
    if crew.leader ~= player.identifier then return { ok = false, message = Locale.t('Seul le chef du crew peut inviter.') } end

    local target = PlayerService.get(tonumber(targetId))
    if not target or target == player then return { ok = false, message = Locale.t('Joueur introuvable.') } end
    if target.mode ~= 'pvp' then return { ok = false, message = Locale.t('%s n\'est pas en PvP.', target.name) } end
    if CrewService.memberOf[target.identifier] then
        return { ok = false, message = Locale.t('%s est déjà dans un crew.', target.name) }
    end
    if #crew.members >= Config.Crews.maxMembers then
        return { ok = false, message = Locale.t('Crew complet (%d max).', Config.Crews.maxMembers) }
    end

    CrewService.invites[target.source] = { tag = crew.tag, from = source, expires = os.time() + Config.Crews.inviteTimeout }
    TriggerClientEvent(Events.client.crewInvite, target.source, { tag = crew.tag, name = crew.name, fromName = player.name })
    return { ok = true, message = Locale.t('Invitation envoyée à %s.', target.name) }
end

---@param source integer
---@param accept any
---@return { ok: boolean, message?: string }
function CrewService.respond(source, accept)
    local invite = CrewService.invites[source]
    CrewService.invites[source] = nil
    local player = PlayerService.get(source)
    if not player or not invite or invite.expires < os.time() then
        return { ok = false, message = Locale.t('Aucune invitation en attente.') }
    end
    if accept ~= true then return { ok = true, message = Locale.t('Invitation refusée.') } end

    local crew = CrewService.crews[invite.tag]
    if not crew then return { ok = false, message = Locale.t('Ce crew n\'existe plus.') } end
    if player.mode ~= 'pvp' then return { ok = false, message = Locale.t('Disponible seulement en PvP.') } end
    if CrewService.memberOf[player.identifier] then return { ok = false, message = Locale.t('Quitte d\'abord ton crew.') } end
    if #crew.members >= Config.Crews.maxMembers then return { ok = false, message = Locale.t('Le crew est complet.') } end

    CrewService.attach(crew, player.identifier, player.name)
    CrewRepository.addMember(player.identifier, crew.tag, player.name)
    CrewService.notifyMembers(crew, Locale.t('%s a rejoint le crew.', player.name), player.identifier)
    CrewService.refreshPlayer(player.identifier)
    CrewService.sync(crew)
    return { ok = true, message = Locale.t('Tu as rejoint le crew [%s].', crew.tag) }
end

---Quitter le crew : le plus ancien membre devient chef si le chef part, le dernier à partir le dissout.
---@param source integer
---@return { ok: boolean, message?: string }
function CrewService.leave(source)
    local player = PlayerService.get(source)
    local crew = CrewService.crewOf(source)
    if not player or not crew then return { ok = false, message = Locale.t('Tu n\'es dans aucun crew.') } end

    local wasLeader = crew.leader == player.identifier
    CrewService.removeMember(crew, player.identifier)
    if #crew.members == 0 then
        CrewService.crews[crew.tag] = nil
        CrewRepository.delete(crew.tag)
        return { ok = true, message = Locale.t('Tu as quitté le crew : il est dissous.') }
    end

    if wasLeader then CrewService.setLeader(crew, crew.members[1]) end
    CrewService.notifyMembers(crew, Locale.t('%s a quitté le crew.', player.name))
    CrewService.sync(crew)
    return { ok = true, message = Locale.t('Tu as quitté le crew.') }
end

---@param source integer chef
---@param key any numéro du membre
---@return { ok: boolean, message?: string }
function CrewService.kick(source, key)
    local player = PlayerService.get(source)
    local crew = CrewService.crewOf(source)
    if not player or not crew or crew.leader ~= player.identifier then
        return { ok = false, message = Locale.t('Seul le chef du crew peut exclure.') }
    end
    local member = CrewService.findMember(crew, key)
    if not member or member.identifier == player.identifier then
        return { ok = false, message = Locale.t('Joueur introuvable dans le crew.') }
    end

    local target = CrewService.findOnline(member.identifier)
    CrewService.removeMember(crew, member.identifier)
    if target then target:notify(Locale.t('Tu as été exclu du crew [%s].', crew.tag), 'info') end
    CrewService.sync(crew)
    return { ok = true, message = Locale.t('%s exclu du crew.', member.name) }
end

---@param source integer chef
---@param key any numéro du nouveau chef
---@return { ok: boolean, message?: string }
function CrewService.transfer(source, key)
    local player = PlayerService.get(source)
    local crew = CrewService.crewOf(source)
    if not player or not crew or crew.leader ~= player.identifier then
        return { ok = false, message = Locale.t('Seul le chef du crew peut passer la main.') }
    end
    local member = CrewService.findMember(crew, key)
    if not member or member.identifier == player.identifier then
        return { ok = false, message = Locale.t('Joueur introuvable dans le crew.') }
    end

    CrewService.setLeader(crew, member)
    CrewService.sync(crew)
    return { ok = true }
end

---@param source integer chef
---@return { ok: boolean, message?: string }
function CrewService.disband(source)
    local player = PlayerService.get(source)
    local crew = CrewService.crewOf(source)
    if not player or not crew or crew.leader ~= player.identifier then
        return { ok = false, message = Locale.t('Seul le chef du crew peut le dissoudre.') }
    end

    CrewService.dissolve(crew)
    Logger.info('[crew] %s dissout [%s]', player.name, crew.tag)
    return { ok = true }
end

---crewdissoudre <label>
---@param source integer 0 = console
---@param tag string|nil
function CrewService.commandDisband(source, tag)
    local crew = CrewService.crews[CrewService.cleanTag(tag) or '']
    if not crew then return AdminService.reply(source, Locale.t('Usage : crewdissoudre <label d\'un crew existant>')) end

    CrewService.dissolve(crew)
    local by = source == 0 and 'console' or GetPlayerName(source)
    Logger.info('[admin] %s : crewdissoudre %s', by, crew.tag)
    DiscordService.adminCommand(source, 'crewdissoudre', crew.tag)
    AdminService.reply(source, Locale.t('Crew [%s] dissous.', crew.tag))
end

-- ---------------------------------------------------------------------------
-- Cycle de vie
-- ---------------------------------------------------------------------------

---@param crew PvpCrew
---@param identifier string
---@param name string
function CrewService.attach(crew, identifier, name)
    CrewService.nextKey = CrewService.nextKey + 1
    crew.members[#crew.members + 1] = { key = CrewService.nextKey, identifier = identifier, name = name }
    CrewService.memberOf[identifier] = crew.tag
end

---@param crew PvpCrew
---@param identifier string
function CrewService.removeMember(crew, identifier)
    for index, member in ipairs(crew.members) do
        if member.identifier == identifier then table.remove(crew.members, index) break end
    end
    CrewService.memberOf[identifier] = nil
    CrewRepository.removeMember(identifier)

    local player = CrewService.findOnline(identifier)
    if player then TriggerClientEvent(Events.client.crewSync, player.source, false) end
    CrewService.refreshPlayer(identifier)
end

---@param crew PvpCrew
---@param member PvpCrewMember
function CrewService.setLeader(crew, member)
    crew.leader = member.identifier
    CrewRepository.setLeader(crew.tag, member.identifier)
    CrewService.notifyMembers(crew, Locale.t('%s est le nouveau chef du crew.', member.name))
end

---@param crew PvpCrew
function CrewService.dissolve(crew)
    CrewService.notifyMembers(crew, Locale.t('Le crew [%s] est dissous.', crew.tag))
    CrewService.crews[crew.tag] = nil
    while crew.members[1] do
        CrewService.removeMember(crew, crew.members[1].identifier)
    end
    CrewRepository.delete(crew.tag)
end

---@param source integer
function CrewService.onPlayerLoaded(source)
    local player = PlayerService.get(source)
    if not player then return end
    Player(source).state:set(CrewService.STATE_KEY, CrewService.memberOf[player.identifier] or false, true)

    local crew = CrewService.crewOf(source)
    if not crew then return end
    for _, member in ipairs(crew.members) do
        if member.identifier == player.identifier and member.name ~= player.name then
            member.name = player.name
            CrewRepository.setMemberName(player.identifier, player.name)
        end
    end
    CrewService.sync(crew)
end

---@param source integer
function CrewService.onPlayerUnloading(source)
    CrewService.invites[source] = nil
    local crew = CrewService.crewOf(source)
    if crew then CrewService.sync(crew, source) end
end
