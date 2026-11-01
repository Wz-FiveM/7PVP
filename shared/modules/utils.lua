---@class UtilsModule
local Utils = PVP.define('Utils')

---@param range integer[] { min, max }
---@return integer
function Utils.randomRange(range)
    return math.random(range[1], range[2])
end

---@generic T
---@param list T[]
---@return T
function Utils.pick(list)
    return list[math.random(#list)]
end

---Quantité venue du réseau : un entier, 0 si ce n'est pas un nombre fini (NaN passe sinon tous les contrôles).
---@param value any
---@return integer
function Utils.toCount(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then return 0 end
    return math.floor(number)
end

---@param tbl table
---@return integer
function Utils.count(tbl)
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    return n
end

---@param tbl table
---@return table
function Utils.shallowCopy(tbl)
    local copy = {}
    for key, value in pairs(tbl) do copy[key] = value end
    return copy
end
