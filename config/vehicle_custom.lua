-- Custom des véhicules (mode PvP) : un mécanicien par zone safe (rôle 'custom', config/npcs.lua).
-- On gare devant lui, au volant de son véhicule sorti d'un objet, sur le repère au sol, et on appuie sur E.
-- La custom est gardée en base, par joueur et par modèle : toutes ses prochaines Felon auront la même.
-- Elle est gratuite et ne se perd jamais (véhicule détruit, volé, revendu : elle reste au joueur).
-- Le Freeroam a sa propre custom, depuis son menu, avec les mêmes listes (Config.Freeroam.customPerformance).
--
-- Les positions se règlent dans le panneau admin (F10 > Positions > PNJ de service) : le repère est
-- devant le mécanicien, dans la direction où il regarde.
Config.VehicleCustom = {
    role = 'custom', -- rôle du PNJ dans Config.SafeNpcs
    spotOffset = 6.0, -- mètres entre le mécanicien et le centre du repère
    spotRadius = 3.5, -- rayon du repère
    markerDistance = 30.0, -- le repère n'est dessiné qu'à cette distance
    serverDistance = 14.0, -- portée vérifiée par le serveur autour du mécanicien
    maxSpeed = 3.0, -- km/h : au-dessus, le véhicule roule encore
    -- Moteur, freins, transmission, suspension, blindage et turbo : ils changent le combat et la custom
    -- est gratuite, donc coupés par défaut. true les ajoute au menu (et ceux déjà enregistrés s'appliquent).
    performance = false,

    -- Pièces, dans l'ordre du menu. id : type de modification GTA ; tab : body, wheels ou performance.
    -- Seules celles qui existent sur le modèle sont proposées.
    mods = {
        { id = 0, label = 'Aileron', tab = 'body' },
        { id = 1, label = 'Pare-chocs avant', tab = 'body' },
        { id = 2, label = 'Pare-chocs arrière', tab = 'body' },
        { id = 3, label = 'Bas de caisse', tab = 'body' },
        { id = 4, label = 'Échappement', tab = 'body' },
        { id = 5, label = 'Arceau', tab = 'body' },
        { id = 6, label = 'Calandre', tab = 'body' },
        { id = 7, label = 'Capot', tab = 'body' },
        { id = 8, label = 'Ailes', tab = 'body' },
        { id = 9, label = 'Ailes droites', tab = 'body' },
        { id = 10, label = 'Toit', tab = 'body' },
        { id = 48, label = 'Motif', tab = 'body' },
        { id = 14, label = 'Klaxon', tab = 'body' },
        { id = 25, label = 'Support de plaque', tab = 'body' },
        { id = 27, label = 'Garnitures', tab = 'body' },
        { id = 28, label = 'Ornements', tab = 'body' },
        { id = 29, label = 'Tableau de bord', tab = 'body' },
        { id = 30, label = 'Compteurs', tab = 'body' },
        { id = 31, label = 'Haut-parleurs de portes', tab = 'body' },
        { id = 32, label = 'Sièges', tab = 'body' },
        { id = 33, label = 'Volant', tab = 'body' },
        { id = 34, label = 'Levier de vitesses', tab = 'body' },
        { id = 35, label = 'Plaques', tab = 'body' },
        { id = 36, label = 'Haut-parleurs', tab = 'body' },
        { id = 37, label = 'Coffre', tab = 'body' },
        { id = 38, label = 'Hydraulique', tab = 'body' },
        { id = 39, label = 'Bloc moteur', tab = 'body' },
        { id = 40, label = 'Filtre à air', tab = 'body' },
        { id = 41, label = 'Entretoises', tab = 'body' },
        { id = 42, label = 'Couvre-arches', tab = 'body' },
        { id = 43, label = 'Antennes', tab = 'body' },
        { id = 44, label = 'Bandes', tab = 'body' },
        { id = 45, label = 'Réservoir', tab = 'body' },
        { id = 46, label = 'Vitres', tab = 'body' },
        { id = 23, label = 'Jantes', tab = 'wheels' },
        { id = 24, label = 'Roue arrière', tab = 'wheels' },
        { id = 11, label = 'Moteur', tab = 'performance' },
        { id = 12, label = 'Freins', tab = 'performance' },
        { id = 13, label = 'Transmission', tab = 'performance' },
        { id = 15, label = 'Suspension', tab = 'performance' },
        { id = 16, label = 'Blindage', tab = 'performance' },
    },

    -- Peintures : id = couleur GTA, hex = aperçu dans le menu
    colors = {
        { id = 0, label = 'Noir', hex = '#0d1116' },
        { id = 1, label = 'Graphite', hex = '#1c1d21' },
        { id = 12, label = 'Noir mat', hex = '#13181f' },
        { id = 11, label = 'Anthracite', hex = '#1d2129' },
        { id = 13, label = 'Gris mat', hex = '#26282a' },
        { id = 10, label = 'Gris métal', hex = '#444e54' },
        { id = 6, label = 'Acier', hex = '#979a97' },
        { id = 4, label = 'Argent', hex = '#999da0' },
        { id = 120, label = 'Chrome', hex = '#c8cdd1' },
        { id = 111, label = 'Blanc', hex = '#f5f5ef' },
        { id = 131, label = 'Blanc mat', hex = '#fcf9f1' },
        { id = 27, label = 'Rouge', hex = '#c00e1a' },
        { id = 28, label = 'Rouge vif', hex = '#da1918' },
        { id = 39, label = 'Rouge mat', hex = '#cf1f21' },
        { id = 150, label = 'Rouge lave', hex = '#bc1917' },
        { id = 34, label = 'Bordeaux', hex = '#49111d' },
        { id = 38, label = 'Orange', hex = '#f78616' },
        { id = 41, label = 'Orange mat', hex = '#f27d20' },
        { id = 37, label = 'Or', hex = '#c2944f' },
        { id = 158, label = 'Or pur', hex = '#d4af37' },
        { id = 88, label = 'Jaune', hex = '#ffcf20' },
        { id = 42, label = 'Jaune mat', hex = '#ffc91f' },
        { id = 49, label = 'Vert foncé', hex = '#132428' },
        { id = 50, label = 'Vert course', hex = '#122e2b' },
        { id = 53, label = 'Vert vif', hex = '#155c2d' },
        { id = 92, label = 'Citron vert', hex = '#98d223' },
        { id = 55, label = 'Citron vert mat', hex = '#66b81f' },
        { id = 62, label = 'Bleu nuit', hex = '#233155' },
        { id = 64, label = 'Bleu', hex = '#47578f' },
        { id = 73, label = 'Bleu course', hex = '#2354a1' },
        { id = 70, label = 'Bleu ultra', hex = '#0b9cf1' },
        { id = 74, label = 'Bleu clair', hex = '#6ea3c6' },
        { id = 83, label = 'Bleu mat', hex = '#253aa7' },
        { id = 71, label = 'Violet nuit', hex = '#2f2d52' },
        { id = 145, label = 'Violet', hex = '#621276' },
        { id = 148, label = 'Violet mat', hex = '#6b1f7b' },
        { id = 135, label = 'Rose vif', hex = '#f21f99' },
        { id = 137, label = 'Rose', hex = '#df5891' },
        { id = 96, label = 'Marron', hex = '#221b19' },
    },
    -- Néons
    neonColors = {
        { label = 'Blanc', hex = '#ffffff' },
        { label = 'Rouge', hex = '#ff0000' },
        { label = 'Orange', hex = '#ff6a00' },
        { label = 'Jaune', hex = '#ffd800' },
        { label = 'Vert', hex = '#00ff3c' },
        { label = 'Cyan', hex = '#00e5ff' },
        { label = 'Bleu', hex = '#0040ff' },
        { label = 'Violet', hex = '#8a00ff' },
        { label = 'Rose', hex = '#ff1493' },
    },
    -- Phares xénon : id = couleur GTA (255 : blanc d'origine)
    xenonColors = {
        { id = 255, label = 'Blanc', hex = '#dfe9f0' },
        { id = 1, label = 'Bleu', hex = '#1f6fff' },
        { id = 3, label = 'Vert', hex = '#4dffb0' },
        { id = 5, label = 'Jaune', hex = '#ffe14d' },
        { id = 7, label = 'Orange', hex = '#ff8a1f' },
        { id = 8, label = 'Rouge', hex = '#ff2020' },
        { id = 10, label = 'Rose', hex = '#ff2fa0' },
        { id = 11, label = 'Violet', hex = '#8a3bff' },
    },
    tints = {
        { id = 0, label = 'Aucune' },
        { id = 3, label = 'Légères' },
        { id = 2, label = 'Foncées' },
        { id = 1, label = 'Noires' },
        { id = 5, label = 'Limousine' },
        { id = 6, label = 'Vertes' },
    },
    plates = {
        { id = 0, label = 'Blanche' },
        { id = 1, label = 'Jaune et noire' },
        { id = 2, label = 'Jaune et bleue' },
        { id = 5, label = 'Yankton' },
    },
    -- Types de jantes (voitures seulement ; les motos n'en ont qu'un)
    wheelTypes = {
        { id = 0, label = 'Sport' },
        { id = 1, label = 'Muscle' },
        { id = 2, label = 'Lowrider' },
        { id = 3, label = 'SUV' },
        { id = 4, label = 'Tout-terrain' },
        { id = 5, label = 'Tuner' },
        { id = 7, label = 'Haut de gamme' },
        { id = 8, label = 'Benny\'s Original' },
        { id = 9, label = 'Benny\'s Bespoke' },
        { id = 11, label = 'Rue' },
        { id = 12, label = 'Piste' },
    },
}
