-- 1VS1 Bike : mode de jeu du Freeroam (PNJ de la zone safe), variante du 1VS1 GunFight
-- (même service : server/modules/activities/gunfight_service.lua).
--  1. Les joueurs rejoignent la file ; dès que deux joueurs attendent, la partie se lance.
--  2. Chaque manche : les deux joueurs apparaissent sur une moto, loin l'un de l'autre, avec un
--     pistolet. Ils doivent se rejoindre et s'affronter, à pied : pas de drive-by. Une seule vie : le
--     premier qui tue l'autre gagne la manche.
--  3. Le premier à `roundsToWin` manches gagne la partie.
-- Chaque partie se joue dans son propre bucket : plusieurs duels en même temps au même endroit.
Config.Bike = {
    roundsToWin = 3,
    countdown = 5, -- secondes bloqué sur la moto avant chaque manche
    roundTime = 180, -- secondes par manche : à la fin, manche nulle (elle est rejouée)
    roundPause = 5, -- secondes entre deux manches (résultat affiché)
    bucketBase = 3500, -- buckets des parties : bucketBase + numéro de la partie

    -- Moto de chaque joueur, recréée à chaque manche (modifiable dans le panneau admin, onglet Freeroam)
    vehicle = 'bati',

    -- Zone de combat autour du milieu des deux départs : hors zone, dégâts chaque seconde
    radius = 250.0,
    outsideDamage = 10,

    -- Même arme pour les deux joueurs, redonnée à chaque manche
    kit = {
        weapons = {
            { weapon = 'WEAPON_PISTOL', ammo = 120 },
        },
        armor = 0,
    },

    -- Points de départ des deux joueurs (cap = direction de la moto), modifiables depuis le panneau
    -- admin (F10, onglet Freeroam, « Spawns 1VS1 Bike »). Aérodrome de Sandy Shores, ~350 m d'écart.
    spawns = {
        vector4(1300.0, 3120.0, 40.4, 286.0),
        vector4(1640.0, 3220.0, 41.0, 106.0),
    },
}
