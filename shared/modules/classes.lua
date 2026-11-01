---Accès aux classes de Config.Classes, côté serveur et client.
---@class ClassDefsModule
local ClassDefs = PVP.define('ClassDefs')

---@type table<string, table> id -> classe
ClassDefs.byId = {}

for _, class in ipairs(Config.Classes.list) do
    ClassDefs.byId[class.id] = class
end

---@param id any
---@return table|nil
function ClassDefs.get(id)
    return ClassDefs.byId[id]
end
