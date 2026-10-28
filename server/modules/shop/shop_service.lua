---@class ShopServiceModule
local ShopService = PVP.define('ShopService')
local PlayerService = PVP.use('PlayerService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Events = PVP.use('Events')

function ShopService.init()
    Callback.register(Events.callbacks.buy, ShopService.buy)
end

---@param source integer
---@param index integer index (1-based) dans Config.Shop
---@return { ok: boolean, message: string }
function ShopService.buy(source, index)
    local player = PlayerService.get(source)
    local entry = Config.Shop[tonumber(index)]
    if not player or player.dead or not entry then
        return { ok = false, message = 'Achat impossible.' }
    end
    if not player:isInSafeZone() then
        return { ok = false, message = 'La boutique n\'est accessible qu\'en zone safe.' }
    end
    if player:getLevel() < (entry.level or 1) then
        return { ok = false, message = ('Niveau %d requis.'):format(entry.level) }
    end
    if player:getMoney() < entry.price then
        return { ok = false, message = 'Pas assez d\'argent.' }
    end
    if player.inventory:maxFit('bag', entry.item) < entry.count then
        return { ok = false, message = 'Ton sac est trop lourd.' }
    end

    player:removeMoney(entry.price)
    player:giveItem(entry.item, entry.count)
    player:sync()
    return { ok = true, message = ('Acheté : %s'):format(Items.describe({ [entry.item] = entry.count })) }
end
