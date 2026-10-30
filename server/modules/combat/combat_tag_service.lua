---Statut « en combat » : un joueur qui touche ou est touché par un autre joueur est marqué
---pendant Config.CombatTagDuration secondes. S'il se déconnecte pendant ce temps, c'est une
---mort : sac au sol, mort comptée, kill et récompense pour le dernier joueur qui l'a touché.
---Les touches viennent du tireur (weaponDamageEvent) et du joueur touché (hitmarker) :
---aucun des deux ne peut éviter seul le marquage.
---@class CombatTagServiceModule
local CombatTagService = PVP.define('CombatTagService')
local PlayerService = PVP.use('PlayerService')
local CombatService = PVP.use('CombatService')
local GroupService = PVP.use('GroupService')
local BountyService = PVP.use('BountyService')
local PveWorldService = PVP.use('PveWorldService')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

-- Le statut n'est renvoyé au client qu'une fois par seconde au plus (rafales)
CombatTagService.NOTIFY_INTERVAL = 1000

function CombatTagService.init()
    AddEventHandler('weaponDamageEvent', function(sender, data)
        CombatTagService.onWeaponDamage(sender, data)
    end)

    -- Avant la sauvegarde du joueur qui quitte (voir PlayerService.unload)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        CombatTagService.onPlayerLeaving(playerSource)
    end)
end

---@param player PvpPlayer
---@return boolean
function CombatTagService.isTagged(player)
    return player.combatUntil > GetGameTimer()
end

---@param player PvpPlayer
---@return integer secondes restantes
function CombatTagService.remaining(player)
    return math.max(0, math.ceil((player.combatUntil - GetGameTimer()) / 1000))
end

---@param player PvpPlayer
function CombatTagService.tag(player)
    local now = GetGameTimer()
    player.combatUntil = now + Config.CombatTagDuration * 1000
    player.lastCombatCoords = player:getCoords()

    if now - player.combatNotifiedAt >= CombatTagService.NOTIFY_INTERVAL then
        player.combatNotifiedAt = now
        TriggerClientEvent(Events.client.combatTag, player.source, Config.CombatTagDuration)
    end
end

---Fin du statut (mort, réapparition).
---@param player PvpPlayer
function CombatTagService.clear(player)
    local wasTagged = CombatTagService.isTagged(player)
    player.combatUntil = 0
    player.combatNotifiedAt = 0
    player.lastAttacker = nil
    if wasTagged then
        TriggerClientEvent(Events.client.combatTag, player.source, 0)
    end
end

---Un joueur en a touché un autre : les deux passent en combat.
---@param attacker PvpPlayer
---@param victim PvpPlayer
function CombatTagService.onPlayerHit(attacker, victim)
    if attacker == victim or attacker.dead or victim.dead then return end
    -- Seul le PvP a un statut « en combat » (pas le Freeroam)
    if attacker.mode ~= 'pvp' or victim.mode ~= 'pvp' or victim:isInSafeZone() then return end
    if GroupService.areAllies(attacker.source, victim.source) then return end

    CombatTagService.tag(attacker)
    CombatTagService.tag(victim)
    victim.lastAttacker = attacker.source
end

---Événement natif envoyé par le client du tireur pour chaque touche.
---@param sender integer
---@param data table hitGlobalId ou hitGlobalIds (selon la version du serveur)
function CombatTagService.onWeaponDamage(sender, data)
    local attacker = PlayerService.get(sender)
    -- Monde zombies : pas de PvP, les touches sur un joueur y sont annulées (PveWorldService)
    if not attacker or type(data) ~= 'table' or PveWorldService.isInside(sender) then return end

    local ids = data.hitGlobalIds or { data.hitGlobalId }
    for _, netId in ipairs(ids) do
        local victim = CombatTagService.getPlayerByNetId(netId)
        if victim then CombatTagService.onPlayerHit(attacker, victim) end
    end
end

---@param netId any
---@return PvpPlayer|nil joueur dont c'est le ped
function CombatTagService.getPlayerByNetId(netId)
    netId = tonumber(netId)
    local ped = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if ped == 0 or not DoesEntityExist(ped) then return nil end

    local owner = NetworkGetEntityOwner(ped)
    local player = owner and PlayerService.get(owner)
    if player and GetPlayerPed(owner) == ped then return player end
    return nil
end

---Déconnexion en plein combat : traitée comme une mort.
---@param source integer
function CombatTagService.onPlayerLeaving(source)
    local player = PlayerService.get(source)
    if not player or player.dead or not CombatTagService.isTagged(player) then return end

    player:incrementStat('deaths')
    -- Le ped peut déjà avoir disparu : on garde la position de la dernière touche
    local coords = player:getCoords()
    if #coords < 1.0 and player.lastCombatCoords then coords = player.lastCombatCoords end
    CombatService.dropVictimLoot(player, coords)
    -- Il revient comme après une mort : kit de réapparition
    player:applyRespawnKit()

    local killer = player.lastAttacker and PlayerService.get(player.lastAttacker)
    if killer then
        CombatService.rewardPlayerKill(killer, player, Locale.t('%s s\'est déconnecté en combat', player.name))
    end
    CombatService.broadcastKill(killer and killer.name, player.name, 'disconnect', nil, {
        killerId = killer and killer.source,
        victimId = player.source,
    })
    BountyService.reset(player)
    Logger.info('[combat] %s s\'est déconnecté en combat (dernier attaquant : %s)', player.name,
        killer and killer.name or 'aucun')
end
