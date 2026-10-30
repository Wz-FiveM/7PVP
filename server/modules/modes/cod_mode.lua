---Mode Call of Duty : menu (classes, recherche de partie), parties en équipes ou chacun pour soi,
---progression propre. Rien ne touche à l'inventaire du PvP. Voir server/modules/cod/ et config/cod.lua.
---@class CodModeModule
local CodMode = PVP.define('CodMode')
local ModeRegistry = PVP.use('ModeRegistry')
local PlayerService = PVP.use('PlayerService')
local CodService = PVP.use('CodService')
local CodProfileService = PVP.use('CodProfileService')
local Events = PVP.use('Events')

CodMode.ID = 'cod'

function CodMode.init()
    ModeRegistry.register(CodMode.ID, CodMode)
    SetRoutingBucketPopulationEnabled(Config.Cod.bucket, false)
    AddEventHandler('weaponDamageEvent', function(sender, data)
        CodMode.onWeaponDamage(sender, data)
    end)
end

---@param player PvpPlayer
function CodMode.enter(player)
    CodService.openMenu(player)
end

---@param player PvpPlayer
function CodMode.leave(player)
    CodService.leave(player.source)
    CodProfileService.unload(player.source)
    TriggerClientEvent(Events.client.codCleanup, player.source)
end

---Annule la touche hors partie ou entre alliés. Voir CodMatch:damageAllowed.
---@param sender integer
---@param data table hitGlobalId ou hitGlobalIds
function CodMode.onWeaponDamage(sender, data)
    local attacker = PlayerService.get(sender)
    if not attacker or attacker.mode ~= CodMode.ID or type(data) ~= 'table' then return end

    local ids = data.hitGlobalIds or { data.hitGlobalId }
    for _, netId in ipairs(ids) do
        local ped = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
        if ped ~= 0 and DoesEntityExist(ped) then
            local owner = NetworkGetEntityOwner(ped)
            if PlayerService.get(owner) and GetPlayerPed(owner) == ped and not CodService.damageAllowed(sender, owner) then
                CancelEvent()
                return
            end
        end
    end
end
