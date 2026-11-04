---Donjon côté client : menu de James, objets du parcours, tirs sur les portes et les bonbonnes, et interface.
---Le serveur décide de tout (voir server/modules/dungeon) : ce module affiche l'état reçu et lui
---envoie ce que fait le joueur. Les objets sont locaux : chaque joueur de la salle a les siens.
---@class DungeonModule
local Dungeon = PVP.define('Dungeon')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')
local PedUtils = PVP.use('PedUtils')

Dungeon.MODEL_TIMEOUT = 3000
Dungeon.WALL_SEND_INTERVAL = 500
Dungeon.SHOT_INTERVAL = 60 -- une balle compte une fois, même si le tir dure plusieurs images
Dungeon.BARREL_RESEND = 1000 -- le serveur peut avoir manqué le tir : on peut retoucher la bonbonne
Dungeon.PLACE_DISTANCE = 40.0 -- les objets ne sont créés qu'à portée : le sol et la salle doivent être chargés
Dungeon.PLACE_TRIES = 300
Dungeon.SNAP_DISTANCE = 12.0 -- au-delà, un zombie n'est plus dans la salle prévue
Dungeon.SNAP_HEIGHT = 3.0 -- ni au bon étage
Dungeon.SNAP_NEAR_PLAYER = 10.0
Dungeon.FLOOR_OFFSET = 0.5 -- un objet est créé un peu au-dessus du sol, puis posé dessus

---@type table|false état reçu du serveur
Dungeon.state = false
---@type table<string, { entity: integer|nil, data: table, placed: boolean }>
Dungeon.props = {}
Dungeon.blips = {}
Dungeon.wallHits = 0
Dungeon.wallSentAt = 0
Dungeon.shotAt = 0
Dungeon.barrelSentAt = {} -- [numéro de bonbonne] = dernier envoi (ms)
Dungeon.endsAt = 0
Dungeon.menuOpen = false
---@type integer[] intérieurs gardés chargés
Dungeon.interiors = {}

function Dungeon.init()
    RegisterNetEvent(Events.client.dungeonState, function(data)
        Dungeon.onState(data)
    end)
    RegisterNetEvent(Events.client.dungeonExplosion, function(points, damage)
        Dungeon.explode(points, damage)
    end)

    RegisterCommand('donjon', function(_, args)
        Dungeon.command(args[1], args[2])
    end, false)
    RegisterCommand('dungeon', function(_, args)
        Dungeon.command(args[1], args[2])
    end, false)

    RegisterNUICallback('dungeonMenuClose', function(_, cb)
        Dungeon.closeMenu()
        cb({})
    end)
    RegisterNUICallback('dungeonMenuOpen', function(_, cb)
        local result = Callback.await(Events.callbacks.dungeonCommand, 'ouvrir')
            or { ok = false, message = Locale.t('Le serveur ne répond pas.') }
        if result.ok then Dungeon.closeMenu() end
        if result.message then Nui.notify(result.message, result.ok and 'success' or 'error') end
        cb(result)
    end)

    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then Dungeon.clear() end
    end)

    CreateThread(Dungeon.loop)
end

---@param word string|nil
---@param argument string|nil
function Dungeon.command(word, argument)
    CreateThread(function()
        local result = Callback.await(Events.callbacks.dungeonCommand, word, argument)
        if result and result.message then
            Nui.notify(result.message, result.ok and 'success' or 'error')
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Menu de James
-- ---------------------------------------------------------------------------

---À appeler depuis un thread.
function Dungeon.openMenu()
    if Dungeon.menuOpen or IsNuiFocused() or not State.isAlive() then return end
    local menu = Callback.await(Events.callbacks.dungeonMenu)
    if not menu then return end
    Dungeon.menuOpen = true
    SetNuiFocus(true, true)
    Nui.send('dungeonMenu', { open = true, menu = menu })
end

function Dungeon.closeMenu()
    if not Dungeon.menuOpen then return end
    Dungeon.menuOpen = false
    SetNuiFocus(false, false)
    Nui.send('dungeonMenu', { open = false })
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
        -- Les zombies sans cible errent autour de l'étape en cours
        Config.Dungeon.zone.coords = data.step.coords
        Dungeon.loadInteriors()
        Dungeon.syncProps(data.props)
        Dungeon.syncBlips(data)
    end
    Dungeon.sendHud()
end

---Sortie du donjon : décor retiré.
function Dungeon.clear()
    Dungeon.state = false
    Dungeon.barrelSentAt = {}
    Dungeon.syncProps({})
    Dungeon.removeBlips()
    Dungeon.releaseInteriors()
    Nui.send('dungeon', { dungeon = false })
end

---Les tronçons du parcours restent chargés tant que le joueur est dans le donjon.
function Dungeon.loadInteriors()
    if #Dungeon.interiors > 0 then return end
    for _, point in ipairs(Config.Dungeon.interiors) do
        local interior = GetInteriorAtCoords(point.x, point.y, point.z)
        if interior == 0 then
            print(('[donjon] intérieur introuvable en %.1f, %.1f, %.1f'):format(point.x, point.y, point.z))
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
    }
    local step = state.step
    if not step then return data end

    if step.reached then
        data.objective = Locale.t(step.objective)
        data.hint = step.hint and Locale.t(step.hint) or nil
    else
        data.objective = Locale.t('Avance dans le tunnel')
    end
    if step.left and step.reached then
        data.subtitle = Locale.t('Zombies restants : %d', step.left)
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

---@param wanted table[] { key, model, coords, barrel }
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

---Un modèle absent du jeu ne bloque rien : la bonbonne ou la porte reste touchable à son emplacement.
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
    -- Le point peut être sur le toit du tunnel ou à côté : l'objet est posé dans le tunnel, au plus près
    local x, y, ground = PedUtils.findIndoorFloor(coords.x, coords.y, coords.z)
    if x then
        prop.entity = CreateObject(model, x, y, ground + Dungeon.FLOOR_OFFSET, false, false, false)
    else
        prop.entity = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    end
    SetEntityHeading(prop.entity, coords.w)
    FreezeEntityPosition(prop.entity, true)
    -- Une bonbonne du jeu saute toute seule : ici, c'est le serveur qui décide, pour toute la salle
    SetEntityInvincible(prop.entity, true)
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
                if prop.placed then PedUtils.enterRoom(prop.entity) end
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

---Repère de l'objectif : la porte, sinon le centre de l'étape.
---@param state table
function Dungeon.syncBlips(state)
    Dungeon.removeBlips()
    local settings = Config.Dungeon.blip
    local point = state.step.wall or state.step.coords
    local blip = AddBlipForCoord(point.x, point.y, point.z)
    SetBlipSprite(blip, settings.sprite)
    SetBlipColour(blip, settings.color)
    SetBlipRoute(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Locale.t(state.step.objective))
    EndTextCommandSetBlipName(blip)
    Dungeon.blips[1] = blip
end

---Explosions lancées par ce client, le jeu les transmet à la salle. Elles sont à son nom : les zombies
---soufflés lui reviennent.
---@param points vector3[]
---@param damage number 0.0 : le décor saute, sans blesser personne
function Dungeon.explode(points, damage)
    local settings = Config.Dungeon.barrel
    CreateThread(function()
        for index, point in ipairs(points) do
            if index > 1 then Wait(settings.chainDelay) end
            AddOwnedExplosion(PlayerPedId(), point.x, point.y, point.z, settings.explosion.type, damage, true, false, settings.explosion.shake)
        end
    end)
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
    Dungeon.placeProps(GetEntityCoords(ped))
    Dungeon.watchShots(state, ped)
end

---Une balle tirée par ce joueur : sur la porte, ou sur une bonbonne.
---@param state table
---@param ped integer
function Dungeon.watchShots(state, ped)
    local now = GetGameTimer()
    if IsPedShooting(ped) and now - Dungeon.shotAt >= Dungeon.SHOT_INTERVAL then
        local hit, impact = GetPedLastWeaponImpactCoord(ped)
        if hit then
            Dungeon.shotAt = now
            Dungeon.onImpact(state, impact, now)
        end
    end
    if Dungeon.wallHits > 0 and now - Dungeon.wallSentAt >= Dungeon.WALL_SEND_INTERVAL then
        Dungeon.wallSentAt = now
        TriggerServerEvent(Events.server.dungeonWallHit, Dungeon.wallHits)
        Dungeon.wallHits = 0
    end
end

---@param state table
---@param impact vector3
---@param now integer
function Dungeon.onImpact(state, impact, now)
    local wall = state.step.wall and Dungeon.propPoint(state.step.id, state.step.wall)
    if wall and #(impact - wall) <= state.step.hitRadius then
        Dungeon.wallHits = Dungeon.wallHits + 1
    end
    for _, prop in ipairs(state.props) do
        if prop.barrel and now - (Dungeon.barrelSentAt[prop.barrel] or 0) >= Dungeon.BARREL_RESEND
            and #(impact - Dungeon.propPoint(prop.key, prop.coords)) <= Config.Dungeon.barrel.hitRadius then
            Dungeon.barrelSentAt[prop.barrel] = now
            TriggerServerEvent(Events.server.dungeonBarrelHit, prop.barrel)
        end
    end
end

---@param key string objet de l'état (bonbonne, porte)
---@param coords vector4 son point dans la config
---@return vector3 où il est vraiment : il a été posé sur le sol
function Dungeon.propPoint(key, coords)
    local placed = Dungeon.props[key]
    if placed and placed.entity and DoesEntityExist(placed.entity) then return GetEntityCoords(placed.entity) end
    return coords.xyz
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
    -- Apparu sur le toit du tunnel ou à côté : ramené dans le tunnel, au plus près
    local x, y, ground = PedUtils.findIndoorFloor(pos.x, pos.y, pos.z)
    local covered = x ~= nil
    if covered then pos = vector3(x, y, ground + Dungeon.FLOOR_OFFSET) end
    local safe, point = GetSafeCoordForPed(pos.x, pos.y, pos.z, true, 16)
    if not safe or #(point - pos) > Dungeon.SNAP_DISTANCE or math.abs(point.z - pos.z) > Dungeon.SNAP_HEIGHT then
        if covered then
            safe, point = true, pos
        else
            local player = GetEntityCoords(PlayerPedId())
            local angle = math.random() * math.pi * 2
            safe, point = GetSafeCoordForPed(player.x + math.cos(angle) * Dungeon.SNAP_NEAR_PLAYER,
                player.y + math.sin(angle) * Dungeon.SNAP_NEAR_PLAYER, player.z, true, 16)
        end
    end
    if safe then SetEntityCoords(ped, point.x, point.y, point.z, false, false, false, false) end
    PedUtils.enterRoom(ped)
end

---Le boss se bat comme un zombie (Pve.updatePed) : seule sa vie lui est propre. Appliquée une fois,
---sinon un changement de propriétaire la remettrait au max.
---@param ped integer
function Dungeon.setupBoss(ped)
    local state = Entity(ped).state
    if state.pvpNpcReady then return end
    local health = 100 + state.dungeonBoss
    SetPedMaxHealth(ped, health)
    SetEntityHealth(ped, health)
    state:set('pvpNpcReady', true, true)
end
