---Donjon côté client : objets du parcours, repères, actions, tirs sur les murs, boss et interface.
---Le serveur décide de tout (voir server/modules/dungeon) : ce module affiche l'état reçu et lui
---envoie ce que fait le joueur. Les objets sont locaux : chaque joueur de la salle a les siens.
---@class DungeonModule
local Dungeon = PVP.define('Dungeon')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local HelpNotify = PVP.use('HelpNotify')
local Callback = PVP.use('Callback')
local Pve = PVP.use('Pve')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Dungeon.CONTROL = 38 -- E
Dungeon.MODEL_TIMEOUT = 3000
Dungeon.HOLD_SCENARIO = 'WORLD_HUMAN_WELDING'
Dungeon.DRAW_DISTANCE = 60.0
Dungeon.WALL_SEND_INTERVAL = 500
Dungeon.WALL_SHOT_INTERVAL = 60 -- une balle compte une fois, même si le tir dure plusieurs images
Dungeon.PLACE_DISTANCE = 40.0 -- les objets ne sont créés qu'à portée : le sol et la salle doivent être chargés
Dungeon.PLACE_TRIES = 300
Dungeon.SNAP_DISTANCE = 12.0 -- au-delà, un zombie n'est plus dans la salle prévue
Dungeon.SNAP_HEIGHT = 3.0 -- ni au bon étage
Dungeon.SNAP_NEAR_PLAYER = 10.0
Dungeon.TORCH_RANGE = 10.0 -- courant coupé : le noir serait complet sous terre
Dungeon.TORCH_INTENSITY = 1.5
Dungeon.BOSS_RETASK = 2000

---@type table|false état reçu du serveur
Dungeon.state = false
---@type table<string, { entity: integer|nil, data: table, placed: boolean }>
Dungeon.props = {}
Dungeon.blips = {}
Dungeon.holding = false
Dungeon.wallHits = 0
Dungeon.wallSentAt = 0
Dungeon.wallShotAt = 0
Dungeon.endsAt = 0
Dungeon.progress = false
Dungeon.bossConfigured = {} -- [ped] = true quand ce client l'a armé
Dungeon.bossTask = {} -- [ped] = dernier ordre de combat (ms)
---@type integer[] intérieurs gardés chargés
Dungeon.interiors = {}
---@type table<integer, integer> portes du décor ouvertes : [entité] = identifiant dans le système de portes
Dungeon.openDoors = {}
---@type table<integer, boolean> [modèle] = c'est une porte
Dungeon.doorModels = {}

function Dungeon.init()
    RegisterNetEvent(Events.client.dungeonState, function(data)
        Dungeon.onState(data)
    end)
    RegisterNetEvent(Events.client.dungeonExplosion, function(points)
        Dungeon.explode(points)
    end)

    RegisterCommand('donjon', function(_, args)
        Dungeon.command(args[1])
    end, false)
    RegisterCommand('dungeon', function(_, args)
        Dungeon.command(args[1])
    end, false)

    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then Dungeon.clear() end
    end)

    CreateThread(Dungeon.loop)
    CreateThread(Dungeon.doorLoop)
end

---@param word string|nil
function Dungeon.command(word)
    CreateThread(function()
        local result = Callback.await(Events.callbacks.dungeonCommand, word)
        if result and result.message then
            Nui.notify(result.message, result.ok and 'success' or 'error')
        end
    end)
end

-- ---------------------------------------------------------------------------
-- État
-- ---------------------------------------------------------------------------

---@param data table|false
function Dungeon.onState(data)
    Dungeon.state = type(data) == 'table' and data or false
    if not Dungeon.state then return Dungeon.clear() end

    Dungeon.endsAt = GetGameTimer() + data.endsIn * 1000
    if data.step then
        -- Les zombies sans cible errent autour de la salle en cours
        Config.Dungeon.zone.coords = data.step.coords
        Dungeon.loadInteriors()
        Dungeon.syncProps(data.props)
        Dungeon.syncBlips(data)
        SetArtificialLightsState(data.dark == true)
        SetArtificialLightsStateAffectsVehicles(false)
    end
    Dungeon.sendHud()
end

---Sortie du donjon : décor retiré, lumières rendues.
function Dungeon.clear()
    Dungeon.state = false
    Dungeon.syncProps({})
    Dungeon.removeBlips()
    Dungeon.releaseInteriors()
    Dungeon.closeDoors()
    SetArtificialLightsState(false)
    Nui.send('dungeon', { dungeon = false })
end

---Les salles du parcours restent chargées tant que le joueur est dans le donjon.
function Dungeon.loadInteriors()
    if #Dungeon.interiors > 0 then return end
    for _, origin in ipairs(Config.Dungeon.interiors) do
        local interior = GetInteriorAtCoords(origin.x, origin.y, origin.z)
        if interior == 0 then
            print(('[donjon] intérieur introuvable en %.1f, %.1f, %.1f'):format(origin.x, origin.y, origin.z))
        else
            Dungeon.interiors[#Dungeon.interiors + 1] = interior
            DisableInterior(interior, false)
            CapInterior(interior, false)
            PinInteriorInMemory(interior)
        end
    end
end

function Dungeon.releaseInteriors()
    for _, interior in ipairs(Dungeon.interiors) do UnpinInterior(interior) end
    Dungeon.interiors = {}
end

---@return boolean dans l'instance (la nuit y est imposée, voir ClockClient)
function Dungeon.isInside()
    return Dungeon.state ~= false and Dungeon.state.step ~= nil
end

---Coffre personnel à portée : le menu l'affiche comme le banquier (Nui.sendMenuState).
---@param coords vector3
---@return boolean
function Dungeon.isAtChest(coords)
    if not Dungeon.isInside() then return false end
    for _, chest in ipairs(Dungeon.state.chests or {}) do
        if #(coords - chest) <= Config.Dungeon.chestDistance then return true end
    end
    return false
end

---@return table|false données du HUD
function Dungeon.buildHud()
    local state = Dungeon.state
    if not state then return false end
    local data = {
        status = state.status,
        players = state.players,
        maxPlayers = state.maxPlayers,
        leader = state.leader,
        lives = state.lives,
        maxLives = state.maxLives,
        endsIn = math.max(0, math.ceil((Dungeon.endsAt - GetGameTimer()) / 1000)),
        progress = Dungeon.progress or nil,
    }
    local step = state.step
    if not step then return data end

    data.objective = Locale.t(step.objective)
    data.hint = step.hint and Locale.t(step.hint) or nil
    if step.quota then
        data.subtitle = Locale.t('Zombies tués : %d/%d · Joueurs terminés : %d/%d', math.min(step.kills, step.quota), step.quota, step.done, state.players)
    elseif step.type == 'plant' then
        data.subtitle = state.fuseIn and Locale.t('Explosion imminente : éloigne-toi !')
            or Locale.t('Charges à poser : %d', #step.targets)
    end
    if step.bar then
        data.bar = { label = Locale.t(step.bar.label), value = step.bar.value, max = step.bar.max }
    end
    return data
end

function Dungeon.sendHud()
    Nui.send('dungeon', { dungeon = Dungeon.buildHud() })
end

-- ---------------------------------------------------------------------------
-- Décor
-- ---------------------------------------------------------------------------

---@param wanted table[] { key, model, coords, small }
function Dungeon.syncProps(wanted)
    local keys = {}
    for _, data in ipairs(wanted) do
        keys[data.key] = true
        if not Dungeon.props[data.key] then
            Dungeon.props[data.key] = { data = data, requested = false, placed = false, tries = 0 }
        end
    end
    for key, prop in pairs(Dungeon.props) do
        if not keys[key] then
            if prop.entity and DoesEntityExist(prop.entity) then DeleteObject(prop.entity) end
            Dungeon.props[key] = nil
        end
    end
end

---Un modèle absent du jeu ne bloque rien : le repère de l'étape reste affiché.
---@param key string
function Dungeon.createProp(key)
    local prop = Dungeon.props[key]
    local model = GetHashKey(prop.data.model)
    if not IsModelInCdimage(model) then return end
    RequestModel(model)
    local timeout = GetGameTimer() + Dungeon.MODEL_TIMEOUT
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    -- Retiré pendant le chargement
    if Dungeon.props[key] ~= prop or not HasModelLoaded(model) then return end

    local coords = prop.data.coords
    prop.entity = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(prop.entity, coords.w)
    FreezeEntityPosition(prop.entity, true)
    SetModelAsNoLongerNeeded(model)
end

---Créé de loin, un objet resterait hors de la salle et invisible : il n'apparaît qu'à portée, puis
---il est posé sur le sol une fois celui-ci chargé.
---@param pos vector3
function Dungeon.placeProps(pos)
    for key, prop in pairs(Dungeon.props) do
        if not prop.placed and #(pos - prop.data.coords.xyz) < Dungeon.PLACE_DISTANCE then
            if not prop.requested then
                prop.requested = true
                CreateThread(function()
                    Dungeon.createProp(key)
                end)
            elseif prop.entity then
                prop.tries = prop.tries + 1
                prop.placed = PlaceObjectOnGroundProperly(prop.entity) or prop.tries >= Dungeon.PLACE_TRIES
            end
        end
    end
end

function Dungeon.removeBlips()
    for _, blip in ipairs(Dungeon.blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    Dungeon.blips = {}
end

---Repères de l'objectif ; un objet caché n'en a qu'une fois révélé.
---@param state table
function Dungeon.syncBlips(state)
    Dungeon.removeBlips()
    local settings = Config.Dungeon.blip
    local points = {}
    for _, target in ipairs(state.step.targets) do
        if not target.hidden then points[#points + 1] = target.coords end
    end
    if state.step.wall then points[#points + 1] = state.step.wall end
    if #points == 0 then points[1] = state.step.coords end

    for _, point in ipairs(points) do
        local blip = AddBlipForCoord(point.x, point.y, point.z)
        SetBlipSprite(blip, settings.sprite)
        SetBlipColour(blip, settings.color)
        SetBlipRoute(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Locale.t(state.step.objective))
        EndTextCommandSetBlipName(blip)
        Dungeon.blips[#Dungeon.blips + 1] = blip
    end
end

---La porte du coffre-fort saute : l'explosion ne fait aucun dégât, le jeu la transmet à la salle.
---@param points vector3[]
function Dungeon.explode(points)
    local settings = Config.Dungeon.explosion
    for _, point in ipairs(points) do
        AddExplosion(point.x, point.y, point.z, settings.type, 0.0, true, false, settings.shake)
    end
end

-- ---------------------------------------------------------------------------
-- Boucle
-- ---------------------------------------------------------------------------

function Dungeon.loop()
    while true do
        if Dungeon.isInside() then
            Dungeon.frame(Dungeon.state)
            Wait(0)
        else
            Wait(500)
        end
    end
end

---@param state table
function Dungeon.frame(state)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    Dungeon.placeProps(pos)
    if state.dark then
        DrawLightWithRange(pos.x, pos.y, pos.z + 0.6, 255, 235, 205, Dungeon.TORCH_RANGE, Dungeon.TORCH_INTENSITY)
    end
    Dungeon.drawTargets(state.step, pos)
    if state.step.type == 'destroy' then Dungeon.watchWall(state.step, ped) end
    if not State.isAlive() or State.menuOpen or IsNuiFocused() or Dungeon.holding then return end

    local target = Dungeon.nearestTarget(state.step, pos)
    if target then return Dungeon.promptTarget(state.step, target) end
    if Dungeon.isAtChest(pos) then
        HelpNotify.show(HelpNotify.controlKey(Dungeon.CONTROL), Locale.t('Ouvrir ton coffre'))
        if IsControlJustReleased(0, Dungeon.CONTROL) then Nui.setMenu(true, 'inventory') end
    end
end

---@param step table
---@param pos vector3
function Dungeon.drawTargets(step, pos)
    for _, target in ipairs(step.targets) do
        local point = target.coords
        local distance = #(pos - point.xyz)
        -- Un objet caché ne se voit que de près, jusqu'à ce que la carte l'indique
        local range = target.hidden and 6.0 or Dungeon.DRAW_DISTANCE
        if distance < range then
            DrawMarker(1, point.x, point.y, point.z - 1.0, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.6,
                255, 200, 60, 150, false, false, 2, false, nil, nil, false)
        end
    end
end

---@param step table
---@param pos vector3
---@return table|nil cible à portée d'action
function Dungeon.nearestTarget(step, pos)
    local best, bestDistance = nil, Config.Dungeon.interactDistance
    for _, target in ipairs(step.targets) do
        local distance = #(pos - target.coords.xyz)
        if distance <= bestDistance then best, bestDistance = target, distance end
    end
    return best
end

-- Texte de l'action, par sorte d'étape
Dungeon.PROMPTS = {
    fetch = 'Ramasser',
    use = 'Utiliser',
    repair = 'Réparer (maintenir)',
    plant = 'Poser le C4 (maintenir)',
}

---@param step table
---@param target table
function Dungeon.promptTarget(step, target)
    HelpNotify.show(HelpNotify.controlKey(Dungeon.CONTROL), Locale.t(Dungeon.PROMPTS[step.type]))
    if (step.hold or 0) > 0 then
        if IsControlJustPressed(0, Dungeon.CONTROL) then
            Dungeon.holding = true
            CreateThread(function()
                Dungeon.hold(step, target)
                Dungeon.holding = false
            end)
        end
    elseif IsControlJustReleased(0, Dungeon.CONTROL) then
        CreateThread(function()
            Dungeon.finishAction(target)
        end)
    end
end

---@param target table
function Dungeon.finishAction(target)
    local result = Callback.await(Events.callbacks.dungeonAction, 'finish', target.index)
    if result and result.message then Nui.notify(result.message, 'error') end
end

---Maintenir E : la barre se remplit ; lâcher, s'éloigner ou mourir fait tout perdre.
---@param step table
---@param target table
function Dungeon.hold(step, target)
    local result = Callback.await(Events.callbacks.dungeonAction, 'start', target.index)
    if not result or not result.ok then
        if result and result.message then Nui.notify(result.message, 'error') end
        return
    end

    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, Dungeon.HOLD_SCENARIO, 0, true)
    Dungeon.progress = { label = Locale.t(Dungeon.PROMPTS[step.type]), seconds = step.hold }
    Dungeon.sendHud()

    local finish = GetGameTimer() + step.hold * 1000
    local done = true
    while GetGameTimer() < finish do
        Wait(0)
        if not IsControlPressed(0, Dungeon.CONTROL) or not State.isAlive() or not Dungeon.isInside()
            or #(GetEntityCoords(ped) - target.coords.xyz) > Config.Dungeon.interactDistance + 1.0 then
            done = false
            break
        end
    end

    ClearPedTasks(ped)
    Dungeon.progress = false
    Dungeon.sendHud()
    if done then Dungeon.finishAction(target) end
end

---Balles du joueur sur le mur, envoyées par paquet.
---@param step table
---@param ped integer
function Dungeon.watchWall(step, ped)
    local now = GetGameTimer()
    if IsPedShooting(ped) and now - Dungeon.wallShotAt >= Dungeon.WALL_SHOT_INTERVAL then
        local hit, impact = GetPedLastWeaponImpactCoord(ped)
        if hit and #(impact - step.wall.xyz) <= step.hitRadius then
            Dungeon.wallShotAt = now
            Dungeon.wallHits = Dungeon.wallHits + 1
        end
    end
    if Dungeon.wallHits > 0 and now - Dungeon.wallSentAt >= Dungeon.WALL_SEND_INTERVAL then
        Dungeon.wallSentAt = now
        TriggerServerEvent(Events.server.dungeonWallHit, Dungeon.wallHits)
        Dungeon.wallHits = 0
    end
end

-- ---------------------------------------------------------------------------
-- Portes du décor : fermées d'origine dans ces intérieurs, ouvertes pour ce client
-- ---------------------------------------------------------------------------

---Le jeu ne dit pas ce qui est une porte, et leurs modèles sont trop nombreux : on regarde la forme.
---@param model integer
---@return boolean
function Dungeon.isDoorModel(model)
    local known = Dungeon.doorModels[model]
    if known ~= nil then return known end

    local settings = Config.Dungeon.doors
    local isDoor = false
    local closed = false
    for _, name in ipairs(settings.keepClosed) do
        if GetHashKey(name) == model then closed = true end
    end
    if not closed then
        local low, high = GetModelDimensions(model)
        local size = high - low
        local thickness = math.min(size.x, size.y)
        local width = math.max(size.x, size.y)
        isDoor = thickness <= settings.maxThickness
            and width >= settings.width[1] and width <= settings.width[2]
            and size.z >= settings.height[1] and size.z <= settings.height[2]
    end
    Dungeon.doorModels[model] = isDoor
    return isDoor
end

---@param entity integer
function Dungeon.openDoor(entity)
    local coords = GetEntityCoords(entity)
    local model = GetEntityModel(entity)
    local door = GetHashKey(('dungeon_door_%d_%d_%d'):format(math.floor(coords.x * 10), math.floor(coords.y * 10), model))
    AddDoorToSystem(door, model, coords.x, coords.y, coords.z, false, false, false)
    DoorSystemSetDoorState(door, 0, false, true)
    DoorSystemSetOpenRatio(door, 1.0, false, true)
    -- Même si le système refuse la porte, on doit pouvoir passer
    SetEntityCollision(entity, false, false)
    Dungeon.openDoors[entity] = door
end

function Dungeon.scanDoors()
    local mine = {}
    for _, prop in pairs(Dungeon.props) do
        if prop.entity then mine[prop.entity] = true end
    end
    local pos = GetEntityCoords(PlayerPedId())
    for _, entity in ipairs(GetGamePool('CObject')) do
        if not mine[entity] and not Dungeon.openDoors[entity]
            and #(GetEntityCoords(entity) - pos) <= Config.Dungeon.doors.range
            and Dungeon.isDoorModel(GetEntityModel(entity)) then
            Dungeon.openDoor(entity)
        end
    end
    for entity, door in pairs(Dungeon.openDoors) do
        if not DoesEntityExist(entity) then
            RemoveDoorFromSystem(door)
            Dungeon.openDoors[entity] = nil
        end
    end
end

---Hors du donjon, le décor redevient celui du jeu.
function Dungeon.closeDoors()
    for entity, door in pairs(Dungeon.openDoors) do
        RemoveDoorFromSystem(door)
        if DoesEntityExist(entity) then SetEntityCollision(entity, true, true) end
    end
    Dungeon.openDoors = {}
end

function Dungeon.doorLoop()
    while true do
        if Dungeon.isInside() then Dungeon.scanDoors() end
        Wait(Config.Dungeon.doors.interval)
    end
end

-- ---------------------------------------------------------------------------
-- Zombies : posés une fois sur le sol de la salle par le client propriétaire
-- ---------------------------------------------------------------------------

---Le serveur ne connaît pas les murs : un point d'apparition peut tomber dans une cloison ou dans le
---vide. Le zombie rejoint le point de marche le plus proche, ou à défaut les abords du joueur.
---@param ped integer
function Dungeon.settlePed(ped)
    local state = Entity(ped).state
    if state.dungeonSettled then return end
    state:set('dungeonSettled', true, true)

    local pos = GetEntityCoords(ped)
    local safe, point = GetSafeCoordForPed(pos.x, pos.y, pos.z, true, 16)
    if not safe or #(point - pos) > Dungeon.SNAP_DISTANCE or math.abs(point.z - pos.z) > Dungeon.SNAP_HEIGHT then
        local player = GetEntityCoords(PlayerPedId())
        local angle = math.random() * math.pi * 2
        safe, point = GetSafeCoordForPed(player.x + math.cos(angle) * Dungeon.SNAP_NEAR_PLAYER,
            player.y + math.sin(angle) * Dungeon.SNAP_NEAR_PLAYER, player.z, true, 16)
    end
    if safe then SetEntityCoords(ped, point.x, point.y, point.z, false, false, false, false) end
end

-- ---------------------------------------------------------------------------
-- Boss : piloté par le client propriétaire, depuis la boucle des zombies (Pve.updatePed)
-- ---------------------------------------------------------------------------

---@param ped integer
function Dungeon.driveBoss(ped)
    local state = Entity(ped).state
    -- La vie n'est appliquée qu'une fois, sinon un changement de propriétaire la remettrait au max
    if not state.pvpNpcReady and state.dungeonBoss then
        local health = 100 + state.dungeonBoss
        SetPedMaxHealth(ped, health)
        SetEntityHealth(ped, health)
        SetPedArmour(ped, Config.Dungeon.boss.armour)
        state:set('pvpNpcReady', true, true)
    end
    if not Dungeon.bossConfigured[ped] then
        Dungeon.bossConfigured[ped] = true
        Dungeon.setupBoss(ped)
    end

    local now = GetGameTimer()
    if now - (Dungeon.bossTask[ped] or 0) < Dungeon.BOSS_RETASK then return end
    Dungeon.bossTask[ped] = now
    local target = Pve.findTarget(ped)
    if target then TaskCombatPed(ped, target.ped, 0, 16) end
end

---@param ped integer
function Dungeon.setupBoss(ped)
    local settings = Config.Dungeon.boss
    SetPedRelationshipGroupHash(ped, Pve.npcGroup)
    GiveWeaponToPed(ped, GetHashKey(settings.weapon), 9999, false, true)
    SetPedInfiniteAmmo(ped, true, GetHashKey(settings.weapon))
    SetPedAccuracy(ped, settings.accuracy)
    SetPedCombatAttributes(ped, 46, true) -- se bat jusqu'au bout
    SetPedCombatAttributes(ped, 0, true) -- se met à couvert
    SetPedFleeAttributes(ped, 0, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedSuffersCriticalHits(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedConfigFlag(ped, 281, true)
end
