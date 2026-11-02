---À terre et réanimation (Config.Downed). Le client demande à rester à terre pendant que son personnage est
---encore mort : le serveur valide alors son tueur (KillProof a besoin de voir la mort), le garde pour plus
---tard, puis le client relève son personnage. Le serveur force la mort à la fin du temps.
---@class PvpDowned
---@field killer integer|nil server id du tueur validé
---@field killerObject PvpPlayer|nil
---@field cause table
---@field token integer

---@class DownedServiceModule
local DownedService = PVP.define('DownedService')
local PlayerService = PVP.use('PlayerService')
local CombatService = PVP.use('CombatService')
local GroupService = PVP.use('GroupService')
local CrewService = PVP.use('CrewService')
local AntiCheatService = PVP.use('AntiCheatService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

DownedService.MODE = 'pvp'
DownedService.STATE_KEY = 'downed'
-- Le client meurt lui-même à la fin du temps : le serveur lui laisse cette marge
DownedService.FORCE_MARGIN = 3
DownedService.REVIVE_MARGIN = 2.0

DownedService.nextToken = 0

function DownedService.init()
    Callback.register(Events.callbacks.downedStart, DownedService.start)
    Callback.register(Events.callbacks.downedRevive, DownedService.revive)
end

---@param a PvpPlayer
---@param b PvpPlayer
---@return boolean même équipe ou même crew
function DownedService.areAllies(a, b)
    if GroupService.areAllies(a.source, b.source) then return true end
    local tag = CrewService.tagOf(a.identifier)
    return tag ~= nil and tag == CrewService.tagOf(b.identifier)
end

---@param player PvpPlayer
---@return boolean un allié vivant est assez près
function DownedService.hasAllyNear(player)
    local coords = player:getCoords()
    for _, other in pairs(PlayerService.all()) do
        if other ~= player and other.mode == DownedService.MODE and not other.dead and not other.downed
            and DownedService.areAllies(player, other)
            and #(other:getCoords() - coords) <= Config.Downed.allyRange then
            return true
        end
    end
    return false
end

---Le client vient de voir son personnage mourir. À appeler depuis un thread : attend la preuve du kill.
---@param source integer
---@param data any { killer, cause }
---@return { ok: boolean }
function DownedService.start(source, data)
    local player = PlayerService.get(source)
    local settings = Config.Downed
    if not settings.enabled or not player or player.dead or player.downed or player.mode ~= DownedService.MODE or type(data) ~= 'table' then
        return { ok = false }
    end
    if player.downedAt and os.time() - player.downedAt < settings.cooldown then return { ok = false } end
    if not DownedService.hasAllyNear(player) then return { ok = false } end

    DownedService.nextToken = DownedService.nextToken + 1
    local token = DownedService.nextToken
    -- Réservé avant d'attendre : une 2e demande ne peut pas passer pendant la validation
    player.downed = { token = token, cause = type(data.cause) == 'table' and data.cause or {} }
    player.downedAt = os.time()
    local killer = CombatService.resolveKiller(player, data.killer)
    if PlayerService.get(source) ~= player or not player.downed or player.downed.token ~= token then return { ok = false } end

    player.downed.killer = killer and killer.source or nil
    player.downed.killerObject = killer
    -- Vie basse et personnage relevé : ni l'immunité ni la téléportation ne doivent se déclencher
    AntiCheatService.grace(source, settings.duration + DownedService.FORCE_MARGIN + 2)
    Player(source).state:set(DownedService.STATE_KEY, true, true)

    SetTimeout((settings.duration + DownedService.FORCE_MARGIN) * 1000, function()
        DownedService.forceDeath(player, token)
    end)
    return { ok = true }
end

---Le client n'a pas annoncé sa mort à temps : le serveur la prononce.
---@param player PvpPlayer
---@param token integer
function DownedService.forceDeath(player, token)
    if PlayerService.get(player.source) ~= player or not player.downed or player.downed.token ~= token then return end
    TriggerClientEvent(Events.client.downedEnd, player.source, false)
    CombatService.onPlayerDied(player.source, nil, player.downed.cause)
end

---Fin de l'état à terre : mort, ou joueur relevé.
---@param player PvpPlayer
---@return PvpDowned|nil
function DownedService.clear(player)
    local downed = player.downed
    if not downed then return nil end
    player.downed = nil
    Player(player.source).state:set(DownedService.STATE_KEY, false, true)
    return downed
end

---Tueur gardé au moment où le joueur est tombé, s'il est encore là.
---@param downed PvpDowned
---@return PvpPlayer|nil
function DownedService.killerOf(downed)
    if not downed.killer then return nil end
    local killer = PlayerService.get(downed.killer)
    return killer == downed.killerObject and killer or nil
end

---@param source integer celui qui relève
---@param targetId any
---@return { ok: boolean, message?: string }
function DownedService.revive(source, targetId)
    local rescuer = PlayerService.get(source)
    local target = PlayerService.get(tonumber(targetId))
    if not rescuer or rescuer.dead or rescuer.downed or rescuer.mode ~= DownedService.MODE then return { ok = false } end
    if not target or target == rescuer or not target.downed or target.dead then
        return { ok = false, message = Locale.t('Ce joueur n\'est plus à terre.') }
    end
    if not DownedService.areAllies(rescuer, target) then return { ok = false } end
    if #(rescuer:getCoords() - target:getCoords()) > Config.Downed.reviveDistance + DownedService.REVIVE_MARGIN then
        return { ok = false, message = Locale.t('Trop loin.') }
    end

    DownedService.clear(target)
    AntiCheatService.grace(target.source, DownedService.FORCE_MARGIN)
    TriggerClientEvent(Events.client.downedEnd, target.source, true)
    target:notify(Locale.t('%s t\'a relevé.', rescuer.name), 'success')
    rescuer:addMoney(Config.Downed.reviveReward)
    rescuer:sync()
    return { ok = true, message = Locale.t('%s relevé (+$%d)', target.name, Config.Downed.reviveReward) }
end
