---Couleurs du nom (Config.NameColors), côté serveur et client : une chaîne avec un code par lettre.
---« qg-r » : 1re lettre rose, 2e verte, 3e sans couleur, 4e rouge, les suivantes sans couleur.
---@class NameColorsModule
local NameColors = PVP.define('NameColors')

NameColors.STATE_KEY = 'nameColor' -- publié par server/modules/player/name_color_service, lu par les gamertags
NameColors.NONE = '-' -- lettre sans couleur

local codes = { '%', NameColors.NONE }
for _, color in ipairs(Config.NameColors.list) do
    codes[#codes + 1] = color.code
end
NameColors.INVALID = '[^' .. table.concat(codes) .. ']'

---@param colors any
---@return boolean chaîne de codes connus, de taille permise (vide = sans couleur)
function NameColors.isValid(colors)
    return type(colors) == 'string' and #colors <= Config.NameColors.maxLetters and not colors:find(NameColors.INVALID)
end

---@param colors any valeur de la colonne name_color
---@return string|nil couleurs sans les lettres sans couleur de la fin, nil s'il n'en reste aucune
function NameColors.sanitize(colors)
    if not NameColors.isValid(colors) then return nil end
    local trimmed = colors:gsub('%' .. NameColors.NONE .. '+$', '')
    return trimmed ~= '' and trimmed or nil
end

---@param name string
---@param colors? any
---@return string nom avec les codes couleur GTA, sans les ~ écrits dans le nom (ils serviraient de codes gratuits)
function NameColors.format(name, colors)
    colors = NameColors.sanitize(colors)
    if not colors then return (name:gsub('~', '')) end

    local parts, index, current = {}, 0, NameColors.NONE
    for letter in name:gmatch(utf8.charpattern) do
        index = index + 1
        local code = colors:sub(index, index)
        if code == '' then code = NameColors.NONE end
        if code ~= current then
            parts[#parts + 1] = code == NameColors.NONE and '~s~' or ('~%s~'):format(code)
            current = code
        end
        if letter ~= '~' then parts[#parts + 1] = letter end
    end
    if current ~= NameColors.NONE then parts[#parts + 1] = '~s~' end
    return table.concat(parts)
end
