---Groupe (escouade) côté client : repères des coéquipiers, leur vie dans le HUD,
---invitations, commandes du chat et menu Groupe.
---Le serveur décide de tout (voir server/modules/group/group_service.lua).
---@class GroupModule
local Group = PVP.define('Group')
local Nui = PVP.use('Nui')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

---@type table|false groupe actuel { id, leader, members = { { id, name } } }
Group.data = false
---@type table<integer, { blip: integer, entity: boolean }> server id -> repère (sur le joueur ou sur une position)
Group.blips = {}
---@type table<integer, table> dernier état reçu du serveur par coéquipier { health, armor, dead, x, y, z, heading }
Group.state = {}

function Group.init()
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
