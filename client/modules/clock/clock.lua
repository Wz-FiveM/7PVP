---Applique l'heure commune du jeu (shared/modules/clock.lua) et l'affiche dans le HUD.
---@class ClockClientModule
local ClockClient = PVP.define('ClockClient')
local Clock = PVP.use('Clock')
local Nui = PVP.use('Nui')

ClockClient.INTERVAL = 1000
ClockClient.lastMinute = -1

function ClockClient.init()
    CreateThread(ClockClient.loop)
end

function ClockClient.loop()
    while true do
        local hour, minute = Clock.time()
        NetworkOverrideClockTime(hour, minute, 0)
        if minute ~= ClockClient.lastMinute then
            ClockClient.lastMinute = minute
            Nui.send('clock', { hour = hour, minute = minute, night = Clock.isNight() })
        end
        Wait(ClockClient.INTERVAL)
    end
end
