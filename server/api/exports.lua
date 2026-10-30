---API publique serveur, accessible depuis les autres ressources :
---    exports['7PVP']:addMoney(source, 500)
---@class ServerApiModule
local ServerApi = PVP.define('ServerApi')
local PlayerService = PVP.use('PlayerService')
local LootService = PVP.use('LootService')
local Zones = PVP.use('Zones')
local ChatService = PVP.use('ChatService')
local ShopPointsService = PVP.use('ShopPointsService')
local VipService = PVP.use('VipService')

ServerApi.EXPORTS = {
    'getPlayer', 'getMoney', 'addMoney', 'removeMoney', 'addXp',
    'giveItem', 'removeItem', 'getItemCount', 'getZone', 'isInSafeZone', 'dropLoot',
    'sendSystemMessage', 'announce',
    'getShopPoints', 'addShopPoints', 'removeShopPoints',
    'isVip',
}

function ServerApi.init()
    for _, name in ipairs(ServerApi.EXPORTS) do
        exports(name, ServerApi[name])
    end
end

---@param source integer
---@return table|nil données sérialisées du joueur
function ServerApi.getPlayer(source)
    local player = PlayerService.get(source)
    return player and player:serialize()
end

---@param source integer
---@return integer|nil argent total (sac + conteneur protégé)
function ServerApi.getMoney(source)
    local player = PlayerService.get(source)
    return player and player:getMoney()
end

---@param source integer
---@param amount integer ajouté dans le sac
---@return boolean
function ServerApi.addMoney(source, amount)
    local player = PlayerService.get(source)
    if not player then return false end
    player:addMoney(amount)
    player:sync()
    return true
end

---@param source integer
---@param amount integer
---@return boolean false si le joueur n'a pas assez d'argent
function ServerApi.removeMoney(source, amount)
    local player = PlayerService.get(source)
    if not player or not player:removeMoney(amount) then return false end
    player:sync()
    return true
end

---@param source integer
---@param amount integer
---@return boolean
function ServerApi.addXp(source, amount)
    local player = PlayerService.get(source)
    if not player then return false end
    player:addXp(amount)
    player:sync()
    return true
end

---@param source integer
---@param item string clé de Config.Items
---@param count? integer
---@param container? 'bag'|'protected'
---@return integer quantité réellement ajoutée (limitée par le poids)
function ServerApi.giveItem(source, item, count, container)
    local player = PlayerService.get(source)
    if not player then return 0 end
    local added = player:giveItem(item, count or 1, container)
    player:sync()
    return added
end

---@param source integer
---@param item string
---@param count? integer
---@return boolean
function ServerApi.removeItem(source, item, count)
    local player = PlayerService.get(source)
    if not player or not player:removeItem(item, count or 1) then return false end
    player:sync()
    return true
end

---@param source integer
---@param item string
---@return integer
function ServerApi.getItemCount(source, item)
    local player = PlayerService.get(source)
    return player and player:getItemCount(item) or 0
end

---@param source integer
---@return ZoneInfo|nil
function ServerApi.getZone(source)
    local player = PlayerService.get(source)
    return player and Zones.toInfo(player:getZone())
end

---@param source integer
---@return boolean
function ServerApi.isInSafeZone(source)
    local player = PlayerService.get(source)
    return player ~= nil and player:isInSafeZone()
end

---@param coords vector3
---@param items table<string, integer> ex: { weapon_pistol = 1, ammo_9mm = 24, money = 100 }
---@return integer|nil id du sac
function ServerApi.dropLoot(coords, items)
    return LootService.drop(coords, items)
end

---Message système dans le chat d'un joueur.
---@param source integer
---@param text string
function ServerApi.sendSystemMessage(source, text)
    ChatService.system(source, tostring(text))
end

---Message système dans le chat de tous les joueurs d'un mode ('pvp', 'freeroam').
---@param mode string
---@param text string
function ServerApi.announce(mode, text)
    ChatService.announce(mode, tostring(text))
end

---@param source integer
---@return integer|nil solde de points boutique
function ServerApi.getShopPoints(source)
    local player = PlayerService.get(source)
    return player and ShopPointsService.get(player)
end

---Crédite des points boutique (joueur en ligne ou licence, même hors ligne).
---@param target integer|string server id ou license:xxxx
---@param amount integer
---@param reason? string
---@param reference? string référence unique : un doublon n'est pas crédité
---@return 'ok'|'duplicate'|'invalid'|'error'
function ServerApi.addShopPoints(target, amount, reason, reference)
    local player = PlayerService.get(target)
    local identifier = player and player.identifier or (type(target) == 'string' and target:match('^license:%x+$'))
    if not identifier then return 'invalid' end
    return ShopPointsService.credit(identifier, amount, tostring(reason or 'export'), reference and tostring(reference))
end

---Dépense des points boutique d'un joueur en ligne.
---@param source integer
---@param amount integer
---@param reason? string
---@return boolean false si le solde est insuffisant
function ServerApi.removeShopPoints(source, amount, reason)
    local player = PlayerService.get(source)
    if not player or not ShopPointsService.spend(player, amount, tostring(reason or 'export')) then return false end
    player:sync()
    return true
end

---@param source integer
---@return boolean le joueur en ligne est VIP
function ServerApi.isVip(source)
    local player = PlayerService.get(source)
    return player ~= nil and VipService.isActive(player.identifier)
end
