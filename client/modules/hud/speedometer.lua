---Compteur de vitesse : en véhicule, en Freeroam uniquement, envoie vitesse, régime,
---rapport et état du moteur à l'interface ; il disparaît à la sortie du véhicule.
---@class SpeedometerModule
local Speedometer = PVP.define('Speedometer')
local State = PVP.use('State')
local Nui = PVP.use('Nui')

Speedometer.INTERVAL = 100
Speedometer.IDLE_INTERVAL = 500
Speedometer.visible = false

function Speedometer.init()
    CreateThread(Speedometer.loop)
end

function Speedometer.loop()
    while true do
        local vehicle = Speedometer.currentVehicle()
        if vehicle then
            Speedometer.send(vehicle)
            Wait(Speedometer.INTERVAL)
        else
            if Speedometer.visible then
                Speedometer.visible = false
                Nui.send('speedometer', { visible = false })
            end
            Wait(Speedometer.IDLE_INTERVAL)
        end
    end
end

---@return integer|nil véhicule où est le joueur (vivant, en Freeroam), sinon nil
function Speedometer.currentVehicle()
    if State.mode ~= 'freeroam' or not State.isAlive() then return nil end
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then return nil end
    return vehicle
end

---@param vehicle integer
function Speedometer.send(vehicle)
    Speedometer.visible = true
    local gear = GetVehicleCurrentGear(vehicle)
    local speed = GetEntitySpeed(vehicle) * 3.6
    -- Marche arrière : vitesse vers l'arrière du véhicule
    local reversing = GetEntitySpeedVector(vehicle, true).y < -0.5
    Nui.send('speedometer', {
        visible = true,
        speed = math.floor(speed + 0.5),
        rpm = GetIsVehicleEngineRunning(vehicle) and GetVehicleCurrentRpm(vehicle) or 0.0,
        gear = reversing and 'R' or (speed < 1.0 and 'N' or tostring(math.max(1, gear))),
        engine = math.max(0, math.min(100, math.floor(GetVehicleEngineHealth(vehicle) / 10))),
    })
end
