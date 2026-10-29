---Gungame côté client (server/modules/activities/gungame_service.lua) : placement aux apparitions,
---arme du niveau (et couteau), limite de la zone de combat, signalement de sa mort, HUD.
---Le serveur décide des kills, des niveaux et de la fin de partie ; il bloque aussi les tirs hors
---partie et sur un joueur qui vient d'apparaître.
---@class GungameModule
local Gungame = PVP.define('Gungame')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local PedUtils = PVP.use('PedUtils')
local Death = PVP.use('Death')
local Freeroam = PVP.use('Freeroam')
local Events = PVP.use('Events')

Gungame.ACTIVITY = 'gungame'
Gungame.FADE = 400
Gungame.AMMO = 9999 -- munitions de réserve (infinies de toute façon, il faut recharger)
-- Pendant le compte à rebours : pas de déplacement ni de tir
Gungame.LOCKED_CONTROLS = { 21, 22, 24, 25, 30, 31, 32, 33, 34, 35, 44, 140, 141, 142, 257 }

---@type table|nil partie en cours (données envoyées par le serveur : arena, outsideDamage, ...)
Gungame.match = nil
Gungame.level = 1
Gungame.lockedUntil = 0
Gungame.arenaBlip = nil
Gungame.outside = false
Gungame.nextOutsideDamage = 0

function Gungame.init()
    RegisterNetEvent(Events.client.gungameQueue, function(data)
        Nui.send('gungameQueue', data or { count = 0 })
    end)
    RegisterNetEvent(Events.client.gungameStart, function(data)
        CreateThread(function()
            Gungame.start(data)
        end)
    end)
    RegisterNetEvent(Events.client.gungameSpawn, function(data)
        if not Gungame.isActive() then return end
        CreateThread(function()
            Gungame.respawn(data)
        end)
    end)
    RegisterNetEvent(Events.client.gungameLevel, function(data)
        if Gungame.isActive() then Gungame.setLevel(data.level, data.reason) end
    end)
    RegisterNetEvent(Events.client.gungameState, function(data)
        if Gungame.isActive() then Nui.send('gungameState', data) end
    end)
    RegisterNetEvent(Events.client.gungameKill, function(data)
        if Gungame.isActive() then Nui.send('gungameKill', data) end
    end)
    RegisterNetEvent(Events.client.gungameEnd, function(data)
        CreateThread(function()
            Gungame.finish(data)
        end)
    end)
    CreateThread(Gungame.loop)
end

---@return boolean une partie de Gungame est en cours pour ce joueur
function Gungame.isActive()
    return Gungame.match ~= nil and State.activity == Gungame.ACTIVITY
end

---@return string[] nom de l'arme de chaque niveau
function Gungame.levelLabels()
    local labels = {}
    for index, level in ipairs(Config.Gungame.levels) do labels[index] = level.label end
    return labels
end

-- ---------------------------------------------------------------------------
-- Partie
-- ---------------------------------------------------------------------------

---Arrivée dans la partie (lancement ou partie rejointe en cours).
---@param data table level, spawn, arena, countdown, remaining, outsideDamage, protection
function Gungame.start(data)
    Gungame.match = data
    State.activity = Gungame.ACTIVITY
    Gungame.level = data.level
    Gungame.lockedUntil = GetGameTimer() + data.countdown * 1000
    Nui.send('gungameHud', {
        open = true,
        levels = Gungame.levelLabels(),
        level = data.level,
        countdown = data.countdown,
        remaining = data.remaining,
    })

    Freeroam.setMenu(false)
    Freeroam.deleteVehicle()
    Gungame.drawArena(data.arena)
    Gungame.placeAt(data.spawn, data.countdown + data.protection)
end

---Réapparition après une mort (point choisi par le serveur, loin des autres joueurs).
---@param data { spawn: vector4, level: integer, protection: integer }
function Gungame.respawn(data)
    Gungame.level = data.level
    Gungame.placeAt(data.spawn, data.protection)
end

---Fondu, résurrection si besoin, placement au sol, vie, arme du niveau.
---@param spawn vector4
---@param protection integer secondes de protection affichées
function Gungame.placeAt(spawn, protection)
    DoScreenFadeOut(Gungame.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    Death.stopSpectate()
    if State.dead or IsEntityDead(PlayerPedId()) then
        NetworkResurrectLocalPlayer(spawn.x, spawn.y, spawn.z, spawn.w, true, false)
        State.dead = false
    end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then ClearPedTasksImmediately(ped) end
    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, PedUtils.findGroundZ(spawn.x, spawn.y, spawn.z), false, false, false)
    SetEntityHeading(ped, spawn.w)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, Config.Gungame.armor)
    ClearPedBloodDamage(ped)
    Gungame.giveWeapons(ped)
    Nui.send('gungameSpawn', { protection = protection })
    DoScreenFadeIn(Gungame.FADE)
end

---Arme du niveau en main, couteau en plus (sauf au dernier niveau, qui est le couteau).
---@param ped integer
function Gungame.giveWeapons(ped)
    RemoveAllPedWeapons(ped, true)
    local knife = GetHashKey(Config.Gungame.knife)
    local weapon = GetHashKey(Config.Gungame.levels[Gungame.level].weapon)
    if weapon ~= knife then GiveWeaponToPed(ped, knife, 0, false, false) end
    GiveWeaponToPed(ped, weapon, Gungame.AMMO, false, true)
    SetPedInfiniteAmmo(ped, true, weapon)
    SetCurrentPedWeapon(ped, weapon, true)
end

---Niveau changé par le serveur (kill, coup de couteau subi, suicide) : nouvelle arme tout de suite.
---@param level integer
---@param reason 'kill'|'knifed'|'suicide'
function Gungame.setLevel(level, reason)
    local up = level > Gungame.level
    Gungame.level = level
    Nui.send('gungameLevel', { level = level, reason = reason })
    PlaySoundFrontend(-1, up and 'RANK_UP' or 'LOSER', 'HUD_AWARDS', true)
    if not State.dead then Gungame.giveWeapons(PlayerPedId()) end
end

---@param arena { center: vector3, radius: number }
function Gungame.drawArena(arena)
    if Gungame.arenaBlip and DoesBlipExist(Gungame.arenaBlip) then RemoveBlip(Gungame.arenaBlip) end
    Gungame.arenaBlip = AddBlipForRadius(arena.center.x, arena.center.y, arena.center.z, arena.radius)
    SetBlipColour(Gungame.arenaBlip, 1)
    SetBlipAlpha(Gungame.arenaBlip, 80)
end

---Compte à rebours (commandes bloquées) et dégâts hors de la zone de combat.
function Gungame.loop()
    while true do
        if Gungame.isActive() then
            local now = GetGameTimer()
            if now < Gungame.lockedUntil then
                for _, control in ipairs(Gungame.LOCKED_CONTROLS) do DisableControlAction(0, control, true) end
            end
            Gungame.checkArena(now)
            Wait(0)
        else
            Wait(500)
        end
    end
end

---@param now integer
function Gungame.checkArena(now)
    if State.dead then return end
    local ped = PlayerPedId()
    local arena = Gungame.match.arena
    local outside = #(GetEntityCoords(ped).xy - arena.center.xy) > arena.radius
    if outside ~= Gungame.outside then
        Gungame.outside = outside
        Nui.send('gungameOutside', { outside = outside })
    end
    if outside and now >= Gungame.nextOutsideDamage then
        Gungame.nextOutsideDamage = now + 1000
        ApplyDamageToPed(ped, Gungame.match.outsideDamage, false)
    end
end

---Appelé à la mort (Freeroam.onDeath) : le serveur compte le kill et renvoie un point de réapparition.
function Gungame.onDeath()
    State.dead = true
    if Gungame.outside then
        Gungame.outside = false
        Nui.send('gungameOutside', { outside = false })
    end
    local ped = PlayerPedId()
    TriggerServerEvent(Events.server.gungameDied, PedUtils.getKillerServerId(ped), GetPedCauseOfDeath(ped))
end

-- ---------------------------------------------------------------------------
-- Fin
-- ---------------------------------------------------------------------------

---Fin de la partie : résultats, retour à la zone safe du Freeroam.
---@param data { result: string, reason: string, place: integer, players: integer, top: table[], spawn: vector4|nil, elo: table|nil }
function Gungame.finish(data)
    Nui.send('gungameHud', { open = false })
    Nui.send('gungameEnd', {
        result = data.result,
        reason = data.reason,
        place = data.place,
        players = data.players,
        top = data.top,
        elo = data.elo,
    })

    DoScreenFadeOut(Gungame.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    Death.stopSpectate()
    local spawn = data.spawn
    if spawn and (State.dead or IsEntityDead(PlayerPedId())) then
        NetworkResurrectLocalPlayer(spawn.x, spawn.y, spawn.z, spawn.w, true, false)
        State.dead = false
    end
    Gungame.cleanup()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 0)
    ClearPedBloodDamage(ped)
    RemoveAllPedWeapons(ped, true)
    Freeroam.restoreWeapons()
    if spawn then
        RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
        SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, PedUtils.findGroundZ(spawn.x, spawn.y, spawn.z), false, false, false)
        SetEntityHeading(ped, spawn.w)
    end
    DoScreenFadeIn(Gungame.FADE)
end

function Gungame.cleanup()
    if Gungame.arenaBlip and DoesBlipExist(Gungame.arenaBlip) then RemoveBlip(Gungame.arenaBlip) end
    Gungame.arenaBlip = nil
    Gungame.outside = false
    Gungame.lockedUntil = 0
    if Gungame.isActive() then State.activity = nil end
    Gungame.match = nil
end
