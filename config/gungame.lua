-- Gungame : mode de jeu du Freeroam (PNJ de la zone safe), chacun pour soi.
--  1. Les joueurs rejoignent la file ; dès `minPlayers`, un compte à rebours (`queueDelay`) laisse
--     le temps à d'autres d'arriver. Une partie en cours qui a encore de la place (et du temps) se
--     rejoint directement depuis le PNJ, en partant du niveau du dernier joueur.
--  2. Tout le monde commence avec la première arme de `levels` ; chaque kill fait passer à l'arme
--     suivante. On réapparaît après chaque mort, le plus loin possible des autres joueurs.
--  3. Le premier qui fait un kill avec la dernière arme (le couteau) gagne la partie.
--     Un kill au couteau fait reculer la victime d'une arme ; un suicide (chute, hors zone) aussi.
--  4. À la fin du temps, le joueur le plus avancé gagne (puis le plus de kills, puis le moins de morts).
-- Chaque partie se joue dans son propre bucket : les autres joueurs du Freeroam ne gênent pas.
Config.Gungame = {
    minPlayers = 2, -- joueurs pour lancer une partie
    maxPlayers = 12, -- les suivants attendent la partie d'après
    queueDelay = 20, -- secondes d'attente une fois `minPlayers` atteint
    joinMinRemaining = 60, -- secondes : en dessous, une partie en cours n'accepte plus de nouveaux joueurs
    countdown = 5, -- secondes bloqué au point de départ au lancement
    matchTime = 600, -- secondes par partie : à la fin, le plus avancé gagne
    respawnDelay = 3, -- secondes avant de réapparaître après une mort
    spawnProtection = 3, -- secondes sans prendre de dégâts après chaque apparition
    bucketBase = 4000, -- buckets des parties : bucketBase + numéro de la partie

    -- Zone de combat autour du milieu des points d'apparition : hors zone, dégâts chaque seconde
    radius = 75.0,
    outsideDamage = 10,
    armor = 0,

    -- Couteau toujours en main en plus de l'arme du niveau ; un kill au couteau fait reculer la victime
    knife = 'WEAPON_KNIFE',
    knifeDemotes = true,
    suicideDemotes = true, -- mort sans tueur (chute, hors zone) : on recule d'une arme

    -- Une arme par niveau, munitions infinies (il faut quand même recharger).
    -- Le dernier niveau se joue au couteau : le premier kill avec gagne la partie.
    levels = {
        { weapon = 'WEAPON_PISTOL', label = 'Pistolet' },
        { weapon = 'WEAPON_COMBATPISTOL', label = 'Pistolet de combat' },
        { weapon = 'WEAPON_HEAVYPISTOL', label = 'Pistolet lourd' },
        { weapon = 'WEAPON_REVOLVER', label = 'Revolver' },
        { weapon = 'WEAPON_MICROSMG', label = 'Micro SMG' },
        { weapon = 'WEAPON_SMG', label = 'SMG' },
        { weapon = 'WEAPON_ASSAULTSMG', label = 'SMG d\'assaut' },
        { weapon = 'WEAPON_PUMPSHOTGUN', label = 'Fusil à pompe' },
        { weapon = 'WEAPON_CARBINERIFLE', label = 'Carabine' },
        { weapon = 'WEAPON_ASSAULTRIFLE', label = 'Fusil d\'assaut' },
        { weapon = 'WEAPON_COMBATMG', label = 'Mitrailleuse' },
        { weapon = 'WEAPON_MARKSMANRIFLE', label = 'Fusil de précision' },
        { weapon = 'WEAPON_KNIFE', label = 'Couteau' },
    },

    -- Points d'apparition (cap = direction du regard), modifiables depuis le panneau admin
    -- (F10, onglet Freeroam, « Spawns Gungame »). Port de Los Santos, autour des conteneurs.
    spawns = {
        vector4(1020.0, -3045.0, 5.9, 180.0),
        vector4(1052.0, -3058.0, 5.9, 135.0),
        vector4(1065.0, -3090.0, 5.9, 90.0),
        vector4(1052.0, -3122.0, 5.9, 45.0),
        vector4(1020.0, -3135.0, 5.9, 0.0),
        vector4(988.0, -3122.0, 5.9, 315.0),
        vector4(975.0, -3090.0, 5.9, 270.0),
        vector4(988.0, -3058.0, 5.9, 225.0),
        vector4(1020.0, -3090.0, 5.9, 0.0),
        vector4(1036.0, -3074.0, 5.9, 200.0),
    },
}
