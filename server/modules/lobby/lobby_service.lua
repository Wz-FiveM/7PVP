---Lobby : écran de choix du mode à l'arrivée, et retour au lobby depuis un mode.
---@class LobbyServiceModule
local LobbyService = PVP.define('LobbyService')
local PlayerService = PVP.use('PlayerService')
local ModeRegistry = PVP.use('ModeRegistry')
local WorldService = PVP.use('WorldService')
local ChatService = PVP.use('ChatService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

-- Chaque joueur au lobby est seul dans son bucket
LobbyService.BUCKET_OFFSET = 3000

function LobbyService.init()
    Callback.register(Events.callbacks.joinMode, LobbyService.join)
    Callback.register(Events.callbacks.leaveMode, LobbyService.leave)
end

---@param player PvpPlayer
function LobbyService.open(player)
    player.mode = nil
    local bucket = LobbyService.BUCKET_OFFSET + player.source
    WorldService.setupBucket(bucket)
    SetPlayerRoutingBucket(player.source, bucket)
    TriggerClientEvent(Events.client.openLobby, player.source, ModeRegistry.describe())
end

---@param source integer
---@param modeId string
---@return { ok: boolean, message?: string }
function LobbyService.join(source, modeId)
    local player = PlayerService.get(source)
    if not player or player.creating then return { ok = false } end
    if player.mode then
        return { ok = false, message = Locale.t('Tu es déjà dans un mode.') }
    end
    if not ModeRegistry.isAvailable(modeId) then
        return { ok = false, message = Locale.t('Ce mode n\'est pas encore disponible.') }
    end

    local config = ModeRegistry.getConfig(modeId)
    player.mode = modeId
    SetPlayerRoutingBucket(source, config.bucket)
    ModeRegistry.get(modeId).enter(player)
    if Config.Chat.announceJoins then
        ChatService.announce(modeId, Locale.t('%s a rejoint le %s.', player.name, Locale.t(config.label)))
    end
    return { ok = true, mode = modeId }
end

---@param source integer
---@return { ok: boolean, message?: string }
function LobbyService.leave(source)
    local player = PlayerService.get(source)
    if not player or not player.mode then return { ok = false } end

    local mode = ModeRegistry.get(player.mode)
    if mode.canLeave then
        local allowed, message = mode.canLeave(player)
        if not allowed then return { ok = false, message = message } end
    end

    local modeId = player.mode
    mode.leave(player)
    LobbyService.open(player)
    if Config.Chat.announceJoins then
        ChatService.announce(modeId, Locale.t('%s est retourné au lobby.', player.name))
    end
    return { ok = true }
end
