---Effets des objets consommables sur le ped (l'inventaire lui-même est serveur).
---@class InventoryModule
local Inventory = PVP.define('Inventory')
local State = PVP.use('State')
local Items = PVP.use('Items')
local Callback = PVP.use('Callback')
local Nui = PVP.use('Nui')
local Effects = PVP.use('Effects')
local Events = PVP.use('Events')

function Inventory.init()
    RegisterNetEvent(Events.client.applyItem, function(name)
        Inventory.applyItem(name)
    end)
end

---@param name string
---@return integer quantité possédée (sac + conteneur protégé)
function Inventory.count(name)
    if not State.player then return 0 end
    return Items.countOwned(State.player.inventory, name)
end

---Demande au serveur d'utiliser un consommable. À appeler depuis un thread.
---@param name string
function Inventory.use(name)
    local result = Callback.await(Events.callbacks.useItem, name)
    if result and result.message then
        Nui.notify(result.message, result.ok and 'success' or 'error')
    end
end

---Sort une arme possédée.
---@param name string
function Inventory.equip(name)
    local item = Items.get(name)
    if not item or item.type ~= 'weapon' or Inventory.count(name) <= 0 or not State.isAlive() then return end
    SetCurrentPedWeapon(PlayerPedId(), GetHashKey(item.weapon), true)
end

---@param name string clé de Config.Items
function Inventory.applyItem(name)
    local item = Items.get(name)
    if not item or State.dead then return end

    local ped = PlayerPedId()
    if item.heal then
        SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + item.heal))
    end
    if item.armor then
        SetPedArmour(ped, math.min(100, GetPedArmour(ped) + item.armor))
    end
    if item.effect then
        Effects.start(item.effect)
    end
    if item.repair then
        Inventory.repairVehicle(ped)
    end
end

---Répare le véhicule où est le joueur, sinon le dernier conduit (le serveur a vérifié qu'il est à côté).
---@param ped integer
function Inventory.repairVehicle(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then vehicle = GetVehiclePedIsIn(ped, true) end
    if vehicle == 0 then return end
    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
end
