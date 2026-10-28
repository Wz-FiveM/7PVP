---Inventaire d'un joueur : sac, conteneur protégé et coffre (limite de poids) + raccourcis.
---Données pures, aucun native. Toutes les entrées venant du client sont validées ici.
---@class PvpInventory
---@field bag table<string, integer> perdu à la mort
---@field protected table<string, integer> conservé à la mort
---@field stash table<string, integer> coffre : conservé, utilisable seulement en zone safe
---@field shortcuts (string|false)[] objet assigné à chaque touche (false = vide)
---@field attachments table<string, table<string, boolean>> arme -> accessoires fixés dessus
local InventoryObject = PVP.define('InventoryObject')
local Items = PVP.use('Items')
local Utils = PVP.use('Utils')

InventoryObject.__index = InventoryObject

---@param data? table
---@return PvpInventory
function InventoryObject.new(data)
    data = type(data) == 'table' and data or {}
    local saved = type(data.shortcuts) == 'table' and data.shortcuts or {}

    local shortcuts = {}
    for slot = 1, Config.ShortcutSlots do
        shortcuts[slot] = Items.exists(saved[slot]) and saved[slot] or false
    end

    return setmetatable({
        bag = InventoryObject.sanitize(data.bag),
        protected = InventoryObject.sanitize(data.protected),
        stash = InventoryObject.sanitize(data.stash),
        shortcuts = shortcuts,
        attachments = InventoryObject.sanitizeAttachments(data.attachments),
    }, InventoryObject)
end

---Ne garde que les objets connus avec une quantité entière positive.
---@param container any
---@return table<string, integer>
function InventoryObject.sanitize(container)
    local clean = {}
    if type(container) ~= 'table' then return clean end
    for name, count in pairs(container) do
        count = math.floor(tonumber(count) or 0)
        if Items.exists(name) and count > 0 then
            clean[name] = count
        end
    end
    return clean
end

---Ne garde que les accessoires compatibles avec leur arme (voir Config.Attachments).
---@param data any
---@return table<string, table<string, boolean>>
function InventoryObject.sanitizeAttachments(data)
    local clean = {}
    if type(data) ~= 'table' then return clean end
    for weapon, list in pairs(data) do
        if type(list) == 'table' then
            for attachment, on in pairs(list) do
                if on == true and Config.Attachments[attachment] and Config.Attachments[attachment][weapon] then
                    clean[weapon] = clean[weapon] or {}
                    clean[weapon][attachment] = true
                end
            end
        end
    end
    return clean
end

---@param kit { bag: table, protected?: table }
---@return PvpInventory
function InventoryObject.fromKit(kit)
    return InventoryObject.new({
        bag = Utils.shallowCopy(kit.bag),
        protected = Utils.shallowCopy(kit.protected or {}),
    })
end

---@param raw string|nil
---@return PvpInventory
function InventoryObject.decode(raw)
    local ok, data = pcall(json.decode, raw or '')
    if not ok or type(data) ~= 'table' then
        return InventoryObject.fromKit(Config.NewPlayerKit)
    end
    return InventoryObject.new(data)
end

---@return string
function InventoryObject:encode()
    return json.encode(self:serialize())
end

---@return table
function InventoryObject:serialize()
    return {
        bag = self.bag,
        protected = self.protected,
        stash = self.stash,
        shortcuts = self.shortcuts,
        attachments = self.attachments,
    }
end

-- ---------------------------------------------------------------------------
-- Lecture
-- ---------------------------------------------------------------------------

---Quantité portée (sac + conteneur protégé ; le coffre n'est pas porté).
---@param name string
---@return integer
function InventoryObject:count(name)
    return (self.bag[name] or 0) + (self.protected[name] or 0)
end

---@param container 'bag'|'protected'|'stash'
---@param name string
---@return integer
function InventoryObject:countIn(container, name)
    if not Items.isContainer(container) then return 0 end
    return self[container][name] or 0
end

---@param container 'bag'|'protected'|'stash'
---@return number
function InventoryObject:getWeight(container)
    return Items.weightOf(self[container])
end

---@param container 'bag'|'protected'|'stash'
---@return number
function InventoryObject:getCapacity(container)
    return Config.Containers[container].capacity
end

---Nombre maximum d'unités de `name` qu'on peut encore mettre dans `container`.
---@param container 'bag'|'protected'|'stash'
---@param name string
---@return number
function InventoryObject:maxFit(container, name)
    local item = Items.get(name)
    if not item or not Items.isContainer(container) then return 0 end
    if item.weight <= 0 then return math.huge end
    local free = self:getCapacity(container) - self:getWeight(container)
    return math.max(0, math.floor((free + 1e-6) / item.weight))
end

-- ---------------------------------------------------------------------------
-- Écriture
-- ---------------------------------------------------------------------------

---Ajoute autant d'unités que le poids le permet.
---@param container 'bag'|'protected'|'stash'
---@param name string
---@param count integer
---@return integer quantité réellement ajoutée
function InventoryObject:add(container, name, count)
    count = math.floor(tonumber(count) or 0)
    if count <= 0 then return 0 end

    local added = math.min(count, self:maxFit(container, name))
    if added > 0 then
        self[container][name] = (self[container][name] or 0) + added
    end
    return added
end

---@param container 'bag'|'protected'|'stash'
---@param name string
---@param count integer
---@return integer quantité réellement retirée
function InventoryObject:removeFrom(container, name, count)
    count = math.floor(tonumber(count) or 0)
    local current = self:countIn(container, name)
    local removed = math.min(count, current)
    if removed <= 0 then return 0 end

    self[container][name] = current > removed and current - removed or nil
    return removed
end

---Retire `count` unités, en vidant le sac avant le conteneur protégé.
---@param name string
---@param count integer
---@return boolean false si la quantité totale est insuffisante (rien n'est retiré)
function InventoryObject:remove(name, count)
    if count < 0 or self:count(name) < count then return false end
    local fromBag = self:removeFrom('bag', name, count)
    self:removeFrom('protected', name, count - fromBag)
    return true
end

---@param from 'bag'|'protected'|'stash'
---@param to 'bag'|'protected'|'stash'
---@param name string
---@param count integer
---@return boolean ok, string|nil message d'erreur
function InventoryObject:move(from, to, name, count)
    count = math.floor(tonumber(count) or 0)
    if not Items.isContainer(from) or not Items.isContainer(to) or from == to then
        return false, 'Déplacement invalide.'
    end
    if count <= 0 or self:countIn(from, name) < count then
        return false, 'Quantité invalide.'
    end
    if self:maxFit(to, name) < count then
        return false, ('Pas assez de place dans : %s.'):format(Config.Containers[to].label)
    end

    self:removeFrom(from, name, count)
    self:add(to, name, count)
    return true
end

---Vide le sac et renvoie son contenu (pour le sac de butin à la mort).
---Les accessoires d'une arme qui n'est plus possédée nulle part tombent avec elle.
---@return table<string, integer>
function InventoryObject:takeBag()
    local bag = self.bag
    self.bag = {}
    for name in pairs(Utils.shallowCopy(bag)) do
        for attachment, count in pairs(self:releaseAttachments(name)) do
            bag[attachment] = (bag[attachment] or 0) + count
        end
    end
    return bag
end

-- ---------------------------------------------------------------------------
-- Accessoires d'armes
-- ---------------------------------------------------------------------------

---@param name string
---@return integer quantité possédée partout (sac, conteneur protégé et coffre)
function InventoryObject:countEverywhere(name)
    return self:count(name) + (self.stash[name] or 0)
end

---Fixe un accessoire de l'inventaire (sac ou conteneur protégé) sur une arme portée.
---@param weapon string
---@param attachment string
---@return boolean ok, string|nil message
function InventoryObject:attach(weapon, attachment)
    local compatible = Config.Attachments[attachment]
    if not compatible or not compatible[weapon] then return false, 'Accessoire incompatible avec cette arme.' end
    if self:count(weapon) <= 0 then return false, 'Tu dois porter l\'arme.' end
    if self.attachments[weapon] and self.attachments[weapon][attachment] then return false, 'Déjà fixé.' end
    if not self:remove(attachment, 1) then return false, 'Tu n\'as pas cet accessoire.' end

    self.attachments[weapon] = self.attachments[weapon] or {}
    self.attachments[weapon][attachment] = true
    return true
end

---Retire un accessoire d'une arme : il revient dans le sac.
---@param weapon string
---@param attachment string
---@return boolean ok, string|nil message
function InventoryObject:detach(weapon, attachment)
    local list = self.attachments[weapon]
    if not list or not list[attachment] then return false, 'Accessoire absent.' end
    if self:add('bag', attachment, 1) < 1 then return false, 'Ton sac est plein.' end

    list[attachment] = nil
    if next(list) == nil then self.attachments[weapon] = nil end
    return true
end

---Arme plus possédée nulle part : ses accessoires sont détachés et renvoyés (pour tomber au sol).
---@param weapon string
---@return table<string, integer>
function InventoryObject:releaseAttachments(weapon)
    local released = {}
    local list = self.attachments[weapon]
    if not list or self:countEverywhere(weapon) > 0 then return released end
    for attachment in pairs(list) do released[attachment] = 1 end
    self.attachments[weapon] = nil
    return released
end

---@param items table<string, integer>
function InventoryObject:setBag(items)
    self.bag = InventoryObject.sanitize(Utils.shallowCopy(items))
end

---Seules les armes et les consommables peuvent être assignés à un raccourci.
---@param slot any
---@param name any nil/false pour vider l'emplacement
---@return boolean
function InventoryObject:setShortcut(slot, name)
    slot = math.floor(tonumber(slot) or 0)
    if slot < 1 or slot > Config.ShortcutSlots then return false end
    if name and not (Items.isType(name, 'weapon') or Items.isType(name, 'consumable')) then return false end
    self.shortcuts[slot] = name or false
    return true
end
