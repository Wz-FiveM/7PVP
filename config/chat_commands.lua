-- Commandes proposées par le chat quand le joueur tape « / ». Le texte français sert de clé de
-- traduction (voir config/locale.lua). Une commande absente reste utilisable, sans suggestion.
--   name         commande, sans le « / »
--   description  affichée dans la liste
--   admin        visible seulement par les admins (les droits restent vérifiés par le serveur)
--   mode         visible seulement dans ce mode de jeu
--   args         arguments, dans l'ordre :
--     label      affiché dans la syntaxe : <obligatoire>, [facultatif]
--     required   Entrée refuse la commande tant qu'il manque
--     hint       explication affichée quand l'argument est en cours de saisie
--     players    propose les joueurs du mode (complète avec leur character id)
--     values     valeurs proposées : { { value, label } }, ou 'languages' pour Config.Locale.languages
local PLAYER = {
    label = '<id du joueur>',
    required = true,
    hint = 'Choisis un joueur du mode ou saisis son Character ID.',
    players = true,
}
local ACCOUNT = {
    label = '<id du joueur | license:xxxx>',
    required = true,
    hint = 'Choisis un joueur du mode ou saisis son Character ID ou sa license.',
    players = true,
}
local OPTIONAL_PLAYER = {
    label = '[id du joueur]',
    hint = 'Sans id : toi-même.',
    players = true,
}
local DUNGEON_ACTIONS = {
    {
        label = '<action>',
        required = true,
        hint = 'Parle d\'abord à James pour ouvrir le donjon.',
        values = {
            { value = 'invite', label = 'Inviter un coéquipier' },
            { value = 'pret', label = 'Rejoindre le donjon où tu es invité' },
            { value = 'lancer', label = 'Entrer dans le donjon' },
            { value = 'quitter', label = 'Quitter le donjon' },
        },
    },
    { label = '[id du joueur]', hint = 'Pour invite : le joueur à inviter.', players = true },
}
local REFERENCE = { label = '[référence]', hint = 'Référence facultative.' }

Config.ChatCommands = {
    { name = 'lobby', description = 'Retourner au lobby' },
    {
        name = 'donjon',
        description = 'Inviter, se dire prêt, lancer ou quitter un donjon',
        mode = 'pvp',
        args = DUNGEON_ACTIONS,
    },

    { name = 'inviter', description = 'Inviter un joueur dans ton groupe', args = { PLAYER } },
    { name = 'accepter', description = 'Accepter l\'invitation de groupe' },
    { name = 'refuser', description = 'Refuser l\'invitation de groupe' },
    { name = 'quittergroupe', description = 'Quitter ton groupe' },

    { name = 'crewinviter', description = 'Inviter un joueur dans ton crew', args = { PLAYER } },
    { name = 'crewaccepter', description = 'Accepter l\'invitation de crew' },
    { name = 'crewrefuser', description = 'Refuser l\'invitation de crew' },
    { name = 'crewquitter', description = 'Quitter ton crew' },

    {
        name = 'trade',
        description = 'Proposer un échange',
        args = {
            {
                label = '[id | accepter | refuser | annuler]',
                hint = 'Sans argument : le joueur le plus proche.',
                players = true,
                values = {
                    { value = 'accepter', label = 'Accepter la demande reçue' },
                    { value = 'refuser', label = 'Refuser la demande reçue' },
                    { value = 'annuler', label = 'Annuler ta demande' },
                },
            },
        },
    },
    {
        name = 'prime',
        description = 'Mettre une prime sur un joueur',
        mode = 'pvp',
        args = { PLAYER, { label = '<montant>', required = true, hint = 'Montant de la prime.' } },
    },
    {
        name = 'langue',
        description = 'Changer la langue',
        args = { { label = '[code]', hint = 'Sans code : liste des langues.', values = 'languages' } },
    },

    { name = 'tpm', description = 'Aller au marqueur de la carte', admin = true },
    { name = 'coords', description = 'Copier ta position (vector4)', admin = true },
    { name = 'interieur', description = 'Diagnostic de l\'intérieur où tu es', admin = true },
    {
        name = 'heure',
        description = 'Régler l\'heure du jeu',
        admin = true,
        args = {
            {
                label = '<0-23 | reset>',
                required = true,
                hint = 'Heure pour tout le monde, ou reset.',
                values = { { value = 'reset', label = 'Revenir au cycle normal' } },
            },
            { label = '[minutes]', hint = 'Minutes, 0 par défaut.' },
        },
    },
    {
        name = 'ban',
        description = 'Bannir un joueur',
        admin = true,
        args = {
            ACCOUNT,
            { label = '<jours, 0 = définitif>', required = true, hint = 'Durée du bannissement.' },
            { label = '<raison>', required = true, hint = 'Raison du bannissement.' },
        },
    },
    {
        name = 'unban',
        description = 'Lever un bannissement',
        admin = true,
        args = { { label = '<license:xxxx>', required = true, hint = 'La commande /bans donne la license.' } },
    },
    { name = 'bans', description = 'Lister les bannis', admin = true },
    {
        name = 'addvip',
        description = 'Donner le VIP',
        admin = true,
        args = { ACCOUNT, { label = '<jours>', required = true, hint = 'Durée en jours.' }, REFERENCE },
    },
    { name = 'removevip', description = 'Retirer le VIP', admin = true, args = { ACCOUNT } },
    { name = 'vip', description = 'Voir le VIP d\'un joueur', admin = true, args = { ACCOUNT } },
    {
        name = 'addpoints',
        description = 'Ajouter des points boutique',
        admin = true,
        args = { ACCOUNT, { label = '<montant>', required = true, hint = 'Nombre de points.' }, REFERENCE },
    },
    {
        name = 'removepoints',
        description = 'Retirer des points boutique',
        admin = true,
        args = { ACCOUNT, { label = '<montant>', required = true, hint = 'Nombre de points.' } },
    },
    { name = 'points', description = 'Voir les points d\'un joueur', admin = true, args = { ACCOUNT } },
    { name = 'setadmin', description = 'Nommer un admin', admin = true, args = { ACCOUNT } },
    { name = 'removeadmin', description = 'Retirer un admin', admin = true, args = { ACCOUNT } },
    { name = 'admins', description = 'Lister les admins', admin = true },
    {
        name = 'crewdissoudre',
        description = 'Dissoudre un crew',
        admin = true,
        args = { { label = '<label d\'un crew existant>', required = true, hint = 'Label de 3 lettres.' } },
    },

    {
        name = 'codserie',
        description = 'Donner des séries',
        admin = true,
        mode = 'cod',
        args = {
            {
                label = '[id de la série | toutes]',
                hint = 'Sans id : les séries choisies du joueur.',
                values = { { value = 'toutes', label = 'Toutes les séries' } },
            },
            OPTIONAL_PLAYER,
        },
    },
    {
        name = 'codniveau',
        description = 'Changer le rang d\'un joueur',
        admin = true,
        mode = 'cod',
        args = {
            { label = '<nombre>', required = true, hint = 'Rangs en plus, ou en moins si négatif.' },
            OPTIONAL_PLAYER,
        },
    },
    {
        name = 'codarme',
        description = 'Régler la progression d\'une arme',
        admin = true,
        mode = 'cod',
        args = {
            {
                label = '<arme | toutes>',
                required = true,
                hint = 'Nom de l\'arme, par exemple WEAPON_SMG.',
                values = { { value = 'toutes', label = 'Toutes les armes' } },
            },
            { label = '<kills>', required = true, hint = 'Nombre de kills.' },
            { label = '<tirs à la tête>', required = true, hint = 'Dont tirs à la tête.' },
            OPTIONAL_PLAYER,
        },
    },
    {
        name = 'codxp',
        description = 'Lancer un bonus d\'XP',
        admin = true,
        mode = 'cod',
        args = {
            { label = '<multiplicateur>', required = true, hint = 'Multiplicateur d\'XP, 1 pour arrêter.' },
            { label = '<heures>', required = true, hint = 'Durée en heures.' },
        },
    },
}
