---Mode Sabotage : menu (rôle, recherche de partie, classement), parties tactiques en manches.
---Rien ne touche à l'inventaire du PvP. Voir server/modules/tactical/ et config/tactical.lua.
---@class TacticalModeModule
local TacticalMode = PVP.define('TacticalMode')
local ModeRegistry = PVP.use('ModeRegistry')
local PlayerService = PVP.use('PlayerService')
local TacticalService = PVP.use('TacticalService')
local TacticalProfileService = PVP.use('TacticalProfileService')
local Events = PVP.use('Events')

TacticalMode.ID = 'tactical'

function TacticalMode.init()
    ModeRegistry.register(TacticalMode.ID, TacticalMode)
    SetRoutingBucketPopulationEnabled(Config.Tactical.bucket, false)
    AddEventHandler('weaponDamageEvent', function(sender, data)
        TacticalMode.onWeaponDamage(sender, data)
    end)
end

---@param player PvpPlayer
function TacticalMode.enter(player)
    TacticalService.openMenu(player)
end

---@param player PvpPlayer
function TacticalMode.leave(player)
    TacticalService.leave(player.source)
    TacticalProfileService.unload(player.source)
    TriggerClientEvent(Events.client.tacCleanup, player.source)
end

---Annule la touche hors manche ou entre alliés. Voir TacticalMatch:damageAllowed.
---@param sender integer|string
---@param data table hitGlobalId ou hitGlobalIds
function TacticalMode.onWeaponDamage(sender, data)
    local attacker = PlayerService.get(tonumber(sender))
    if not attacker or attacker.mode ~= TacticalMode.ID or type(data) ~= 'table' then return end

    local ids = data.hitGlobalIds or { data.hitGlobalId }
    for _, netId in ipairs(ids) do
        local ped = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
        if ped ~= 0 and DoesEntityExist(ped) then
            local owner = NetworkGetEntityOwner(ped)
            if PlayerService.get(owner) and GetPlayerPed(owner) == ped
                and not TacticalService.damageAllowed(attacker.source, owner, data.weaponDamage) then
                CancelEvent()
                return
            end
        end
    end
end
