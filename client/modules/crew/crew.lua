---Crew côté client : menu Crew, invitations, commandes du chat et label des autres joueurs.
---Le serveur décide de tout (voir server/modules/crew/crew_service.lua).
---@class CrewModule
local Crew = PVP.define('Crew')
local Nui = PVP.use('Nui')
local State = PVP.use('State')
local Gamertags = PVP.use('Gamertags')
local Control = PVP.use('Control')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Crew.STATE_KEY = 'crewTag' -- publié par server/modules/crew

---@type table|false crew du joueur { tag, name, members = { { key, name, id, leader } } }
Crew.data = false

function Crew.init()
    RegisterNetEvent(Events.client.crewSync, function(data)
        Crew.onSync(data)
    end)
    RegisterNetEvent(Events.client.crewInvite, function(invite)
        Crew.onInvite(invite)
    end)

    -- Commandes du chat (T puis /commande)
    RegisterCommand('crewinviter', function(_, args)
        Crew.request(Events.callbacks.crewInvite, tonumber(args[1]))
    end, false)
    RegisterCommand('crewaccepter', function()
        Crew.respond(true)
    end, false)
    RegisterCommand('crewrefuser', function()
        Crew.respond(false)
    end, false)
    RegisterCommand('crewquitter', function()
        Crew.request(Events.callbacks.crewLeave)
    end, false)

    -- Menu Crew
    RegisterNUICallback('crewCreate', function(data, cb)
        cb(Callback.await(Events.callbacks.crewCreate, { tag = data.tag, name = data.name }) or { ok = false })
    end)
    RegisterNUICallback('crewInvite', function(data, cb)
        cb(Callback.await(Events.callbacks.crewInvite, tonumber(data.target)) or { ok = false })
    end)
    RegisterNUICallback('crewRespond', function(data, cb)
        local result = Callback.await(Events.callbacks.crewRespond, data.accept == true) or { ok = false }
        Nui.send('crewInvite', false)
        cb(result)
    end)
    RegisterNUICallback('crewLeave', function(_, cb)
        cb(Callback.await(Events.callbacks.crewLeave) or { ok = false })
    end)
    RegisterNUICallback('crewKick', function(data, cb)
        cb(Callback.await(Events.callbacks.crewKick, tonumber(data.key)) or { ok = false })
    end)
    RegisterNUICallback('crewTransfer', function(data, cb)
        cb(Callback.await(Events.callbacks.crewTransfer, tonumber(data.key)) or { ok = false })
    end)
    RegisterNUICallback('crewDisband', function(_, cb)
        cb(Callback.await(Events.callbacks.crewDisband) or { ok = false })
    end)
    RegisterNUICallback('crewStashPut', function(data, cb)
        cb(Callback.await(Events.callbacks.crewStashPut, { item = data.item, count = data.count, from = data.from }) or { ok = false })
    end)
    RegisterNUICallback('crewStashTake', function(data, cb)
        cb(Callback.await(Events.callbacks.crewStashTake, { item = data.item, count = data.count, to = data.to }) or { ok = false })
    end)
    RegisterNUICallback('crewLeaderboard', function(data, cb)
        cb(Callback.await(Events.callbacks.crewLeaderboard, data.scope) or { rows = {}, title = '' })
    end)
end

---Commande du chat : le résultat s'affiche en notification.
---@param name string callback serveur
---@param ... any
function Crew.request(name, ...)
    local args = { ... }
    CreateThread(function()
        local result = Callback.await(name, table.unpack(args))
        if result and result.message then
            Nui.notify(result.message, result.ok and 'success' or 'error')
        end
    end)
end

---@param accept boolean
function Crew.respond(accept)
    Crew.request(Events.callbacks.crewRespond, accept)
    Nui.send('crewInvite', false)
end

---@param data table|false
function Crew.onSync(data)
    Crew.data = data or false
    Gamertags.setCrew(Crew.data and Crew.data.tag or nil)
    Nui.send('crew', { crew = Crew.data })
    Control.refresh()
end

---@param invite { tag: string, name: string, fromName: string }
function Crew.onInvite(invite)
    Nui.send('crewInvite', invite)
    Nui.notify(Locale.t('%s t\'invite dans le crew [%s] : /crewaccepter ou menu Crew.', invite.fromName, invite.tag), 'info')
end

---@return boolean le joueur est chef de son crew
function Crew.isLeader()
    if not Crew.data then return false end
    local me = GetPlayerServerId(PlayerId())
    for _, member in ipairs(Crew.data.members) do
        if member.id == me then return member.leader end
    end
    return false
end

---Le label ne compte qu'en PvP.
---@param serverId integer
---@return string|nil label du crew de ce joueur
function Crew.tagOf(serverId)
    if State.mode ~= 'pvp' then return nil end
    return Player(serverId).state[Crew.STATE_KEY] or nil
end

---@param serverId integer
---@param name string
---@return string nom précédé du label du crew : « [MGZ] Nom »
function Crew.label(serverId, name)
    local tag = Crew.tagOf(serverId)
    return tag and ('[%s] %s'):format(tag, name) or name
end
