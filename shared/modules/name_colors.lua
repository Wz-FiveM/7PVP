---Accès aux couleurs de nom de Config.NameColors, côté serveur et client.
---@class NameColorsModule
local NameColors = PVP.define('NameColors')

NameColors.STATE_KEY = 'nameColor' -- publié par server/modules/player/name_color_service, lu par les gamertags

---@type table<string, table> id -> couleur
NameColors.byId = {}

for _, color in ipairs(Config.NameColors) do
    NameColors.byId[color.id] = color
end

---@param id any
---@return table|nil
function NameColors.get(id)
    return NameColors.byId[id]
end

---@param id any valeur de la colonne name_color
---@return string|nil id d'une couleur connue
function NameColors.sanitize(id)
    return NameColors.get(id) and id or nil
end
