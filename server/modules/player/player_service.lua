---Cycle de vie des joueurs : chargement, cache, sauvegarde.
---@class PlayerServiceModule
local PlayerService = PVP.define('PlayerService')
local PlayerObject = PVP.use('PlayerObject')
local PlayerRepository = PVP.use('PlayerRepository')
local InventoryObject = PVP.use('InventoryObject')
local LootService = PVP.use('LootService')
local AppearanceService = PVP.use('AppearanceService')
local LobbyService = PVP.use('LobbyService')
local Events = PVP.use('Events')
local Logger = PVP.use('Logger')

---@type table<integer, PvpPlayer>
PlayerService.players = {}

function PlayerService.init()
    RegisterNetEvent(Events.server.ready, function()
        PlayerService.onReady(source)
    end)

    RegisterNetEvent(Events.server.ammoUsed, function(seq, report)
        PlayerService.onAmmoUsed(source, seq, report)
    end)

    AddEventHandler('playerDropped', function()
        PlayerService.unload(source)
    end)

    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
            PlayerService.saveAll()
        end
    end)

    CreateThread(PlayerService.autoSaveLoop)
end

---@param source integer|string
---@return PvpPlayer|nil
function PlayerService.get(source)
    return PlayerService.players[tonumber(source)]
end

---@return table<integer, PvpPlayer>
function PlayerService.all()
    return PlayerService.players
end

---@param source integer
---@return PvpPlayer|nil
function PlayerService.load(source)
    local identifier = GetPlayerIdentifierByType(source, 'license')
    if not identifier then
        DropPlayer(source, 'Licence Rockstar introuvable.')
        return nil
    end

    local row = PlayerRepository.find(identifier)
    if not row then
        local inventory = InventoryObject.fromKit(Config.NewPlayerKit):encode()
        PlayerRepository.create(identifier, GetPlayerName(source), inventory)
        row = { xp = 0, kills = 0, deaths = 0, npc_kills = 0, inventory = inventory }
        Logger.info('Nouveau joueur : %s', GetPlayerName(source))
    end

    local player = PlayerObject.new(source, identifier, row)
    PlayerService.players[source] = player
    return player
end

---@param source integer
function PlayerService.unload(source)
    local player = PlayerService.get(source)
    if not player then return end
    PlayerRepository.save(player)
    PlayerService.players[player.source] = nil
end

function PlayerService.saveAll()
    for _, player in pairs(PlayerService.players) do
        PlayerRepository.save(player)
    end
end

function PlayerService.autoSaveLoop()
    while true do
        Wait(Config.AutoSaveInterval * 1000)
        PlayerService.saveAll()
    end
end

---@param source integer
function PlayerService.onReady(source)
    local player = PlayerService.get(source) or PlayerService.load(source)
    if not player then return end
    LootService.syncTo(source)

    -- Premier passage : le joueur crée son personnage, puis choisit son mode au lobby
    if player.appearance then
        LobbyService.open(player)
    else
        AppearanceService.startCreator(player)
    end
end

---@param source integer
---@param seq integer
---@param report table<string, number> munitions tirées par objet de munitions
function PlayerService.onAmmoUsed(source, seq, report)
    local player = PlayerService.get(source)
    if player and player:consumeAmmo(seq, report) then
        player:sync()
    end
end
