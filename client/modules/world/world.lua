---Réglages du monde côté client : population ambiante de GTA et IPL de la carte.
---Le serveur coupe déjà la population (voir server/modules/world/world_service.lua) ;
---ici on met aussi les densités à zéro, en sécurité et pour régler chaque type à part.
---Les PNJ des zones PvE sont créés par le serveur et ne sont pas concernés.
---@class WorldModule
local World = PVP.define('World')

function World.init()
    World.applyOnce()
    CreateThread(World.densityLoop)
    CreateThread(World.loadIpls)
end

---Retire d'abord les états écartés (certains sont actifs d'origine), puis charge le reste
---par petits lots : le jeu ne streame ensuite que ce qui est près du joueur.
function World.loadIpls()
    local ipls = Config.Ipls
    local count = 0

    for _, name in ipairs(ipls.remove) do
        RemoveIpl(name)
    end
    for _, name in ipairs(ipls.load) do
        RequestIpl(name)
        count = count + 1
        if count % ipls.perFrame == 0 then Wait(0) end
    end
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
    -- Générateurs de véhicules de la carte (hélicoptères des héliports, voitures garées fixes) :
    -- ils créent des véhicules même population coupée
    local generators = world.parkedVehicles
    SetAllVehicleGeneratorsActiveInArea(-10000.0, -10000.0, -1000.0, 10000.0, 10000.0, 1000.0, generators, false)
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
