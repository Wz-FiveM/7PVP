---Groupes (escouades) du mode PvP : invitations, pas de tir allié, coéquipiers synchronisés.
---Un groupe n'existe qu'en mémoire : il disparaît quand son dernier membre le quitte.
---@class PvpGroup
---@field id integer
---@field leader integer server id du chef
---@field members integer[] server ids, dans l'ordre d'arrivée

---@class GroupServiceModule
local GroupService = PVP.define('GroupService')
local PlayerService = PVP.use('PlayerService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

---@type table<integer, PvpGroup>
GroupService.groups = {}
---@type table<integer, integer> server id -> id du groupe
GroupService.memberOf = {}
---@type table<integer, { groupId: integer, from: integer, expires: integer }> invitation reçue par joueur
GroupService.invites = {}
GroupService.nextId = 0

function GroupService.init()
    Callback.register(Events.callbacks.groupInvite, GroupService.invite)
    Callback.register(Events.callbacks.groupRespond, GroupService.respond)
    Callback.register(Events.callbacks.groupLeave, GroupService.leaveCallback)
    Callback.register(Events.callbacks.groupKick, GroupService.kick)

    -- Pas de tir allié : la touche est annulée avant d'être appliquée
    AddEventHandler('weaponDamageEvent', function(sender, data)
        GroupService.onWeaponDamage(sender, data)
    end)

    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        GroupService.leave(playerSource)
        GroupService.invites[playerSource] = nil
    end)

    CreateThread(GroupService.stateLoop)
end

GroupService.STATE_INTERVAL = 1000

---Vie, armure et position des membres, lues par le serveur : connues même quand les
---coéquipiers sont trop loin pour que le jeu du joueur les charge.
function GroupService.stateLoop()
    while true do
        Wait(GroupService.STATE_INTERVAL)
        for _, group in pairs(GroupService.groups) do
            if #group.members > 1 then GroupService.sendState(group) end
        end
    end
end

---@param group PvpGroup
function GroupService.sendState(group)
    local state = {}
    for _, source in ipairs(group.members) do
        local player = PlayerService.get(source)
        local ped = GetPlayerPed(source)
        if player and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            state[#state + 1] = {
                id = source,
                health = player.dead and 0 or math.max(0, GetEntityHealth(ped) - 100),
                armor = GetPedArmour(ped),
                dead = player.dead,
                x = coords.x,
                y = coords.y,
                z = coords.z,
                heading = GetEntityHeading(ped),
            }
        end
    end
    for _, source in ipairs(group.members) do
        TriggerClientEvent(Events.client.groupState, source, state)
    end
end

-- ---------------------------------------------------------------------------
-- Lecture
-- ---------------------------------------------------------------------------

---@param source integer
---@return PvpGroup|nil
function GroupService.getGroupOf(source)
    local id = GroupService.memberOf[source]
    return id and GroupService.groups[id] or nil
end

---@param a integer server id
---@param b integer server id
---@return boolean même groupe
function GroupService.areAllies(a, b)
    local group = GroupService.memberOf[a]
    return group ~= nil and a ~= b and group == GroupService.memberOf[b]
end

---@param group PvpGroup
---@return table données envoyées aux clients
function GroupService.serialize(group)
    local members = {}
    for _, source in ipairs(group.members) do
        local player = PlayerService.get(source)
        members[#members + 1] = {
            id = source,
            name = player and player.name or GetPlayerName(source),
            avatar = player and player.avatar,
        }
    end
    return { id = group.id, leader = group.leader, members = members }
end

---Renvoie le groupe à jour à tous ses membres (ou `false` à un joueur sans groupe).
---@param group PvpGroup
function GroupService.sync(group)
    local data = GroupService.serialize(group)
    for _, source in ipairs(group.members) do
        TriggerClientEvent(Events.client.groupSync, source, data)
    end
end

---@param group PvpGroup
---@param text string
---@param except? integer
function GroupService.notifyMembers(group, text, except)
    for _, source in ipairs(group.members) do
        local player = source ~= except and PlayerService.get(source)
        if player then player:notify(text, 'info') end
    end
end

-- ---------------------------------------------------------------------------
-- Actions (callbacks du menu Groupe et commandes du chat)
-- ---------------------------------------------------------------------------

---@param source integer
---@param targetId any server id du joueur invité
---@return { ok: boolean, message?: string }
function GroupService.invite(source, targetId)
    local player = PlayerService.get(source)
    local target = PlayerService.get(tonumber(targetId))
    if not player or player.mode ~= 'pvp' then return { ok = false, message = Locale.t('Disponible seulement en PvP.') } end
    if not target or target == player then return { ok = false, message = Locale.t('Joueur introuvable.') } end
    if target.mode ~= 'pvp' then return { ok = false, message = Locale.t('%s n\'est pas en PvP.', target.name) } end
    if GroupService.getGroupOf(target.source) then
        return { ok = false, message = Locale.t('%s est déjà dans une équipe.', target.name) }
    end

    local group = GroupService.getGroupOf(source) or GroupService.create(source)
    if group.leader ~= source then return { ok = false, message = Locale.t('Seul le chef peut inviter.') } end
    if #group.members >= Config.Groups.maxSize then
        return { ok = false, message = Locale.t('Équipe complète (%d max).', Config.Groups.maxSize) }
    end

    GroupService.invites[target.source] = {
        groupId = group.id,
        from = source,
        expires = os.time() + Config.Groups.inviteTimeout,
    }
    TriggerClientEvent(Events.client.groupInvite, target.source, { from = source, fromName = player.name })
    return { ok = true, message = Locale.t('Invitation envoyée à %s.', target.name) }
end

---@param source integer
---@param accept any
---@return { ok: boolean, message?: string }
function GroupService.respond(source, accept)
    local invite = GroupService.invites[source]
    GroupService.invites[source] = nil
    local player = PlayerService.get(source)
    if not player or not invite or invite.expires < os.time() then
        return { ok = false, message = Locale.t('Aucune invitation en attente.') }
    end
    if accept ~= true then return { ok = true, message = Locale.t('Invitation refusée.') } end

    local group = GroupService.groups[invite.groupId]
    if not group then return { ok = false, message = Locale.t('Cette équipe n\'existe plus.') } end
    if player.mode ~= 'pvp' then return { ok = false, message = Locale.t('Disponible seulement en PvP.') } end
    if GroupService.getGroupOf(source) then return { ok = false, message = Locale.t('Quitte d\'abord ton équipe.') } end
    if #group.members >= Config.Groups.maxSize then return { ok = false, message = Locale.t('L\'équipe est complète.') } end

    group.members[#group.members + 1] = source
    GroupService.memberOf[source] = group.id
    GroupService.notifyMembers(group, Locale.t('%s a rejoint l\'équipe.', player.name), source)
    GroupService.sync(group)
    return { ok = true, message = Locale.t('Tu as rejoint l\'équipe.') }
end

---@param source integer
---@return { ok: boolean, message?: string }
function GroupService.leaveCallback(source)
    if not GroupService.getGroupOf(source) then return { ok = false, message = Locale.t('Tu n\'es dans aucune équipe.') } end
    GroupService.leave(source)
    return { ok = true, message = Locale.t('Tu as quitté l\'équipe.') }
end

---@param source integer chef
---@param targetId any
---@return { ok: boolean, message?: string }
function GroupService.kick(source, targetId)
    local group = GroupService.getGroupOf(source)
    targetId = tonumber(targetId)
    if not group or group.leader ~= source then return { ok = false, message = Locale.t('Seul le chef peut exclure.') } end
    if not targetId or targetId == source or GroupService.memberOf[targetId] ~= group.id then
        return { ok = false, message = Locale.t('Joueur introuvable dans l\'équipe.') }
    end

    local target = PlayerService.get(targetId)
    GroupService.leave(targetId)
    if target then target:notify(Locale.t('Tu as été exclu de l\'équipe.'), 'info') end
    return { ok = true }
end

-- ---------------------------------------------------------------------------
-- Cycle de vie
-- ---------------------------------------------------------------------------

---@param leader integer
---@return PvpGroup
function GroupService.create(leader)
    GroupService.nextId = GroupService.nextId + 1
    local group = { id = GroupService.nextId, leader = leader, members = { leader } }
    GroupService.groups[group.id] = group
    GroupService.memberOf[leader] = group.id
    GroupService.sync(group)
    return group
end

---Retire le joueur de son groupe (départ, exclusion, retour au lobby, déconnexion).
---Le chef suivant est le plus ancien membre ; un groupe d'une seule personne est dissous.
---@param source integer
function GroupService.leave(source)
    local group = GroupService.getGroupOf(source)
    if not group then return end

    GroupService.memberOf[source] = nil
    for index, member in ipairs(group.members) do
        if member == source then table.remove(group.members, index) break end
    end
    TriggerClientEvent(Events.client.groupSync, source, false)

    if #group.members <= 1 then
        GroupService.disband(group)
        return
    end
    if group.leader == source then group.leader = group.members[1] end

    local player = PlayerService.get(source)
    GroupService.notifyMembers(group, Locale.t('%s a quitté l\'équipe.', player and player.name or GetPlayerName(source)))
    GroupService.sync(group)
end

---@param group PvpGroup
function GroupService.disband(group)
    for _, source in ipairs(group.members) do
        GroupService.memberOf[source] = nil
        TriggerClientEvent(Events.client.groupSync, source, false)
        local player = PlayerService.get(source)
        if player then player:notify(Locale.t('Équipe dissoute.'), 'info') end
    end
    GroupService.groups[group.id] = nil
end

---@param sender integer
---@param data table hitGlobalId ou hitGlobalIds
function GroupService.onWeaponDamage(sender, data)
    if not GroupService.memberOf[sender] or type(data) ~= 'table' then return end
    -- Un groupe survit au changement de mode : en Call of Duty, seules les équipes de la partie comptent
    local attacker = PlayerService.get(sender)
    if attacker and attacker.mode == 'cod' then return end
    local ids = data.hitGlobalIds or { data.hitGlobalId }
    for _, netId in ipairs(ids) do
        local ped = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
        if ped ~= 0 and DoesEntityExist(ped) then
            local owner = NetworkGetEntityOwner(ped)
            if GetPlayerPed(owner) == ped and GroupService.areAllies(sender, owner) then
                CancelEvent()
                return
            end
        end
    end
end
