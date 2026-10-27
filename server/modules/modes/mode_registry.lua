---Registre des modes de jeu (PvP, Freeroam...).
---
---Chaque mode est un module qui s'enregistre avec :
---    ModeRegistry.register('pvp', PvpMode)
---et qui définit :
---    Mode.enter(player)          -- le joueur arrive dans le mode (il est déjà dans le bucket du mode)
---    Mode.leave(player)          -- le joueur retourne au lobby
---    Mode.canLeave(player)       -- (optionnel) true, ou false + message
---La configuration (libellé, bucket, activé) vient de Config.Lobby.Modes.
---@class ModeRegistryModule
local ModeRegistry = PVP.define('ModeRegistry')
local PlayerService = PVP.use('PlayerService')

---@type table<string, table>
ModeRegistry.modes = {}

---@param id string clé de Config.Lobby.Modes
---@param handlers table module du mode
function ModeRegistry.register(id, handlers)
    ModeRegistry.modes[id] = handlers
end

---@param id string
---@return table|nil configuration du mode
function ModeRegistry.getConfig(id)
    for _, mode in ipairs(Config.Lobby.Modes) do
        if mode.id == id then return mode end
    end
    return nil
end

---@param id string
---@return table|nil handlers du mode
function ModeRegistry.get(id)
    return ModeRegistry.modes[id]
end

---@param id string
---@return boolean jouable (activé dans la config et implémenté)
function ModeRegistry.isAvailable(id)
    local config = ModeRegistry.getConfig(id)
    return config ~= nil and config.enabled and ModeRegistry.modes[id] ~= nil
end

---@param id string
---@return integer
function ModeRegistry.countPlayers(id)
    local count = 0
    for _, player in pairs(PlayerService.all()) do
        if player.mode == id then count = count + 1 end
    end
    return count
end

---@param id string
---@return integer[] server ids des joueurs dans ce mode
function ModeRegistry.getPlayers(id)
    local list = {}
    for source, player in pairs(PlayerService.all()) do
        if player.mode == id then list[#list + 1] = source end
    end
    return list
end

---Envoie un événement client à tous les joueurs d'un mode.
---@param id string
---@param event string
function ModeRegistry.broadcast(id, event, ...)
    for _, source in ipairs(ModeRegistry.getPlayers(id)) do
        TriggerClientEvent(event, source, ...)
    end
end

---Liste envoyée à l'écran du lobby.
---@return table[]
function ModeRegistry.describe()
    local list = {}
    for i, mode in ipairs(Config.Lobby.Modes) do
        list[i] = {
            id = mode.id,
            label = mode.label,
            tagline = mode.tagline,
            description = mode.description,
            enabled = ModeRegistry.isAvailable(mode.id),
            players = ModeRegistry.countPlayers(mode.id),
        }
    end
    return list
end
