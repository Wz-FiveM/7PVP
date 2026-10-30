---Touches de raccourcis (1 à Config.ShortcutSlots) : sortir une arme ou utiliser un objet.
---@class ShortcutsModule
local Shortcuts = PVP.define('Shortcuts')
local State = PVP.use('State')
local Inventory = PVP.use('Inventory')
local Items = PVP.use('Items')
local Nui = PVP.use('Nui')
local Locale = PVP.use('Locale')

-- Sélection d'armes de GTA (roue sur TAB, catégories sur 1-9), remplacée par les raccourcis
Shortcuts.DISABLED_CONTROLS = { 37, 157, 158, 159, 160, 161, 162, 163, 164, 165 }

function Shortcuts.init()
    for slot = 1, Config.ShortcutSlots do
        Shortcuts.registerSlot(slot)
    end

    CreateThread(Shortcuts.controlLoop)
end

Shortcuts.hotbarToken = 0

---Barre de raccourcis du HUD : affichée quelques secondes après l'utilisation d'un raccourci
---(TAB, qui la montrait, ouvre maintenant le menu).
function Shortcuts.flashHotbar()
    Shortcuts.hotbarToken = Shortcuts.hotbarToken + 1
    local token = Shortcuts.hotbarToken
    Nui.send('hotbar', { visible = State.isAlive() })
    SetTimeout(Config.HotbarShowTime, function()
        if Shortcuts.hotbarToken == token then Nui.send('hotbar', { visible = false }) end
    end)
end

---@param slot integer
function Shortcuts.registerSlot(slot)
    local command = ('pvp_slot_%d'):format(slot)
    RegisterCommand(command, function()
        Shortcuts.use(slot)
    end, false)
    RegisterKeyMapping(command, Locale.t('Raccourci %d', slot), 'keyboard', tostring(slot))
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
    if not State.isAlive() or not State.player or not State.inPvp() then return end

    Shortcuts.flashHotbar()
    local name = State.player.inventory.shortcuts[slot]
    local item = Items.get(name)
    if not item or Inventory.count(name) <= 0 then return end

    if item.type == 'weapon' then
        Shortcuts.toggleWeapon(item)
    elseif item.type == 'consumable' or item.type == 'vehicle' then
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
