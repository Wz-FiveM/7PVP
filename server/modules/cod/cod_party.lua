---Escouades du mode Call of Duty : jouer entre amis. Le chef invite, lance la recherche pour tout le monde ou une partie
---privée ; en partie, l'escouade reste dans le même camp. Une escouade n'existe qu'en mémoire.
---@class CodPartyData
---@field id integer
---@field leader integer
---@field members integer[]

---@class CodPartyModule
local CodParty = PVP.define('CodParty')
local CodService = PVP.use('CodService')
local CodMapService = PVP.use('CodMapService')
local PlayerService = PVP.use('PlayerService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

---@type table<integer, CodPartyData>
CodParty.parties = {}
---@type table<integer, integer> joueur -> escouade
CodParty.memberOf = {}
---@type table<integer, { party: integer, expires: integer }> invitation en attente, par joueur invité
CodParty.invites = {}
CodParty.nextId = 0

function CodParty.init()
    Callback.register(Events.callbacks.codPartyInvite, CodParty.invite)
    Callback.register(Events.callbacks.codPartyRespond, CodParty.respond)
    Callback.register(Events.callbacks.codPartyLeave, function(source)
        CodParty.leave(source)
        return { ok = true }
    end)
    Callback.register(Events.callbacks.codPartyKick, CodParty.kick)
    Callback.register(Events.callbacks.codPartyLobby, CodParty.lobby)
    AddEventHandler(Events.internal.playerUnloading, function(source)
        CodParty.leave(source)
        CodParty.invites[source] = nil
    end)
end

---@param source integer
---@return CodPartyData|nil
function CodParty.of(source)
    return CodParty.parties[CodParty.memberOf[source]]
end

---@param source integer
---@return integer[] lui et son escouade
function CodParty.membersOf(source)
    local party = CodParty.of(source)
    return party and { table.unpack(party.members) } or { source }
end

---@param party CodPartyData
function CodParty.sync(party)
    local members = {}
    for index, source in ipairs(party.members) do
        members[index] = { id = source, name = GetPlayerName(source) or '?' }
    end
    for _, source in ipairs(party.members) do
        TriggerClientEvent(Events.client.codParty, source, { leader = party.leader, members = members })
    end
end

---@param source integer
---@param targetId any
---@return { ok: boolean, message?: string }
function CodParty.invite(source, targetId)
    local player, target = PlayerService.get(source), PlayerService.get(tonumber(targetId))
    if not player or player.mode ~= 'cod' then return { ok = false } end
    if not target or target == player or target.mode ~= 'cod' then return { ok = false, message = Locale.t('Joueur introuvable.') } end
    if CodParty.of(target.source) then return { ok = false, message = Locale.t('%s est déjà dans une escouade.', target.name) } end

    local party = CodParty.of(source)
    if not party then
        CodParty.nextId = CodParty.nextId + 1
        party = { id = CodParty.nextId, leader = source, members = { source } }
        CodParty.parties[party.id] = party
        CodParty.memberOf[source] = party.id
        CodParty.sync(party)
    end
    if party.leader ~= source then return { ok = false, message = Locale.t('Seul le chef de l\'escouade peut inviter.') } end
    if #party.members >= Config.Cod.party.maxSize then
        return { ok = false, message = Locale.t('Escouade complète (%d au maximum).', Config.Cod.party.maxSize) }
    end

    CodParty.invites[target.source] = { party = party.id, expires = os.time() + Config.Cod.party.inviteTimeout }
    TriggerClientEvent(Events.client.codPartyInvite, target.source, { fromName = player.name, seconds = Config.Cod.party.inviteTimeout })
    return { ok = true, message = Locale.t('Invitation envoyée à %s.', target.name) }
end

---@param source integer
---@param accept any
---@return { ok: boolean, message?: string }
function CodParty.respond(source, accept)
    local invite = CodParty.invites[source]
    CodParty.invites[source] = nil
    if accept ~= true then return { ok = true } end
    local party = invite and invite.expires >= os.time() and CodParty.parties[invite.party]
    if not party then return { ok = false, message = Locale.t('Cette escouade n\'existe plus.') } end
    if CodParty.of(source) then return { ok = false, message = Locale.t('Quitte d\'abord ton escouade.') } end
    if #party.members >= Config.Cod.party.maxSize then return { ok = false, message = Locale.t('L\'escouade est complète.') } end
    if CodService.isBusy(party.leader) or CodService.isBusy(source) then
        return { ok = false, message = Locale.t('Annule ta recherche de partie avant de rejoindre une escouade.') }
    end

    party.members[#party.members + 1] = source
    CodParty.memberOf[source] = party.id
    CodParty.sync(party)
    return { ok = true }
end

---Départ, exclusion, retour au lobby, déconnexion. Une escouade d'un seul joueur disparaît.
---@param source integer
function CodParty.leave(source)
    local party = CodParty.of(source)
    if not party then return end
    CodParty.memberOf[source] = nil
    for index, member in ipairs(party.members) do
        if member == source then table.remove(party.members, index) break end
    end
    TriggerClientEvent(Events.client.codParty, source, false)

    if #party.members <= 1 then
        for _, member in ipairs(party.members) do
            CodParty.memberOf[member] = nil
            TriggerClientEvent(Events.client.codParty, member, false)
        end
        CodParty.parties[party.id] = nil
        return
    end
    if party.leader == source then party.leader = party.members[1] end
    CodParty.sync(party)
end

---@param source integer chef
---@param targetId any
---@return { ok: boolean }
function CodParty.kick(source, targetId)
    local party = CodParty.of(source)
    targetId = tonumber(targetId)
    if not party or party.leader ~= source or targetId == source or CodParty.memberOf[targetId] ~= party.id then return { ok = false } end
    CodParty.leave(targetId)
    return { ok = true }
end

---Ce que montre l'onglet Escouade : les joueurs à inviter et les cartes des parties privées.
---@return { players: table[], maps: table[] }
function CodParty.lobby(source)
    local players, maps = {}, {}
    for _, player in pairs(PlayerService.all()) do
        if player.mode == 'cod' and player.source ~= source and not CodParty.of(player.source) then
            players[#players + 1] = { id = player.source, name = player.name, busy = CodService.isBusy(player.source) }
        end
    end
    table.sort(players, function(a, b) return a.name < b.name end)
    for _, map in ipairs(Config.Cod.maps) do
        if CodMapService.playable(map) then maps[#maps + 1] = { id = map.id, label = map.label, place = map.place } end
    end
    return { players = players, maps = maps }
end
