---Réglages du monde côté client : population ambiante de GTA.
---Le serveur coupe déjà la population (voir server/modules/world/world_service.lua) ;
---ici on met aussi les densités à zéro, en sécurité et pour régler chaque type à part.
---Les PNJ des zones PvE sont créés par le serveur et ne sont pas concernés.
---@class WorldModule
local World = PVP.define('World')

function World.init()
    World.applyOnce()
    CreateThread(World.densityLoop)
end

---Réglages qui n'ont besoin d'être appliqués qu'une fois.
function World.applyOnce()
    local world = Config.World

    SetCreateRandomCops(world.ambientPeds)
    SetCreateRandomCopsNotOnScenarios(world.ambientPeds)
    SetCreateRandomCopsOnScenarios(world.ambientPeds)
    SetGarbageTrucks(world.traffic)
    SetRandomBoats(world.traffic)
    SetRandomTrains(world.traffic)
    SetPedPopulationBudget(world.ambientPeds and 3 or 0)
    SetVehiclePopulationBudget((world.traffic or world.parkedVehicles) and 3 or 0)
end

---Les multiplicateurs de densité se réappliquent à chaque image.
function World.densityLoop()
    local world = Config.World
    local peds = world.ambientPeds and 1.0 or 0.0
    local traffic = world.traffic and 1.0 or 0.0
    local parked = world.parkedVehicles and 1.0 or 0.0

    while true do
        Wait(0)
        SetPedDensityMultiplierThisFrame(peds)
        SetScenarioPedDensityMultiplierThisFrame(peds, peds)
        SetVehicleDensityMultiplierThisFrame(traffic)
        SetRandomVehicleDensityMultiplierThisFrame(traffic)
        SetParkedVehicleDensityMultiplierThisFrame(parked)
    end
end
