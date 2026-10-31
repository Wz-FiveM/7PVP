-- Call of Duty : listes de jeu Warzone (Battle Royale et Résurgence), avec les rangs, les défis et les classes du mode.
--   br         : une seule vie. Première mort : duel au goulag pour revenir. Ensuite, seul un coéquipier peut te racheter.
--   resurgence : petite carte, réapparition en parachute tant qu'un coéquipier est en vie. Escouade entière à terre : éliminée.
-- Les points d'intérêt ne donnent qu'une zone : le butin et les véhicules se calent sur la route la plus proche, côté client.
Config.CodWarzone = {
    squadSize = 3,
    startCash = 0,
    startPlates = 2,
    maxPlates = 5,
    plateArmor = 34, -- armure par plaque (100 au maximum)
    plateCooldown = 1500, -- ms entre deux plaques
    plateKey = 'X',
    start = { primary = 'WEAPON_PISTOL', perks = { 'marathon' } }, -- équipement d'une vie qui commence
    killCash = 500,
    deathDropShare = 0.5, -- part de l'argent lâchée à la mort, avec l'arme principale
    placementXp = 200, -- XP par place d'avance sur la 6e (1re escouade éliminée hors du top 5 : rien)
    parachuteOpenHeight = 120.0, -- m : le parachute s'ouvre seul en dessous
    airDropHeight = 250.0, -- m au-dessus du sol à une réapparition en parachute
    takeRange = 80.0, -- m : tolérance du serveur (la position exacte du butin est calée sur la route par le client)

    -- Avion du déploiement : traverse la carte, le joueur saute quand il veut (touche E), sinon en bout de trajet
    plane = { model = 'titan', height = 450.0, speed = 70.0, overshoot = 1.15 },

    loot = {
        perPoint = 7, -- caisses par point d'intérêt
        spread = 35.0, -- m autour du point
        model = 'prop_box_ammo03a',
        showRange = 70.0, -- m : marqueur et caisse visibles
        pickRange = 3.0, -- m
        -- Tirage : poids de chaque type de butin
        weights = { weapon = 40, plates = 20, cash = 20, ammo = 12, equipment = 8 },
        cash = { 200, 300, 500, 800 },
        plates = { 1, 2 },
        -- attachments : accessoires posés au hasard sur l'arme ; color : marqueur
        rarities = {
            { id = 'common', label = 'Commune', weight = 60, attachments = 0, color = { 220, 222, 216 } },
            { id = 'rare', label = 'Rare', weight = 30, attachments = 2, color = { 70, 150, 255 } },
            { id = 'epic', label = 'Épique', weight = 10, attachments = 4, color = { 190, 90, 255 } },
        },
    },

    vehicles = {
        everyPoints = 2, -- un véhicule tous les N points d'intérêt
        models = { 'sanchez', 'bf400', 'blazer', 'mesa', 'baller', 'sandking' },
        claimRange = 200.0, -- m : le premier joueur à portée le fait apparaître
    },

    stations = {
        everyPoints = 3, -- une station d'achat tous les N points d'intérêt
        useRange = 3.5, -- m
    },

    shop = {
        { id = 'plates', label = 'Plaques d\'armure', description = 'Trois plaques de plus.', price = 1000, amount = 3 },
        { id = 'uav', label = 'Drone', description = 'Les ennemis apparaissent sur la carte pendant 30 s.', price = 4000, duration = 30 },
        { id = 'loadout', label = 'Colis d\'équipement', description = 'Reçois aussitôt les armes, l\'équipement et les atouts de ta classe.', price = 10000 },
        { id = 'buyback', label = 'Racheter un coéquipier', description = 'Il revient en parachute. Battle Royale : aussi pour un coéquipier sorti du goulag.', price = 4500 },
    },

    gulag = {
        -- Terrain à part, dans son propre bucket : personne d'autre ne le voit
        points = { vector4(-480.0, -1700.0, 18.7, 270.0), vector4(-420.0, -1700.0, 18.7, 90.0) },
        delay = 4, -- secondes entre la mort et le goulag
        duel = 60, -- secondes : au-delà, le joueur le plus en forme gagne
        maxWait = 30, -- secondes sans adversaire : retour gratuit dans la partie
        maxPhase = 4, -- phase de la zone au-delà de laquelle le goulag ferme
        weapon = 'WEAPON_PISTOL',
    },

    -- Phases de la zone. wait, shrink : secondes ; radius : part du rayon de la carte ; damage : par seconde hors zone
    br = {
        phases = {
            { wait = 240, shrink = 120, radius = 0.55, damage = 2 },
            { wait = 150, shrink = 90, radius = 0.30, damage = 4 },
            { wait = 120, shrink = 75, radius = 0.16, damage = 7 },
            { wait = 90, shrink = 60, radius = 0.08, damage = 12 },
            { wait = 60, shrink = 45, radius = 0.035, damage = 18 },
            { wait = 45, shrink = 45, radius = 0.01, damage = 30 },
        },
    },
    resurgence = {
        -- delay : secondes avant de réapparaître pendant cette phase
        phases = {
            { wait = 120, shrink = 60, radius = 0.6, damage = 3, delay = 20 },
            { wait = 90, shrink = 60, radius = 0.35, damage = 5, delay = 30 },
            { wait = 75, shrink = 45, radius = 0.18, damage = 8, delay = 40 },
            { wait = 60, shrink = 45, radius = 0.08, damage = 14, delay = 50 },
            { wait = 45, shrink = 30, radius = 0.02, damage = 25, delay = false },
        },
    },

    maps = {
        { id = 'wz_ls', mode = 'br', label = 'Los Santos', place = 'Toute la ville', center = vector3(200.0, -1000.0, 30.0), radius = 1800.0 },
        { id = 'wz_blaine', mode = 'br', label = 'Comté de Blaine', place = 'Sandy Shores, Alamo Sea, Grapeseed', center = vector3(1500.0, 3600.0, 40.0), radius = 2100.0 },
        { id = 'wz_downtown', mode = 'resurgence', label = 'Centre-ville', place = 'Los Santos', center = vector3(150.0, -900.0, 30.0), radius = 750.0 },
        { id = 'wz_sandy', mode = 'resurgence', label = 'Sandy Shores', place = 'Comté de Blaine', center = vector3(1750.0, 3650.0, 35.0), radius = 650.0 },
        { id = 'wz_paleto', mode = 'resurgence', label = 'Paleto Bay', place = 'Comté de Blaine', center = vector3(-150.0, 6350.0, 32.0), radius = 600.0 },
    },

    -- Points d'intérêt (x, y), placés de mémoire sans test en jeu
    points = {
        -- Los Santos
        { 195.0, -934.0 }, { 300.0, -584.0 }, { 430.0, -980.0 }, { -48.0, -1100.0 }, { 25.0, -700.0 }, { 240.0, -1300.0 },
        { 120.0, -1940.0 }, { 220.0, -1500.0 }, { -254.0, -2026.0 }, { -1037.0, -2737.0 }, { 1020.0, -3050.0 }, { -1322.0, -1510.0 },
        { -1620.0, -1030.0 }, { -330.0, -120.0 }, { -710.0, -240.0 }, { -440.0, 1160.0 }, { 700.0, 1200.0 }, { 1100.0, -500.0 },
        { 1530.0, -2100.0 }, { 1330.0, -1700.0 }, { 800.0, -1000.0 }, { 800.0, -2100.0 }, { 480.0, -1500.0 }, { -600.0, -900.0 },
        { 100.0, -400.0 }, { 400.0, -200.0 }, { -120.0, -1500.0 }, { -900.0, -1200.0 }, { 900.0, -100.0 }, { 200.0, 150.0 },
        -- Comté de Blaine
        { 1850.0, 3700.0 }, { 1700.0, 4800.0 }, { 1850.0, 2600.0 }, { 590.0, 2730.0 }, { 60.0, 3700.0 }, { 2700.0, 1500.0 },
        { 2200.0, 2100.0 }, { 1300.0, 4300.0 }, { 2450.0, 4950.0 }, { 3600.0, 3700.0 }, { 2900.0, 3500.0 }, { 400.0, 3500.0 },
        { 1950.0, 3300.0 }, { 1500.0, 3600.0 }, { 2000.0, 4000.0 }, { 1600.0, 3200.0 }, { 2400.0, 3100.0 }, { 1100.0, 2700.0 },
        -- Paleto Bay
        { -150.0, 6350.0 }, { -300.0, 6200.0 }, { -40.0, 6500.0 }, { 100.0, 6500.0 }, { -400.0, 6050.0 }, { -565.0, 5320.0 },
        { -250.0, 6050.0 }, { 150.0, 6600.0 },
    },
}
