---Chat vocal : applique les règles du serveur (server/modules/voice). C'est celui qui parle qui choisit qui l'entend :
---les joueurs à portée (leur canal, recalculé en continu) et ses coéquipiers (par leur ID, à toute distance).
---GetActivePlayers ne donne que les joueurs du même bucket : les mondes séparés ne s'entendent pas.
---@class VoiceModule
local Voice = PVP.define('Voice')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Events = PVP.use('Events')

Voice.TARGET = 1
Voice.INTERVAL = 200 -- ms
Voice.JOIN_RETRY = 100 -- ms
Voice.MATES_REFRESH = 2000 -- ms : un coéquipier peut arriver sur le serveur vocal après l'envoi des règles
Voice.STATE_KEY = 'voiceChannel' -- publié par server/modules/voice
Voice.NATIVE_AUDIO_RANGE = 3 -- la voix du jeu s'atténue encore au-delà de la portée réglée
Voice.NO_OVERRIDE = -1.0

Voice.channel = nil -- canal rejoint, nil = pas encore connecté
Voice.rules = { proximity = false, mates = {} }
Voice.mateIds = {}
Voice.matesDirty = false
Voice.nextMatesRefresh = 0
Voice.lastHud = ''

function Voice.init()
    RegisterNetEvent(Events.client.voiceRules, function(rules)
        Voice.setRules(rules)
    end)
    AddEventHandler('onResourceStop', Voice.onResourceStop)
    CreateThread(Voice.loop)
end

---@param rules { proximity: boolean, mates: { id: integer, name: string }[] }
function Voice.setRules(rules)
    local ids = {}
    for _, mate in ipairs(rules.mates) do ids[mate.id] = true end
    for id in pairs(Voice.mateIds) do
        if not ids[id] then MumbleSetVolumeOverrideByServerId(id, Voice.NO_OVERRIDE) end
    end
    Voice.rules = rules
    Voice.mateIds = ids
    Voice.matesDirty = true
end

function Voice.loop()
    while true do
        if MumbleIsConnected() then
            local channel = LocalPlayer.state[Voice.STATE_KEY]
            if channel and channel ~= Voice.channel then Voice.join(channel) end
            Voice.update()
        else
            Voice.channel = nil
        end
        Wait(Voice.INTERVAL)
    end
end

---Rejoint son canal (aussi après une coupure du serveur vocal ou un redémarrage de la ressource).
---@param channel integer
function Voice.join(channel)
    MumbleSetTalkerProximity(Config.Voice.range + 0.0)
    MumbleClearVoiceTarget(Voice.TARGET)
    MumbleSetVoiceTarget(Voice.TARGET)
    MumbleSetVoiceChannel(channel)
    local serverId = GetPlayerServerId(PlayerId())
    while MumbleIsConnected() and MumbleGetVoiceChannelFromServerId(serverId) ~= channel do
        Wait(Voice.JOIN_RETRY)
        MumbleSetVoiceChannel(channel)
    end
    Voice.channel = channel
    Voice.matesDirty = true
end

function Voice.update()
    if not Voice.channel then return end
    Voice.refreshMates()
    Voice.refreshNearby()
    Voice.updateHud()
end

---@return boolean le joueur peut parler à quelqu'un (un admin en spectateur n'est entendu de personne)
function Voice.canSpeak()
    return not State.spectating and (Voice.rules.proximity or #Voice.rules.mates > 0)
end

function Voice.refreshMates()
    local now = GetGameTimer()
    if not Voice.matesDirty and now < Voice.nextMatesRefresh then return end
    Voice.matesDirty = false
    Voice.nextMatesRefresh = now + Voice.MATES_REFRESH

    MumbleClearVoiceTargetPlayers(Voice.TARGET)
    for _, mate in ipairs(Voice.rules.mates) do
        if not State.spectating then MumbleAddVoiceTargetPlayerByServerId(Voice.TARGET, mate.id) end
        MumbleSetVolumeOverrideByServerId(mate.id, Config.Voice.teamVolume + 0.0)
    end
end

function Voice.refreshNearby()
    MumbleClearVoiceTargetChannels(Voice.TARGET)
    if not Voice.canSpeak() then return end
    MumbleAddVoiceChannelListen(Voice.channel)
    MumbleAddVoiceTargetChannel(Voice.TARGET, Voice.channel)
    if not Voice.rules.proximity then return end

    local coords = GetEntityCoords(PlayerPedId())
    local range = Config.Voice.range * Voice.NATIVE_AUDIO_RANGE
    local self = PlayerId()
    for _, player in ipairs(GetActivePlayers()) do
        local serverId = GetPlayerServerId(player)
        local ped = GetPlayerPed(player)
        if player ~= self and not Voice.mateIds[serverId] and ped ~= 0 and #(coords - GetEntityCoords(ped)) < range then
            local channel = MumbleGetVoiceChannelFromServerId(serverId)
            if channel ~= -1 then MumbleAddVoiceTargetChannel(Voice.TARGET, channel) end
        end
    end
end

---@param player integer
---@return boolean
function Voice.isTalking(player)
    local talking = MumbleIsPlayerTalking(player)
    return talking == true or talking == 1
end

---Micro du joueur et coéquipiers qui parlent. Un coéquipier trop loin pour être chargé s'entend mais n'est pas affiché.
function Voice.updateHud()
    local speakers = {}
    for _, mate in ipairs(Voice.rules.mates) do
        local player = GetPlayerFromServerId(mate.id)
        if player ~= -1 and Voice.isTalking(player) then speakers[#speakers + 1] = mate.name end
    end
    local talking = Voice.canSpeak() and Voice.isTalking(PlayerId())
    local key = ('%s|%s|%d|%s'):format(talking, Voice.rules.proximity, #Voice.rules.mates, table.concat(speakers, ','))
    if key == Voice.lastHud then return end
    Voice.lastHud = key
    Nui.send('voice', {
        talking = talking,
        proximity = Voice.rules.proximity,
        team = #Voice.rules.mates > 0,
        speakers = speakers,
    })
end

---Le volume des coéquipiers survivrait à l'arrêt de la ressource.
---@param resource string
function Voice.onResourceStop(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(Voice.mateIds) do
        MumbleSetVolumeOverrideByServerId(id, Voice.NO_OVERRIDE)
    end
end
