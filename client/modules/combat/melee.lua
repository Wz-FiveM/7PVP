---Pas de coup de crosse : avec une arme à feu ou un explosif en main, les touches de corps à corps
---ne font plus rien. Le couteau et les poings ne sont pas concernés.
---@class MeleeModule
local Melee = PVP.define('Melee')
local State = PVP.use('State')

Melee.DISABLED_CONTROLS = { 140, 141, 142, 263, 264 }
Melee.MODES = { pvp = true, cod = true }
Melee.ARMED_FLAGS = 6 -- IsPedArmed : 2 (explosifs) + 4 (armes à feu), sans 1 (armes de mêlée)
Melee.CHECK_INTERVAL = 250

function Melee.init()
    CreateThread(Melee.controlLoop)
end

function Melee.controlLoop()
    while true do
        if Melee.MODES[State.mode] and IsPedArmed(PlayerPedId(), Melee.ARMED_FLAGS) then
            for _, control in ipairs(Melee.DISABLED_CONTROLS) do
                DisableControlAction(0, control, true)
            end
            Wait(0)
        else
            Wait(Melee.CHECK_INTERVAL)
        end
    end
end
