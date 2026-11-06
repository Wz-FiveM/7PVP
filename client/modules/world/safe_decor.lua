---Décor des zones safe du PvP (config/safe_decor.lua, objets dans config/safe_decor_props.lua).
---Les objets sont créés en local, figés, quand le joueur approche d'une zone dans un mode prévu,
---et supprimés quand il s'éloigne ou change de mode.
---@class SafeDecorModule
local SafeDecor = PVP.define('SafeDecor')
local State = PVP.use('State')
local Logger = PVP.use('Logger')

SafeDecor.LOOP_INTERVAL = 1000
SafeDecor.MODEL_TIMEOUT = 5000
SafeDecor.KEEP_MARGIN = 50.0

---@type table<string, { objects: integer[], missing: string[] }> id de zone -> décor posé
SafeDecor.built = {}
---@type table<string, boolean>
SafeDecor.building = {}
---@type table<string, vector3> id de zone -> centre de ses objets
SafeDecor.centers = {}

function SafeDecor.init()
    for zoneId, props in pairs(Config.SafeDecor.props or {}) do
        local x, y, z = 0.0, 0.0, 0.0
        for _, p in ipairs(props) do x, y, z = x + p[2], y + p[3], z + p[4] end
        local n = math.max(#props, 1)
        SafeDecor.centers[zoneId] = vector3(x / n, y / n, z / n)
    end
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then SafeDecor.clearAll() end
    end)
    -- /pvp_decor : écrit dans F8 l'état du décor de chaque zone
    RegisterCommand('pvp_decor', SafeDecor.print, false)
    CreateThread(SafeDecor.loop)
end

---@return boolean le décor peut exister dans le mode actuel
function SafeDecor.modeWanted()
    local config = Config.SafeDecor
    return config.enabled == true and State.mode ~= nil and config.modes[State.mode] == true
end

function SafeDecor.loop()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local modeOk = SafeDecor.modeWanted()
        for zoneId, center in pairs(SafeDecor.centers) do
            local dist = #(pos.xy - center.xy)
            local built = SafeDecor.built[zoneId]
            if not SafeDecor.building[zoneId] then
                if built and (not modeOk or dist > Config.SafeDecor.buildDistance + SafeDecor.KEEP_MARGIN) then
                    SafeDecor.clear(zoneId)
                elseif not built and modeOk and dist <= Config.SafeDecor.buildDistance then
                    SafeDecor.building[zoneId] = true
                    CreateThread(function()
                        local ok, err = pcall(SafeDecor.build, zoneId)
                        if not ok then Logger.error('Décor %s : %s', zoneId, tostring(err)) end
                        SafeDecor.building[zoneId] = nil
                    end)
                end
            end
        end
        Wait(SafeDecor.LOOP_INTERVAL)
    end
end

---@param model integer
---@return boolean
function SafeDecor.loadModel(model)
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local deadline = GetGameTimer() + SafeDecor.MODEL_TIMEOUT
    while not HasModelLoaded(model) do
        if GetGameTimer() > deadline then return false end
        Wait(0)
    end
    return true
end

---@param zoneId string
function SafeDecor.build(zoneId)
    local props = Config.SafeDecor.props[zoneId]
    local built = { objects = {}, missing = {} }
    SafeDecor.built[zoneId] = built
    local loaded, count = {}, 0
    for _, p in ipairs(props) do
        -- abandon si le joueur a changé de mode pendant la création
        if not SafeDecor.modeWanted() or SafeDecor.built[zoneId] ~= built then break end
        local name = p[1]
        local model = GetHashKey(name)
        if loaded[model] == nil then loaded[model] = SafeDecor.loadModel(model) end
        if loaded[model] then
            local object = CreateObjectNoOffset(model, p[2] + 0.0, p[3] + 0.0, p[4] + 0.0, false, false, false)
            if object ~= 0 then
                SetEntityHeading(object, p[5] + 0.0)
                FreezeEntityPosition(object, true)
                SetEntityInvincible(object, true)
                SetEntityCanBeDamaged(object, false)
                -- plantes et feuillage : on passe au travers, à pied comme en véhicule
                if p[6] then SetEntityCollision(object, false, false) end
                built.objects[#built.objects + 1] = object
            end
            count = count + 1
            if count % Config.SafeDecor.perFrame == 0 then Wait(0) end
        elseif not built.missing[name] then
            built.missing[name] = true
            built.missing[#built.missing + 1] = name
        end
    end
    for model, ok in pairs(loaded) do
        if ok then SetModelAsNoLongerNeeded(model) end
    end
    if SafeDecor.built[zoneId] ~= built or not SafeDecor.modeWanted() then
        -- zone retirée pendant la création : on supprime ce qui a été posé
        for _, object in ipairs(built.objects) do
            if DoesEntityExist(object) then DeleteObject(object) end
        end
        if SafeDecor.built[zoneId] == built then SafeDecor.built[zoneId] = nil end
    elseif #built.missing > 0 then
        Logger.warn('Décor %s : modèles introuvables %s', zoneId, table.concat(built.missing, ', '))
    end
end

---@param zoneId string
function SafeDecor.clear(zoneId)
    local built = SafeDecor.built[zoneId]
    if not built then return end
    SafeDecor.built[zoneId] = nil
    for _, object in ipairs(built.objects) do
        if DoesEntityExist(object) then DeleteObject(object) end
    end
end

function SafeDecor.clearAll()
    for zoneId in pairs(SafeDecor.built) do SafeDecor.clear(zoneId) end
end

function SafeDecor.print()
    local pos = GetEntityCoords(PlayerPedId())
    print(('[7PVP] Décor des zones safe : mode %s, %s'):format(tostring(State.mode), SafeDecor.modeWanted() and 'prévu' or 'pas dans ce mode'))
    for zoneId, center in pairs(SafeDecor.centers) do
        local built = SafeDecor.built[zoneId]
        print(('  - %s : %d objets sur %d, à %.0f m%s'):format(zoneId, built and #built.objects or 0,
            #Config.SafeDecor.props[zoneId], #(pos.xy - center.xy),
            built and #built.missing > 0 and (', introuvables : ' .. table.concat(built.missing, ', ')) or ''))
    end
end
