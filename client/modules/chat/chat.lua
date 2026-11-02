---Chat : T ouvre la saisie (focus clavier sans curseur), Entrée envoie.
---Un message qui commence par « / » est exécuté comme une commande (/lobby...).
---À l'ouverture, l'interface reçoit les suggestions : commandes (Config.ChatCommands) et joueurs du mode.
---@class ChatModule
local Chat = PVP.define('Chat')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Admin = PVP.use('Admin')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Chat.PLAYERS_REFRESH = 5000 -- ms entre deux demandes de la liste des joueurs au serveur
Chat.open = false
Chat.playersFetchedAt = nil

function Chat.init()
    RegisterCommand('pvp_chat', function()
        Chat.openInput()
    end, false)
    RegisterKeyMapping('pvp_chat', Locale.t('Ouvrir le chat'), 'keyboard', Config.Chat.key)

    RegisterNetEvent(Events.client.chatMessage, function(message)
        Nui.send('chatMessage', message)
    end)

    RegisterNUICallback('chatSend', function(data, cb)
        Chat.submit(data.text)
        cb({})
    end)
    RegisterNUICallback('chatClose', function(_, cb)
        Chat.closeInput()
        cb({})
    end)
end

---@return boolean on est dans un mode, sans autre écran au premier plan
function Chat.canOpen()
    return State.mode ~= nil and not State.menuOpen
end

function Chat.openInput()
    if Chat.open or not Chat.canOpen() then return end
    Chat.open = true
    -- Clavier pour l'interface, sans curseur de souris
    SetNuiFocus(true, false)
    Nui.send('chat', { open = true, commands = Chat.describeCommands() })
    Chat.refreshPlayers()
end

---Commandes visibles par ce joueur, traduites pour l'interface.
---@return table[]
function Chat.describeCommands()
    local list = {}
    for _, command in ipairs(Config.ChatCommands) do
        if (not command.admin or Admin.isAdmin) and (not command.mode or command.mode == State.mode) then
            list[#list + 1] = {
                name = command.name,
                description = Locale.t(command.description),
                admin = command.admin == true,
                args = Chat.describeArgs(command.args),
            }
        end
    end
    return list
end

---@param args table[]|nil
---@return table[]
function Chat.describeArgs(args)
    local list = {}
    for _, arg in ipairs(args or {}) do
        list[#list + 1] = {
            label = Locale.t(arg.label),
            required = arg.required == true,
            hint = Locale.t(arg.hint),
            players = arg.players == true,
            values = Chat.describeValues(arg.values),
        }
    end
    return list
end

---@param values table[]|'languages'|nil
---@return { value: string, label: string }[]
function Chat.describeValues(values)
    local list = {}
    if values == 'languages' then
        for _, language in ipairs(Config.Locale.languages) do
            list[#list + 1] = { value = language.id, label = language.label }
        end
        return list
    end
    for _, entry in ipairs(values or {}) do
        list[#list + 1] = { value = entry.value, label = Locale.t(entry.label) }
    end
    return list
end

---Liste des joueurs du mode, redemandée au plus toutes les PLAYERS_REFRESH ms.
function Chat.refreshPlayers()
    local now = GetGameTimer()
    if Chat.playersFetchedAt and now - Chat.playersFetchedAt < Chat.PLAYERS_REFRESH then return end
    Chat.playersFetchedAt = now
    CreateThread(function()
        Nui.send('chatPlayers', { players = Callback.await(Events.callbacks.chatPlayers) or {} })
    end)
end

function Chat.closeInput()
    if not Chat.open then return end
    Chat.open = false
    SetNuiFocus(false, false)
    Nui.send('chat', { open = false })
end

---@param text any
function Chat.submit(text)
    Chat.closeInput()
    if type(text) ~= 'string' then return end
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return end

    if text:sub(1, 1) == '/' then
        -- Les commandes inconnues du client sont transmises au serveur par FiveM
        ExecuteCommand(text:sub(2))
    else
        TriggerServerEvent(Events.server.chatSend, text)
    end
end
