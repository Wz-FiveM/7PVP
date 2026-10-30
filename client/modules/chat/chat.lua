---Chat : T ouvre la saisie (focus clavier sans curseur), Entrée envoie.
---Un message qui commence par « / » est exécuté comme une commande (/lobby...).
---@class ChatModule
local Chat = PVP.define('Chat')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Chat.open = false

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
    Nui.send('chat', { open = true })
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
