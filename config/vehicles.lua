-- Véhicules en objets : utiliser l'objet fait apparaître le véhicule et met le joueur au volant.
-- L'objet est retiré du sac. Pour le ranger : assis dedans, à l'arrêt, seul à bord, touche K.
-- N'importe quel joueur peut ranger n'importe quel véhicule sorti d'un objet : l'objet va à celui
-- qui range (on peut voler un véhicule laissé sans surveillance), le propriétaire est prévenu.
-- Un seul véhicule sorti par joueur : en sortir un autre range le précédent s'il est intact.
-- Un véhicule détruit est perdu. Déconnexion ou retour au lobby : il est rangé automatiquement.
-- Les armes montées sur certains véhicules sont désactivées (pas d'armes hors inventaire en PvP).
--
-- name : nom de l'objet (vehicle_<modèle>) ; model : modèle GTA ; image : web/public/items/<image>.png
-- weight : poids de l'objet en kg (vélo 1,5, moto 2,5, voiture 4, 4x4 5, utilitaire 6, hélico 8)
Config.VehicleOptions = {
    weight = 4.0, -- poids d'un véhicule sans `weight` dans Config.VehicleList
    storeKey = 'K', -- touche pour ranger le véhicule où l'on est assis (modifiable dans Paramètres > Raccourcis > FiveM)
    storeMaxSpeed = 6.0, -- km/h : au-dessus, le véhicule roule encore et ne peut pas être rangé
    plate = '7PVP', -- plaque des véhicules sortis
    deployCooldown = 5, -- secondes d'attente pour ressortir un véhicule, après en avoir sorti ou rangé un
}

-- Debout sur le toit d'un véhicule qui roule ou qui vole (Deluxo en vol, etc.) : le joueur y reste
-- accroché au lieu de glisser et tomber. Il s'y déplace avec les touches de marche, vise et tire ;
-- Espace (saut) le décroche, F le fait monter à une place libre. Véhicule arrêté au sol : marche normale.
-- Véhicule trop penché : le joueur tombe, avec l'élan du véhicule.
Config.VehicleRoof = {
    enabled = true,
    minSpeed = 1.5, -- m/s : en dessous (et au sol), on n'accroche pas le joueur
    walkSpeed = 1.6, -- m/s : vitesse de marche sur le toit
    runSpeed = 3.5, -- m/s : vitesse de course (touche sprint)
    turnSpeed = 540.0, -- °/s : vitesse à laquelle le joueur se tourne vers où il marche
    edgeMargin = 0.25, -- m gardés entre le joueur et le bord du véhicule
    maxTilt = 35.0, -- ° : véhicule plus penché que ça (avant/arrière ou côté), le joueur tombe
    anim = { dict = 'move_m@generic', walk = 'walk', run = 'run' }, -- animations de marche sur le toit
}

-- En PvP uniquement : pas de dégâts de choc à bord d'un véhicule, et un joueur qui tombe de sa moto
-- ou saute en marche reste debout, sans ragdoll. Les balles, le feu et les explosions blessent normalement.
Config.VehicleCrash = {
    enabled = true,
    exitGrace = 1500, -- ms de protection après avoir quitté le véhicule (le choc arrive juste après l'éjection)
}

Config.VehicleList = {
    -- Deux-roues et quads
    { model = 'bmx', label = 'BMX', weight = 1.5 },
    { model = 'faggio', label = 'Faggio', weight = 2.0 },
    { model = 'esskey', label = 'Esskey', weight = 2.5 },
    { model = 'manchez', label = 'Manchez', weight = 2.5 },
    { model = 'manchez2', label = 'Manchez Scout', weight = 2.5 },
    { model = 'ratbike', label = 'Rat Bike', weight = 2.5 },
    { model = 'cliffhanger', label = 'Cliffhanger', weight = 2.5 },
    { model = 'zombieb', label = 'Zombie Chopper', weight = 2.5 },
    { model = 'deathbike', label = 'Deathbike', weight = 2.5 },
    { model = 'policeb', label = 'Moto de police', weight = 2.5 },
    { model = 'oppressor', label = 'Oppressor', weight = 3.0 },
    { model = 'verus', label = 'Verus', weight = 3.0 },
    { model = 'blazer5', label = 'Blazer Aqua', weight = 3.0 },
    { model = 'caddy', label = 'Caddy', weight = 3.0 },

    -- Berlines, sportives et classiques
    { model = 'emperor', label = 'Emperor', weight = 4.0 },
    { model = 'intruder', label = 'Intruder', weight = 4.0 },
    { model = 'oracle', label = 'Oracle', weight = 4.0 },
    { model = 'felon', label = 'Felon', weight = 4.0 },
    { model = 'sentinel', label = 'Sentinel', weight = 4.0 },
    { model = 'schafter6', label = 'Schafter LWB blindée', weight = 4.5 },
    { model = 'cog552', label = 'Cognoscenti 55 blindée', weight = 4.5 },
    { model = 'kuruma', label = 'Kuruma', weight = 4.5 },
    { model = 'issi2', label = 'Issi', weight = 4.0 },
    { model = 'issi6', label = 'Issi Apocalypse', weight = 4.5 },
    { model = 'brioso2', label = 'Brioso 300', weight = 4.0 },
    { model = 'panto', label = 'Panto', weight = 4.0 },
    { model = 'pigalle', label = 'Pigalle', weight = 4.0 },
    { model = 'btype3', label = 'Roosevelt Valor', weight = 4.0 },
    { model = 'ztype', label = 'Z-Type', weight = 4.0 },
    { model = 'savestra', label = 'Savestra', weight = 4.0 },
    { model = 'toreador', label = 'Toreador', weight = 4.0 },
    { model = 'revolter', label = 'Revolter', weight = 4.0 },
    { model = 'jackal', label = 'Jackal', weight = 4.0 },
    { model = 'voltic2', label = 'Rocket Voltic', weight = 4.0 },
    { model = 'deluxo', label = 'Deluxo', weight = 4.0 },
    { model = 'vigilante', label = 'Vigilante', weight = 4.0 },
    { model = 'zr380', label = 'ZR380 Apocalypse', weight = 4.5 },
    { model = 'police3', label = 'Interceptor de police', weight = 4.0 },

    -- Muscle cars
    { model = 'ruiner', label = 'Ruiner', weight = 4.0 },
    { model = 'phantom2', label = 'Phantom Wedge', weight = 4.0 },
    { model = 'faction2', label = 'Faction Custom', weight = 4.0 },
    { model = 'dukes2', label = 'Duke O\'Death', weight = 4.0 },
    { model = 'gauntlet4', label = 'Gauntlet Hellfire', weight = 4.0 },
    { model = 'dominator4', label = 'Dominator Apocalypse', weight = 5.0 },
    { model = 'impaler4', label = 'Impaler Apocalypse', weight = 5.0 },
    { model = 'imperator', label = 'Imperator Apocalypse', weight = 5.0 },
    { model = 'slamvan', label = 'Slamvan', weight = 4.0 },
    { model = 'slamvan4', label = 'Slamvan Apocalypse', weight = 5.0 },
    { model = 'tornado6', label = 'Tornado Rat Rod', weight = 4.0 },
    { model = 'deviant', label = 'Deviant', weight = 4.0 },

    -- 4x4, SUV et tout-terrain
    { model = 'baller6', label = 'Baller LE LWB blindé', weight = 5.0 },
    { model = 'xls2', label = 'XLS blindé', weight = 5.0 },
    { model = 'habanero', label = 'Habanero', weight = 5.0 },
    { model = 'granger', label = 'Granger', weight = 5.0 },
    { model = 'dubsta3', label = 'Dubsta 6x6', weight = 6.0 },
    { model = 'mesa3', label = 'Mesa Merryweather', weight = 5.0 },
    { model = 'patriot', label = 'Patriot', weight = 5.0 },
    { model = 'contender', label = 'Contender', weight = 5.0 },
    { model = 'bjxl', label = 'BeeJay XL', weight = 5.0 },
    { model = 'bfinjection', label = 'BF Injection', weight = 5.0 },
    { model = 'dune3', label = 'Dune FAV', weight = 5.0 },
    { model = 'nightshark', label = 'Nightshark', weight = 5.0 },
    { model = 'insurgent', label = 'Insurgent', weight = 6.0 },
    { model = 'technical2', label = 'Technical Aqua', weight = 5.0 },
    { model = 'wastelander', label = 'Wastelander', weight = 5.0 },
    { model = 'monster3', label = 'Monster Apocalypse', weight = 6.0 },
    { model = 'monster4', label = 'Monster Future Shock', weight = 6.0 },
    { model = 'bruiser2', label = 'Bruiser Future Shock', weight = 6.0 },
    { model = 'brutus', label = 'Brutus Apocalypse', weight = 6.0 },
    { model = 'cerberus', label = 'Cerberus Apocalypse', weight = 6.0 },

    -- Utilitaires
    { model = 'bobcatxl', label = 'Bobcat XL', weight = 6.0 },
    { model = 'yosemite', label = 'Yosemite', weight = 6.0 },
    { model = 'ratloader', label = 'Rat-Loader', weight = 6.0 },
    { model = 'minivan2', label = 'Minivan Custom', weight = 6.0 },
    { model = 'moonbeam2', label = 'Moonbeam Custom', weight = 6.0 },
    { model = 'speedo2', label = 'Clown Van', weight = 6.0 },
    { model = 'surfer', label = 'Surfer', weight = 6.0 },
    { model = 'mule3', label = 'Mule', weight = 7.0 },
    { model = 'brickade', label = 'Brickade', weight = 7.0 },
    { model = 'vetir', label = 'Vetir', weight = 7.0 },
    { model = 'riot', label = 'Riot', weight = 7.0 },
    { model = 'policet', label = 'Transporteur de police', weight = 7.0 },

    -- Hélicoptères et avions
    { model = 'frogger', label = 'Frogger', weight = 8.0 },
    { model = 'maverick', label = 'Maverick', weight = 8.0 },
    { model = 'buzzard2', label = 'Buzzard', weight = 8.0 },
    { model = 'seasparrow', label = 'Sea Sparrow', weight = 8.0 },
    { model = 'microlight', label = 'Ultraléger', weight = 4.0 },

    -- Bateaux (à sortir au bord de l'eau)
    { model = 'dinghy4', label = 'Dinghy', weight = 5.0 },
    { model = 'seashark3', label = 'Seashark', weight = 2.5 },
    { model = 'suntrap', label = 'Suntrap', weight = 5.0 },
}

for _, vehicle in ipairs(Config.VehicleList) do
    Config.Items['vehicle_' .. vehicle.model] = {
        label = vehicle.label,
        type = 'vehicle',
        weight = vehicle.weight or Config.VehicleOptions.weight,
        model = vehicle.model,
        image = vehicle.model,
    }
end
