---Chat vocal : décide qui parle à qui selon le mode de jeu (voir config/voice.lua). Le client applique ces règles.
---Relu à intervalle régulier : aucun autre module n'a besoin de prévenir d'un changement de mode ou d'équipe.
---@class VoiceServiceModule
local VoiceService = PVP.define('VoiceService')
local PlayerService = PVP.use('PlayerService')
local CodService = PVP.use('CodService')
local Events = PVP.use('Events')

VoiceService.INTERVAL = 1000 -- ms
VoiceService.MAX_CHANNEL = 2048
VoiceService.STATE_KEY = 'voiceChannel' -- lu par client/modules/voice

---@type table<integer, integer> [canal Mumble] = server id
VoiceService.channels = {}
---@type table<integer, string> [server id] = dernières règles envoyées
VoiceService.sent = {}

function VoiceService.init()
    -- Son du jeu (3D, écho) : mêmes réglages que pma-voice, sauf si server.cfg en choisit d'autres
    if GetConvar('voice_useNativeAudio', 'not-set') == 'not-set' and GetConvar('voice_use3dAudio', 'not-set') == 'not-set'
        and GetConvar('voice_use2dAudio', 'not-set') == 'not-set' then
        SetConvarReplicated('voice_useNativeAudio', 'true')
    end

    for _, id in ipairs(GetPlayers()) do
        VoiceService.assignChannel(tonumber(id))
    end
    AddEventHandler('playerJoining', function()
        VoiceService.assignChannel(tonumber(source))
    end)
    AddEventHandler('playerDropped', function()
        VoiceService.release(tonumber(source))
    end)
    CreateThread(VoiceService.loop)
end

---Chaque joueur a son canal : les autres l'y ajoutent à leur cible quand il est à portée.
---@param source integer
function VoiceService.assignChannel(source)
    for channel = 1, VoiceService.MAX_CHANNEL do
        if not VoiceService.channels[channel] then
            VoiceService.channels[channel] = source
            Player(source).state:set(VoiceService.STATE_KEY, channel, true)
            return
        end
    end
end

---@param source integer
function VoiceService.release(source)
    VoiceService.sent[source] = nil
    for channel, owner in pairs(VoiceService.channels) do
        if owner == source then
            VoiceService.channels[channel] = nil
            return
        end
    end
end

---@param source integer
---@param match table
---@return { id: integer, name: string }[] coéquipiers dans la partie
function VoiceService.matesOf(source, match)
    local mates = {}
    local team = match.stats[source].team
    for _, other in ipairs(match.players) do
        local stats = match.stats[other]
        if other ~= source and stats and stats.team == team then
            mates[#mates + 1] = { id = other, name = stats.name }
        end
    end
    return mates
end

---@param source integer
---@param player PvpPlayer
---@return { proximity: boolean, mates: { id: integer, name: string }[] }
function VoiceService.rulesOf(source, player)
    if not player.mode then return { proximity = false, mates = {} } end
    if player.mode ~= 'cod' then return { proximity = true, mates = {} } end

    local match = CodService.matchOf(source)
    if not match or not match.stats[source] then return { proximity = false, mates = {} } end
    if not match.playlist.teams then return { proximity = true, mates = {} } end
    -- Warzone : proximité avec les joueurs hors de l'escouade
    return { proximity = match.playlist.warzone ~= nil, mates = VoiceService.matesOf(source, match) }
end

---@param rules table
---@return string
function VoiceService.keyOf(rules)
    local parts = { tostring(rules.proximity) }
    for _, mate in ipairs(rules.mates) do parts[#parts + 1] = mate.id end
    return table.concat(parts, ',')
end

function VoiceService.loop()
    while true do
        Wait(VoiceService.INTERVAL)
        for source, player in pairs(PlayerService.all()) do
            local rules = VoiceService.rulesOf(source, player)
            local key = VoiceService.keyOf(rules)
            if VoiceService.sent[source] ~= key then
                VoiceService.sent[source] = key
                TriggerClientEvent(Events.client.voiceRules, source, rules)
            end
        end
    end
end
