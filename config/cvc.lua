-- CVC (combat par équipe en convoi) : mode de jeu du Freeroam (PNJ de la zone safe).
--  1. Les joueurs rejoignent la file ; dès `minPlayers`, un compte à rebours (`queueDelay`) laisse
--     le temps à d'autres d'arriver, puis deux équipes équilibrées sont tirées au sort.
--  2. Chaque manche : une zone de combat au hasard, chaque équipe part de son côté dans ses
--     véhicules, avec le même kit d'armes. Une seule vie : la dernière équipe en vie gagne la manche.
--  3. La première équipe à `roundsToWin` manches gagne la partie.
-- Chaque partie se joue dans son propre bucket : les autres joueurs du Freeroam ne gênent pas.
Config.Cvc = {
    minPlayers = 2, -- joueurs pour lancer une partie (1 contre 1 au minimum)
    maxPlayers = 16, -- 8 contre 8 au maximum (les suivants attendent la partie d'après)
    queueDelay = 30, -- secondes d'attente une fois `minPlayers` atteint
    roundsToWin = 3,
    countdown = 10, -- secondes bloqué dans les véhicules avant le départ
    roundTime = 300, -- secondes par manche : à la fin, l'équipe avec le plus de survivants gagne
    roundPause = 6, -- secondes entre deux manches (résultat affiché)
    bucketBase = 2000, -- buckets des parties : bucketBase + numéro de la partie

    -- Hors de la zone de combat : dégâts chaque seconde
    outsideDamage = 8,

    -- Même kit pour tout le monde, redonné à chaque manche
    kit = {
        weapons = {
            { weapon = 'WEAPON_CARBINERIFLE', ammo = 300 },
            { weapon = 'WEAPON_PISTOL', ammo = 90 },
        },
        armor = 100,
    },

    -- Convoi : un véhicule pour `seatsPerVehicle` joueurs (au moins un par équipe)
    vehicle = 'granger',
    seatsPerVehicle = 2,

    teams = {
        { id = 'alpha', label = 'Alpha', blipColor = 3 },
        { id = 'bravo', label = 'Bravo', blipColor = 1 },
    },

    -- Zones de combat (tirées au sort à chaque manche). Les équipes partent de `spawns[1]` et
    -- `spawns[2]`, tournées vers le centre ; les véhicules sont alignés derrière le point de départ.
    -- Coordonnées approximatives : ajuste-les en jeu avec /pvp_coords (la hauteur est recalée sur le sol).
    arenas = {
        {
            label = 'Désert de Senora',
            center = vector3(2340.0, 3130.0, 48.2),
            radius = 450.0,
            spawns = { vector3(2050.0, 3050.0, 45.0), vector3(2640.0, 3230.0, 50.0) },
        },
        {
            label = 'Port de Los Santos',
            center = vector3(1050.0, -3100.0, 5.9),
            radius = 350.0,
            spawns = { vector3(820.0, -3020.0, 5.9), vector3(1280.0, -3190.0, 5.9) },
        },
        {
            label = 'Champs de Grapeseed',
            center = vector3(2200.0, 4900.0, 41.0),
            radius = 400.0,
            spawns = { vector3(1950.0, 4790.0, 41.0), vector3(2450.0, 5020.0, 45.0) },
        },
    },
}
