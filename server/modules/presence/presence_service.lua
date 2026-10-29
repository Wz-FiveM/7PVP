---Publie le nombre de joueurs connectés pour le Discord Rich Presence (client/modules/presence).
---Le client ne voit que les joueurs proches de lui (OneSync) : c'est le serveur qui compte.
---@class PresenceServiceModule
local PresenceService = PVP.define('PresenceService')

PresenceService.STATE_KEY = '7pvp:players'
PresenceService.INTERVAL = 10000

function PresenceService.init()
    if not Config.Presence.enabled then return end
    CreateThread(PresenceService.loop)
end

function PresenceService.loop()
    local maxPlayers = GetConvarInt('sv_maxclients', 48)
    local last = -1
    while true do
        local count = #GetPlayers()
        if count ~= last then
            last = count
            GlobalState[PresenceService.STATE_KEY] = { count = count, max = maxPlayers }
        end
        Wait(PresenceService.INTERVAL)
    end
end
