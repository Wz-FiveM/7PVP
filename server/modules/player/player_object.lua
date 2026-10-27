---Joueur connecté. Toutes les modifications d'argent, d'XP et d'inventaire passent par ici.
---L'argent est un objet (`money`) de l'inventaire.
---@class PvpPlayer
---@field source integer
---@field identifier string
---@field name string
---@field xp integer
---@field kills integer
---@field deaths integer
---@field npcKills integer
---@field inventory PvpInventory
---@field ammoSeq integer dernier rapport de munitions traité
---@field dead boolean
local PlayerObject = PVP.define('PlayerObject')
local InventoryObject = PVP.use('InventoryObject')
local Items = PVP.use('Items')
local Progression = PVP.use('Progression')
local Zones = PVP.use('Zones')
local Events = PVP.use('Events')

PlayerObject.__index = PlayerObject

---@param source integer
---@param identifier string
---@param row table ligne de la table pvp_players
---@return PvpPlayer
function PlayerObject.new(source, identifier, row)
    return setmetatable({
        source = source,
        identifier = identifier,
        name = GetPlayerName(source),
        xp = row.xp,
        kills = row.kills,
        deaths = row.deaths,
        npcKills = row.npc_kills,
        inventory = InventoryObject.decode(row.inventory),
        ammoSeq = 0,
        dead = false,
    }, PlayerObject)
end

-- ---------------------------------------------------------------------------
-- Monde
-- ---------------------------------------------------------------------------

function PlayerObject:getPed()
    return GetPlayerPed(self.source)
end

---@return vector3
function PlayerObject:getCoords()
    return GetEntityCoords(self:getPed())
end

function PlayerObject:getZone()
    return Zones.getAt(self:getCoords())
end

---@return boolean
function PlayerObject:isInSafeZone()
    return Zones.isSafe(self:getCoords())
end

-- ---------------------------------------------------------------------------
-- Communication
-- ---------------------------------------------------------------------------

---@param message string
---@param kind? 'info'|'success'|'error'
function PlayerObject:notify(message, kind)
    TriggerClientEvent(Events.client.notify, self.source, message, kind or 'info')
end

function PlayerObject:sync()
    TriggerClientEvent(Events.client.sync, self.source, self:serialize())
end

---@return table
function PlayerObject:serialize()
    return {
        source = self.source,
        name = self.name,
        money = self:getMoney(),
        xp = self.xp,
        level = self:getLevel(),
        kills = self.kills,
        deaths = self.deaths,
        npcKills = self.npcKills,
        inventory = self.inventory:serialize(),
        ammoSeq = self.ammoSeq,
    }
end

-- ---------------------------------------------------------------------------
-- Argent / progression
-- ---------------------------------------------------------------------------

---@return integer argent total (sac + conteneur protégé)
function PlayerObject:getMoney()
    return self.inventory:count('money')
end

---L'argent gagné arrive dans le sac.
---@param amount integer
function PlayerObject:addMoney(amount)
    self.inventory:add('bag', 'money', amount)
end

---@param amount integer
---@return boolean
function PlayerObject:removeMoney(amount)
    return self.inventory:remove('money', amount)
end

---@return integer
function PlayerObject:getLevel()
    return Progression.levelFromXp(self.xp)
end

---@param amount integer
function PlayerObject:addXp(amount)
    if amount <= 0 then return end
    local before = self:getLevel()
    self.xp = self.xp + amount
    if self:getLevel() > before then
        self:notify(('Niveau %d atteint !'):format(self:getLevel()), 'success')
    end
end

-- ---------------------------------------------------------------------------
-- Inventaire
-- ---------------------------------------------------------------------------

---@param name string
---@param count integer
---@param container? 'bag'|'protected' (défaut : bag)
---@return integer quantité réellement ajoutée (limitée par le poids)
function PlayerObject:giveItem(name, count, container)
    return self.inventory:add(container or 'bag', name, count)
end

---@param name string
---@param count integer
---@return boolean
function PlayerObject:removeItem(name, count)
    return self.inventory:remove(name, count)
end

---@param name string
---@return integer
function PlayerObject:getItemCount(name)
    return self.inventory:count(name)
end

---Vide le sac et renvoie son contenu (le conteneur protégé est conservé).
---@return table<string, integer>
function PlayerObject:takeBag()
    return self.inventory:takeBag()
end

function PlayerObject:applyRespawnKit()
    self.inventory:setBag(Config.RespawnKit)
end

---Munitions tirées, rapportées par le client. `seq` évite de traiter deux fois un rapport.
---@param seq any
---@param report any table<string, number>
---@return boolean
function PlayerObject:consumeAmmo(seq, report)
    seq = tonumber(seq)
    if not seq or seq <= self.ammoSeq or type(report) ~= 'table' then return false end
    self.ammoSeq = seq

    for name, used in pairs(report) do
        if Items.isType(name, 'ammo') and type(used) == 'number' and used > 0 then
            self.inventory:remove(name, math.min(math.floor(used), self.inventory:count(name)))
        end
    end
    return true
end
