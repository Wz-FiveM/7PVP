---Classes du mode PvP, côté client : modificateurs de dégâts selon le monde (zombies ou PvP), radar de
---l'éclaireur, touche de la compétence et effets envoyés par le serveur (server/modules/classes/class_service.lua).
---@class ClassesModule
local Classes = PVP.define('Classes')
local ClassDefs = PVP.use('ClassDefs')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Callback = PVP.use('Callback')
local Effects = PVP.use('Effects')
local Pve = PVP.use('Pve')
local Group = PVP.use('Group')
local Clock = PVP.use('Clock')
local Zones = PVP.use('Zones')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Classes.PASSIVE_INTERVAL = 500
Classes.RADAR_INTERVAL = 1000
Classes.TRAP_INTERVAL = 500
Classes.ROAR_RING_TIME = 400 -- ms d'affichage de l'onde du rugissement
Classes.ROAR_SHAKE = 0.2
Classes.AIM_FLAGS = 1 + 2 + 4 + 8 + 16 -- carte, véhicules, personnages, objets
Classes.MARK_HEIGHT = 1.4 -- m au-dessus de la cible marquée
Classes.RING_COLOR = { 90, 200, 255, 140 }
Classes.MARK_COLOR = { 240, 195, 60, 200 }
Classes.ASSET_TIMEOUT = 3000

-- Effet reçu du serveur -> fonction de ce module
Classes.HANDLERS = {
    stun = 'onStun',
    trap = 'onTrap',
    smoke = 'onSmoke',
    antizin = 'onAntizin',
    heal = 'onHeal',
    mark = 'onMark',
    contract = 'onContract',
}

Classes.applied = false -- réglage de dégâts en place ('classe:monde'), false = aucun
Classes.busy = false
Classes.contractBlip = nil
---@type table<integer, integer> ped -> repère du radar
Classes.radarBlips = {}

function Classes.init()
    RegisterCommand('pvp_class_ability', function()
        Classes.useAbility()
    end, false)
    RegisterKeyMapping('pvp_class_ability', Locale.t('Compétence de classe (PvP)'), 'keyboard', Config.Classes.key)

    RegisterNetEvent(Events.client.classEffect, function(data)
        Classes.onEffect(data)
    end)
    CreateThread(Classes.passiveLoop)
    CreateThread(Classes.radarLoop)
end

---@return table|nil classe du joueur local
function Classes.current()
    local info = State.player and State.player.playerClass
    return info and ClassDefs.get(info.id) or nil
end

---@param damage integer
---@return integer dégâts d'un nuage toxique après le passif de classe (le vomi est calculé par le serveur)
function Classes.zombieDamage(damage)
    local class = State.inPvp() and Classes.current()
    if not class or not class.zombieDamage then return damage end
    return math.max(1, math.floor(damage * class.zombieDamage + 0.5))
end

-- ---------------------------------------------------------------------------
-- Modificateurs de dégâts
-- ---------------------------------------------------------------------------

function Classes.passiveLoop()
    while true do
        Wait(Classes.PASSIVE_INTERVAL)
        Classes.updateModifiers()
    end
end

---Les natifs ne visent pas une cible : c'est le monde du joueur qui sépare les zombies des joueurs,
---car il n'y a pas de PvP dans le monde zombies.
function Classes.updateModifiers()
    local class = State.inPvp() and Classes.current()
    local world = LocalPlayer.state.pveWorld == true and 'pve' or 'pvp'
    local wanted = class and class.modifiers and ('%s:%s'):format(class.id, world) or false
    if wanted == Classes.applied then return end
    Classes.applied = wanted

    local player = PlayerId()
    local modifiers = wanted and class.modifiers[world] or {}
    SetPlayerWeaponDefenseModifier(player, modifiers.defense or 1.0)
    -- En Call of Duty, ces deux réglages appartiennent aux atouts du mode
    if State.mode ~= 'cod' then
        SetPlayerWeaponDamageModifier(player, modifiers.damage or 1.0)
        SetPlayerMeleeWeaponDamageModifier(player, modifiers.melee or 1.0)
    end
end

-- ---------------------------------------------------------------------------
-- Radar de l'éclaireur
-- ---------------------------------------------------------------------------

function Classes.radarLoop()
    while true do
        Wait(Classes.RADAR_INTERVAL)
        Classes.updateRadar()
    end
end

function Classes.updateRadar()
    local class = State.inPvp() and State.isAlive() and Classes.current()
    local radar = class and class.radar
    local wanted = radar and not State.isInSafeZone() and Classes.radarTargets(radar) or {}

    for ped, blip in pairs(Classes.radarBlips) do
        if not wanted[ped] or not DoesBlipExist(blip) then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            Classes.radarBlips[ped] = nil
        end
    end
    for ped, style in pairs(wanted) do
        if not Classes.radarBlips[ped] then
            local blip = AddBlipForEntity(ped)
            SetBlipSprite(blip, style.sprite)
            SetBlipColour(blip, style.color)
            SetBlipScale(blip, style.scale)
            SetBlipAsShortRange(blip, true)
            Classes.radarBlips[ped] = blip
        end
    end
end

---@param radar table
---@return table<integer, table> ped -> style du repère : les joueurs d'abord, jusqu'à `max`
function Classes.radarTargets(radar)
    local coords = GetEntityCoords(PlayerPedId())
    local targets, count = {}, 0
    local me = PlayerId()
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if player ~= me and count < radar.max and Classes.isEnemyVisible(ped, GetPlayerServerId(player), coords, radar.range) then
            targets[ped] = radar.player
            count = count + 1
        end
    end
    for _, ped in ipairs(GetGamePool('CPed')) do
        if count >= radar.max then break end
        if not IsPedAPlayer(ped) and Entity(ped).state.pvpNpc and not IsPedDeadOrDying(ped, true)
            and #(GetEntityCoords(ped) - coords) <= radar.range then
            targets[ped] = radar.zombie
            count = count + 1
        end
    end
    return targets
end

---@param ped integer
---@param serverId integer
---@param coords vector3 position du joueur local
---@param range number
---@return boolean ennemi à portée, hors zone safe (les admins invisibles ne sont pas repérés)
function Classes.isEnemyVisible(ped, serverId, coords, range)
    if IsPedDeadOrDying(ped, true) or not IsEntityVisible(ped) or Classes.isAlly(serverId) then return false end
    local position = GetEntityCoords(ped)
    return #(position - coords) <= range and not Zones.isSafe(position, State.mode)
end

---@param serverId integer
---@return boolean
function Classes.isAlly(serverId)
    for _, member in ipairs(Group.data and Group.data.members or {}) do
        if member.id == serverId then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Touche de la compétence
-- ---------------------------------------------------------------------------

function Classes.useAbility()
    if Classes.busy or not State.inPvp() or not State.isAlive() or State.menuOpen then return end
    Classes.busy = true
    CreateThread(function()
        local class = Classes.current()
        local ability = class and class.ability
        local payload = ability and ability.id == 'mark' and Classes.aimedTarget(ability.range) or nil
        local result = Callback.await(Events.callbacks.classUse, payload)
        Classes.busy = false
        if not result then return end
        if result.message then Nui.notify(result.message, result.ok and 'success' or 'error') end
        if result.ok and ability.nightVision and Clock.isNight() then Classes.runNightVision(ability.duration) end
    end)
end

---@param range number
---@return { x: number, y: number, z: number, netId: integer|nil }|nil ce que le joueur vise
function Classes.aimedTarget(range)
    local from = GetGameplayCamCoord()
    local rotation = GetGameplayCamRot(2)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local to = from + vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch)) * range

    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, Classes.AIM_FLAGS, PlayerPedId(), 7)
    local _, hit, coords, _, entity = GetShapeTestResult(ray)
    if hit ~= 1 then return nil end

    local target = { x = coords.x, y = coords.y, z = coords.z }
    if entity ~= 0 and IsEntityAPed(entity) and NetworkGetEntityIsNetworked(entity) then
        target.netId = NetworkGetNetworkIdFromEntity(entity)
    end
    return target
end

---@param duration integer secondes
function Classes.runNightVision(duration)
    SetNightvision(true)
    local endsAt = GetGameTimer() + duration * 1000
    while GetGameTimer() < endsAt and State.inPvp() and State.isAlive() do Wait(250) end
    SetNightvision(false)
end

-- ---------------------------------------------------------------------------
-- Effets envoyés par le serveur
-- ---------------------------------------------------------------------------

---@param data any
function Classes.onEffect(data)
    if type(data) ~= 'table' then return end
    -- Toujours traité : le repère doit disparaître même si le joueur vient de quitter le mode
    if data.type == 'contractEnd' then return Classes.onContractEnd() end
    if not State.inPvp() then return end
    local handler = Classes[Classes.HANDLERS[data.type]]
    if handler then handler(data) end
end

---@param coords vector3
---@param radius number
---@param color integer[]
function Classes.drawRing(coords, radius, color)
    DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, radius * 2.0, radius * 2.0, 0.6,
        color[1], color[2], color[3], color[4], false, false, 2, false, nil, nil, false)
end

---Rugissement : renverse les zombies dont ce client est propriétaire, onde visible par tous.
---@param data table
function Classes.onStun(data)
    local coords = vector3(data.x, data.y, data.z)
    Pve.stunArea(coords, data.radius, data.stun, data.push)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', Classes.ROAR_SHAKE)
    CreateThread(function()
        local endsAt = GetGameTimer() + Classes.ROAR_RING_TIME
        while GetGameTimer() < endsAt do
            Classes.drawRing(coords, data.radius, Classes.RING_COLOR)
            Wait(0)
        end
    end)
end

---Piège électrique : bloque les zombies qui y entrent tant qu'il est actif.
---@param data table
function Classes.onTrap(data)
    local coords = vector3(data.x, data.y, data.z)
    CreateThread(function()
        local endsAt = GetGameTimer() + data.duration * 1000
        local nextStun = 0
        while GetGameTimer() < endsAt and State.inPvp() do
            local now = GetGameTimer()
            if now >= nextStun then
                nextStun = now + Classes.TRAP_INTERVAL
                Pve.stunArea(coords, data.radius, data.stun, 0.0)
            end
            Classes.drawRing(coords, data.radius, Classes.RING_COLOR)
            Wait(0)
        end
    end)
end

---Fumée sans dégâts : particules locales à chaque client, aucune explosion côté serveur.
---@param data table
function Classes.onSmoke(data)
    CreateThread(function()
        local particle = data.particle
        RequestNamedPtfxAsset(particle.asset)
        local limit = GetGameTimer() + Classes.ASSET_TIMEOUT
        while not HasNamedPtfxAssetLoaded(particle.asset) and GetGameTimer() < limit do Wait(0) end
        if not HasNamedPtfxAssetLoaded(particle.asset) then return end

        UseParticleFxAssetNextCall(particle.asset)
        local effect = StartParticleFxLoopedAtCoord(particle.name, data.x, data.y, data.z, 0.0, 0.0, 0.0,
            particle.scale, false, false, false, false)
        Wait(data.duration * 1000)
        StopParticleFxLooped(effect, false)
    end)
end

---@param data table
function Classes.onAntizin(data)
    Effects.start({ id = 'antizin', duration = tonumber(data.duration) or 0 })
end

---@param data table
function Classes.onHeal(data)
    local ped = PlayerPedId()
    if not State.isAlive() then return end
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + (tonumber(data.amount) or 0)))
end

---@param data table
function Classes.onMark(data)
    CreateThread(function()
        Classes.showMark(data)
    end)
end

---Repère sur la carte et flèche à l'écran : suit la cible marquée si elle est chargée, sinon reste au point.
---@param data table
function Classes.showMark(data)
    local entity = data.netId and NetworkDoesNetworkIdExist(data.netId) and NetworkGetEntityFromNetworkId(data.netId) or 0
    local point = vector3(data.x, data.y, data.z)
    local blip = entity ~= 0 and AddBlipForEntity(entity) or AddBlipForCoord(point.x, point.y, point.z)
    SetBlipSprite(blip, data.blip.sprite)
    SetBlipColour(blip, data.blip.color)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Locale.t('Cible marquée'))
    EndTextCommandSetBlipName(blip)

    local color = Classes.MARK_COLOR
    local endsAt = GetGameTimer() + data.duration * 1000
    while GetGameTimer() < endsAt and State.inPvp() do
        local coords = entity ~= 0 and DoesEntityExist(entity) and GetEntityCoords(entity) or point
        DrawMarker(2, coords.x, coords.y, coords.z + Classes.MARK_HEIGHT, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.5, 0.5, 0.5,
            color[1], color[2], color[3], color[4], true, true, 2, false, nil, nil, false)
        Wait(0)
    end
    if DoesBlipExist(blip) then RemoveBlip(blip) end
end

---Position de la cible d'un contrat : un repère au point envoyé (elle peut être trop loin pour être chargée).
---@param data table
function Classes.onContract(data)
    if Classes.contractBlip and DoesBlipExist(Classes.contractBlip) then
        SetBlipCoords(Classes.contractBlip, data.x, data.y, data.z)
        return
    end
    local blip = AddBlipForCoord(data.x, data.y, data.z)
    SetBlipSprite(blip, data.blip.sprite)
    SetBlipColour(blip, data.blip.color)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Locale.t('Contrat : %s', data.name))
    EndTextCommandSetBlipName(blip)
    Classes.contractBlip = blip
end

function Classes.onContractEnd()
    if Classes.contractBlip and DoesBlipExist(Classes.contractBlip) then RemoveBlip(Classes.contractBlip) end
    Classes.contractBlip = nil
end
