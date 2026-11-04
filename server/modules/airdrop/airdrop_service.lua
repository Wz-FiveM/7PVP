---Largages aériens : à intervalle régulier, un avion traverse la carte et largue une caisse
---au-dessus d'un point de Config.Airdrops ; elle descend en parachute.
---Posée, elle se capture comme une zone de domination (Config.Airdrops.capture) : un camp (un groupe,
---ou un joueur seul) l'ouvre en restant dans le cercle sans adversaire. Ouverte, elle devient un butin
---au sol (voir LootService) qui s'ouvre comme un inventaire : on y prend les objets à la main.
---@class Airdrop
---@field id integer
---@field coords vector3
---@field heading number cap de l'avion (degrés, convention GTA)
---@field releaseAt integer os.time() du largage (avion au-dessus du point)
---@field landAt integer os.time() de l'atterrissage
---@field unlockAt integer os.time() de l'ouverture au plus tôt (capture sans interruption)
---@field capturer string|nil camp qui capture ('g:<groupe>' ou 'p:<server id>', comme ControlService)
---@field progress number 0 à 1
---@field contested boolean
---@field sent string dernier état de capture envoyé

---@class AirdropServiceModule
local AirdropService = PVP.define('AirdropService')
local LootService = PVP.use('LootService')
local ModeRegistry = PVP.use('ModeRegistry')
local ChatService = PVP.use('ChatService')
local PlayerService = PVP.use('PlayerService')
local GroupService = PVP.use('GroupService')
local ControlService = PVP.use('ControlService')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

AirdropService.CAPTURE_TICK = 1000
-- Une somme de pas (1/90 x 90) n'arrive pas tout à fait à 1
AirdropService.CAPTURE_EPSILON = 1e-6

---@type table<integer, Airdrop>
AirdropService.drops = {}
AirdropService.nextId = 0
---@type integer|nil index dans Config.Airdrops.locations du dernier point tiré au sort
AirdropService.lastLocation = nil

---Point de chute au hasard parmi Config.Airdrops.locations, jamais le même que le précédent.
---@return vector3
function AirdropService.pickLocation()
    local locations = Config.Airdrops.locations
    local index = math.random(#locations)
    if #locations > 1 and index == AirdropService.lastLocation then
        -- Tirage parmi les autres points : on saute le précédent
        index = math.random(#locations - 1)
        if index >= AirdropService.lastLocation then index = index + 1 end
    end
    AirdropService.lastLocation = index
    return locations[index]
end

function AirdropService.init()
    -- Les joueurs qui arrivent voient les largages déjà en cours
    RegisterNetEvent(Events.server.ready, function()
        AirdropService.syncTo(source)
    end)

    if Config.Airdrops.enabled then
        CreateThread(AirdropService.loop)
    end
end

function AirdropService.loop()
    Wait(Config.Airdrops.firstDelay * 1000)
    while true do
        if ModeRegistry.countPlayers('pvp') >= Config.Airdrops.minPlayers then
            AirdropService.spawn()
        end
        Wait(Config.Airdrops.interval * 1000)
    end
end

---@param coords? vector3 point imposé (admin), sinon un point de la config au hasard
---@return Airdrop
function AirdropService.spawn(coords)
    AirdropService.nextId = AirdropService.nextId + 1
    local now = os.time()
    local plane = Config.Airdrops.plane
    -- L'avion arrive d'une direction au hasard et passe au-dessus du point de chute
    local releaseAt = now + math.ceil(plane.approach / plane.speed)
    local drop = {
        id = AirdropService.nextId,
        coords = coords or AirdropService.pickLocation(),
        heading = math.random(0, 359) + 0.0,
        releaseAt = releaseAt,
        landAt = releaseAt + Config.Airdrops.fallTime,
        unlockAt = releaseAt + Config.Airdrops.fallTime + Config.Airdrops.capture.time,
        capturer = nil,
        progress = 0,
        contested = false,
        sent = '',
    }
    AirdropService.drops[drop.id] = drop

    TriggerClientEvent(Events.client.airdropSpawn, -1, AirdropService.describe(drop))
    ChatService.announce('pvp', Locale.t('Un avion de largage traverse la carte ! Suis son repère jaune.'))
    ModeRegistry.broadcast('pvp', Events.client.notify, Locale.t('Avion de largage en approche : suis son repère sur la carte.'), 'info')
    Logger.info('[largage] n°%d en approche (%.0f, %.0f)', drop.id, drop.coords.x, drop.coords.y)

    SetTimeout((drop.releaseAt - now) * 1000, function()
        if AirdropService.drops[drop.id] then ChatService.announce('pvp', Locale.t('La caisse est larguée !')) end
    end)
    SetTimeout((drop.landAt - now) * 1000, function()
        if AirdropService.drops[drop.id] == drop then
            ChatService.announce('pvp', Locale.t('Le largage est au sol : tiens le cercle %d s pour l\'ouvrir.', Config.Airdrops.capture.time))
            AirdropService.watchCapture(drop)
        end
    end)
    return drop
end

-- ---------------------------------------------------------------------------
-- Capture
-- ---------------------------------------------------------------------------

---@param drop Airdrop
function AirdropService.watchCapture(drop)
    local timeoutAt = os.time() + Config.Airdrops.capture.timeout
    while AirdropService.drops[drop.id] == drop do
        -- Personne n'est venu la prendre : le butin n'est pas perdu
        if os.time() >= timeoutAt then return AirdropService.open(drop.id) end
        AirdropService.tickCapture(drop)
        if drop.progress >= 1 then return end
        Wait(AirdropService.CAPTURE_TICK)
    end
end

---@param player PvpPlayer
---@return string camp du joueur : son groupe, sinon lui seul (comme une zone de contrôle)
function AirdropService.teamOf(player)
    local group = GroupService.getGroupOf(player.source)
    return group and ('g:' .. group.id) or ('p:' .. player.source)
end

---@param drop Airdrop
---@return table<string, PvpPlayer> camp -> un de ses joueurs vivants dans le cercle
function AirdropService.teamsInside(drop)
    local teams = {}
    for _, player in pairs(PlayerService.all()) do
        if player.mode == 'pvp' and not player.dead and #(player:getCoords().xy - drop.coords.xy) <= Config.Airdrops.capture.radius then
            teams[AirdropService.teamOf(player)] = player
        end
    end
    return teams
end

---Même règle qu'une zone de contrôle : seul dans le cercle, la capture monte ; plusieurs camps, elle est figée ;
---personne, elle retombe. Un autre camp doit d'abord faire retomber la capture entamée.
---@param drop Airdrop
function AirdropService.tickCapture(drop)
    local settings = Config.Airdrops.capture
    local step = AirdropService.CAPTURE_TICK / 1000 / settings.time
    local count, team, member = 0, nil, nil
    for key, player in pairs(AirdropService.teamsInside(drop)) do
        count = count + 1
        team, member = key, player
    end

    drop.contested = count > 1
    if count == 1 then
        if drop.capturer and drop.capturer ~= team then
            drop.progress = math.max(0, drop.progress - step)
            if drop.progress == 0 then drop.capturer = team end
        else
            drop.capturer = team
            drop.progress = math.min(1, drop.progress + step + AirdropService.CAPTURE_EPSILON)
        end
    elseif count == 0 and drop.progress > 0 then
        drop.progress = math.max(0, drop.progress - step * settings.decay)
    end
    if drop.progress == 0 and count == 0 then drop.capturer = nil end

    if drop.progress >= 1 then
        return AirdropService.open(drop.id, ControlService.teamLabel(team, member))
    end
    AirdropService.sendCapture(drop)
end

---Avancement de la capture, envoyé aux joueurs PvP quand il change.
---@param drop Airdrop
function AirdropService.sendCapture(drop)
    local state = { id = drop.id, capturer = drop.capturer or false, progress = math.floor(drop.progress * 100) / 100, contested = drop.contested }
    local key = json.encode(state)
    if key == drop.sent then return end
    drop.sent = key
    ModeRegistry.broadcast('pvp', Events.client.airdropCapture, state)
end

---La caisse s'ouvre : elle est remplacée par un butin au sol, au même endroit.
---@param id integer
---@param winner? string|table camp qui l'a capturée (nom, ou message à traduire)
function AirdropService.open(id, winner)
    local drop = AirdropService.drops[id]
    if not drop then return end
    AirdropService.drops[id] = nil
    TriggerClientEvent(Events.client.airdropRemove, -1, id)

    LootService.drop(drop.coords, LootService.roll(Config.Airdrops.loot), {
        model = Config.Airdrops.model,
        label = Locale.t('Fouiller le largage'),
        kind = 'airdrop',
        solid = true,
        lifetime = Config.Airdrops.lifetime,
        -- Ouvert comme un inventaire : chacun prend ce qu'il veut, à la main
        browse = true,
        title = Locale.t('Largage'),
    })
    if winner then
        ChatService.announce('pvp', Locale.t('%s a capturé le largage aérien !', winner))
    else
        ChatService.announce('pvp', Locale.t('Le largage aérien est ouvert !'))
    end
end

---Données envoyées aux clients : durées restantes plutôt que des dates (horloges différentes).
---@param drop Airdrop
---@return table
function AirdropService.describe(drop)
    local now = os.time()
    return {
        id = drop.id,
        coords = drop.coords,
        heading = drop.heading,
        releaseIn = drop.releaseAt - now,
        landIn = math.max(0, drop.landAt - now),
        unlockIn = math.max(0, drop.unlockAt - now),
        unlockDelay = Config.Airdrops.capture.time,
        captureRadius = Config.Airdrops.capture.radius,
        capture = { capturer = drop.capturer or false, progress = drop.progress, contested = drop.contested },
    }
end

---@param source integer
function AirdropService.syncTo(source)
    for _, drop in pairs(AirdropService.drops) do
        TriggerClientEvent(Events.client.airdropSpawn, source, AirdropService.describe(drop))
    end
end
