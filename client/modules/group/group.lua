---Groupe (escouade) côté client : repères des coéquipiers, leur vie dans le HUD,
---invitations, commandes du chat et menu Groupe.
---Le serveur décide de tout (voir server/modules/group/group_service.lua).
---@class GroupModule
local Group = PVP.define('Group')
local Nui = PVP.use('Nui')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')

Group.VITALS_INTERVAL = 500

---@type table|false groupe actuel { id, leader, members = { { id, name } } }
Group.data = false
---@type table<integer, integer> server id -> blip
Group.blips = {}
Group.lastVitals = ''

function Group.init()
    RegisterNetEvent(Events.client.groupSync, function(data)
        Group.onSync(data)
    end)
    RegisterNetEvent(Events.client.groupInvite, function(invite)
        Group.onInvite(invite)
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

    CreateThread(Group.loop)
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
    Group.lastVitals = ''
    Group.refreshBlips()
    Nui.send('group', { group = Group.data })
end

---@param invite { from: integer, fromName: string }
function Group.onInvite(invite)
    Nui.send('groupInvite', invite)
    Nui.notify(('%s t\'invite dans son groupe : /accepter ou menu Groupe.'):format(invite.fromName), 'info')
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
-- Repères et vie des coéquipiers
-- ---------------------------------------------------------------------------

function Group.loop()
    while true do
        Wait(Group.VITALS_INTERVAL)
        if Group.data then
            Group.refreshBlips()
            Group.sendVitals()
        end
    end
end

---Un repère par coéquipier visible (les joueurs trop loin ne sont pas chargés par le jeu).
function Group.refreshBlips()
    local me = GetPlayerServerId(PlayerId())
    for source, blip in pairs(Group.blips) do
        local player = GetPlayerFromServerId(source)
        if not Group.isMember(source) or player == -1 or not DoesBlipExist(blip) then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            Group.blips[source] = nil
        end
    end
    if not Group.data then return end

    for _, member in ipairs(Group.data.members) do
        local player = GetPlayerFromServerId(member.id)
        if member.id ~= me and player ~= -1 and not Group.blips[member.id] then
            local blip = AddBlipForEntity(GetPlayerPed(player))
            SetBlipSprite(blip, 1)
            SetBlipColour(blip, Config.Groups.blipColor)
            SetBlipScale(blip, 0.85)
            ShowHeadingIndicatorOnBlip(blip, true)
            SetBlipCategory(blip, 7)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(member.name)
            EndTextCommandSetBlipName(blip)
            Group.blips[member.id] = blip
        end
    end
end

---Vie de chaque coéquipier (nil s'il est trop loin pour être chargé), envoyée seulement si elle change.
function Group.sendVitals()
    local vitals = {}
    local parts = {}
    for _, member in ipairs(Group.data.members) do
        local player = GetPlayerFromServerId(member.id)
        local entry = { id = member.id, health = false, armor = 0 }
        if player ~= -1 then
            local ped = GetPlayerPed(player)
            entry.health = math.max(0, GetEntityHealth(ped) - 100)
            entry.armor = GetPedArmour(ped)
        end
        vitals[#vitals + 1] = entry
        parts[#parts + 1] = ('%d:%s:%d'):format(member.id, tostring(entry.health), entry.armor)
    end

    local key = table.concat(parts, ',')
    if key == Group.lastVitals then return end
    Group.lastVitals = key
    Nui.send('groupVitals', vitals)
end
