---PNJ de service des zones safe (config/npcs.lua) : qui est à portée de quel service.
---Utilisé par le client (interaction, menu) et par le serveur (vérification des actions).
---@class SafeNpcsModule
local SafeNpcs = PVP.define('SafeNpcs')
local Locale = PVP.use('Locale')

---@param coords vector3
---@param role string stash, shop, clothing, crafting, contracts
---@param distance? number défaut : Config.SafeNpcs.useDistance
---@return boolean un PNJ de ce rôle est à portée
function SafeNpcs.isNear(coords, role, distance)
    distance = distance or Config.SafeNpcs.useDistance
    for _, npc in ipairs(Config.SafeNpcs.npcs) do
        if npc.role == role and #(coords.xy - npc.coords.xy) <= distance then return true end
    end
    return false
end

---@param coords vector3
---@return table<string, boolean> rôle -> à portée
function SafeNpcs.nearRoles(coords)
    local near = {}
    for role in pairs(Config.SafeNpcs.roles) do
        near[role] = SafeNpcs.isNear(coords, role)
    end
    return near
end

---@param role string
---@return string|table message « va voir le … » (Locale.t : chaîne côté client, message côté serveur)
function SafeNpcs.hint(role)
    local definition = Config.SafeNpcs.roles[role]
    return Locale.t('Va voir le %s en zone safe (repère sur la carte).', definition and Locale.t(definition.label:lower()) or role)
end
