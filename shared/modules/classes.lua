---Accès aux classes de Config.Classes, côté serveur et client.
---@class ClassDefsModule
local ClassDefs = PVP.define('ClassDefs')

ClassDefs.DEAD_HEALTH = 100 -- santé GTA du seuil de mort : les points de vie comptent au-dessus
ClassDefs.BASE_HEALTH = 100 -- points de vie sans classe

---@type table<string, table> id -> classe
ClassDefs.byId = {}
ClassDefs.highestHealth = ClassDefs.DEAD_HEALTH + ClassDefs.BASE_HEALTH -- santé GTA la plus haute d'une classe

---@param class table|nil
---@return integer santé GTA maximale, seuil de mort compris
function ClassDefs.maxHealth(class)
    return ClassDefs.DEAD_HEALTH + (class and class.health or ClassDefs.BASE_HEALTH)
end

for _, class in ipairs(Config.Classes.list) do
    ClassDefs.byId[class.id] = class
    ClassDefs.highestHealth = math.max(ClassDefs.highestHealth, ClassDefs.maxHealth(class))
end

---@param id any
---@return table|nil
function ClassDefs.get(id)
    return ClassDefs.byId[id]
end
