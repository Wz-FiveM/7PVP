---Réglages du monde côté serveur : population ambiante de GTA par bucket de routage.
---Avec OneSync, c'est le serveur qui décide si la population apparaît : la couper ici
---évite qu'elle soit créée, au lieu de la supprimer après coup côté client.
---@class WorldServiceModule
local WorldService = PVP.define('WorldService')
local Logger = PVP.use('Logger')

function WorldService.init()
    WorldService.setupBucket(0)
    Logger.info('Population ambiante : %s', WorldService.isPopulationEnabled() and 'activée' or 'désactivée')
end

---@return boolean true si au moins un type de population ambiante est activé
function WorldService.isPopulationEnabled()
    local world = Config.World
    return world.ambientPeds or world.traffic or world.parkedVehicles
end

---Applique les réglages du monde à un bucket (le monde principal, ou celui d'un joueur
---dans le créateur de personnage).
---@param bucket integer
function WorldService.setupBucket(bucket)
    SetRoutingBucketPopulationEnabled(bucket, WorldService.isPopulationEnabled())
end
