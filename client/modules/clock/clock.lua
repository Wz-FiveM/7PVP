---Applique l'heure commune du jeu (shared/modules/clock.lua) et l'affiche dans le HUD.
---Le mode Call of Duty impose à la place son heure et sa météo (Config.Cod.sky).
---@class ClockClientModule
local ClockClient = PVP.define('ClockClient')
local Clock = PVP.use('Clock')
local Nui = PVP.use('Nui')
local State = PVP.use('State')

ClockClient.INTERVAL = 1000
ClockClient.lastMinute = -1
ClockClient.skyForced = false

function ClockClient.init()
    CreateThread(ClockClient.loop)
end

function ClockClient.loop()
    while true do
        local hour, minute = Clock.time()
        if State.mode == 'cod' then
            ClockClient.forceSky(Config.Cod.sky)
        else
            ClockClient.releaseSky()
            NetworkOverrideClockTime(hour, minute, 0)
        end
        if minute ~= ClockClient.lastMinute then
            ClockClient.lastMinute = minute
            Nui.send('clock', { hour = hour, minute = minute, night = Clock.isNight() })
        end
        Wait(ClockClient.INTERVAL)
    end
end

---@param sky { hour: integer, minute: integer, weather: string }
function ClockClient.forceSky(sky)
    ClockClient.skyForced = true
    PauseClock(true)
    NetworkOverrideClockTime(sky.hour, sky.minute, 0)
    SetOverrideWeather(sky.weather)
    SetWeatherTypeNowPersist(sky.weather)
end

---Rend la météo au cycle normal du jeu en quittant le mode.
function ClockClient.releaseSky()
    if not ClockClient.skyForced then return end
    ClockClient.skyForced = false
    PauseClock(false)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
end
