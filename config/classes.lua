-- Classes du mode PvP (menu > Classe). Une classe se choisit en zone safe, hors combat, et reste
-- sauvegardée. Elle donne des statistiques, des passifs et une compétence (touche `key`), vérifiés
-- par le serveur. Les statistiques ont pour base 100, sans classe ; elles ne sont pas mesurées en jeu.
--
-- key            : touche de la compétence (nom de touche FiveM), keyLabel : nom affiché
-- changeCooldown : secondes entre deux changements de classe (le premier choix est libre)
-- effectRange    : mètres autour du lanceur où les effets visibles par tous sont envoyés
--
-- Dans chaque classe :
-- icon         : nom d'icône de l'interface
-- signature    : objets de Config.Items, armes de prédilection affichées dans le menu
-- health       : points de vie (100 par défaut)
-- speed        : vitesse à pied, en % (100 par défaut)
-- damage       : multiplicateur des armes et du corps à corps (1.0 par défaut)
-- damageLabel  : dégâts affichés dans le menu quand un seul nombre ne suffit pas
-- melee        : multiplicateur du corps à corps, à la place de `damage`
-- weaponGroups : multiplicateur par groupe d'armes GTA, à la place de `damage`
-- playerDamage : multiplicateur en plus de tout le reste, seulement dans le monde PvP
-- noKnockback  : ne peut pas être renversé à pied
-- zombieDamage : multiplicateur des dégâts reçus des zombies (vomi, nuage toxique)
-- healBonus    : multiplicateur des soins consommés par le joueur
-- healShare, healRadius : part des soins partagée avec les coéquipiers proches, en mètres
-- radar        : { range = mètres, max = repères au plus, player / zombie = style des repères }
-- craftCost    : multiplicateur des ingrédients (arrondi au supérieur)
-- bagBonus     : kg ajoutés à la capacité du sac
-- ability      : compétence ; world = 'pve' ou 'pvp' si elle ne sert que dans ce monde, aimed = elle
--                vise un point, cooldown en secondes, reste des réglages selon la compétence
Config.Classes = {
    key = 'G',
    keyLabel = 'G',
    changeCooldown = 300,
    effectRange = 150.0,
    list = {
        {
            id = 'tank',
            label = 'Tank',
            icon = 'armor',
            summary = 'Mur vivant : encaisse en première ligne et tient les positions.',
            role = 'Première ligne, capture de zone',
            passives = {
                'Dégâts des zombies réduits de 30 %',
                'Corps à corps : +30 %',
                'Ne peut pas être renversé à pied',
            },
            signature = { 'weapon_bat', 'weapon_pumpshotgun', 'heavy_kevlar' },
            health = 170,
            speed = 85,
            damage = 0.8,
            melee = 1.04,
            noKnockback = true,
            zombieDamage = 0.7,
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
            id = 'assault',
            label = 'Assaut',
            icon = 'knife',
            summary = 'Spécialiste de la mêlée : le plus dangereux au contact.',
            role = 'Percée, combat rapproché',
            passives = {
                'Corps à corps : +20 %',
                'Armes à feu : dégâts normaux',
            },
            signature = { 'weapon_machete', 'weapon_battleaxe', 'weapon_sawnoffshotgun' },
            health = 110,
            damageLabel = '120 mêlée',
            melee = 1.2,
            ability = {
                id = 'frenzy',
                label = 'Frénésie',
                description = 'Corps à corps : +30 % pendant 10 s.',
                cooldown = 45,
                duration = 10,
                melee = 1.3,
            },
        },
        {
            id = 'demolisher',
            label = 'Démolisseur',
            icon = 'bomb',
            summary = 'Dégâts de zone : redoutable contre un groupe, faible en duel.',
            role = 'Nettoyage de hordes, assaut de position',
            passives = {
                'Fusils à pompe, armes lourdes et explosifs : +40 %',
                'Autres armes et corps à corps : -30 %',
            },
            signature = { 'weapon_grenadelauncher', 'weapon_grenade', 'weapon_pumpshotgun' },
            speed = 95,
            damage = 0.7,
            damageLabel = '140 zone / 70',
            weaponGroups = { GROUP_SHOTGUN = 1.4, GROUP_HEAVY = 1.4, GROUP_THROWN = 1.4 },
            ability = {
                id = 'blast',
                label = 'Charge explosive',
                description = 'Fait exploser le point que tu vises, jusqu\'à 40 m (zone zombies). Attention à ton équipe.',
                world = 'pve',
                aimed = true,
                cooldown = 60,
                range = 40.0,
                minRange = 8.0, -- plus près, l'explosion toucherait le lanceur
                explosion = { type = 23, damage = 1.0, shake = 1.0 }, -- 23 : non bloquée par l'anticheat
            },
        },
        {
            id = 'mercenary',
            label = 'Mercenaire',
            icon = 'contract',
            summary = 'Chasseur de primes : spécialiste du combat entre joueurs.',
            role = 'Agressif, chasse et contestation',
            passives = { 'Contre les joueurs : dégâts +25 %' },
            signature = { 'weapon_pistol50', 'weapon_assaultrifle', 'weapon_carbinerifle' },
            health = 90,
            speed = 105,
            damageLabel = '100 (+25 % PvP)',
            playerDamage = 1.25,
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
            id = 'scout',
            label = 'Éclaireur',
            icon = 'crosshair',
            summary = 'Détection et tir de précision : fragile, mais voit le danger avant les autres.',
            role = 'Repérage, élimination à distance',
            passives = {
                'Radar : zombies et ennemis à moins de 60 m sur la minimap, hors zones safe',
                'Fusils de précision : +30 %, autres armes : -20 %',
            },
            signature = { 'weapon_sniperrifle', 'weapon_marksmanrifle' },
            health = 85,
            speed = 110,
            damage = 0.8,
            damageLabel = '130 précision / 80',
            weaponGroups = { GROUP_SNIPER = 1.3 },
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
                aimed = true,
                cooldown = 30,
                duration = 15,
                range = 300.0,
                nightVision = true,
                blip = { sprite = 161, color = 5 },
            },
        },
        {
            id = 'medic',
            label = 'Médecin',
            icon = 'bandage',
            summary = 'Soutien : soigne son équipe et la protège des infections.',
            role = 'Soutien à protéger, très recherché en groupe',
            passives = {
                'Soins consommés : +50 %',
                'Tes soins profitent à moitié aux coéquipiers à moins de 10 m',
            },
            signature = { 'weapon_pistol', 'weapon_combatpistol', 'medkit' },
            health = 95,
            damage = 0.7,
            healBonus = 1.5,
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
            id = 'engineer',
            label = 'Ingénieur',
            icon = 'craft',
            summary = 'Fabrication et défense : fait plus avec moins de matériaux.',
            role = 'Défense, contrôle de zone',
            passives = {
                'Fabrication : ingrédients réduits d\'un tiers',
                'Piège électrique : 50 % plus long',
            },
            signature = { 'weapon_wrench', 'weapon_hammer', 'weapon_microsmg' },
            speed = 95,
            damage = 0.8,
            craftCost = 2 / 3,
            ability = {
                id = 'trap',
                label = 'Piège électrique',
                description = 'Pose à tes pieds un piège qui bloque les zombies pendant 38 s (zone zombies).',
                world = 'pve',
                cooldown = 75,
                radius = 5.0,
                duration = 38,
                stun = 2000, -- ms, renouvelé tant que le zombie reste dans le piège
            },
        },
        {
            id = 'logistician',
            label = 'Logisticien',
            icon = 'inventory',
            summary = 'Ravitailleur : transporte plus et couvre les replis.',
            role = 'Transport du butin, couverture du groupe',
            passives = { 'Sac : 20 kg de capacité en plus' },
            signature = { 'weapon_combatpistol', 'weapon_smokegrenade', 'repairkit' },
            health = 90,
            damage = 0.75,
            bagBonus = 20.0,
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
