---Détection de la mort du joueur local.
---@class DeathModule
local Death = PVP.define('Death')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Loadout = PVP.use('Loadout')
local Freeroam = PVP.use('Freeroam')
local Cod = PVP.use('Cod')
local PedUtils = PVP.use('PedUtils')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Death.CHECK_INTERVAL = 250

function Death.init()
    RegisterNetEvent(Events.client.dead, function(seconds, recap)
        Death.onConfirmed(seconds, recap)
    end)

    CreateThread(Death.watchLoop)
end

function Death.watchLoop()
    while true do
        Wait(Death.CHECK_INTERVAL)
        if State.isAlive() then
            Death.check()
        end
    end
end

function Death.check()
    local ped = PlayerPedId()
    if not IsEntityDead(ped) then return end

    Death.markPosition(GetEntityCoords(ped))

    -- Freeroam : pas de perte ni d'écran de mort
    if State.mode == 'freeroam' then return Freeroam.onDeath() end
    if State.mode == 'cod' then return Cod.onDeath() end

    State.dead = true
    -- Les munitions tirées sont envoyées avant la mort (les événements arrivent dans l'ordre)
    Loadout.onDeath()
    TriggerServerEvent(Events.server.died, PedUtils.getKillerServerId(ped), Death.getCause(ped))
end

-- ---------------------------------------------------------------------------
-- Repère de la dernière mort
-- ---------------------------------------------------------------------------

Death.blip = nil
Death.blipToken = 0 -- invalide le minuteur d'un repère remplacé par une nouvelle mort

---Repère sur la carte à l'endroit de la mort, retiré après Config.DeathBlip.duration secondes.
---@param coords vector3
function Death.markPosition(coords)
    Death.removeBlip()
    local settings = Config.DeathBlip
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, settings.sprite)
    SetBlipColour(blip, settings.color)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Locale.t('Dernière mort'))
    EndTextCommandSetBlipName(blip)
    Death.blip = blip

    Death.blipToken = Death.blipToken + 1
    local token = Death.blipToken
    SetTimeout(settings.duration * 1000, function()
        if Death.blipToken == token then Death.removeBlip() end
    end)
end

function Death.removeBlip()
    if Death.blip and DoesBlipExist(Death.blip) then RemoveBlip(Death.blip) end
    Death.blip = nil
end

---Arme qui a tué et tueur zombie (pour le récapitulatif de mort).
---@param ped integer
---@return { weapon: integer, zombie: boolean }
function Death.getCause(ped)
    local source = GetPedSourceOfDeath(ped)
    local zombie = source ~= 0 and IsEntityAPed(source) and not IsPedAPlayer(source)
        and Entity(source).state.pvpNpc ~= nil
    local hasBone, bone = GetPedLastDamageBone(ped)
    return { weapon = GetPedCauseOfDeath(ped), zombie = zombie, headshot = hasBone and bone == 31086 }
end

---@param seconds integer délai avant respawn
---@param recap table|nil récapitulatif calculé par le serveur
function Death.onConfirmed(seconds, recap)
    if State.menuOpen then
        Nui.setMenu(false)
    end
    Nui.send('death', { seconds = seconds, recap = recap or {} })
    if recap and recap.killerId then
        Death.spectate(recap.killerId)
    end
end

-- ---------------------------------------------------------------------------
-- Caméra sur le tueur pendant le délai de réapparition
-- ---------------------------------------------------------------------------

Death.spectating = false

---@param serverId integer
function Death.spectate(serverId)
    local player = GetPlayerFromServerId(serverId)
    -- Trop loin : le jeu ne l'a pas chargé, on reste sur son propre corps
    if player == -1 then return end
    local target = GetPlayerPed(player)
    if not DoesEntityExist(target) then return end

    Death.spectating = true
    NetworkSetInSpectatorMode(true, target)
end

---Appelé à la réapparition.
function Death.stopSpectate()
    if not Death.spectating then return end
    Death.spectating = false
    NetworkSetInSpectatorMode(false, PlayerPedId())
end
