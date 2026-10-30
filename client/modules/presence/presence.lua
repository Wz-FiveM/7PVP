---Discord Rich Presence (Config.Presence) : mode de jeu, zone ou mode du Freeroam, nombre de joueurs.
---Ne fait que lire l'état local (State) : aucun autre module n'a besoin de le prévenir.
---@class PresenceModule
local Presence = PVP.define('Presence')
local State = PVP.use('State')

Presence.STATE_KEY = '7pvp:players' -- publié par server/modules/presence
Presence.last = nil

function Presence.init()
    local config = Config.Presence
    if not config.enabled or config.appId == '' then return end

    SetDiscordAppId(config.appId)
    SetDiscordRichPresenceAsset(config.largeImage)
    for index, button in ipairs(config.buttons) do
        if index > 2 then break end
        SetDiscordRichPresenceAction(index - 1, button.label, button.url)
    end
    CreateThread(Presence.loop)
end

function Presence.loop()
    while true do
        Presence.update()
        Wait(Config.Presence.interval)
    end
end

---@return string
function Presence.status()
    local config = Config.Presence
    if State.mode == 'pvp' then
        if State.dead then return config.pvp .. ' · ' .. config.dead end
        local zone = type(State.zone) == 'table' and State.zone.label or config.pvpFree
        return config.pvp .. ' · ' .. zone
    end
    if State.mode == 'freeroam' then
        local activity = State.activity and Config.FreeroamActivities[State.activity]
        if activity then return config.freeroam .. ' · ' .. activity.label end
        return config.freeroam
    end
    if State.mode == 'cod' then return config.cod end
    return config.lobby
end

function Presence.update()
    local config = Config.Presence
    local text = Presence.status()
    local players = GlobalState[Presence.STATE_KEY]
    if type(players) == 'table' then
        text = text .. ' · ' .. config.players:format(players.count, players.max)
    end

    local player = State.player
    local largeText = config.largeText
    if player and player.level then
        largeText = ('Niveau %d · %d kills'):format(player.level, player.kills or 0)
    end

    local key = text .. '|' .. largeText
    if key == Presence.last then return end
    Presence.last = key
    SetRichPresence(text)
    SetDiscordRichPresenceAssetText(largeText)
end
