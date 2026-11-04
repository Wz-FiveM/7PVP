---Groupe (escouade) côté client : repères des coéquipiers, leur vie dans le HUD,
---invitations, commandes du chat et menu Groupe.
---Le serveur décide de tout (voir server/modules/group/group_service.lua).
---@class GroupModule
local Group = PVP.define('Group')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

-- Équipes que le jeu sait distinguer. Au-delà, le tir allié est seulement annulé par le serveur.
Group.MAX_SLOTS = 24
Group.FIRE_INTERVAL = 250

---@type table|false groupe actuel { id, leader, slot, members = { { id, name } } }
Group.data = false
---@type table<integer, { blip: integer, entity: boolean }> server id -> repère (sur le joueur ou sur une position)
Group.blips = {}
---@type table<integer, table> dernier état reçu du serveur par coéquipier { health, armor, dead, x, y, z, heading }
Group.state = {}
---@type table<integer, integer> place de l'équipe -> groupe de relations du personnage
Group.relationGroups = {}
Group.firePed = 0 -- personnage sur lequel le groupe de relations est appliqué, 0 = réglé par Seven of Duty
Group.fireRelation = false -- groupe de relations appliqué, false = celui de tous les joueurs

function Group.init()
    Group.setupRelationships()
    CreateThread(Group.fireLoop)

    RegisterNetEvent(Events.client.groupSync, function(data)
        Group.onSync(data)
    end)
    RegisterNetEvent(Events.client.groupInvite, function(invite)
        Group.onInvite(invite)
    end)
    RegisterNetEvent(Events.client.groupState, function(state)
        Group.onState(state)
    end)

    -- Commandes du chat (T puis /commande)
    RegisterCommand('inviter', function(_, args)
        Group.request(Events.callbacks.groupInvite, tonumber(args[1]))
    end, false)
    RegisterCommand('accepter', function()
        Group.request(Events.callbacks.groupRespond, true)
    end, false)
    RegisterCommand('refuser', function()
        Group.request(Events.callbacks.groupRespond, false)
    end, false)
    RegisterCommand('quittergroupe', function()
        Group.request(Events.callbacks.groupLeave)
    end, false)

    -- Menu Groupe
    RegisterNUICallback('groupInvite', function(data, cb)
        cb(Callback.await(Events.callbacks.groupInvite, tonumber(data.target)) or { ok = false })
    end)
    RegisterNUICallback('groupRespond', function(data, cb)
        cb(Callback.await(Events.callbacks.groupRespond, data.accept == true) or { ok = false })
    end)
    RegisterNUICallback('groupLeave', function(_, cb)
        cb(Callback.await(Events.callbacks.groupLeave) or { ok = false })
    end)
    RegisterNUICallback('groupKick', function(data, cb)
        cb(Callback.await(Events.callbacks.groupKick, tonumber(data.target)) or { ok = false })
    end)

end

---Commande du chat : le résultat s'affiche en notification.
---@param name string callback serveur
---@param ... any
function Group.request(name, ...)
    local args = { ... }
    CreateThread(function()
        local result = Callback.await(name, table.unpack(args))
        if result and result.message then
            Nui.notify(result.message, result.ok and 'success' or 'error')
        end
    end)
end

---@param data table|false
function Group.onSync(data)
    Group.data = data or false
    if not Group.data then Group.state = {} end
    Group.refreshBlips()
    Nui.send('group', { group = Group.data })
end

---État des coéquipiers envoyé par le serveur chaque seconde : HUD et repères.
---@param list table[]
function Group.onState(list)
    if not Group.data or type(list) ~= 'table' then return end
    Group.state = {}
    local vitals = {}
    for _, entry in ipairs(list) do
        Group.state[entry.id] = entry
        vitals[#vitals + 1] = { id = entry.id, health = entry.health, armor = entry.armor, dead = entry.dead }
    end
    Nui.send('groupVitals', vitals)
    Group.refreshBlips()
end

---@param invite { from: integer, fromName: string }
function Group.onInvite(invite)
    Nui.send('groupInvite', invite)
    Nui.notify(Locale.t('%s t\'invite dans son équipe : /accepter ou menu Équipe.', invite.fromName), 'info')
end

---@param source integer
---@return boolean
function Group.isMember(source)
    if not Group.data then return false end
    for _, member in ipairs(Group.data.members) do
        if member.id == source then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Tir sur les autres joueurs
-- ---------------------------------------------------------------------------

---Chaque équipe est alliée à elle-même et ennemie de tous les autres joueurs.
function Group.setupRelationships()
    local playerGroup = GetHashKey('PLAYER')
    for slot = 1, Group.MAX_SLOTS do
        local _, group = AddRelationshipGroup('PVP_SQUAD_' .. slot)
        Group.relationGroups[slot] = group
    end
    for slot, group in ipairs(Group.relationGroups) do
        SetRelationshipBetweenGroups(5, group, playerGroup)
        SetRelationshipBetweenGroups(5, playerGroup, group)
        for other, otherGroup in ipairs(Group.relationGroups) do
            SetRelationshipBetweenGroups(slot == other and 0 or 5, group, otherGroup)
        end
    end
end

function Group.fireLoop()
    while true do
        Wait(Group.FIRE_INTERVAL)
        Group.updateFire()
    end
end

---Le jeu refuse lui-même le tir sur un coéquipier (équipe) ou sur tout autre joueur (monde zombies, où
---tous restent dans le même groupe). Le serveur annule aussi ces touches, mais une touche annulée seule
---abîme la cible chez le tireur alors qu'elle reste en vie chez elle : il la voit tomber ou disparaître.
function Group.updateFire()
    -- En Seven of Duty et en Sabotage, seules les équipes de la partie comptent (Cod.applyTeam)
    if State.mode == 'cod' or State.mode == 'tactical' then
        if Group.firePed ~= 0 then
            Group.applyFire(false, false)
            Group.firePed = 0
        end
        return
    end

    local pveWorld = LocalPlayer.state.pveWorld == true
    local relation = not pveWorld and Group.data and Group.relationGroups[Group.data.slot] or false
    Group.applyFire(relation, pveWorld or relation ~= false)
end

---@param relation integer|false groupe de relations de l'équipe, false = celui de tous les joueurs
---@param blocked boolean le jeu refuse le tir sur les joueurs du même groupe
function Group.applyFire(relation, blocked)
    local ped = PlayerPedId()
    if ped ~= Group.firePed or relation ~= Group.fireRelation then
        SetPedRelationshipGroupHash(ped, relation or GetHashKey('PLAYER'))
        Group.firePed, Group.fireRelation = ped, relation
    end
    -- Redemandé à chaque passage : une réapparition rétablit le tir sur le même personnage (Spawn.resetPed)
    SetCanAttackFriendly(ped, not blocked, false)
    NetworkSetFriendlyFireOption(not blocked)
end

-- ---------------------------------------------------------------------------
-- Repères des coéquipiers
-- ---------------------------------------------------------------------------

---Un repère par coéquipier : sur son personnage s'il est chargé par le jeu (suit en douceur),
---sinon sur la position envoyée par le serveur (mise à jour chaque seconde), à toute distance.
function Group.refreshBlips()
    local me = GetPlayerServerId(PlayerId())
    for source, entry in pairs(Group.blips) do
        local loaded = GetPlayerFromServerId(source) ~= -1
        if not Group.isMember(source) or not DoesBlipExist(entry.blip) or entry.entity ~= loaded then
            if DoesBlipExist(entry.blip) then RemoveBlip(entry.blip) end
            Group.blips[source] = nil
        end
    end
    if not Group.data then return end

    for _, member in ipairs(Group.data.members) do
        local state = Group.state[member.id]
        if member.id ~= me then
            local entry = Group.blips[member.id]
            local player = GetPlayerFromServerId(member.id)
            if not entry and player ~= -1 then
                entry = { blip = AddBlipForEntity(GetPlayerPed(player)), entity = true }
                Group.setupBlip(entry.blip, member.name)
                Group.blips[member.id] = entry
            elseif not entry and state then
                entry = { blip = AddBlipForCoord(state.x, state.y, state.z), entity = false }
                Group.setupBlip(entry.blip, member.name)
                Group.blips[member.id] = entry
            end
            if entry and not entry.entity and state then
                SetBlipCoords(entry.blip, state.x, state.y, state.z)
                SetBlipRotation(entry.blip, math.floor(state.heading))
            end
        end
    end
end

---@param blip integer
---@param name string
function Group.setupBlip(blip, name)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, Config.Groups.blipColor)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, false)
    ShowHeadingIndicatorOnBlip(blip, true)
    SetBlipCategory(blip, 7)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(name)
    EndTextCommandSetBlipName(blip)
end
