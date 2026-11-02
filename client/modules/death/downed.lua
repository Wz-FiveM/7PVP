---À terre et réanimation côté client (voir DownedService). À la mort en PvP, le personnage reste mort le temps
---que le serveur réponde ; s'il accepte, il est relevé sur place, sans pouvoir bouger ni tirer. Il meurt
---pour de bon s'il est achevé ou à la fin du temps ; un allié peut le relever en maintenant E.
---@class DownedModule
local Downed = PVP.define('Downed')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Loadout = PVP.use('Loadout')
local Group = PVP.use('Group')
local Crew = PVP.use('Crew')
local DuiLabels = PVP.use('DuiLabels')
local HelpNotify = PVP.use('HelpNotify')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Downed.STATE_KEY = 'downed'
Downed.CONTROL_REVIVE = 38 -- E
Downed.SEARCH_INTERVAL = 250
-- Le jeu peut encore voir le personnage mort juste après l'avoir relevé
Downed.RESURRECT_DELAY = 500
Downed.ANIM_DICT = 'combat@damage@writhe'
Downed.ANIM_NAME = 'writhe_loop'
-- Déplacement, saut, tir, visée, armes, couverture, mêlée, attaque du véhicule
Downed.BLOCKED_CONTROLS = { 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 44, 45, 47, 58, 140, 141, 142, 143, 257, 263, 264 }

---@type boolean le joueur est à terre
Downed.active = false
---@type boolean le serveur n'a pas encore répondu
Downed.pending = false
---@type boolean le serveur a refusé : c'est une mort normale
Downed.refused = false
---@type integer GetGameTimer() de la fin du temps
Downed.endsAt = 0
---@type integer GetGameTimer() de la chute
Downed.startedAt = 0

function Downed.init()
    RegisterNetEvent(Events.client.downedEnd, function(revived)
        if revived then Downed.onRevived() else Downed.die() end
    end)
    CreateThread(Downed.searchLoop)
end

---Appelé par Death.check quand le personnage est mort.
---@param ped integer
---@param killer integer|nil
---@param cause table
---@return boolean true si la mort attend (le joueur reste à terre ou le serveur répond)
function Downed.onDeath(ped, killer, cause)
    if Downed.pending then return true end
    -- Achevé à terre, ou temps écoulé : la mort normale prend le relais
    if Downed.active then
        if GetGameTimer() - Downed.startedAt < Downed.RESURRECT_DELAY then return true end
        Downed.stop()
        return false
    end
    if Downed.refused then
        Downed.refused = false
        return false
    end
    if State.mode ~= 'pvp' or not Config.Downed.enabled or IsPedInAnyVehicle(ped, true) then return false end

    Downed.pending = true
    CreateThread(function()
        local result = Callback.await(Events.callbacks.downedStart, { killer = killer, cause = cause })
        Downed.pending = false
        if result and result.ok then Downed.begin() else Downed.refused = true end
    end)
    return true
end

function Downed.begin()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    ped = PlayerPedId()
    SetEntityHealth(ped, 100 + Config.Downed.health)
    ClearPedTasksImmediately(ped)
    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
    AnimpostfxStopAll()
    if State.menuOpen then Nui.setMenu(false) end

    Downed.active = true
    State.downed = true
    Downed.startedAt = GetGameTimer()
    Downed.endsAt = Downed.startedAt + Config.Downed.duration * 1000
    CreateThread(Downed.downLoop)
end

function Downed.downLoop()
    RequestAnimDict(Downed.ANIM_DICT)
    while Downed.active do
        if not State.inPvp() then
            Downed.stop()
            break
        end
        local ped = PlayerPedId()
        for _, control in ipairs(Downed.BLOCKED_CONTROLS) do DisableControlAction(0, control, true) end
        if HasAnimDictLoaded(Downed.ANIM_DICT) and not IsEntityPlayingAnim(ped, Downed.ANIM_DICT, Downed.ANIM_NAME, 3) then
            TaskPlayAnim(ped, Downed.ANIM_DICT, Downed.ANIM_NAME, 8.0, -8.0, -1, 1, 0.0, false, false, false)
        end

        local left = Downed.endsAt - GetGameTimer()
        if left <= 0 then
            SetEntityHealth(ped, 0)
            break
        end
        DuiLabels.draw('downed:self', GetEntityCoords(ped) + vector3(0.0, 0.0, 1.0), {
            title = Locale.t('À terre'),
            subtitle = Locale.t('Mort dans %d s', math.ceil(left / 1000)),
            accent = 'critique',
            icon = 'bandage',
            progress = math.floor(left / (Config.Downed.duration * 1000) * 50) / 50,
        })
        Wait(0)
    end
    RemoveAnimDict(Downed.ANIM_DICT)
end

---Fin de l'état à terre, sans rien dire au serveur.
function Downed.stop()
    Downed.active = false
    State.downed = false
    ClearPedTasks(PlayerPedId())
end

---Le serveur a prononcé la mort : Death.check verra le personnage mort et fera le reste.
function Downed.die()
    if Downed.active then SetEntityHealth(PlayerPedId(), 0) end
end

---Relevé par un allié.
function Downed.onRevived()
    if not Downed.active then return end
    Downed.stop()
    local ped = PlayerPedId()
    SetEntityHealth(ped, 100 + Config.Downed.reviveHealth)
    ClearPedTasksImmediately(ped)
    -- Armes rendues : celles du personnage ne survivent pas toujours à la résurrection
    Loadout.apply()
end

-- ---------------------------------------------------------------------------
-- Relever un allié
-- ---------------------------------------------------------------------------

---@param serverId integer
---@return boolean
function Downed.isAlly(serverId)
    if Group.isMember(serverId) then return true end
    local tag = Crew.tagOf(GetPlayerServerId(PlayerId()))
    return tag ~= nil and tag == Crew.tagOf(serverId)
end

---@param coords vector3
---@return integer|nil server id de l'allié à terre le plus proche
---@return integer|nil son personnage
function Downed.findTarget(coords)
    local me = PlayerId()
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= me then
            local serverId = GetPlayerServerId(player)
            if Player(serverId).state[Downed.STATE_KEY] and Downed.isAlly(serverId) then
                local ped = GetPlayerPed(player)
                if #(GetEntityCoords(ped) - coords) <= Config.Downed.reviveDistance then return serverId, ped end
            end
        end
    end
    return nil, nil
end

function Downed.searchLoop()
    while true do
        Wait(Downed.SEARCH_INTERVAL)
        if State.inPvp() and State.isAlive() and not State.menuOpen then
            local serverId, ped = Downed.findTarget(GetEntityCoords(PlayerPedId()))
            if serverId then Downed.reviveLoop(serverId, ped) end
        end
    end
end

---Tant qu'un allié à terre est à portée : aide à l'écran, E maintenu pour le relever.
---@param serverId integer
---@param target integer son personnage
function Downed.reviveLoop(serverId, target)
    local holdMs = Config.Downed.reviveTime * 1000
    local startedAt = nil
    while State.inPvp() and State.isAlive() and DoesEntityExist(target)
        and Player(serverId).state[Downed.STATE_KEY]
        and #(GetEntityCoords(target) - GetEntityCoords(PlayerPedId())) <= Config.Downed.reviveDistance do
        HelpNotify.show(HelpNotify.controlKey(Downed.CONTROL_REVIVE), Locale.t('Maintiens pour relever cet allié'))

        if IsControlPressed(0, Downed.CONTROL_REVIVE) then
            startedAt = startedAt or GetGameTimer()
            local progress = (GetGameTimer() - startedAt) / holdMs
            DuiLabels.draw('downed:revive', GetEntityCoords(target) + vector3(0.0, 0.0, 1.0), {
                title = Locale.t('Réanimation'),
                accent = 'hazard',
                icon = 'bandage',
                progress = math.floor(math.min(1, progress) * 50) / 50,
            })
            if progress >= 1 then
                local result = Callback.await(Events.callbacks.downedRevive, serverId)
                if result and result.message then Nui.notify(result.message, result.ok and 'success' or 'error') end
                return
            end
        else
            startedAt = nil
        end
        Wait(0)
    end
end
