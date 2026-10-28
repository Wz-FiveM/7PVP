-- Véhicules en objets : utiliser l'objet fait apparaître le véhicule et met le joueur au volant.
-- L'objet est retiré du sac. Pour le ranger : assis dedans, à l'arrêt, seul à bord, touche K.
-- N'importe quel joueur peut ranger n'importe quel véhicule sorti d'un objet : l'objet va à celui
-- qui range (on peut voler un véhicule laissé sans surveillance), le propriétaire est prévenu.
-- Un seul véhicule sorti par joueur : en sortir un autre range le précédent s'il est intact.
-- Un véhicule détruit est perdu. Déconnexion ou retour au lobby : il est rangé automatiquement.
-- Les armes montées sur certains véhicules sont désactivées (pas d'armes hors inventaire en PvP).
--
-- name : nom de l'objet (vehicle_<modèle>) ; model : modèle GTA ; image : web/public/items/<image>.png
Config.VehicleOptions = {
    weight = 1.0, -- poids de l'objet (une clé, pas le véhicule)
    storeKey = 'K', -- touche pour ranger le véhicule où l'on est assis (modifiable dans Paramètres > Raccourcis > FiveM)
    storeMaxSpeed = 3.0, -- km/h : au-dessus, le véhicule roule encore et ne peut pas être rangé
    plate = '7PVP', -- plaque des véhicules sortis
}

-- Debout sur le toit d'un véhicule qui roule ou qui vole (Deluxo en vol, etc.) : le joueur y reste
-- accroché au lieu de glisser et tomber. Il s'y déplace avec les touches de marche, vise et tire ;
-- Espace (saut) le décroche, F le fait monter à une place libre. Véhicule arrêté au sol : marche normale.
Config.VehicleRoof = {
    enabled = true,
    minSpeed = 1.5, -- m/s : en dessous (et au sol), on n'accroche pas le joueur
    walkSpeed = 1.6, -- m/s : vitesse de marche sur le toit
    edgeMargin = 0.25, -- m gardés entre le joueur et le bord du véhicule
}

Config.VehicleList = {
    -- Deux-roues et quads
    { model = 'bmx', label = 'BMX' },
    { model = 'faggio', label = 'Faggio' },
    { model = 'esskey', label = 'Esskey' },
    { model = 'manchez', label = 'Manchez' },
    { model = 'manchez2', label = 'Manchez Scout' },
    { model = 'ratbike', label = 'Rat Bike' },
    { model = 'cliffhanger', label = 'Cliffhanger' },
    { model = 'zombieb', label = 'Zombie Chopper' },
    { model = 'deathbike', label = 'Deathbike' },
    { model = 'policeb', label = 'Moto de police' },
    { model = 'oppressor', label = 'Oppressor' },
    { model = 'verus', label = 'Verus' },
    { model = 'blazer5', label = 'Blazer Aqua' },
    { model = 'caddy', label = 'Caddy' },

    -- Berlines, sportives et classiques
    { model = 'emperor', label = 'Emperor' },
    { model = 'intruder', label = 'Intruder' },
    { model = 'oracle', label = 'Oracle' },
    { model = 'felon', label = 'Felon' },
    { model = 'sentinel', label = 'Sentinel' },
    { model = 'schafter6', label = 'Schafter LWB blindée' },
    { model = 'cog552', label = 'Cognoscenti 55 blindée' },
    { model = 'kuruma', label = 'Kuruma' },
    { model = 'issi2', label = 'Issi' },
    { model = 'issi6', label = 'Issi Apocalypse' },
    { model = 'brioso2', label = 'Brioso 300' },
    { model = 'pigalle', label = 'Pigalle' },
    { model = 'btype3', label = 'Roosevelt Valor' },
    { model = 'ztype', label = 'Z-Type' },
    { model = 'savestra', label = 'Savestra' },
    { model = 'toreador', label = 'Toreador' },
    { model = 'revolter', label = 'Revolter' },
    { model = 'jackal', label = 'Jackal' },
    { model = 'voltic2', label = 'Rocket Voltic' },
    { model = 'deluxo', label = 'Deluxo' },
    { model = 'vigilante', label = 'Vigilante' },
    { model = 'zr380', label = 'ZR380 Apocalypse' },
    { model = 'police3', label = 'Interceptor de police' },

    -- Muscle cars
    { model = 'ruiner', label = 'Ruiner' },
    { model = 'phantom2', label = 'Phantom Wedge' },
    { model = 'faction2', label = 'Faction Custom' },
    { model = 'dukes2', label = 'Duke O\'Death' },
    { model = 'gauntlet4', label = 'Gauntlet Hellfire' },
    { model = 'dominator4', label = 'Dominator Apocalypse' },
    { model = 'impaler4', label = 'Impaler Apocalypse' },
    { model = 'imperator', label = 'Imperator Apocalypse' },
    { model = 'slamvan', label = 'Slamvan' },
    { model = 'slamvan4', label = 'Slamvan Apocalypse' },
    { model = 'tornado6', label = 'Tornado Rat Rod' },
    { model = 'deviant', label = 'Deviant' },

    -- 4x4, SUV et tout-terrain
    { model = 'baller6', label = 'Baller LE LWB blindé' },
    { model = 'xls2', label = 'XLS blindé' },
    { model = 'habanero', label = 'Habanero' },
    { model = 'granger', label = 'Granger' },
    { model = 'dubsta3', label = 'Dubsta 6x6' },
    { model = 'mesa3', label = 'Mesa Merryweather' },
    { model = 'patriot', label = 'Patriot' },
    { model = 'contender', label = 'Contender' },
    { model = 'bjxl', label = 'BeeJay XL' },
    { model = 'bfinjection', label = 'BF Injection' },
    { model = 'dune3', label = 'Dune FAV' },
    { model = 'nightshark', label = 'Nightshark' },
    { model = 'insurgent', label = 'Insurgent' },
    { model = 'technical2', label = 'Technical Aqua' },
    { model = 'wastelander', label = 'Wastelander' },
    { model = 'monster3', label = 'Monster Apocalypse' },
    { model = 'monster4', label = 'Monster Future Shock' },
    { model = 'bruiser2', label = 'Bruiser Future Shock' },
    { model = 'brutus', label = 'Brutus Apocalypse' },
    { model = 'cerberus', label = 'Cerberus Apocalypse' },

    -- Utilitaires
    { model = 'bobcatxl', label = 'Bobcat XL' },
    { model = 'yosemite', label = 'Yosemite' },
    { model = 'ratloader', label = 'Rat-Loader' },
    { model = 'minivan2', label = 'Minivan Custom' },
    { model = 'moonbeam2', label = 'Moonbeam Custom' },
    { model = 'speedo2', label = 'Clown Van' },
    { model = 'surfer', label = 'Surfer' },
    { model = 'mule3', label = 'Mule' },
    { model = 'brickade', label = 'Brickade' },
    { model = 'vetir', label = 'Vetir' },
    { model = 'riot', label = 'Riot' },
    { model = 'policet', label = 'Transporteur de police' },

    -- Hélicoptères et avions
    { model = 'frogger', label = 'Frogger' },
    { model = 'maverick', label = 'Maverick' },
    { model = 'buzzard2', label = 'Buzzard' },
    { model = 'seasparrow', label = 'Sea Sparrow' },
    { model = 'microlight', label = 'Ultraléger' },

    -- Bateaux (à sortir au bord de l'eau)
    { model = 'dinghy4', label = 'Dinghy' },
    { model = 'seashark3', label = 'Seashark' },
    { model = 'suntrap', label = 'Suntrap' },
}

for _, vehicle in ipairs(Config.VehicleList) do
    Config.Items['vehicle_' .. vehicle.model] = {
        label = vehicle.label,
        type = 'vehicle',
        weight = Config.VehicleOptions.weight,
        model = vehicle.model,
        image = vehicle.model,
    }
end
