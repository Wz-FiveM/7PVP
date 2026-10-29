---Accès au catalogue d'objets (Config.Items), partagé client/serveur.
---@class ItemsModule
local Items = PVP.define('Items')
local Logger = PVP.use('Logger')

Items.CONTAINERS = { 'bag', 'protected' }

function Items.init()
    for name, item in pairs(Config.Items) do
        if item.type == 'weapon' and item.ammo and not Config.Items[item.ammo] then
            Logger.warn('L\'arme "%s" utilise des munitions inconnues "%s"', name, item.ammo)
        end
    end
end

---@param name any
---@return table|nil
function Items.get(name)
    return type(name) == 'string' and Config.Items[name] or nil
end

---@param name any
---@return boolean
function Items.exists(name)
    return Items.get(name) ~= nil
end

---@param name string
---@return string
function Items.label(name)
    local item = Items.get(name)
    return item and item.label or name
end

---@param name string
---@param itemType 'weapon'|'ammo'|'consumable'|'money'
---@return boolean
function Items.isType(name, itemType)
    local item = Items.get(name)
    return item ~= nil and item.type == itemType
end

---@param id any
---@return boolean
function Items.isContainer(id)
    return type(id) == 'string' and Config.Containers[id] ~= nil
end

---Coffres (conteneurs `safeOnly`) dans l'ordre de leurs onglets.
---@return string[]
function Items.stashIds()
    local ids = {}
    for id, container in pairs(Config.Containers) do
        if container.safeOnly then ids[#ids + 1] = id end
    end
    table.sort(ids, function(a, b)
        return (Config.Containers[a].order or 0) < (Config.Containers[b].order or 0)
    end)
    return ids
end

---Poids total d'un conteneur { [nom] = quantité }.
---@param container table<string, integer>
---@return number
function Items.weightOf(container)
    local weight = 0.0
    for name, count in pairs(container) do
        local item = Items.get(name)
        if item then weight = weight + item.weight * count end
    end
    return weight
end

---Quantité totale (sac + conteneur protégé) dans un inventaire sérialisé.
---@param inventory { bag: table, protected: table }
---@param name string
---@return integer
function Items.countOwned(inventory, name)
    return (inventory.bag[name] or 0) + (inventory.protected[name] or 0)
end

---@param items table<string, integer>
---@return string ex: "2x Bandage, Pistolet, $120"
function Items.describe(items)
    local parts = {}
    for name, count in pairs(items) do
        if name == 'money' then
            parts[#parts + 1] = ('$%d'):format(count)
        elseif count > 1 then
            parts[#parts + 1] = ('%dx %s'):format(count, Items.label(name))
        else
            parts[#parts + 1] = Items.label(name)
        end
    end
    return table.concat(parts, ', ')
end
