---Téléportation entre zones safe (F1) en mode PvP.
---Instantanée depuis une zone safe ; ailleurs, le joueur doit rester immobile et hors combat
---pendant Config.Teleport.channel secondes. Un délai sépare deux téléportations.
---@class TeleportServiceModule
local TeleportService = PVP.define('TeleportService')
local PlayerService = PVP.use('PlayerService')
local CombatTagService = PVP.use('CombatTagService')
local AntiCheatService = PVP.use('AntiCheatService')
local Callback = PVP.use('Callback')
local Zones = PVP.use('Zones')
local Events = PVP.use('Events')

TeleportService.CHECK_INTERVAL = 250

---@type table<integer, integer> server id -> os.time() de la dernière téléportation
TeleportService.lastUse = {}
---@type table<integer, integer> server id -> numéro de la téléportation en attente
TeleportService.pending = {}
TeleportService.nextId = 0

function TeleportService.init()
    Callback.register(Events.callbacks.teleportInfo, TeleportService.info)
    Callback.register(Events.callbacks.teleport, TeleportService.request)

    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        TeleportService.pending[playerSource] = nil
        TeleportService.lastUse[playerSource] = nil
    end)
end

---@param source integer
---@return integer secondes avant la prochaine téléportation
function TeleportService.cooldown(source)
    local last = TeleportService.lastUse[source]
    if not last then return 0 end
    return math.max(0, Config.Teleport.cooldown - (os.time() - last))
end

---Infos du menu F1 : délai restant et temps d'attente depuis la position actuelle.
---@param source integer
function TeleportService.info(source)
    local player = PlayerService.get(source)
    if not player then return nil end
    return {
        cooldown = TeleportService.cooldown(source),
        channel = player:isInSafeZone() and 0 or Config.Teleport.channel,
        pending = TeleportService.pending[source] ~= nil,
    }
end

---@param player PvpPlayer|nil
---@param zone table|nil
---@return boolean, string|nil
function TeleportService.check(player, zone)
    if not player or player.mode ~= 'pvp' then
        return false, 'Téléportation disponible en mode PvP.'
    end
    if player.dead then
        return false, 'Attends de réapparaître.'
    end
    if not zone or zone.type ~= 'safe' or not Zones.inMode(zone, 'pvp') then
        return false, 'Zone safe inconnue.'
    end
    if player:getZone() == zone then
        return false, 'Tu es déjà dans cette zone safe.'
    end
    if CombatTagService.isTagged(player) then
        return false, ('Tu es en combat : attends %d s.'):format(CombatTagService.remaining(player))
    end
    local cooldown = TeleportService.cooldown(player.source)
    if cooldown > 0 then
        return false, ('Téléportation disponible dans %d s.'):format(cooldown)
    end
    return true
end

---@param source integer
---@param zoneId any id de la zone safe visée
function TeleportService.request(source, zoneId)
    local player = PlayerService.get(source)
    local zone = type(zoneId) == 'string' and Zones.byId(zoneId) or nil
    local ok, message = TeleportService.check(player, zone)
    if not ok then
        return { ok = false, message = message }
    end
    if TeleportService.pending[source] then
        return { ok = false, message = 'Une téléportation est déjà en cours.' }
    end

    if player:isInSafeZone() then
        TeleportService.teleport(player, zone)
        return { ok = true, channel = 0 }
    end

    TeleportService.nextId = TeleportService.nextId + 1
    local id = TeleportService.nextId
    TeleportService.pending[source] = id
    CreateThread(function()
        TeleportService.channel(player, id, zone)
    end)
    return {
        ok = true,
        channel = Config.Teleport.channel,
        message = ('Téléportation vers %s dans %d s : ne bouge pas.'):format(zone.label, Config.Teleport.channel),
    }
end

---Attente avant la téléportation : annulée si le joueur bouge, meurt, entre en combat ou part.
---@param player PvpPlayer
---@param id integer
---@param zone table
function TeleportService.channel(player, id, zone)
    local source = player.source
    local start = player:getCoords()
    local deadline = GetGameTimer() + Config.Teleport.channel * 1000

    while GetGameTimer() < deadline do
        Wait(TeleportService.CHECK_INTERVAL)
        if TeleportService.pending[source] ~= id or PlayerService.get(source) ~= player then return end
        local reason = TeleportService.interruption(player, start)
        if reason then return TeleportService.cancel(player, reason) end
    end

    TeleportService.pending[source] = nil
    local ok, message = TeleportService.check(player, zone)
    if not ok then return TeleportService.cancel(player, message) end
    TeleportService.teleport(player, zone)
end

---@param player PvpPlayer
---@param start vector3
---@return string|nil raison de l'annulation
function TeleportService.interruption(player, start)
    if player.dead or player.mode ~= 'pvp' then
        return 'Téléportation annulée.'
    end
    if CombatTagService.isTagged(player) then
        return 'Téléportation annulée : tu es en combat.'
    end
    if #(player:getCoords() - start) > Config.Teleport.maxMove then
        return 'Téléportation annulée : tu as bougé.'
    end
    return nil
end

---@param player PvpPlayer
---@param message string
function TeleportService.cancel(player, message)
    TeleportService.pending[player.source] = nil
    TriggerClientEvent(Events.client.teleportCancel, player.source)
    player:notify(message, 'error')
end

---@param player PvpPlayer
---@param zone table
function TeleportService.teleport(player, zone)
    TeleportService.lastUse[player.source] = os.time()
    -- Le saut de position ne doit pas être pris pour une téléportation illégale
    AntiCheatService.grace(player.source)
    local spawns = zone.spawns or {}
    local spawn = spawns[math.random(math.max(#spawns, 1))]
        or vector4(zone.coords.x, zone.coords.y, zone.coords.z, 0.0)
    TriggerClientEvent(Events.client.teleport, player.source, spawn, zone.label)
end
