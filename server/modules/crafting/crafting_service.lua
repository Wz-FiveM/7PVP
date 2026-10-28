---Fabrication : transforme les matériaux récupérés sur les zombies (Config.Recipes).
---À côté de l'artisan de la zone safe ; les ingrédients sont pris dans le sac puis le conteneur protégé.
---@class CraftingServiceModule
local CraftingService = PVP.define('CraftingService')
local PlayerService = PVP.use('PlayerService')
local ContractService = PVP.use('ContractService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local SafeNpcs = PVP.use('SafeNpcs')
local Events = PVP.use('Events')

---@type table<string, table> id -> recette
CraftingService.recipes = {}

function CraftingService.init()
    for _, recipe in ipairs(Config.Recipes) do
        CraftingService.recipes[recipe.id] = recipe
    end
    Callback.register(Events.callbacks.craft, CraftingService.craft)
end

---@param source integer
---@param recipeId any
---@return { ok: boolean, message?: string }
function CraftingService.craft(source, recipeId)
    local player = PlayerService.get(source)
    local recipe = CraftingService.recipes[recipeId]
    if not player or player.dead or not recipe then return { ok = false, message = 'Fabrication impossible.' } end
    if not SafeNpcs.isNear(player:getCoords(), 'crafting', Config.SafeNpcs.useDistance + 2.0) then
        return { ok = false, message = SafeNpcs.hint('crafting') }
    end
    if player:getLevel() < (recipe.level or 1) then
        return { ok = false, message = ('Niveau %d requis.'):format(recipe.level) }
    end

    local inventory = player.inventory
    for item, count in pairs(recipe.ingredients) do
        if inventory:count(item) < count then
            return { ok = false, message = ('Il te manque : %s'):format(Items.label(item)) }
        end
    end
    if inventory:maxFit('bag', recipe.result.item) < recipe.result.count then
        return { ok = false, message = 'Ton sac est trop lourd.' }
    end

    for item, count in pairs(recipe.ingredients) do
        inventory:remove(item, count)
    end
    player:giveItem(recipe.result.item, recipe.result.count)
    ContractService.track(player, 'craft', 1)
    player:sync()
    return { ok = true, message = ('Fabriqué : %s'):format(Items.describe({ [recipe.result.item] = recipe.result.count })) }
end
