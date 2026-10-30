---@class ShopServiceModule
local ShopService = PVP.define('ShopService')
local PlayerService = PVP.use('PlayerService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local SafeNpcs = PVP.use('SafeNpcs')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

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
        return { ok = false, message = Locale.t('Achat impossible.') }
    end
    if not SafeNpcs.isNear(player:getCoords(), 'shop', Config.SafeNpcs.useDistance + 2.0) then
        return { ok = false, message = SafeNpcs.hint('shop') }
    end
    if player:getLevel() < (entry.level or 1) then
        return { ok = false, message = Locale.t('Niveau %d requis.', entry.level) }
    end
    if player:getMoney() < entry.price then
        return { ok = false, message = Locale.t('Pas assez d\'argent.') }
    end
    if player.inventory:maxFit('bag', entry.item) < entry.count then
        return { ok = false, message = Locale.t('Ton sac est trop lourd.') }
    end

    player:removeMoney(entry.price)
    player:giveItem(entry.item, entry.count)
    player:sync()
    return { ok = true, message = Locale.t('Acheté : %s', Items.describeText({ [entry.item] = entry.count })) }
end
