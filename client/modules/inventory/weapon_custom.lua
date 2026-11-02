---Custom des armes (Config.WeaponCustom) : menu du customiseur, essai sur un modèle local posé devant
---le joueur (ni lui ni les autres joueurs n'en voient rien avant d'enregistrer), et pose de la custom
---enregistrée sur les armes du personnage (Loadout.apply). Voir server/modules/inventory/weapon_custom_service.lua.
---@class WeaponCustomModule
local WeaponCustom = PVP.define('WeaponCustom')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Loadout = PVP.use('Loadout')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

WeaponCustom.WATCH_INTERVAL = 250
WeaponCustom.ASSET_TIMEOUT = 3000 -- ms pour charger une arme ou une finition
WeaponCustom.SPIN_SPEED = 25.0 -- °/s, jusqu'à ce que le joueur tourne l'arme lui-même
WeaponCustom.CAMERA_DISTANCE = 1.2 -- m : défaut, avant de connaître la taille de l'arme
WeaponCustom.CAMERA_HEIGHT = 0.55 -- m au-dessus du centre du personnage

---@type table<string, { tint: integer, finish: string|nil }> arme -> custom enregistrée
WeaponCustom.saved = {}
WeaponCustom.active = false
WeaponCustom.opening = false
WeaponCustom.cam = nil
---@type integer|nil modèle d'essai (entité locale)
WeaponCustom.object = nil
---@type string|nil arme du modèle d'essai
WeaponCustom.shown = nil
---@type string|nil finition posée sur le modèle d'essai
WeaponCustom.shownFinish = nil
---@type table<string, boolean> accessoires posés sur le modèle d'essai (composant GTA)
WeaponCustom.shownParts = {}
-- Numéro de la dernière demande : une arme encore en chargement est abandonnée si le joueur en a choisi une autre
WeaponCustom.request = 0
WeaponCustom.spinning = true
WeaponCustom.cameraPos = nil
WeaponCustom.direction = nil

function WeaponCustom.init()
    RegisterNetEvent(Events.client.weaponCustoms, function(customs)
        WeaponCustom.saved = type(customs) == 'table' and customs or {}
        if State.isAlive() then Loadout.apply() end
    end)

    RegisterNUICallback('weaponCustomPreview', function(data, cb)
        cb({})
        if type(data) == 'table' then WeaponCustom.preview(data.name, data.tint, data.finish, data.attachments) end
    end)
    RegisterNUICallback('weaponCustomRotate', function(data, cb)
        WeaponCustom.rotate(tonumber(data.delta) or 0)
        cb({})
    end)
    RegisterNUICallback('weaponCustomSave', function(data, cb)
        cb(WeaponCustom.save(data))
    end)
    RegisterNUICallback('weaponCustomCancel', function(_, cb)
        WeaponCustom.close()
        cb({})
    end)
end

-- ---------------------------------------------------------------------------
-- Sur le personnage
-- ---------------------------------------------------------------------------

---Pose la custom enregistrée sur une arme possédée. Une arme redonnée (mort, perdue puis retrouvée)
---repart sans rien : Loadout.apply repasse à chaque synchro.
---@param ped integer
---@param name string objet de l'arme
---@param item table entrée de Config.Items
function WeaponCustom.applyTo(ped, name, item)
    local custom = WeaponCustom.saved[name]
    local hash = GetHashKey(item.weapon)
    local tint = custom and custom.tint or 0
    if GetPedWeaponTintIndex(ped, hash) ~= tint and tint < GetWeaponTintCount(hash) then
        SetPedWeaponTintIndex(ped, hash, tint)
    end
    for _, finish in ipairs(Config.WeaponCustom.finishes[name] or {}) do
        local component = GetHashKey(finish.component)
        local wanted = custom ~= nil and custom.finish == finish.component
        local has = HasPedGotWeaponComponent(ped, hash, component)
        if wanted and not has then
            GiveWeaponComponentToPed(ped, hash, component)
        elseif has and not wanted then
            RemoveWeaponComponentFromPed(ped, hash, component)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------

---@param name string
---@param item table
---@return table|nil ce que le menu propose pour cette arme, nil si elle n'a ni teinte ni finition
function WeaponCustom.describe(name, item)
    local hash = GetHashKey(item.weapon)
    local tintCount = GetWeaponTintCount(hash)
    local tints = {}
    if tintCount > 1 then
        local palette = tintCount > #Config.WeaponCustom.tints and Config.WeaponCustom.tintsMk2 or Config.WeaponCustom.tints
        for _, tint in ipairs(palette) do
            if tint.id < tintCount then tints[#tints + 1] = tint end
        end
    end
    local finishes = {}
    for _, finish in ipairs(Config.WeaponCustom.finishes[name] or {}) do
        if DoesWeaponTakeWeaponComponent(hash, GetHashKey(finish.component)) then
            finishes[#finishes + 1] = finish
        end
    end
    if #tints == 0 and #finishes == 0 then return nil end
    local attachments = {}
    for attachment, weapons in pairs(Config.Attachments) do
        if weapons[name] and DoesWeaponTakeWeaponComponent(hash, GetHashKey(weapons[name])) then
            attachments[#attachments + 1] = attachment
        end
    end
    table.sort(attachments)
    local custom = WeaponCustom.saved[name]
    return {
        name = name,
        label = item.label,
        tint = custom and custom.tint or 0,
        finish = custom and custom.finish or false,
        tints = tints,
        finishes = finishes,
        attachments = attachments,
    }
end

---@return table[] armes portées dans le sac qu'on peut customiser, par ordre alphabétique
function WeaponCustom.carried()
    local inventory = State.player and State.player.inventory
    local list = {}
    for name, count in pairs(inventory and inventory.bag or {}) do
        local item = Config.Items[name]
        if count > 0 and item and item.type == 'weapon' then
            list[#list + 1] = WeaponCustom.describe(name, item)
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

---E à côté du customiseur (voir Npcs.interact).
---@param npc table entrée de Config.SafeNpcs.npcs
function WeaponCustom.open(npc)
    if WeaponCustom.active or WeaponCustom.opening then return end
    WeaponCustom.opening = true
    local result = Callback.await(Events.callbacks.weaponCustomOpen)
    WeaponCustom.opening = false
    if not result or not result.ok then
        if result and result.message then Nui.notify(result.message, 'error') end
        return
    end
    if IsNuiFocused() or State.menuOpen or not State.isAlive() then return end

    local weapons = WeaponCustom.carried()
    if #weapons == 0 then
        return Nui.notify(Locale.t('Tu ne portes aucune arme à customiser : mets-la dans ton sac.'), 'error')
    end

    WeaponCustom.active = true
    WeaponCustom.spinning = true
    WeaponCustom.startCamera(npc)
    DisplayRadar(false)
    SetNuiFocus(true, true)
    Nui.send('weaponCustom', { open = true, weapons = weapons })
    WeaponCustom.preview(weapons[1].name, weapons[1].tint, weapons[1].finish)
    CreateThread(WeaponCustom.frameLoop)
    CreateThread(WeaponCustom.watch)
end

---Mort ou changement de mode : le menu se referme sans enregistrer.
function WeaponCustom.watch()
    while WeaponCustom.active do
        if not State.inPvp() or not State.isAlive() then return WeaponCustom.close() end
        Wait(WeaponCustom.WATCH_INTERVAL)
    end
end

---@param data any arme -> { tint, finish } des armes modifiées
---@return { ok: boolean, message?: string }
function WeaponCustom.save(data)
    if not WeaponCustom.active then return { ok = false } end
    local result = Callback.await(Events.callbacks.weaponCustomSave, data)
    if not result or not result.ok then
        return result or { ok = false, message = Locale.t('Le serveur ne répond pas.') }
    end
    WeaponCustom.close()
    Nui.notify(result.message, 'success')
    return { ok = true }
end

function WeaponCustom.close()
    if not WeaponCustom.active then return end
    WeaponCustom.active = false
    WeaponCustom.request = WeaponCustom.request + 1
    WeaponCustom.deleteObject()
    if WeaponCustom.cam then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(WeaponCustom.cam, false)
        WeaponCustom.cam = nil
    end
    DisplayRadar(true)
    SetNuiFocus(false, false)
    Nui.send('weaponCustom', { open = false })
end

-- ---------------------------------------------------------------------------
-- Modèle d'essai et caméra
-- ---------------------------------------------------------------------------

---La caméra regarde à l'opposé du customiseur, pour qu'il ne se retrouve pas dans l'arme.
---@param npc table
function WeaponCustom.startCamera(npc)
    local pos = GetEntityCoords(PlayerPedId())
    local away = vector2(pos.x - npc.coords.x, pos.y - npc.coords.y)
    local length = #away
    if length < 0.1 then
        away, length = vector2(0.0, 1.0), 1.0
    end
    WeaponCustom.direction = vector3(away.x / length, away.y / length, 0.0)
    WeaponCustom.cameraPos = pos + vector3(0.0, 0.0, WeaponCustom.CAMERA_HEIGHT) + WeaponCustom.direction * 0.3
    WeaponCustom.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(WeaponCustom.cam, WeaponCustom.cameraPos.x, WeaponCustom.cameraPos.y, WeaponCustom.cameraPos.z)
    SetCamFov(WeaponCustom.cam, 45.0)
    WeaponCustom.aim(WeaponCustom.CAMERA_DISTANCE)
    RenderScriptCams(true, true, 300, true, true)
end

---@param distance number
---@return vector3 endroit où poser l'arme
function WeaponCustom.aim(distance)
    local target = WeaponCustom.cameraPos + WeaponCustom.direction * distance
    PointCamAtCoord(WeaponCustom.cam, target.x, target.y, target.z)
    return target
end

function WeaponCustom.deleteObject()
    local object = WeaponCustom.object
    local shown = WeaponCustom.shown
    WeaponCustom.object = nil
    WeaponCustom.shown = nil
    WeaponCustom.shownFinish = nil
    WeaponCustom.shownParts = {}
    if object and DoesEntityExist(object) then DeleteObject(object) end
    if shown then RemoveWeaponAsset(GetHashKey(Config.Items[shown].weapon)) end
end

---Essai demandé par le menu : arme choisie, teinte, finition et accessoires fixés.
---@param name any
---@param tint any
---@param finish any
---@param fitted any accessoires fixés sur cette arme
function WeaponCustom.preview(name, tint, finish, fitted)
    local item = Config.Items[name]
    if not WeaponCustom.active or not item or item.type ~= 'weapon' then return end
    WeaponCustom.request = WeaponCustom.request + 1
    local request = WeaponCustom.request
    local parts = WeaponCustom.partsOf(name, fitted)
    CreateThread(function()
        -- Un accessoire retiré repart d'un modèle neuf : un chargeur retiré laisserait l'arme sans chargeur
        local stale = name ~= WeaponCustom.shown or WeaponCustom.losesPart(parts)
        if stale and not WeaponCustom.createObject(name, item, request) then return end
        WeaponCustom.dress(item, tonumber(tint) or 0, finish or nil, request)
        WeaponCustom.fit(parts, request)
    end)
end

---@param name string objet de l'arme
---@param fitted any accessoires
---@return table<string, boolean> composants GTA à poser
function WeaponCustom.partsOf(name, fitted)
    local parts = {}
    for _, attachment in ipairs(type(fitted) == 'table' and fitted or {}) do
        local weapons = Config.Attachments[attachment]
        if weapons and weapons[name] then parts[weapons[name]] = true end
    end
    return parts
end

---@param parts table<string, boolean>
---@return boolean true si un accessoire posé sur le modèle n'est plus voulu
function WeaponCustom.losesPart(parts)
    for component in pairs(WeaponCustom.shownParts) do
        if not parts[component] then return true end
    end
    return false
end

---Pose les accessoires qui manquent sur le modèle d'essai.
---@param parts table<string, boolean>
---@param request integer
function WeaponCustom.fit(parts, request)
    local object = WeaponCustom.object
    if not object or request ~= WeaponCustom.request then return end
    for component in pairs(parts) do
        if not WeaponCustom.shownParts[component] then
            if not WeaponCustom.giveComponent(object, GetHashKey(component), request) then return end
            WeaponCustom.shownParts[component] = true
        end
    end
end

---Charge le modèle d'un composant et le pose sur le modèle d'essai.
---@param object integer
---@param component integer hash du composant
---@param request integer
---@return boolean false si la demande a été remplacée entre-temps
function WeaponCustom.giveComponent(object, component, request)
    local model = GetWeaponComponentTypeModel(component)
    if model ~= 0 then
        RequestModel(model)
        local timeout = GetGameTimer() + WeaponCustom.ASSET_TIMEOUT
        while not HasModelLoaded(model) and GetGameTimer() < timeout and request == WeaponCustom.request do Wait(0) end
    end
    if request ~= WeaponCustom.request or WeaponCustom.object ~= object then return false end
    GiveWeaponComponentToWeaponObject(object, component)
    if model ~= 0 then SetModelAsNoLongerNeeded(model) end
    return true
end

---@param name string
---@param item table
---@param request integer
---@return boolean true si le modèle est prêt
function WeaponCustom.createObject(name, item, request)
    local hash = GetHashKey(item.weapon)
    -- Même arme remise à neuf : elle garde son angle
    local heading = name == WeaponCustom.shown and WeaponCustom.object and GetEntityHeading(WeaponCustom.object)
    WeaponCustom.deleteObject()
    RequestWeaponAsset(hash, 31, 0)
    local timeout = GetGameTimer() + WeaponCustom.ASSET_TIMEOUT
    while not HasWeaponAssetLoaded(hash) and GetGameTimer() < timeout and request == WeaponCustom.request do Wait(0) end
    if request ~= WeaponCustom.request or not HasWeaponAssetLoaded(hash) then return false end

    local target = WeaponCustom.aim(WeaponCustom.CAMERA_DISTANCE)
    local object = CreateWeaponObject(hash, 0, target.x, target.y, target.z, true, 1.0, 0)
    if not object or object == 0 then return false end
    SetEntityCollision(object, false, false)
    FreezeEntityPosition(object, true)
    SetEntityCoordsNoOffset(object, target.x, target.y, target.z, false, false, false)
    WeaponCustom.object = object
    WeaponCustom.shown = name

    -- Assez de recul pour voir toute l'arme, du pistolet à la mitrailleuse
    local min, max = GetModelDimensions(GetEntityModel(object))
    local size = max - min
    target = WeaponCustom.aim(math.max(size.x, size.y, size.z) * 1.1 + 0.35)
    SetEntityCoordsNoOffset(object, target.x, target.y, target.z, false, false, false)
    if heading then SetEntityHeading(object, heading) end
    return true
end

---Pose la teinte et la finition sur le modèle d'essai.
---@param item table
---@param tint number
---@param finish string|nil
---@param request integer
function WeaponCustom.dress(item, tint, finish, request)
    local object = WeaponCustom.object
    if not object then return end
    if tint >= 0 and tint < GetWeaponTintCount(GetHashKey(item.weapon)) then
        SetWeaponObjectTintIndex(object, math.floor(tint))
    end
    if finish == WeaponCustom.shownFinish then return end

    if WeaponCustom.shownFinish then
        RemoveWeaponComponentFromWeaponObject(object, GetHashKey(WeaponCustom.shownFinish))
        WeaponCustom.shownFinish = nil
    end
    if type(finish) ~= 'string' then return end

    if WeaponCustom.giveComponent(object, GetHashKey(finish), request) then
        WeaponCustom.shownFinish = finish
    end
end

---L'arme tourne seule tant que le joueur n'y a pas touché, éclairée même la nuit.
function WeaponCustom.frameLoop()
    while WeaponCustom.active do
        local object = WeaponCustom.object
        if object and DoesEntityExist(object) then
            if WeaponCustom.spinning then
                SetEntityHeading(object, (GetEntityHeading(object) + WeaponCustom.SPIN_SPEED * GetFrameTime()) % 360.0)
            end
            local coords = GetEntityCoords(object)
            DrawLightWithRange(coords.x, coords.y, coords.z + 0.6, 255, 255, 255, 3.0, 2.5)
        end
        Wait(0)
    end
end

---@param delta number degrés
function WeaponCustom.rotate(delta)
    WeaponCustom.spinning = false
    local object = WeaponCustom.object
    if object and DoesEntityExist(object) then
        SetEntityHeading(object, (GetEntityHeading(object) + delta) % 360.0)
    end
end
