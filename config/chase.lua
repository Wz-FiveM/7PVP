-- Course poursuite : mode de jeu du Freeroam (PNJ de la zone safe), 1 contre 1 en deux manches.
--  1. Les deux joueurs votent chacun pour un véhicule.
--  2. Manche 1 : tous les deux avec le véhicule du joueur 1 ; le joueur 1 est le voleur, le joueur 2
--     le policier, qui part juste derrière. Le voleur gagne s'il met `escapeDistance` entre eux avant
--     la fin du temps ; le policier gagne s'il l'immobilise `arrestTime` secondes, ou si le temps finit.
--  3. Manche 2 : véhicule du joueur 2, rôles inversés. 1 - 1 : égalité.
-- Chaque partie se joue dans son propre bucket : les autres joueurs du Freeroam ne gênent pas.
Config.Chase = {
    voteTime = 20, -- secondes pour choisir son véhicule
    countdown = 5, -- secondes à l'arrêt avant le départ
    roundTime = 180, -- secondes laissées au voleur pour fuir
    escapeDistance = 1500.0, -- mètres entre voleur et policier pour que le voleur gagne
    arrestTime = 5, -- secondes d'immobilisation pour que le policier gagne
    arrestSpeed = 3.0, -- km/h : en dessous, le voleur est considéré immobilisé
    arrestDistance = 15.0, -- mètres : le policier doit être collé au voleur pour l'immobiliser
    copGap = 15.0, -- mètres entre le voleur et le policier au départ (le policier derrière)
    roundPause = 6, -- secondes entre deux manches (résultat affiché)
    bucketBase = 1000, -- buckets des parties : bucketBase + numéro de la partie

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
    starts = {
        vector4(-1336.0, -2244.0, 13.9, 240.0), -- piste de l'aéroport de Los Santos
        vector4(220.0, -1040.0, 29.2, 160.0), -- centre-ville, sous Legion Square
        vector4(1580.0, 3200.0, 40.4, 285.0), -- aérodrome de Sandy Shores
        vector4(-430.0, 6050.0, 31.4, 45.0), -- Paleto Bay
    },
}
