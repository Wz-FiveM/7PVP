---Schéma de l'apparence d'un personnage, partagé client/serveur :
---valeurs par défaut, validation et libellés envoyés au créateur React.
---
---Format (JSON-safe, aucune clé numérique éparse) :
---{
---  sex = 'male'|'female',
---  heritage = { mother, father, shapeMix, skinMix },
---  features = { 20 nombres entre -1 et 1 },
---  eyeColor = 0..31,
---  hair = { style, color, highlight },
---  overlays = { [clé] = { style (-1 = aucun), opacity, color } },
---  components = { [clé] = { drawable, texture } },
---  props = { [clé] = { drawable (-1 = aucun), texture } },
---}
---@class AppearanceSchemaModule
local AppearanceSchema = PVP.define('AppearanceSchema')

AppearanceSchema.MODELS = { male = 'mp_m_freemode_01', female = 'mp_f_freemode_01' }

-- Visages de parents de GTA (identifiants de head blend)
AppearanceSchema.FATHERS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 42, 43, 44 }
AppearanceSchema.MOTHERS = { 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 45 }

-- Traits du visage, dans l'ordre des index GTA (0 à 19)
AppearanceSchema.FEATURES = {
    'Largeur du nez', 'Hauteur du nez', 'Longueur du nez', 'Arête du nez', 'Pointe du nez', 'Torsion du nez',
    'Hauteur des sourcils', 'Profondeur des sourcils', 'Hauteur des pommettes', 'Largeur des pommettes',
    'Joues', 'Ouverture des yeux', 'Épaisseur des lèvres', 'Largeur de la mâchoire', 'Longueur de la mâchoire',
    'Hauteur du menton', 'Longueur du menton', 'Largeur du menton', 'Fossette du menton', 'Épaisseur du cou',
}

-- Calques de la tête : index GTA, type de couleur (1 = cheveux, 2 = maquillage)
AppearanceSchema.OVERLAYS = {
    { key = 'eyebrows', index = 2, color = 1, label = 'Sourcils' },
    { key = 'beard', index = 1, color = 1, label = 'Barbe' },
    { key = 'chestHair', index = 10, color = 1, label = 'Pilosité du torse' },
    { key = 'blemishes', index = 0, label = 'Imperfections' },
    { key = 'ageing', index = 3, label = 'Rides' },
    { key = 'complexion', index = 6, label = 'Teint' },
    { key = 'freckles', index = 9, label = 'Taches de rousseur' },
    { key = 'makeup', index = 4, color = 2, label = 'Maquillage' },
    { key = 'blush', index = 5, color = 2, label = 'Fard à joues' },
    { key = 'lipstick', index = 8, color = 2, label = 'Rouge à lèvres' },
}

AppearanceSchema.COMPONENTS = {
    { key = 'top', id = 11, label = 'Haut' },
    { key = 'undershirt', id = 8, label = 'Sous-haut' },
    { key = 'arms', id = 3, label = 'Bras' },
    { key = 'legs', id = 4, label = 'Pantalon' },
    { key = 'shoes', id = 6, label = 'Chaussures' },
}

AppearanceSchema.PROPS = {
    { key = 'hat', id = 0, label = 'Chapeau' },
    { key = 'glasses', id = 1, label = 'Lunettes' },
}

---@param sex 'male'|'female'
---@return table
function AppearanceSchema.default(sex)
    sex = AppearanceSchema.MODELS[sex] and sex or 'male'

    local features = {}
    for i = 1, #AppearanceSchema.FEATURES do features[i] = 0.0 end

    local overlays = {}
    for _, overlay in ipairs(AppearanceSchema.OVERLAYS) do
        overlays[overlay.key] = { style = -1, opacity = 1.0, color = 0 }
    end
    overlays.eyebrows.style = 0

    local components = {}
    for key, value in pairs(Config.Appearance.DefaultOutfits[sex]) do
        components[key] = { drawable = value[1], texture = value[2] }
    end

    local props = {}
    for _, prop in ipairs(AppearanceSchema.PROPS) do
        props[prop.key] = { drawable = -1, texture = 0 }
    end

    return {
        sex = sex,
        heritage = {
            mother = AppearanceSchema.MOTHERS[1],
            father = AppearanceSchema.FATHERS[1],
            shapeMix = sex == 'male' and 0.7 or 0.3,
            skinMix = 0.5,
        },
        features = features,
        eyeColor = 0,
        hair = { style = Config.Appearance.DefaultHair[sex], color = 0, highlight = 0 },
        overlays = overlays,
        components = components,
        props = props,
    }
end

---@return number
function AppearanceSchema.clamp(value, min, max, integer)
    value = tonumber(value) or min
    if integer then value = math.floor(value) end
    return math.max(min, math.min(max, value))
end

---@return boolean
function AppearanceSchema.contains(list, value)
    for _, item in ipairs(list) do
        if item == value then return true end
    end
    return false
end

---Valide et normalise une apparence venue du client. Renvoie nil si inutilisable.
---@param data any
---@return table|nil
function AppearanceSchema.sanitize(data)
    if type(data) ~= 'table' or not AppearanceSchema.MODELS[data.sex] then return nil end

    local clamp = AppearanceSchema.clamp
    local result = AppearanceSchema.default(data.sex)

    local heritage = type(data.heritage) == 'table' and data.heritage or {}
    if AppearanceSchema.contains(AppearanceSchema.MOTHERS, tonumber(heritage.mother)) then
        result.heritage.mother = tonumber(heritage.mother)
    end
    if AppearanceSchema.contains(AppearanceSchema.FATHERS, tonumber(heritage.father)) then
        result.heritage.father = tonumber(heritage.father)
    end
    result.heritage.shapeMix = clamp(heritage.shapeMix, 0.0, 1.0)
    result.heritage.skinMix = clamp(heritage.skinMix, 0.0, 1.0)

    local features = type(data.features) == 'table' and data.features or {}
    for i = 1, #AppearanceSchema.FEATURES do
        result.features[i] = clamp(features[i], -1.0, 1.0)
    end

    result.eyeColor = clamp(data.eyeColor, 0, 31, true)

    local hair = type(data.hair) == 'table' and data.hair or {}
    result.hair = {
        style = clamp(hair.style, 0, 511, true),
        color = clamp(hair.color, 0, 63, true),
        highlight = clamp(hair.highlight, 0, 63, true),
    }

    local overlays = type(data.overlays) == 'table' and data.overlays or {}
    for _, overlay in ipairs(AppearanceSchema.OVERLAYS) do
        local value = type(overlays[overlay.key]) == 'table' and overlays[overlay.key] or {}
        result.overlays[overlay.key] = {
            style = clamp(value.style, -1, 254, true),
            opacity = clamp(value.opacity, 0.0, 1.0),
            color = clamp(value.color, 0, 63, true),
        }
    end

    local components = type(data.components) == 'table' and data.components or {}
    for _, component in ipairs(AppearanceSchema.COMPONENTS) do
        local value = type(components[component.key]) == 'table' and components[component.key] or {}
        result.components[component.key] = {
            drawable = clamp(value.drawable, 0, 1023, true),
            texture = clamp(value.texture, 0, 63, true),
        }
    end

    local props = type(data.props) == 'table' and data.props or {}
    for _, prop in ipairs(AppearanceSchema.PROPS) do
        local value = type(props[prop.key]) == 'table' and props[prop.key] or {}
        result.props[prop.key] = {
            drawable = clamp(value.drawable, -1, 1023, true),
            texture = clamp(value.texture, 0, 63, true),
        }
    end

    return result
end

---@param raw string|nil
---@return table|nil
function AppearanceSchema.decode(raw)
    if type(raw) ~= 'string' or raw == '' then return nil end
    local ok, data = pcall(json.decode, raw)
    return ok and AppearanceSchema.sanitize(data) or nil
end

---Ne garde que les champs utiles à l'interface (clé, libellé, type de couleur).
---@param list table[]
---@return table[]
function AppearanceSchema.describeList(list)
    local out = {}
    for i, entry in ipairs(list) do
        out[i] = { key = entry.key, label = entry.label, color = entry.color }
    end
    return out
end

---Libellés et listes envoyés à l'interface du créateur.
---@return table
function AppearanceSchema.describe()
    return {
        mothers = AppearanceSchema.MOTHERS,
        fathers = AppearanceSchema.FATHERS,
        features = AppearanceSchema.FEATURES,
        overlays = AppearanceSchema.describeList(AppearanceSchema.OVERLAYS),
        components = AppearanceSchema.describeList(AppearanceSchema.COMPONENTS),
        props = AppearanceSchema.describeList(AppearanceSchema.PROPS),
    }
end

---@param data table
---@return table copie profonde
function AppearanceSchema.copy(data)
    local copy = {}
    for key, value in pairs(data) do
        copy[key] = type(value) == 'table' and AppearanceSchema.copy(value) or value
    end
    return copy
end
