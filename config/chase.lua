-- Course poursuite : mode de jeu du Freeroam (PNJ de la zone safe), 1 contre 1 en deux manches.
--  1. Les deux joueurs votent chacun pour un véhicule.
--  2. Manche 1 : tous les deux avec le véhicule du joueur 1 ; le joueur 1 est le voleur, le joueur 2
--     le policier, qui part juste derrière. Aucun repère ni distance à l'écran : on se cherche à vue.
--     Le voleur gagne s'il met `escapeDistance` entre eux avant
--     la fin du temps ; le policier gagne s'il l'immobilise `arrestTime` secondes, ou si le temps finit.
--  3. Manche 2 : véhicule du joueur 2, rôles inversés. 1 - 1 : égalité.
-- Chaque partie se joue dans son propre bucket : les autres joueurs du Freeroam ne gênent pas.
Config.Chase = {
    voteTime = 20, -- secondes pour choisir son véhicule
    countdown = 5, -- secondes à l'arrêt avant le départ
    roundTime = 180, -- secondes laissées au voleur pour fuir
    escapeDistance = 500.0, -- mètres entre voleur et policier pour que le voleur gagne (non affichée en jeu)
    arrestTime = 5, -- secondes d'immobilisation pour que le policier gagne
    arrestSpeed = 3.0, -- km/h : en dessous, le voleur est considéré immobilisé
    arrestDistance = 15.0, -- mètres : le policier doit être collé au voleur pour l'immobiliser
    copGap = 15.0, -- mètres entre le voleur et le policier au départ (le policier derrière)
    roundPause = 6, -- secondes entre deux manches (résultat affiché)
    bucketBase = 1000, -- buckets des parties : bucketBase + numéro de la partie

    -- Règles de conduite, vérifiées pendant la manche ---------------------------------------
    -- Anti-PIT : faire tourner l'adversaire en percutant l'arrière de son véhicule. Celui qui le fait
    -- prend un avertissement et le véhicule de la victime est réparé ; au bout de `maxWarns`
    -- avertissements (sur toute la partie), il perd la manche.
    pit = {
        maxWarns = 3,
        minSpeed = 30.0, -- km/h de la victime au moment du choc (les accrochages lents ne comptent pas)
        turnAngle = 70.0, -- degrés : la victime a pivoté d'au moins autant juste après le choc
        window = 2.0, -- secondes après le choc pendant lesquelles on regarde si elle pivote
        maxDistance = 12.0, -- mètres entre les deux véhicules quand le serveur reçoit le signalement
    },
    -- Véhicule trop endommagé (santé GTA, 1000 = neuf) : son conducteur perd la manche
    damage = { minEngine = 250.0, minBody = 250.0 },
    -- Anti-stunt : un saut trop haut ou trop long fait perdre la manche à celui qui saute
    stunt = { maxHeight = 6.0, maxAirTime = 1.6 }, -- mètres au-dessus du sol, secondes en l'air
    -- Véhicule sur le toit : son conducteur perd la manche
    roof = { angle = 140.0, time = 2.0 }, -- degrés de roulis, secondes sur le toit

    -- Classement ELO (table pvp_chase_ratings) : recalculé à la fin de chaque partie.
    -- Victoire 1, égalité 0,5, défaite 0 ; quitter une partie en cours compte comme une défaite.
    elo = {
        start = 1000, -- cote de départ
        k = 32, -- points en jeu par partie (plus haut = la cote bouge plus vite)
        boardSize = 10, -- joueurs affichés sur le tableau
    },
    -- Tableau du classement dans la zone safe du Freeroam (écran DUI posé dans le monde)
    board = {
        coords = vector3(216.4, -944.8, 30.7), -- pied de l'écran (juste derrière le PNJ de la course)
        heading = 60.0, -- l'écran fait face à cette direction (vers le centre de la zone safe)
        width = 5.0, -- mètres (la hauteur suit le format de la page : 4/3)
        elevation = 0.6, -- mètres entre le sol et le bas de l'écran
        drawDistance = 60.0, -- mètres : au-delà, l'écran n'est plus dessiné
    },

    -- Dégâts réalistes des véhicules de la course : les chocs abîment bien plus que dans GTA,
    -- et un moteur abîmé perd de la puissance (accélère moins, ne tient plus sa vitesse)
    damageRealism = {
        collision = 3.0, -- dégâts des collisions (multiplie fCollisionDamageMult du véhicule)
        deformation = 2.0, -- carrosserie qui se déforme plus (fDeformationDamageMult)
        engine = 3.0, -- dégâts reçus par le moteur (fEngineDamageMult)
        impactSpeed = 25.0, -- km/h perdus d'un coup : au-delà, le choc abîme en plus le moteur
        impactDamage = 8.0, -- points de moteur perdus par km/h au-delà de impactSpeed
        minPower = 0.35, -- puissance gardée par un moteur très abîmé (0.35 = 35 %)
    },

    -- Véhicules proposés au vote (image : web/public/items/<model>.png si elle existe)
    vehicles = {
        { model = 'kuruma', label = 'Kuruma' },
        { model = 'sentinel', label = 'Sentinel' },
        { model = 'felon', label = 'Felon' },
        { model = 'jackal', label = 'Jackal' },
        { model = 'revolter', label = 'Revolter' },
        { model = 'ruiner', label = 'Ruiner' },
        { model = 'granger', label = 'Granger' },
        { model = 'manchez', label = 'Manchez' },
    },

    -- Départs du voleur (le policier est placé `copGap` mètres derrière, dans l'axe).
    -- Coordonnées approximatives : ajuste-les en jeu avec /pvp_coords (la hauteur est recalée sur le sol).
    -- Uniquement en ville (Los Santos) : ni l'aéroport ni le nord de la carte.
    starts = {
        vector4(220.0, -1040.0, 29.2, 160.0), -- centre-ville, sous Legion Square
        vector4(-1300.0, -420.0, 34.6, 125.0), -- Del Perro, boulevard vers l'est
        vector4(1110.0, -760.0, 57.7, 0.0), -- Mirror Park
        vector4(170.0, -1500.0, 29.2, 140.0), -- Strawberry
        vector4(-560.0, -230.0, 37.0, 210.0), -- Rockford Hills
    },
}
