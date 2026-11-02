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

---Jamais sous 1.0 : le client remet le multiplicateur des armes à 1.0 quand le joueur tient une arme de corps à corps.
---@param class table|nil
---@return number multiplicateur le plus haut des armes à feu, tous groupes d'armes confondus
function ClassDefs.weaponDamageLimit(class)
    if not class then return 1.0 end
    local limit = math.max(1.0, class.damage or 1.0)
    for _, damage in pairs(class.weaponGroups or {}) do
        limit = math.max(limit, damage)
    end
    return limit * (class.playerDamage or 1.0)
end

---@param class table|nil
---@return number multiplicateur le plus haut du corps à corps, compétence comprise, jamais sous 1.0
function ClassDefs.meleeDamageLimit(class)
    if not class then return 1.0 end
    local limit = (class.melee or class.damage or 1.0) * (class.playerDamage or 1.0) * (class.ability and class.ability.melee or 1.0)
    return math.max(1.0, limit)
end

ClassDefs.highestWeaponDamage = 1.0
ClassDefs.highestMeleeDamage = 1.0
for _, class in ipairs(Config.Classes.list) do
    ClassDefs.byId[class.id] = class
    ClassDefs.highestHealth = math.max(ClassDefs.highestHealth, ClassDefs.maxHealth(class))
    ClassDefs.highestWeaponDamage = math.max(ClassDefs.highestWeaponDamage, ClassDefs.weaponDamageLimit(class))
    ClassDefs.highestMeleeDamage = math.max(ClassDefs.highestMeleeDamage, ClassDefs.meleeDamageLimit(class))
end

---@param id any
---@return table|nil
function ClassDefs.get(id)
    return ClassDefs.byId[id]
end
