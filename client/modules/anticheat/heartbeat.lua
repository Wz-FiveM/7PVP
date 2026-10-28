---Signal régulier envoyé au serveur : s'il s'arrête, le script du client a été coupé
---(menu de triche « resource stopper ») et l'anti-cheat réagit (voir AntiCheatService).
---@class HeartbeatModule
local Heartbeat = PVP.define('Heartbeat')
local Events = PVP.use('Events')

function Heartbeat.init()
    CreateThread(Heartbeat.loop)
end

function Heartbeat.loop()
    while true do
        TriggerServerEvent(Events.server.heartbeat)
        Wait(Config.AntiCheat.heartbeatInterval * 1000)
    end
end
