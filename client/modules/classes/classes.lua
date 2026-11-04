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
local Fall = PVP.use('Fall')
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
    frenzy = 'onFrenzy',
    blast = 'onBlast',
}
-- Groupes d'armes que les classes peuvent viser (weaponGroups dans config/classes.lua)
Classes.WEAPON_GROUPS = { 'GROUP_MELEE', 'GROUP_UNARMED', 'GROUP_SHOTGUN', 'GROUP_SNIPER', 'GROUP_HEAVY', 'GROUP_THROWN' }

Classes.applied = false -- réglage de dégâts en place, false = aucun
Classes.busy = false
Classes.ragdollBlocked = false
Classes.frenzyUntil = 0 -- ms de fin de la Frénésie
Classes.frenzyMelee = 1.0
---@type table<integer, string> hash non signé -> nom du groupe d'armes
Classes.weaponGroups = {}
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
    for _, name in ipairs(Classes.WEAPON_GROUPS) do
        Classes.weaponGroups[GetHashKey(name) & 0xFFFFFFFF] = name
    end
    CreateThread(Classes.passiveLoop)
    CreateThread(Classes.speedLoop)
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
        Classes.updateKnockback(State.inPvp() and Classes.current())
    end
end

---Les natifs ne visent pas une cible : c'est le monde du joueur qui sépare les zombies des joueurs,
---car il n'y a pas de PvP dans le monde zombies. Ils ne connaissent pas non plus la portée ni le
---nombre de cibles : les dégâts à distance et de zone dépendent de l'arme en main.
function Classes.updateModifiers()
    local class = State.inPvp() and Classes.current()
    local inPve = LocalPlayer.state.pveWorld == true
    local group = class and Classes.weaponGroup(PlayerPedId())
    local frenzy = class and Classes.frenzyUntil > GetGameTimer() and Classes.frenzyMelee or 1.0
    local wanted = class and ('%s:%s:%s:%s'):format(class.id, inPve, group, frenzy) or false
    if wanted == Classes.applied then return end
    Classes.applied = wanted
    -- En Seven of Duty, ces réglages appartiennent aux atouts du mode
    if State.mode == 'cod' then return end

    local player = PlayerId()
    SetPlayerWeaponDamageModifier(player, class and Classes.weaponDamage(class, inPve, group) or 1.0)
    SetPlayerMeleeWeaponDamageModifier(player, class and Classes.meleeDamage(class, inPve) * frenzy or 1.0)
end

---@param ped integer
---@return string|nil groupe de l'arme en main, seulement parmi Classes.WEAPON_GROUPS
function Classes.weaponGroup(ped)
    return Classes.weaponGroups[GetWeapontypeGroup(GetSelectedPedWeapon(ped)) & 0xFFFFFFFF]
end

---@param class table
---@param inPve boolean
---@param group string|nil
---@return number multiplicateur de l'arme en main
function Classes.weaponDamage(class, inPve, group)
    -- Le corps à corps a son propre réglage : ne pas l'appliquer deux fois
    if group == 'GROUP_MELEE' or group == 'GROUP_UNARMED' then return 1.0 end
    local damage = class.weaponGroups and class.weaponGroups[group] or class.damage or 1.0
    return damage * (not inPve and class.playerDamage or 1.0)
end

---@param class table
---@param inPve boolean
---@return number multiplicateur du corps à corps
function Classes.meleeDamage(class, inPve)
    return (class.melee or class.damage or 1.0) * (not inPve and class.playerDamage or 1.0)
end

---@return integer santé GTA maximale du joueur local, selon sa classe en mode PvP
function Classes.maxHealth()
    return ClassDefs.maxHealth(State.inPvp() and Classes.current() or nil)
end

---@param amount integer soin d'un consommable
---@return integer soin après le passif de classe
function Classes.healAmount(amount)
    local class = State.inPvp() and Classes.current()
    if not class or not class.healBonus then return amount end
    return math.floor(amount * class.healBonus + 0.5)
end

---Un ped sans ragdoll fige le véhicule où il monte : la protection ne vaut qu'à pied, et Fall garde la main en chute.
---@param class table|false|nil
function Classes.updateKnockback(class)
    if class and class.noKnockback and State.isAlive() and not Fall.active then
        local ped = PlayerPedId()
        SetPedCanRagdoll(ped, Fall.inVehicle(ped))
        Classes.ragdollBlocked = true
    elseif Classes.ragdollBlocked then
        Classes.ragdollBlocked = false
        if not Fall.active then SetPedCanRagdoll(PlayerPedId(), true) end
    end
end

---La vitesse doit être imposée à chaque image, et seulement pour une classe qui la change.
function Classes.speedLoop()
    while true do
        local class = State.inPvp() and State.isAlive() and Classes.current()
        if class and class.speed and class.speed ~= 100 then
            SetPedMoveRateOverride(PlayerPedId(), class.speed / 100)
            Wait(0)
        else
            Wait(Classes.PASSIVE_INTERVAL)
        end
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
        local payload = ability and ability.aimed and Classes.aimedTarget(ability.range) or nil
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
function Classes.onFrenzy(data)
    Classes.frenzyUntil = GetGameTimer() + data.duration * 1000
    Classes.frenzyMelee = data.melee
    Classes.updateModifiers()
end

---Charge explosive : l'explosion porte le nom du lanceur, pour lui compter les zombies tués.
---@param data table
function Classes.onBlast(data)
    local explosion = data.explosion
    AddOwnedExplosion(PlayerPedId(), data.x, data.y, data.z, explosion.type, explosion.damage, true, false, explosion.shake)
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
