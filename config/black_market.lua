-- Marchand noir ambulant : apparaît de temps en temps hors des zones safe, vend quelques lots rares en
-- quantité limitée (le premier arrivé se sert), puis repart. Annoncé dans le chat et sur la carte.
-- Les prix restent au-dessus du receleur (config/resale.lua) : acheter puis revendre ne rapporte rien.
Config.BlackMarket = {
    enabled = true,
    firstDelay = 1200, -- secondes avant le premier passage après le démarrage
    interval = { 1800, 3600 }, -- secondes entre deux passages (au hasard)
    duration = 900, -- secondes de présence
    minPlayers = 2, -- joueurs en PvP pour qu'il se déplace
    interactDistance = 2.5, -- distance pour lui parler (E)
    useDistance = 8.0, -- distance pour acheter, menu ouvert
    drawDistance = 80.0,
    model = 's_m_m_chemsec_01',
    scenario = 'WORLD_HUMAN_SMOKING',
    blip = { sprite = 110, color = 1 },
    offers = 5, -- lots tirés à chaque passage parmi `stock`
    -- item, count : contenu d'un lot ; lots : nombre de lots en vente ; price : prix du lot
    stock = {
        { item = 'weapon_specialcarbine_mk2', count = 1, lots = 3, price = 12000 },
        { item = 'weapon_grenadelauncher', count = 1, lots = 2, price = 18000 },
        { item = 'ammo_grenade40', count = 6, lots = 4, price = 2400 },
        { item = 'weapon_rpg', count = 1, lots = 1, price = 25000 },
        { item = 'ammo_rocket', count = 2, lots = 4, price = 3000 },
        { item = 'weapon_stickybomb', count = 3, lots = 3, price = 4500 },
        { item = 'drug_health', count = 3, lots = 6, price = 1000 },
        { item = 'antizin', count = 3, lots = 6, price = 700 },
        { item = 'mat_chemicals', count = 10, lots = 5, price = 700 },
        { item = 'vehicle_nightshark', count = 1, lots = 1, price = 40000 },
        { item = 'vehicle_insurgent', count = 1, lots = 1, price = 55000 },
    },
    locations = {
        vector4(1392.0, 3605.0, 34.9, 200.0), -- Sandy Shores, le long de la route 68
        vector4(-1161.0, -1562.0, 4.3, 30.0), -- Vespucci Beach
        vector4(1215.0, -3225.0, 5.8, 0.0), -- docks d'Elysian Island
        vector4(-1097.0, 4945.0, 218.4, 0.0), -- camp des Altruistes
        vector4(2340.0, 3130.0, 48.2, 90.0), -- casse du désert de Senora
        vector4(711.0, 1198.0, 348.5, 180.0), -- panneau Vinewood
        vector4(2450.0, 4950.0, 45.0, 45.0), -- Grapeseed
        vector4(-260.0, -2030.0, 30.1, 145.0), -- Maze Bank Arena
    },
}
