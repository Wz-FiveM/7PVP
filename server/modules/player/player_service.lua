---Cycle de vie des joueurs : chargement, cache, sauvegarde.
---@class PlayerServiceModule
local PlayerService = PVP.define('PlayerService')
local PlayerObject = PVP.use('PlayerObject')
local PlayerRepository = PVP.use('PlayerRepository')
local InventoryObject = PVP.use('InventoryObject')
local LootService = PVP.use('LootService')
local AppearanceService = PVP.use('AppearanceService')
local LobbyService = PVP.use('LobbyService')
local SeasonService = PVP.use('SeasonService')
local AntiCheatService = PVP.use('AntiCheatService')
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

    RegisterNetEvent(Events.server.uiError, function(name, message)
        PlayerService.onUiError(source, name, message)
    end)

    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
            PlayerService.saveAll()
        end
    end)

    CreateThread(PlayerService.autoSaveLoop)
end

---Une partie de l'interface d'un joueur a planté : gardé dans le journal pour la corriger.
---@param source integer
---@param name any
---@param message any
function PlayerService.onUiError(source, name, message)
    if not AntiCheatService.allow(source, 'ui') then return end
    Logger.warn('[interface] %s (ID %d) : « %s » a planté : %s', GetPlayerName(source) or '?', source,
        tostring(name):sub(1, 40), tostring(message):sub(1, 300))
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
    player.season = SeasonService.load(identifier)
    PlayerService.players[source] = player
    -- Le chargement attend la base : les modules qui ont besoin du profil (ex : statut admin)
    -- réagissent ici plutôt qu'à l'événement « ready », qui peut passer avant la fin du chargement
    TriggerEvent(Events.internal.playerLoaded, source)
    return player
end

---@param source integer
function PlayerService.unload(source)
    local player = PlayerService.get(source)
    if not player then return end
    -- Prévient les autres modules avant la sauvegarde : ils peuvent encore modifier le joueur
    -- (déconnexion en combat, kit de réapparition) ; ex : annonce dans le chat
    TriggerEvent(Events.internal.playerUnloading, player.source, player.name, player.mode)
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
