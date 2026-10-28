---Hordes : une zone PvE occupée par des joueurs est envahie pendant Config.Hordes.duration
---secondes (plus de zombies, réapparition immédiate). Les joueurs encore en vie dans la
---zone à la fin touchent une récompense.
---@class HordeServiceModule
local HordeService = PVP.define('HordeService')
local PveService = PVP.use('PveService')
local PlayerService = PVP.use('PlayerService')
local ModeRegistry = PVP.use('ModeRegistry')
local ChatService = PVP.use('ChatService')
local Utils = PVP.use('Utils')
local Logger = PVP.use('Logger')
local ContractService = PVP.use('ContractService')
local Events = PVP.use('Events')

-- Le compteur de kills n'est renvoyé aux joueurs qu'une fois par seconde au plus
HordeService.SYNC_INTERVAL = 1000

---@type PveZone|nil
HordeService.active = nil
HordeService.lastSync = 0
HordeService.lastKills = -1

function HordeService.init()
    RegisterNetEvent(Events.server.ready, function()
        TriggerClientEvent(Events.client.hordeState, source, HordeService.describe())
    end)
    if Config.Hordes.enabled then
        CreateThread(HordeService.loop)
    end
end

function HordeService.loop()
    Wait(Config.Hordes.firstDelay * 1000)
    while true do
        local started = HordeService.active == nil and HordeService.start()
        Wait((started and Config.Hordes.interval or Config.Hordes.retryDelay) * 1000)
    end
end

---@param zone? PveZone zone imposée (admin), sinon une zone où se trouvent des joueurs
---@return boolean horde lancée
function HordeService.start(zone)
    if HordeService.active then return false end
    zone = zone or HordeService.pickZone()
    if not zone then return false end

    zone.horde = { endsAt = GetGameTimer() + Config.Hordes.duration * 1000, kills = 0 }
    HordeService.active = zone
    HordeService.lastKills = -1
    ChatService.announce('pvp', ('Une horde envahit : %s ! Tenez %d minutes.'):format(zone.zone.label, math.floor(Config.Hordes.duration / 60)))
    ModeRegistry.broadcast('pvp', Events.client.notify, ('Horde en cours : %s'):format(zone.zone.label), 'error')
    Logger.info('[horde] %s', zone.zone.label)
    HordeService.sync(true)
    CreateThread(HordeService.watch)
    return true
end

---@return PveZone|nil zone PvE avec au moins un joueur dedans
function HordeService.pickZone()
    local candidates = {}
    for _, zone in pairs(PveService.zones) do
        if zone:hasPlayersNear(0.0) then candidates[#candidates + 1] = zone end
    end
    return #candidates > 0 and Utils.pick(candidates) or nil
end

function HordeService.watch()
    local zone = HordeService.active
    while zone and HordeService.active == zone and GetGameTimer() < zone.horde.endsAt do
        Wait(500)
        HordeService.sync(false)
    end
    if zone and HordeService.active == zone then HordeService.finish() end
end

---Fin de la horde : récompense des survivants présents dans la zone.
function HordeService.finish()
    local zone = HordeService.active
    if not zone then return end
    local kills = zone.horde.kills
    zone.horde = nil
    HordeService.active = nil

    local survivors = {}
    for _, player in pairs(PlayerService.all()) do
        if player.mode == 'pvp' and not player.dead and #(player:getCoords() - zone.zone.coords) <= zone.zone.radius then
            player:addMoney(Config.Hordes.reward.money)
            player:addXp(Config.Hordes.reward.xp)
            ContractService.track(player, 'hordeSurvive', 1)
            player:notify(('Horde repoussée : +$%d, +%d XP'):format(Config.Hordes.reward.money, Config.Hordes.reward.xp), 'success')
            player:sync()
            survivors[#survivors + 1] = player.name
        end
    end

    if #survivors > 0 then
        ChatService.announce('pvp', ('Horde repoussée à %s (%d zombies tués) par %s.'):format(zone.zone.label, kills, table.concat(survivors, ', ')))
    else
        ChatService.announce('pvp', ('La horde a submergé %s.'):format(zone.zone.label))
    end
    TriggerClientEvent(Events.client.hordeState, -1, false)
end

---@return table|false état envoyé aux clients
function HordeService.describe()
    local zone = HordeService.active
    if not zone then return false end
    return {
        zoneId = zone.zone.id,
        label = zone.zone.label,
        endsIn = math.max(0, math.ceil((zone.horde.endsAt - GetGameTimer()) / 1000)),
        kills = zone.horde.kills,
    }
end

---@param force boolean envoyer même si rien n'a changé
function HordeService.sync(force)
    local zone = HordeService.active
    if not zone then return end
    local now = GetGameTimer()
    if not force and (zone.horde.kills == HordeService.lastKills or now - HordeService.lastSync < HordeService.SYNC_INTERVAL) then
        return
    end
    HordeService.lastSync = now
    HordeService.lastKills = zone.horde.kills
    TriggerClientEvent(Events.client.hordeState, -1, HordeService.describe())
end
