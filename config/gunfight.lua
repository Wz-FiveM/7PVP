-- 1VS1 GunFight : mode de jeu du Freeroam (PNJ de la zone safe).
--  1. Les joueurs rejoignent la file ; dès que deux joueurs attendent, la partie se lance.
--  2. Chaque manche : les deux joueurs apparaissent face à face aux deux points de départ, avec un
--     pistolet. Une seule vie : le premier qui tue l'autre gagne la manche.
--  3. Le premier à `roundsToWin` manches gagne la partie.
-- Chaque partie se joue dans son propre bucket : plusieurs duels en même temps au même endroit.
Config.Gunfight = {
    roundsToWin = 3,
    countdown = 5, -- secondes bloqué au point de départ avant chaque manche
    roundTime = 120, -- secondes par manche : à la fin, manche nulle (elle est rejouée)
    roundPause = 5, -- secondes entre deux manches (résultat affiché)
    bucketBase = 3000, -- buckets des parties : bucketBase + numéro de la partie

    -- Zone de combat autour du milieu des deux départs : hors zone, dégâts chaque seconde
    radius = 60.0,
    outsideDamage = 10,

    -- Même arme pour les deux joueurs, redonnée à chaque manche
    kit = {
        weapons = {
            { weapon = 'WEAPON_PISTOL', ammo = 120 },
        },
        armor = 0,
    },

    -- Points de départ des deux joueurs (cap = direction du regard), modifiables depuis le panneau
    -- admin (F10, onglet Freeroam, « Spawns 1VS1 GunFight »). Port de Los Santos, entre les conteneurs.
    spawns = {
        vector4(1000.0, -3090.0, 5.9, 270.0),
        vector4(1040.0, -3090.0, 5.9, 90.0),
    },
}
