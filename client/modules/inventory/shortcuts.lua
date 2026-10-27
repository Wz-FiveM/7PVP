---Touches de raccourcis (1 à Config.ShortcutSlots) : sortir une arme ou utiliser un objet.
---@class ShortcutsModule
local Shortcuts = PVP.define('Shortcuts')
local State = PVP.use('State')
local Inventory = PVP.use('Inventory')
local Items = PVP.use('Items')

-- Sélection d'armes par catégorie de GTA, remplacée par les raccourcis
Shortcuts.DISABLED_CONTROLS = { 157, 158, 159, 160, 161, 162, 163, 164, 165 }

function Shortcuts.init()
    for slot = 1, Config.ShortcutSlots do
        Shortcuts.registerSlot(slot)
    end
    CreateThread(Shortcuts.controlLoop)
end

---@param slot integer
function Shortcuts.registerSlot(slot)
    local command = ('pvp_slot_%d'):format(slot)
    RegisterCommand(command, function()
        Shortcuts.use(slot)
    end, false)
    RegisterKeyMapping(command, ('Raccourci %d'):format(slot), 'keyboard', tostring(slot))
end

function Shortcuts.controlLoop()
    while true do
        Wait(0)
        for _, control in ipairs(Shortcuts.DISABLED_CONTROLS) do
            DisableControlAction(0, control, true)
        end
    end
end

---@param slot integer
function Shortcuts.use(slot)
    if not State.isAlive() or not State.player then return end

    local name = State.player.inventory.shortcuts[slot]
    local item = Items.get(name)
    if not item or Inventory.count(name) <= 0 then return end

    if item.type == 'weapon' then
        Shortcuts.toggleWeapon(item)
    elseif item.type == 'consumable' then
        CreateThread(function()
            Inventory.use(name)
        end)
    end
end

---Sort l'arme, ou la range si elle est déjà en main.
---@param item table
function Shortcuts.toggleWeapon(item)
    local ped = PlayerPedId()
    local hash = GetHashKey(item.weapon)
    if GetSelectedPedWeapon(ped) == hash then
        SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
    else
        SetCurrentPedWeapon(ped, hash, true)
    end
end
