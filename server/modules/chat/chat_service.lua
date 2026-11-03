---Chat : un salon par mode de jeu (les joueurs du PvP ne parlent qu'entre eux).
---Les commandes (/lobby...) sont exécutées côté client et ne passent pas par ici.
---@class ChatServiceModule
local ChatService = PVP.define('ChatService')
local AchievementService = PVP.use('AchievementService')
local PlayerService = PVP.use('PlayerService')
local ModeRegistry = PVP.use('ModeRegistry')
local DiscordService = PVP.use('DiscordService')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')
local Callback = PVP.use('Callback')
local CrewService = PVP.use('CrewService')

---@type table<integer, integer> dernier message de chaque joueur (GetGameTimer)
ChatService.lastSent = {}

function ChatService.init()
    RegisterNetEvent(Events.server.chatSend, function(text)
        ChatService.onMessage(source, text)
    end)

    Callback.register(Events.callbacks.chatPlayers, ChatService.listPlayers)

    AddEventHandler(Events.internal.playerUnloading, function(playerSource, name, mode)
        ChatService.onPlayerLeft(playerSource, name, mode)
    end)
end

---@param source integer
---@param name string
---@param mode string|nil
function ChatService.onPlayerLeft(source, name, mode)
    ChatService.lastSent[source] = nil
    if mode and Config.Chat.announceJoins then
        ChatService.announce(mode, Locale.t('%s s\'est déconnecté.', name))
    end
end

---Nettoie un message : texte uniquement, sans caractères de contrôle, longueur limitée.
---@param text any
---@param maxLength? integer longueur en caractères (défaut : celle du chat)
---@return string|nil
function ChatService.sanitize(text, maxLength)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' or not utf8.len(text) then return nil end

    -- Coupe en caractères (UTF-8), pas en octets, pour ne pas casser un accent
    maxLength = maxLength or Config.Chat.maxLength
    if utf8.len(text) > maxLength then
        text = text:sub(1, utf8.offset(text, maxLength + 1) - 1)
    end
    return text
end

---@param source integer
---@param text any
function ChatService.onMessage(source, text)
    local player = PlayerService.get(source)
    if not player or not player.mode then return end

    local now = GetGameTimer()
    if now - (ChatService.lastSent[source] or 0) < Config.Chat.cooldown then
        return ChatService.system(source, Locale.t('Doucement : un message par seconde.'))
    end

    local clean = ChatService.sanitize(text)
    if not clean then return end
    ChatService.lastSent[source] = now

    ChatService.broadcast(player.mode, {
        kind = 'player',
        author = AchievementService.chatName(player),
        -- Pour colorer le nom à la fin de `author`, sans le titre ni le label du crew
        name = player.name,
        colors = player.mode == 'pvp' and player.nameColor or nil,
        text = clean,
    })
    Logger.info('[chat:%s] %s : %s', player.mode, player.name, clean)
    DiscordService.chat(player, clean)
end

---Joueurs proposés par les suggestions du chat : ceux du même mode, sans le demandeur.
---@param source integer
---@return { id: integer, name: string, crew: string|nil }[]
function ChatService.listPlayers(source)
    local player = PlayerService.get(source)
    if not player or not player.mode then return {} end

    local list = {}
    for _, id in ipairs(ModeRegistry.getPlayers(player.mode)) do
        local other = PlayerService.get(id)
        if other and id ~= source then
            list[#list + 1] = {
                id = other.charId,
                name = other.name,
                -- Le label du crew ne s'affiche qu'en PvP (voir PlayerObject:displayName)
                crew = other.mode == 'pvp' and CrewService.memberOf[other.identifier] or nil,
            }
        end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

---Envoie un message à tous les joueurs d'un mode.
---@param mode string
---@param message { kind: 'player'|'system', author?: string, text: string|table }
function ChatService.broadcast(mode, message)
    message.time = os.time()
    ModeRegistry.broadcast(mode, Events.client.chatMessage, message)
end

---Message système à un joueur.
---@param source integer
---@param text string|table texte ou message à traduire (Locale.t)
function ChatService.system(source, text)
    TriggerClientEvent(Events.client.chatMessage, source, { kind = 'system', text = text, time = os.time() })
end

---Message système à tous les joueurs d'un mode.
---@param mode string
---@param text string|table texte ou message à traduire (Locale.t)
function ChatService.announce(mode, text)
    ChatService.broadcast(mode, { kind = 'system', text = text })
end
