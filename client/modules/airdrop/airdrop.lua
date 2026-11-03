---Largages aériens côté client : un avion traverse la carte (repère qui le suit), largue la caisse
---au-dessus du point de chute, puis elle descend en parachute ; fumigène et compte à rebours
---avant l'ouverture. La caisse ouverte devient un butin affiché par client/modules/loot/loot.lua.
---
---L'avion n'existe que sur chaque client (pas en réseau) : sa position se calcule à partir de
---l'heure du largage et de son cap envoyés par le serveur, donc tout le monde le voit au même endroit.
---@class ClientAirdrop
---@field id integer
---@field coords vector3 point d'atterrissage (z recalé sur le sol une fois chargé)
---@field track vector3 point survolé par l'avion : ne bouge pas quand la caisse se recale
---@field altitude number hauteur d'où part la caisse
---@field fallTime number secondes de chute
---@field unlockDelay number secondes entre l'atterrissage et l'ouverture
---@field captureRadius number|nil largage du PvP : rayon du cercle à tenir pour l'ouvrir
---@field capture { capturer: string|false, progress: number, contested: boolean }|nil avancement reçu du serveur
---@field isShown fun(): boolean|nil le joueur voit ce largage (par défaut : en PvP)
---@field locate fun(drop: ClientAirdrop, pos: vector3)|nil recalage sur le sol propre à ce largage
---@field dir vector3 direction de vol de l'avion
---@field heading number
---@field releaseAt integer GetGameTimer() du largage
---@field landAt integer GetGameTimer() de l'atterrissage
---@field unlockAt integer GetGameTimer() de l'ouverture
---@field blip integer|nil point de chute, créé au largage
---@field planeBlip integer|nil repère de l'avion pendant son vol
---@field plane integer|nil avion (local)
---@field crate integer|nil
---@field chute integer|nil
---@field smoke integer|nil
---@field grounded boolean hauteur du sol trouvée
---@field landed boolean caisse posée (solide)
---@field top number hauteur du dessus de la caisse, pour le texte

---@class AirdropModule
local Airdrop = PVP.define('Airdrop')
local State = PVP.use('State')
local PedUtils = PVP.use('PedUtils')
local DuiLabels = PVP.use('DuiLabels')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')
local Control = PVP.use('Control')

Airdrop.STREAM_DISTANCE = 450.0
Airdrop.TEXT_DISTANCE = 60.0
Airdrop.IDLE_INTERVAL = 100
-- L'avion vole un peu au-dessus de la caisse qu'il largue
Airdrop.PLANE_CLEARANCE = 15.0
Airdrop.RING_HEIGHT = 1.5
Airdrop.RING_ALPHA = 120

---@type table<integer, ClientAirdrop>
Airdrop.drops = {}

function Airdrop.init()
    RegisterNetEvent(Events.client.airdropSpawn, function(data)
        Airdrop.add(data)
    end)
    RegisterNetEvent(Events.client.airdropRemove, function(id)
        Airdrop.remove(id)
    end)
    RegisterNetEvent(Events.client.airdropCapture, function(state)
        local drop = Airdrop.drops[state.id]
        if drop and drop.captureRadius then drop.capture = state end
    end)
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
            for id in pairs(Airdrop.drops) do Airdrop.remove(id) end
        end
    end)
    CreateThread(Airdrop.renderLoop)
end

---Warzone (client/modules/cod/cod_warzone.lua) y passe ses propres largages : altitude, durées et `options` diffèrent.
---@param data { id: integer|string, coords: vector3, heading: number, releaseIn: integer, landIn: integer, unlockIn: integer, altitude?: number, fallTime?: number, unlockDelay?: number }
---@param options? { isShown: fun(): boolean, locate: fun(drop: ClientAirdrop, pos: vector3) }
function Airdrop.add(data, options)
    Airdrop.remove(data.id)
    local now = GetGameTimer()
    local radians = math.rad(data.heading or 0.0)
    Airdrop.drops[data.id] = {
        id = data.id,
        coords = data.coords,
        track = data.coords,
        altitude = data.altitude or data.coords.z + Config.Airdrops.fallHeight,
        fallTime = data.fallTime or Config.Airdrops.fallTime,
        unlockDelay = data.unlockDelay or Config.Airdrops.capture.time,
        captureRadius = data.captureRadius,
        capture = data.capture,
        isShown = options and options.isShown,
        locate = options and options.locate,
        heading = data.heading or 0.0,
        -- Cap GTA : 0° = nord, sens inverse des aiguilles d'une montre
        dir = vector3(-math.sin(radians), math.cos(radians), 0.0),
        releaseAt = now + (data.releaseIn or 0) * 1000,
        landAt = now + data.landIn * 1000,
        unlockAt = now + data.unlockIn * 1000,
        grounded = false,
        landed = false,
        top = 1.0,
    }
end

---@param id integer
function Airdrop.remove(id)
    local drop = Airdrop.drops[id]
    if not drop then return end
    Airdrop.deleteBlips(drop)
    Airdrop.deletePlane(drop)
    Airdrop.deleteProps(drop)
    Airdrop.drops[id] = nil
end

---@param drop ClientAirdrop
function Airdrop.deleteBlips(drop)
    for _, key in ipairs({ 'blip', 'planeBlip' }) do
        if drop[key] and DoesBlipExist(drop[key]) then RemoveBlip(drop[key]) end
        drop[key] = nil
    end
end

---@param drop ClientAirdrop
function Airdrop.deleteProps(drop)
    for _, key in ipairs({ 'crate', 'chute' }) do
        if drop[key] and DoesEntityExist(drop[key]) then DeleteObject(drop[key]) end
        drop[key] = nil
    end
    drop.landed = false
    if drop.smoke then
        StopParticleFxLooped(drop.smoke, false)
        drop.smoke = nil
    end
end

function Airdrop.renderLoop()
    while true do
        local needsFrame = false
        local inPvp = State.inPvp()
        local pos = GetEntityCoords(PlayerPedId())
        local now = GetGameTimer()
        for _, drop in pairs(Airdrop.drops) do
            local shown = inPvp
            if drop.isShown then shown = drop.isShown() end
            if shown then
                if Airdrop.updatePlane(drop, pos, now) then needsFrame = true end
                if now >= drop.releaseAt and Airdrop.render(drop, pos, now) then needsFrame = true end
            else
                -- Les repères aussi : un largage du PvP n'a rien à faire sur la carte d'une Warzone
                Airdrop.deleteBlips(drop)
                Airdrop.deletePlane(drop)
                Airdrop.deleteProps(drop)
            end
        end
        Wait(needsFrame and 0 or Airdrop.IDLE_INTERVAL)
    end
end

-- ---------------------------------------------------------------------------
-- Avion
-- ---------------------------------------------------------------------------

---Position de l'avion à l'instant `now` (avant le largage : en approche, après : il s'éloigne).
---@param drop ClientAirdrop
---@param now integer
---@return vector3
function Airdrop.planePosition(drop, now)
    local travelled = Config.Airdrops.plane.speed * (now - drop.releaseAt) / 1000
    return vector3(drop.track.x + drop.dir.x * travelled, drop.track.y + drop.dir.y * travelled, drop.altitude + Airdrop.PLANE_CLEARANCE)
end

---Repère et avion pendant le vol ; au largage, le point de chute apparaît sur la carte.
---@param drop ClientAirdrop
---@param pos vector3 position du joueur
---@param now integer
---@return boolean true si l'avion doit être déplacé à chaque image
function Airdrop.updatePlane(drop, pos, now)
    local plane = Config.Airdrops.plane
    local endAt = drop.releaseAt + plane.exit / plane.speed * 1000
    if now >= drop.releaseAt and not drop.blip then Airdrop.createDropBlip(drop) end

    if now >= endAt then
        if drop.planeBlip then
            RemoveBlip(drop.planeBlip)
            drop.planeBlip = nil
        end
        Airdrop.deletePlane(drop)
        return false
    end

    local position = Airdrop.planePosition(drop, now)
    if not drop.planeBlip then Airdrop.createPlaneBlip(drop, position) end
    SetBlipCoords(drop.planeBlip, position.x, position.y, position.z)

    if #(pos.xy - position.xy) > plane.drawDistance then
        Airdrop.deletePlane(drop)
        return false
    end
    if not drop.plane then Airdrop.createPlane(drop, position) end
    if drop.plane then
        SetEntityCoordsNoOffset(drop.plane, position.x, position.y, position.z, false, false, false)
        SetEntityHeading(drop.plane, drop.heading)
    end
    return true
end

---@param drop ClientAirdrop
---@param position vector3
function Airdrop.createPlaneBlip(drop, position)
    local settings = Config.Airdrops.plane.blip
    local blip = AddBlipForCoord(position.x, position.y, position.z)
    SetBlipSprite(blip, settings.sprite)
    SetBlipColour(blip, settings.color)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, false)
    SetBlipRotation(blip, math.floor(-drop.heading))
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Locale.t('Avion de largage'))
    EndTextCommandSetBlipName(blip)
    drop.planeBlip = blip
end

---@param drop ClientAirdrop
function Airdrop.createDropBlip(drop)
    local blip = AddBlipForCoord(drop.coords.x, drop.coords.y, drop.coords.z)
    SetBlipSprite(blip, Config.Airdrops.blip.sprite)
    SetBlipColour(blip, Config.Airdrops.blip.color)
    SetBlipScale(blip, 1.1)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Locale.t('Largage aérien'))
    EndTextCommandSetBlipName(blip)
    drop.blip = blip
end

---Avion local (pas en réseau), moteurs allumés et train rentré, déplacé à chaque image.
---@param drop ClientAirdrop
---@param position vector3
function Airdrop.createPlane(drop, position)
    local model = GetHashKey(Config.Airdrops.plane.model)
    if not PedUtils.loadModel(model) then return end
    local plane = CreateVehicle(model, position.x, position.y, position.z, drop.heading, false, false)
    SetModelAsNoLongerNeeded(model)
    if plane == 0 then return end

    SetEntityCollision(plane, false, false)
    FreezeEntityPosition(plane, true)
    SetEntityInvincible(plane, true)
    SetVehicleEngineOn(plane, true, true, false)
    ControlLandingGear(plane, 3)
    SetVehicleLights(plane, 2)
    drop.plane = plane
end

---@param drop ClientAirdrop
function Airdrop.deletePlane(drop)
    if drop.plane and DoesEntityExist(drop.plane) then DeleteEntity(drop.plane) end
    drop.plane = nil
end

-- ---------------------------------------------------------------------------
-- Caisse (après le largage)
-- ---------------------------------------------------------------------------

---@param drop ClientAirdrop
---@param pos vector3
---@param now integer
---@return boolean true si le largage doit être mis à jour à chaque image
function Airdrop.render(drop, pos, now)
    local dist = #(pos.xy - drop.coords.xy)
    if dist > Airdrop.STREAM_DISTANCE then
        Airdrop.deleteProps(drop)
        return false
    end

    if not drop.grounded then
        if drop.locate then drop.locate(drop, pos) else Airdrop.findGround(drop) end
        -- Sol trouvé sous une caisse déjà posée : elle reprend sa place
        if drop.grounded and drop.landed then Airdrop.deleteProps(drop) end
    end
    if not drop.crate then Airdrop.createProps(drop) end
    -- Retiré pendant le chargement des modèles
    if not drop.crate then return false end

    local falling = now < drop.landAt
    local height = falling and (drop.landAt - now) / (drop.fallTime * 1000) * (drop.altitude - drop.coords.z) or 0.0
    local z = drop.coords.z + height

    if falling then
        SetEntityCoords(drop.crate, drop.coords.x, drop.coords.y, z, false, false, false, false)
        SetEntityCoords(drop.chute, drop.coords.x, drop.coords.y, z + drop.top, false, false, false, false)
    elseif not drop.landed then
        Airdrop.land(drop)
    end

    if drop.captureRadius and not falling then Airdrop.drawRing(drop) end
    if dist < Airdrop.TEXT_DISTANCE then
        Airdrop.drawLabel(drop, vector3(drop.coords.x, drop.coords.y, z + drop.top + 0.6), falling, now)
    end
    return true
end

---Cercle à tenir autour de la caisse posée : vert quand ton camp capture, rouge pour un autre camp.
---@param drop ClientAirdrop
function Airdrop.drawRing(drop)
    local r, g, b = 255, 210, 40
    local capture = drop.capture
    if capture and capture.contested then
        r, g, b = 255, 130, 30
    elseif capture and capture.capturer then
        -- Pas de crew pour un largage : le camp est le groupe, sinon le joueur seul
        if capture.capturer == Control.myTeam({}) then r, g, b = 181, 242, 61 else r, g, b = 255, 40, 30 end
    end
    local diameter = drop.captureRadius * 2
    DrawMarker(1, drop.coords.x, drop.coords.y, drop.coords.z - 1.0, 0, 0, 0, 0, 0, 0, diameter, diameter, Airdrop.RING_HEIGHT,
        r, g, b, Airdrop.RING_ALPHA, false, false, 2, false, nil, nil, false)
end

---Recale la caisse sur le sol une fois le terrain chargé autour du point.
---@param drop ClientAirdrop
function Airdrop.findGround(drop)
    local found, ground = GetGroundZFor_3dCoord(drop.coords.x, drop.coords.y, drop.coords.z + 50.0, false)
    if found then
        drop.coords = vector3(drop.coords.x, drop.coords.y, ground)
        drop.grounded = true
    end
end

---@param drop ClientAirdrop
function Airdrop.createProps(drop)
    local crateModel = GetHashKey(Config.Airdrops.model)
    local chuteModel = GetHashKey(Config.Airdrops.parachute)
    RequestModel(crateModel)
    RequestModel(chuteModel)
    local limit = GetGameTimer() + 3000
    while (not HasModelLoaded(crateModel) or not HasModelLoaded(chuteModel)) and GetGameTimer() < limit do Wait(0) end

    drop.crate = CreateObject(crateModel, drop.coords.x, drop.coords.y, drop.coords.z, false, false, false)
    FreezeEntityPosition(drop.crate, true)
    -- En chute, la caisse traverse tout ; elle devient solide une fois posée (Airdrop.land)
    SetEntityCollision(drop.crate, false, false)
    local _, maximum = GetModelDimensions(crateModel)
    if maximum and maximum.z > 0 then drop.top = maximum.z end
    if GetGameTimer() < drop.landAt then
        drop.chute = CreateObject(chuteModel, drop.coords.x, drop.coords.y, drop.coords.z, false, false, false)
        FreezeEntityPosition(drop.chute, true)
        SetEntityCollision(drop.chute, false, false)
    end
    SetModelAsNoLongerNeeded(crateModel)
    SetModelAsNoLongerNeeded(chuteModel)
    if Airdrop.drops[drop.id] ~= drop then Airdrop.deleteProps(drop) end
end

---Atterrissage : la caisse est posée à plat sur le sol et devient solide, le parachute disparaît.
---@param drop ClientAirdrop
function Airdrop.land(drop)
    drop.landed = true
    if drop.chute then
        DeleteObject(drop.chute)
        drop.chute = nil
    end
    SetEntityCoords(drop.crate, drop.coords.x, drop.coords.y, drop.coords.z, false, false, false, false)
    PlaceObjectOnGroundProperly(drop.crate)
    FreezeEntityPosition(drop.crate, true)
    SetEntityCollision(drop.crate, true, true)
    Airdrop.startSmoke(drop)
end

---Fumigène jaune au sol pour repérer la caisse de loin.
---@param drop ClientAirdrop
function Airdrop.startSmoke(drop)
    if drop.smoke then return end
    RequestNamedPtfxAsset('core')
    local limit = GetGameTimer() + 2000
    while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < limit do Wait(0) end
    UseParticleFxAssetNextCall('core')
    drop.smoke = StartParticleFxLoopedAtCoord('exp_grd_flare', drop.coords.x, drop.coords.y, drop.coords.z + 0.2,
        0.0, 0.0, 0.0, 1.5, false, false, false, false)
end

---@param drop ClientAirdrop
---@return string texte, number avancement de la capture (0 à 1)
function Airdrop.captureStatus(drop)
    local capture = drop.capture
    if not capture or not capture.capturer then
        return Locale.t('Tiens le cercle %d s pour l\'ouvrir', drop.unlockDelay), 0
    end
    local percent = math.floor(capture.progress * 100)
    if capture.contested then return Locale.t('Contesté · %d %%', percent), capture.progress end
    if capture.capturer == Control.myTeam({}) then return Locale.t('Capture · %d %%', percent), capture.progress end
    return Locale.t('Capture ennemie · %d %%', percent), capture.progress
end

---Étiquette DUI au-dessus de la caisse : état et avancement (chute, puis ouverture).
---@param drop ClientAirdrop
---@param coords vector3
---@param falling boolean
---@param now integer
function Airdrop.drawLabel(drop, coords, falling, now)
    local subtitle, progress
    if falling then
        subtitle = Locale.t('En chute')
        progress = 1 - (drop.landAt - now) / (drop.fallTime * 1000)
    elseif drop.captureRadius then
        subtitle, progress = Airdrop.captureStatus(drop)
    else
        local seconds = math.max(0, math.ceil((drop.unlockAt - now) / 1000))
        -- En Warzone, la caisse reste fermée jusqu'à ce qu'un joueur l'ouvre
        subtitle = seconds > 0 and Locale.t('Ouverture dans %d s', seconds) or Locale.t('Prêt')
        progress = 1 - (drop.unlockAt - now) / (drop.unlockDelay * 1000)
    end
    DuiLabels.draw('airdrop:' .. drop.id, coords, {
        title = Locale.t('Largage aérien'),
        subtitle = subtitle,
        accent = 'critique',
        icon = 'crate',
        progress = math.floor(math.max(0, math.min(1, progress)) * 50) / 50,
    })
end
