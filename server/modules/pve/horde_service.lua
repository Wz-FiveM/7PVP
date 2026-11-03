---Hordes : une zone PvE occupée par des joueurs est envahie pendant Config.Hordes.duration
---secondes (plus de zombies, réapparition immédiate), puis un mini boss arrive (Config.Hordes.boss)
---et la horde continue autour de lui. Les joueurs encore en vie dans la zone à la fin touchent
---une récompense, et celle du boss en plus s'il est tombé à temps.
---@class HordeServiceModule
local HordeService = PVP.define('HordeService')
local PveService = PVP.use('PveService')
local PlayerService = PVP.use('PlayerService')
local ModeRegistry = PVP.use('ModeRegistry')
local ChatService = PVP.use('ChatService')
local CombatService = PVP.use('CombatService')
local LootService = PVP.use('LootService')
local Utils = PVP.use('Utils')
local Logger = PVP.use('Logger')
local ContractService = PVP.use('ContractService')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

-- Le compteur de kills n'est renvoyé aux joueurs qu'une fois par seconde au plus
HordeService.SYNC_INTERVAL = 1000

---@type PveZone|nil
HordeService.active = nil
HordeService.lastSync = 0
HordeService.lastKey = ''

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
    HordeService.lastKey = ''
    ChatService.announce('pvp', Locale.t('Une horde envahit : %s ! Tenez %d minutes.', Locale.t(zone.zone.label), math.floor(Config.Hordes.duration / 60)))
    ModeRegistry.broadcast('pvp', Events.client.notify, Locale.t('Horde en cours : %s', Locale.t(zone.zone.label)), 'error')
    Logger.info('[horde] %s', zone.zone.label)
    HordeService.sync(true)
    CreateThread(HordeService.watch)
    return true
end

---@return PveZone|nil zone PvE avec au moins un joueur dedans (sauf celles sans horde, npc.horde = false)
function HordeService.pickZone()
    local candidates = {}
    for _, zone in pairs(PveService.zones) do
        if zone.config.horde ~= false and zone:hasPlayersNear(0.0) then candidates[#candidates + 1] = zone end
    end
    return #candidates > 0 and Utils.pick(candidates) or nil
end

function HordeService.watch()
    local zone = HordeService.active
    while zone and HordeService.active == zone do
        Wait(500)
        if HordeService.active ~= zone then return end
        if GetGameTimer() >= zone.horde.endsAt then
            -- Fin du temps : le boss arrive (une seule fois), sinon la horde se termine
            if zone.horde.bossMax or not HordeService.spawnBoss(zone) then return HordeService.finish() end
        end
        HordeService.sync(false)
    end
end

---@param zone PveZone
---@return integer joueurs PvP vivants dans la zone
function HordeService.countPlayers(zone)
    local count = 0
    for _, player in pairs(PlayerService.all()) do
        if player.mode == 'pvp' and not player.dead and #(player:getCoords() - zone.zone.coords) <= zone.zone.radius then
            count = count + 1
        end
    end
    return count
end

---Le mini boss apparaît à un point de la zone ; le temps de la horde repart pour le tuer.
---@param zone PveZone
---@return boolean apparu
function HordeService.spawnBoss(zone)
    local settings = Config.Hordes.boss
    if not settings then return false end
    local ped = zone:createPed(Utils.pick(zone.config.spawns), settings.model, settings.type)
    if not ped then return false end

    local max = settings.health + settings.healthPerPlayer * math.max(0, HordeService.countPlayers(zone) - 1)
    -- Vie appliquée par le client propriétaire (voir Horde.setupBoss)
    Entity(ped).state:set('hordeBoss', max, true)
    zone.horde.boss = ped
    zone.horde.bossMax = max
    zone.horde.endsAt = GetGameTimer() + settings.duration * 1000

    local label = Config.ZombieTypes[settings.type].label
    ChatService.announce('pvp', Locale.t('%s surgit de la horde à %s ! Tuez-le en %d minutes.', Locale.t(label),
        Locale.t(zone.zone.label), math.ceil(settings.duration / 60)))
    Logger.info('[horde] boss %s (%d PV)', zone.zone.label, max)
    HordeService.sync(true)
    return true
end

---@param zone PveZone
---@param ped integer
---@param killer PvpPlayer|nil
function HordeService.onBossDeath(zone, ped, killer)
    local settings = Config.Hordes.boss
    zone.horde.boss = nil
    zone.horde.bossKilled = true
    Entity(ped).state:set('pvpNpcDead', true, true)
    if killer then CombatService.rewardNpcKill(killer, zone.zone.id) end
    LootService.drop(GetEntityCoords(ped), LootService.rollMany(settings.loot, settings.lootRolls),
        { netId = NetworkGetNetworkIdFromEntity(ped), bucket = Config.PveWorld.bucket })
    HordeService.finish()
end

---Fin de la horde : récompense des survivants présents dans la zone.
function HordeService.finish()
    local zone = HordeService.active
    if not zone then return end
    local horde = zone.horde
    zone.horde = nil
    HordeService.active = nil
    -- Boss pas tué à temps : il repart
    if horde.boss and DoesEntityExist(horde.boss) then DeleteEntity(horde.boss) end

    local bossReward = horde.bossKilled and Config.Hordes.boss.reward or { money = 0, xp = 0 }
    local money = Config.Hordes.reward.money + bossReward.money
    local xp = Config.Hordes.reward.xp + bossReward.xp
    local survivors = {}
    for _, player in pairs(PlayerService.all()) do
        if player.mode == 'pvp' and not player.dead and #(player:getCoords() - zone.zone.coords) <= zone.zone.radius then
            player:addMoney(money)
            player:addXp(xp)
            ContractService.track(player, 'hordeSurvive', 1)
            player:notify(Locale.t('Horde repoussée : +$%d, +%d XP', money, xp), 'success')
            player:sync()
            survivors[#survivors + 1] = player.name
        end
    end

    local label = Locale.t(zone.zone.label)
    if #survivors == 0 then
        ChatService.announce('pvp', Locale.t('La horde a submergé %s.', label))
    elseif horde.bossKilled then
        ChatService.announce('pvp', Locale.t('Horde et boss vaincus à %s (%d zombies tués) par %s.', label, horde.kills, table.concat(survivors, ', ')))
    else
        ChatService.announce('pvp', Locale.t('Horde repoussée à %s (%d zombies tués) par %s.', label, horde.kills, table.concat(survivors, ', ')))
    end
    if horde.bossMax and not horde.bossKilled then
        ChatService.announce('pvp', Locale.t('Le boss de la horde s\'est enfui de %s.', label))
    end
    TriggerClientEvent(Events.client.hordeState, -1, false)
end

---@param horde table
---@return integer vie restante du boss
function HordeService.bossHealth(horde)
    local ped = horde.boss
    if not ped or not DoesEntityExist(ped) then return 0 end
    -- Sa vie n'est appliquée qu'une fois qu'un client le pilote
    if not Entity(ped).state.pvpNpcReady then return horde.bossMax end
    return math.max(0, GetEntityHealth(ped) - 100)
end

---@return table|false état envoyé aux clients
function HordeService.describe()
    local zone = HordeService.active
    if not zone then return false end
    local horde = zone.horde
    return {
        zoneId = zone.zone.id,
        label = zone.zone.label,
        endsIn = math.max(0, math.ceil((horde.endsAt - GetGameTimer()) / 1000)),
        kills = horde.kills,
        boss = horde.bossMax and {
            label = Config.ZombieTypes[Config.Hordes.boss.type].label,
            value = HordeService.bossHealth(horde),
            max = horde.bossMax,
        } or false,
    }
end

---@param force boolean envoyer même si rien n'a changé
function HordeService.sync(force)
    local zone = HordeService.active
    if not zone then return end
    local now = GetGameTimer()
    local key = zone.horde.kills .. ':' .. (zone.horde.bossMax and HordeService.bossHealth(zone.horde) or '')
    if not force and (key == HordeService.lastKey or now - HordeService.lastSync < HordeService.SYNC_INTERVAL) then
        return
    end
    HordeService.lastSync = now
    HordeService.lastKey = key
    TriggerClientEvent(Events.client.hordeState, -1, HordeService.describe())
end
