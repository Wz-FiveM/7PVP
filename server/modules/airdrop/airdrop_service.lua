---Largages aériens : à intervalle régulier, une caisse tombe à un point de Config.Airdrops.
---Elle est annoncée à tous les joueurs PvP puis, une fois ouverte, devient un butin au sol
---(voir LootService) qui s'ouvre comme un inventaire : on y prend les objets à la main.
---@class Airdrop
---@field id integer
---@field coords vector3
---@field landAt integer os.time() de l'atterrissage
---@field unlockAt integer os.time() de l'ouverture

---@class AirdropServiceModule
local AirdropService = PVP.define('AirdropService')
local LootService = PVP.use('LootService')
local ModeRegistry = PVP.use('ModeRegistry')
local ChatService = PVP.use('ChatService')
local Utils = PVP.use('Utils')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')

---@type table<integer, Airdrop>
AirdropService.drops = {}
AirdropService.nextId = 0

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
    local drop = {
        id = AirdropService.nextId,
        coords = coords or Utils.pick(Config.Airdrops.locations),
        landAt = now + Config.Airdrops.fallTime,
        unlockAt = now + Config.Airdrops.fallTime + Config.Airdrops.unlockDelay,
    }
    AirdropService.drops[drop.id] = drop

    TriggerClientEvent(Events.client.airdropSpawn, -1, AirdropService.describe(drop))
    ChatService.announce('pvp', 'Largage aérien en approche ! Repère jaune sur la carte.')
    ModeRegistry.broadcast('pvp', Events.client.notify, 'Largage aérien en approche : repère jaune sur la carte.', 'info')
    Logger.info('[largage] n°%d en approche (%.0f, %.0f)', drop.id, drop.coords.x, drop.coords.y)

    SetTimeout((drop.unlockAt - now) * 1000, function()
        AirdropService.open(drop.id)
    end)
    return drop
end

---La caisse s'ouvre : elle est remplacée par un butin au sol, au même endroit.
---@param id integer
function AirdropService.open(id)
    local drop = AirdropService.drops[id]
    if not drop then return end
    AirdropService.drops[id] = nil
    TriggerClientEvent(Events.client.airdropRemove, -1, id)

    LootService.drop(drop.coords, LootService.roll(Config.Airdrops.loot), {
        model = Config.Airdrops.model,
        label = 'Fouiller le largage',
        kind = 'airdrop',
        solid = true,
        lifetime = Config.Airdrops.lifetime,
        -- Ouvert comme un inventaire : chacun prend ce qu'il veut, à la main
        browse = true,
        title = 'Largage',
    })
    ChatService.announce('pvp', 'Le largage aérien est ouvert !')
end

---Données envoyées aux clients : durées restantes plutôt que des dates (horloges différentes).
---@param drop Airdrop
---@return table
function AirdropService.describe(drop)
    local now = os.time()
    return {
        id = drop.id,
        coords = drop.coords,
        landIn = math.max(0, drop.landAt - now),
        unlockIn = math.max(0, drop.unlockAt - now),
    }
end

---@param source integer
function AirdropService.syncTo(source)
    for _, drop in pairs(AirdropService.drops) do
        TriggerClientEvent(Events.client.airdropSpawn, source, AirdropService.describe(drop))
    end
end
