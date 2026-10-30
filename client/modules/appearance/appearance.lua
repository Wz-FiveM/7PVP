---Applique une apparence (voir shared/modules/appearance.lua) sur le ped du joueur.
---@class AppearanceModule
local Appearance = PVP.define('Appearance')
local AppearanceSchema = PVP.use('AppearanceSchema')
local PedUtils = PVP.use('PedUtils')
local Logger = PVP.use('Logger')

Appearance.palettes = nil
-- À l'arrivée en jeu, le chargement peut prendre bien plus que les 5 s par défaut
Appearance.MODEL_TIMEOUT = 30000
Appearance.MAX_HEALTH = 200 -- 100 points de vie (100 = mort), pour les deux sexes
Appearance.HEALTH_CHECK_INTERVAL = 500

function Appearance.init()
    -- Le modèle féminin n'a que 175 de vie max par défaut, et le jeu peut y revenir à la résurrection
    CreateThread(function()
        while true do
            Appearance.ensureMaxHealth(PlayerPedId())
            Wait(Appearance.HEALTH_CHECK_INTERVAL)
        end
    end)
end

---Un ped qui était plein reste plein avec sa nouvelle vie max.
---@param ped integer
function Appearance.ensureMaxHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    if maxHealth == Appearance.MAX_HEALTH then return end
    local full = GetEntityHealth(ped) >= maxHealth
    SetPedMaxHealth(ped, Appearance.MAX_HEALTH)
    if full then SetEntityHealth(ped, Appearance.MAX_HEALTH) end
end

---Change le modèle du joueur si le sexe ne correspond pas. Le ped change alors :
---les armes et l'apparence doivent être réappliquées.
---@param sex 'male'|'female'
---@return boolean true si le modèle a changé
function Appearance.ensureModel(sex)
    local model = GetHashKey(AppearanceSchema.MODELS[sex] or AppearanceSchema.MODELS.male)
    if GetEntityModel(PlayerPedId()) == model then return false end

    -- SetPlayerModel sur un modèle non chargé laisse un ped à moitié créé, et le jeu plante
    if not PedUtils.loadModel(model, Appearance.MODEL_TIMEOUT) then
        Logger.warn('Modèle du joueur non chargé après %d ms', Appearance.MODEL_TIMEOUT)
        return false
    end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    SetPedDefaultComponentVariation(PlayerPedId())
    Appearance.ensureMaxHealth(PlayerPedId())
    return true
end

---@param ped integer
---@param data table apparence validée
function Appearance.apply(ped, data)
    local heritage = data.heritage
    SetPedHeadBlendData(ped, heritage.mother, heritage.father, 0, heritage.mother, heritage.father, 0,
        heritage.shapeMix, heritage.skinMix, 0.0, false)

    for i, value in ipairs(data.features) do
        SetPedFaceFeature(ped, i - 1, value)
    end

    SetPedComponentVariation(ped, 2, data.hair.style, 0, 0)
    SetPedHairColor(ped, data.hair.color, data.hair.highlight)
    SetPedEyeColor(ped, data.eyeColor)

    for _, overlay in ipairs(AppearanceSchema.OVERLAYS) do
        local value = data.overlays[overlay.key]
        SetPedHeadOverlay(ped, overlay.index, value.style < 0 and 255 or value.style, value.opacity)
        if overlay.color then
            SetPedHeadOverlayColor(ped, overlay.index, overlay.color, value.color, value.color)
        end
    end

    for _, component in ipairs(AppearanceSchema.COMPONENTS) do
        local value = data.components[component.key]
        SetPedComponentVariation(ped, component.id, value.drawable, value.texture, 0)
    end

    for _, prop in ipairs(AppearanceSchema.PROPS) do
        local value = data.props[prop.key]
        if value.drawable < 0 then
            ClearPedProp(ped, prop.id)
        else
            SetPedPropIndex(ped, prop.id, value.drawable, value.texture, true)
        end
    end
end

---Applique l'apparence au joueur local en changeant de modèle si besoin.
---@param data table
---@return boolean true si le modèle a changé
function Appearance.applyToPlayer(data)
    local changed = Appearance.ensureModel(data.sex)
    Appearance.apply(PlayerPedId(), data)
    return changed
end

---Nombre de variantes disponibles pour l'apparence en cours (bornes des sélecteurs).
---@param ped integer
---@param data table
---@return table
function Appearance.getLimits(ped, data)
    local limits = {
        hair = GetNumberOfPedDrawableVariations(ped, 2),
        overlays = {},
        components = {},
        props = {},
    }

    for _, overlay in ipairs(AppearanceSchema.OVERLAYS) do
        limits.overlays[overlay.key] = GetNumHeadOverlayValues(overlay.index)
    end

    for _, component in ipairs(AppearanceSchema.COMPONENTS) do
        limits.components[component.key] = {
            drawables = GetNumberOfPedDrawableVariations(ped, component.id),
            textures = GetNumberOfPedTextureVariations(ped, component.id, data.components[component.key].drawable),
        }
    end

    for _, prop in ipairs(AppearanceSchema.PROPS) do
        local drawable = data.props[prop.key].drawable
        limits.props[prop.key] = {
            drawables = GetNumberOfPedPropDrawableVariations(ped, prop.id),
            textures = drawable >= 0 and GetNumberOfPedPropTextureVariations(ped, prop.id, drawable) or 0,
        }
    end

    return limits
end

---Couleurs de cheveux et de maquillage du jeu, en RGB (calculées une seule fois).
---@return table
function Appearance.getPalettes()
    if Appearance.palettes then return Appearance.palettes end

    local hair, makeup = {}, {}
    for i = 0, GetNumHairColors() - 1 do
        local r, g, b = GetPedHairRgbColor(i)
        hair[#hair + 1] = { r, g, b }
    end
    for i = 0, GetNumMakeupColors() - 1 do
        local r, g, b = GetPedMakeupRgbColor(i)
        makeup[#makeup + 1] = { r, g, b }
    end

    Appearance.palettes = { hair = hair, makeup = makeup }
    return Appearance.palettes
end
