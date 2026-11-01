-- Classes du mode PvP (menu > Classe). Une classe se choisit en zone safe, hors combat, et reste
-- sauvegardée. Elle donne des passifs et une compétence (touche `key`), vérifiés par le serveur.
--
-- key            : touche de la compétence (nom de touche FiveM), keyLabel : nom affiché
-- changeCooldown : secondes entre deux changements de classe (le premier choix est libre)
-- effectRange    : mètres autour du lanceur où les effets visibles par tous sont envoyés
--
-- Dans chaque classe :
-- icon         : nom d'icône de l'interface
-- signature    : objets de Config.Items, armes de prédilection affichées dans le menu
-- zombieDamage : multiplicateur des dégâts reçus des zombies (vomi, nuage toxique)
-- modifiers    : multiplicateurs par monde, `pve` = monde zombies et `pvp` = monde PvP
--                { damage = dégâts des armes, melee = corps à corps, defense = dégâts d'armes reçus }
-- healShare, healRadius : part des soins partagée avec les coéquipiers proches, en mètres
-- radar        : { range = mètres, max = repères au plus, player / zombie = style des repères }
-- craftCost    : multiplicateur des ingrédients (arrondi au supérieur)
-- bagBonus     : kg ajoutés à la capacité du sac
-- ability      : compétence ; world = 'pve' ou 'pvp' si elle ne sert que dans ce monde,
--                cooldown en secondes, reste des réglages selon la compétence
Config.Classes = {
    key = 'G',
    keyLabel = 'G',
    changeCooldown = 300,
    effectRange = 150.0,
    list = {
        {
            id = 'assault',
            label = 'Assaut',
            icon = 'knife',
            summary = 'Tank de mêlée : encaisse les hordes en première ligne.',
            role = 'Première ligne, capture de zone',
            passives = {
                'Dégâts des zombies réduits de 30 %',
                'Corps à corps : +50 % en zone zombies, +10 % contre les joueurs',
            },
            signature = { 'weapon_machete', 'weapon_bat', 'weapon_pumpshotgun' },
            zombieDamage = 0.7,
            modifiers = { pve = { melee = 1.5 }, pvp = { melee = 1.1 } },
            ability = {
                id = 'roar',
                label = 'Rugissement',
                description = 'Renverse et étourdit les zombies autour de toi (zone zombies).',
                world = 'pve',
                cooldown = 45,
                radius = 10.0,
                stun = 3000, -- ms
                push = 8.0,
            },
        },
        {
            id = 'medic',
            label = 'Médecin',
            icon = 'bandage',
            summary = 'Soutien : soigne son équipe et la protège des infections.',
            role = 'Soutien à protéger, très recherché en groupe',
            passives = { 'Tes soins profitent à moitié aux coéquipiers à moins de 10 m' },
            signature = { 'weapon_pistol', 'weapon_combatpistol', 'medkit' },
            healShare = 0.5,
            healRadius = 10.0,
            ability = {
                id = 'antidote',
                label = 'Antidote',
                description = 'Immunise ton équipe proche contre le vomi et les gaz pendant 45 s.',
                cooldown = 120,
                radius = 12.0,
                duration = 45,
            },
        },
        {
            id = 'scout',
            label = 'Éclaireur',
            icon = 'crosshair',
            summary = 'Détection et tir de précision : voit le danger avant les autres.',
            role = 'Repérage, élimination à distance',
            passives = { 'Radar : zombies et ennemis à moins de 60 m sur la minimap, hors zones safe' },
            signature = { 'weapon_sniperrifle', 'weapon_marksmanrifle', 'att_suppressor' },
            radar = {
                range = 60.0,
                max = 24,
                player = { sprite = 1, color = 1, scale = 0.6 },
                zombie = { sprite = 1, color = 2, scale = 0.4 },
            },
            ability = {
                id = 'mark',
                label = 'Marquage',
                description = 'Marque ce que tu vises pour ton équipe pendant 15 s. La nuit, active aussi la vision nocturne.',
                cooldown = 30,
                duration = 15,
                range = 300.0,
                nightVision = true,
                blip = { sprite = 161, color = 5 },
            },
        },
        {
            id = 'engineer',
            label = 'Ingénieur',
            icon = 'craft',
            summary = 'Fabrication et défense : fait plus avec moins de matériaux.',
            role = 'Défense, contrôle de zone',
            passives = { 'Fabrication : ingrédients réduits de 25 %' },
            signature = { 'weapon_wrench', 'weapon_hammer', 'weapon_microsmg' },
            craftCost = 0.75,
            ability = {
                id = 'trap',
                label = 'Piège électrique',
                description = 'Pose à tes pieds un piège qui bloque les zombies pendant 25 s (zone zombies).',
                world = 'pve',
                cooldown = 75,
                radius = 5.0,
                duration = 25,
                stun = 2000, -- ms, renouvelé tant que le zombie reste dans le piège
            },
        },
        {
            id = 'mercenary',
            label = 'Mercenaire',
            icon = 'contract',
            summary = 'Chasseur de primes : spécialiste du combat entre joueurs.',
            role = 'Agressif, chasse et contestation',
            passives = { 'Contre les joueurs : dégâts +7 %, dégâts reçus -7 %' },
            signature = { 'weapon_pistol50', 'weapon_assaultrifle', 'weapon_carbinerifle' },
            modifiers = { pvp = { damage = 1.07, defense = 0.93 } },
            ability = {
                id = 'contract',
                label = 'Contrat',
                description = 'Suit pendant 30 s le joueur le plus recherché, sinon le plus proche. Il en est prévenu.',
                world = 'pvp',
                cooldown = 180,
                duration = 30,
                range = 2000.0,
                interval = 2, -- secondes entre deux positions
                blip = { sprite = 303, color = 1 },
            },
        },
        {
            id = 'logistician',
            label = 'Logisticien',
            icon = 'inventory',
            summary = 'Ravitailleur : transporte plus et couvre les replis.',
            role = 'Transport du butin, couverture du groupe',
            passives = { 'Sac : 15 kg de capacité en plus' },
            signature = { 'weapon_combatpistol', 'weapon_smokegrenade', 'repairkit' },
            bagBonus = 15.0,
            ability = {
                id = 'smoke',
                label = 'Écran de fumée',
                description = 'Fumée épaisse à tes pieds pendant 20 s pour couvrir un repli.',
                cooldown = 90,
                duration = 20,
                particle = { asset = 'core', name = 'exp_grd_grenade_smoke', scale = 2.5 },
            },
        },
    },
}
