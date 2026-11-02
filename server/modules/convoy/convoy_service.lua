---Convoi blindé (Config.Convoy) : le serveur crée le fourgon et son chauffeur, suit leur état et diffuse la
---position ; le client qui en a le contrôle réseau fait rouler le chauffeur (voir client/modules/convoy).
---@class ConvoyRun
---@field id integer
---@field vehicle integer
---@field driver integer
---@field route (vector3|vector4)[]
---@field index integer point visé
---@field endsAt integer os.time()
---@field netId integer

---@class ConvoyServiceModule
local ConvoyService = PVP.define('ConvoyService')
local LootService = PVP.use('LootService')
local ModeRegistry = PVP.use('ModeRegistry')
local ChatService = PVP.use('ChatService')
local Utils = PVP.use('Utils')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

ConvoyService.MODE = 'pvp'
ConvoyService.TICK = 3000
ConvoyService.SPAWN_TIMEOUT = 50 -- essais, à 100 ms

---@type ConvoyRun|nil
ConvoyService.current = nil
ConvoyService.nextId = 0

function ConvoyService.init()
    RegisterNetEvent(Events.server.ready, function()
        if ConvoyService.current then
            TriggerClientEvent(Events.client.convoyState, source, ConvoyService.describe())
        end
    end)
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() and ConvoyService.current then ConvoyService.deleteEntities(ConvoyService.current) end
    end)
    if Config.Convoy.enabled then CreateThread(ConvoyService.loop) end
    CreateThread(function()
        while true do
            Wait(ConvoyService.TICK)
            ConvoyService.tick()
        end
    end)
end

function ConvoyService.loop()
    local settings = Config.Convoy
    Wait(settings.firstDelay * 1000)
    while true do
        if not ConvoyService.current and ModeRegistry.countPlayers(ConvoyService.MODE) >= settings.minPlayers then
            ConvoyService.start()
        end
        Wait(math.random(settings.interval[1], settings.interval[2]) * 1000)
    end
end

---@return ConvoyRun|nil nil si le fourgon n'a pas pu être créé, ou s'il y en a déjà un
function ConvoyService.start()
    if ConvoyService.current then return nil end
    local settings = Config.Convoy
    local route = Utils.pick(settings.routes)
    local first = route[1]

    local vehicle = CreateVehicleServerSetter(GetHashKey(settings.vehicle), 'automobile', first.x, first.y, first.z, first.w)
    local tries = 0
    while not DoesEntityExist(vehicle) and tries < ConvoyService.SPAWN_TIMEOUT do
        tries = tries + 1
        Wait(100)
    end
    if not DoesEntityExist(vehicle) then
        Logger.warn('[convoi] fourgon non créé (%s)', settings.vehicle)
        return nil
    end
    local driver = CreatePedInsideVehicle(vehicle, 4, GetHashKey(settings.driver), -1, true, true)
    -- Sans cela, le serveur supprime ce qu'aucun joueur ne voit
    SetEntityOrphanMode(vehicle, 2)
    SetEntityOrphanMode(driver, 2)
    SetVehicleDoorsLocked(vehicle, 2)

    ConvoyService.nextId = ConvoyService.nextId + 1
    ConvoyService.current = {
        id = ConvoyService.nextId,
        vehicle = vehicle,
        driver = driver,
        route = route,
        index = 2,
        endsAt = os.time() + settings.duration,
        netId = NetworkGetNetworkIdFromEntity(vehicle),
    }
    TriggerClientEvent(Events.client.convoyState, -1, ConvoyService.describe())
    ChatService.announce('pvp', Locale.t('Un convoi blindé est en route : détruis-le pour son butin (repère rouge) !'))
    Logger.info('[convoi] n°%d part de (%.0f, %.0f)', ConvoyService.current.id, first.x, first.y)
    return ConvoyService.current
end

---@return table état envoyé aux clients
function ConvoyService.describe()
    local run = ConvoyService.current
    local pos = GetEntityCoords(run.vehicle)
    local target = run.route[run.index]
    return {
        id = run.id,
        netId = run.netId,
        coords = vector3(pos.x, pos.y, pos.z),
        target = vector3(target.x, target.y, target.z),
    }
end

function ConvoyService.tick()
    local run = ConvoyService.current
    if not run then return end
    if not DoesEntityExist(run.vehicle) then return ConvoyService.finish('lost') end

    local settings = Config.Convoy
    local driverDead = DoesEntityExist(run.driver) and GetEntityHealth(run.driver) <= 0
    if GetVehicleEngineHealth(run.vehicle) <= settings.destroyHealth or driverDead then
        return ConvoyService.finish('destroyed')
    end
    if os.time() >= run.endsAt then return ConvoyService.finish('escaped') end

    local pos = GetEntityCoords(run.vehicle)
    local target = run.route[run.index]
    if #(vector3(pos.x, pos.y, pos.z) - vector3(target.x, target.y, target.z)) <= settings.arriveDistance then
        run.index = run.index + 1
        if not run.route[run.index] then return ConvoyService.finish('escaped') end
    end
    TriggerClientEvent(Events.client.convoyState, -1, ConvoyService.describe())
end

---@param reason 'destroyed'|'escaped'|'lost'
function ConvoyService.finish(reason)
    local run = ConvoyService.current
    if not run then return end
    ConvoyService.current = nil
    TriggerClientEvent(Events.client.convoyState, -1, false)
    Logger.info('[convoi] n°%d : %s', run.id, reason)

    if reason == 'destroyed' then
        local settings = Config.Convoy
        local pos = GetEntityCoords(run.vehicle)
        local items = LootService.roll(settings.reward.loot)
        items.money = (items.money or 0) + settings.reward.money
        LootService.drop(vector3(pos.x, pos.y, pos.z), items, {
            browse = true,
            label = Locale.t('Fouiller le convoi'),
            title = Locale.t('Convoi blindé'),
            lifetime = settings.lootLifetime,
        })
        ChatService.announce('pvp', Locale.t('Le convoi blindé est tombé : son butin est au sol !'))
        SetTimeout(settings.wreckTime * 1000, function() ConvoyService.deleteEntities(run) end)
    else
        if reason == 'escaped' then ChatService.announce('pvp', Locale.t('Le convoi blindé s\'est échappé.')) end
        ConvoyService.deleteEntities(run)
    end
end

---@param run ConvoyRun
function ConvoyService.deleteEntities(run)
    if DoesEntityExist(run.driver) then DeleteEntity(run.driver) end
    if DoesEntityExist(run.vehicle) then DeleteEntity(run.vehicle) end
end
