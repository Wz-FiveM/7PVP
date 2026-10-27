---@class ProgressionModule
local Progression = PVP.define('Progression')

---@param xp integer
---@return integer
function Progression.levelFromXp(xp)
    return math.floor(xp / Config.XpPerLevel) + 1
end
