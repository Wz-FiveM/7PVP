---Mode Freeroam (bac à sable) : pas d'inventaire, armes et véhicules gratuits côté client
---(voir client/modules/freeroam/freeroam.lua). Le serveur gère l'apparition et le PvP
---au choix : une touche entre deux joueurs n'est appliquée que si les deux l'ont activé.
---@class FreeroamModeModule
local FreeroamMode = PVP.define('FreeroamMode')
local ModeRegistry = PVP.use('ModeRegistry')
local PlayerService = PVP.use('PlayerService')
local WorldService = PVP.use('WorldService')
local Callback = PVP.use('Callback')
local Utils = PVP.use('Utils')
local Zones = PVP.use('Zones')
local ChaseService = PVP.use('ChaseService')
local CvcService = PVP.use('CvcService')
local AntiCheatService = PVP.use('AntiCheatService')
local Events = PVP.use('Events')

FreeroamMode.ID = 'freeroam'

function FreeroamMode.init()
    ModeRegistry.register(FreeroamMode.ID, FreeroamMode)
    local config = ModeRegistry.getConfig(FreeroamMode.ID)
    if config then WorldService.setupBucket(config.bucket) end

    Callback.register(Events.callbacks.freeroamPvp, FreeroamMode.setPvp)
    AddEventHandler('weaponDamageEvent', function(sender, data)
        FreeroamMode.onWeaponDamage(sender, data)
    end)
end

---@param player PvpPlayer
function FreeroamMode.enter(player)
    player.dead = false
    AntiCheatService.grace(player.source)
    player.freeroamPvp = false
    -- On arrive dans la zone safe du Freeroam (là où sont les PNJ des modes de jeu)
    local spawn = Zones.randomSpawn(FreeroamMode.ID) or Utils.pick(Config.Freeroam.spawns)
    TriggerClientEvent(Events.client.spawn, player.source, spawn, player.appearance)
end

---@param player PvpPlayer
function FreeroamMode.leave(player)
    player.freeroamPvp = false
    ChaseService.leave(player.source)
    CvcService.leave(player.source)
    TriggerClientEvent(Events.client.freeroamCleanup, player.source)
end

---Active ou coupe le PvP du joueur (pour lui seul).
---@param source integer
---@param enabled any
---@return { ok: boolean, message: string, pvp: boolean }
function FreeroamMode.setPvp(source, enabled)
    local player = PlayerService.get(source)
    if not player or player.mode ~= FreeroamMode.ID then return { ok = false, message = 'Disponible en Freeroam.', pvp = false } end
    player.freeroamPvp = enabled == true
    return {
        ok = true,
        pvp = player.freeroamPvp,
        message = player.freeroamPvp and 'PvP activé : les joueurs qui l\'ont activé peuvent te toucher.' or 'PvP désactivé.',
    }
end

---Annule la touche si le tireur ou sa cible n'a pas activé le PvP.
---@param sender integer
---@param data table hitGlobalId ou hitGlobalIds
function FreeroamMode.onWeaponDamage(sender, data)
    local attacker = PlayerService.get(sender)
    if not attacker or attacker.mode ~= FreeroamMode.ID or type(data) ~= 'table' then return end

    local ids = data.hitGlobalIds or { data.hitGlobalId }
    for _, netId in ipairs(ids) do
        local ped = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
        if ped ~= 0 and DoesEntityExist(ped) then
            local owner = NetworkGetEntityOwner(ped)
            local victim = PlayerService.get(owner)
            if victim and GetPlayerPed(owner) == ped then
                -- CVC : seulement entre équipes adverses ; sinon, PvP activé par les deux joueurs
                local allowed = CvcService.damageAllowed(attacker.source, owner)
                if allowed == nil then allowed = attacker.freeroamPvp and victim.freeroamPvp end
                if not allowed then
                    CancelEvent()
                    return
                end
            end
        end
    end
end
