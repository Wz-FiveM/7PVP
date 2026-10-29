-- Caisses : des objets qu'on achète (page « Caisses » du menu, auprès de l'armurier) ou qu'on
-- trouve dans les butins, puis qu'on ouvre depuis le menu. Le tirage est fait par le serveur.
-- Une caisse est un objet comme un autre : dans le sac, elle est perdue à la mort.
--
-- id      : nom de l'objet (case_<nom>) ; image : web/public/items/<id>.png (sinon icône de caisse)
-- price   : prix à l'armurier (nil = introuvable en boutique, seulement en butin ou via les admins)
-- level   : niveau minimum pour l'acheter (défaut 1) ; l'ouvrir n'a pas de niveau
-- rewards : item = clé de Config.Items ('money' pour de l'argent) ; count = quantité ou { min, max }
--           weight = poids du tirage (la chance affichée = weight / total des weight de la caisse)
--           rarity = clé de Config.CaseRarities (couleur et nom affichés)
Config.CaseOptions = {
    weight = 0.5, -- poids de l'objet caisse, en kg
    spinDuration = 6.5, -- secondes d'animation de la roulette
    reelLength = 56, -- nombre de cases sur la roulette
    winnerSlot = 48, -- position (1-based) de la récompense sur la roulette
    announceRarities = { epic = true, legendary = true }, -- annoncées dans le chat PvP
}

-- Dans l'ordre, du plus courant au plus rare
Config.CaseRarities = {
    common = { label = 'Commun', color = '#a7ada4', order = 1 },
    uncommon = { label = 'Peu commun', color = '#6fcf6a', order = 2 },
    rare = { label = 'Rare', color = '#4f8dff', order = 3 },
    epic = { label = 'Épique', color = '#b36bff', order = 4 },
    legendary = { label = 'Légendaire', color = '#ff9f1c', order = 5 },
}

Config.Cases = {
    {
        id = 'case_street',
        label = 'Caisse de rue',
        description = 'Le kit de survie du quartier : munitions, soins et une petite chance de gros lot.',
        price = 750,
        rewards = {
            { item = 'ammo_9mm', count = { 48, 96 }, weight = 22, rarity = 'common' },
            { item = 'bandage', count = { 3, 5 }, weight = 18, rarity = 'common' },
            { item = 'ammo_45acp', count = { 60, 120 }, weight = 14, rarity = 'common' },
            { item = 'money', count = { 300, 600 }, weight = 12, rarity = 'common' },
            { item = 'weapon_combatpistol', weight = 10, rarity = 'uncommon' },
            { item = 'firstaid', count = { 2, 3 }, weight = 8, rarity = 'uncommon' },
            { item = 'light_kevlar', weight = 6, rarity = 'uncommon' },
            { item = 'weapon_microsmg', weight = 4, rarity = 'rare' },
            { item = 'armor', weight = 3, rarity = 'rare' },
            { item = 'money', count = { 1500, 2500 }, weight = 2.5, rarity = 'rare' },
            { item = 'weapon_smg', weight = 1.2, rarity = 'epic' },
            { item = 'att_suppressor', weight = 0.8, rarity = 'epic' },
            { item = 'weapon_assaultrifle', weight = 0.3, rarity = 'legendary' },
            { item = 'vehicle_kuruma', weight = 0.2, rarity = 'legendary' },
        },
    },
    {
        id = 'case_military',
        label = 'Caisse militaire',
        description = 'Surplus de l\'armée : fusils, protections et accessoires de combat.',
        price = 3500,
        level = 6,
        rewards = {
            { item = 'ammo_556', count = { 120, 240 }, weight = 20, rarity = 'common' },
            { item = 'medkit', count = { 2, 3 }, weight = 16, rarity = 'common' },
            { item = 'money', count = { 1500, 2500 }, weight = 12, rarity = 'common' },
            { item = 'armor', count = 2, weight = 10, rarity = 'uncommon' },
            { item = 'weapon_pumpshotgun', weight = 9, rarity = 'uncommon' },
            { item = 'att_scope', weight = 7, rarity = 'uncommon' },
            { item = 'weapon_carbinerifle', weight = 5, rarity = 'rare' },
            { item = 'heavy_kevlar', weight = 4, rarity = 'rare' },
            { item = 'att_suppressor', weight = 3, rarity = 'rare' },
            { item = 'weapon_specialcarbine', weight = 1.5, rarity = 'epic' },
            { item = 'weapon_marksmanrifle', weight = 0.8, rarity = 'epic' },
            { item = 'vehicle_kuruma', weight = 0.7, rarity = 'epic' },
            { item = 'weapon_carbinerifle_mk2', weight = 0.4, rarity = 'legendary' },
            { item = 'weapon_combatmg', weight = 0.3, rarity = 'legendary' },
            { item = 'vehicle_nightshark', weight = 0.2, rarity = 'legendary' },
        },
    },
    {
        id = 'case_elite',
        label = 'Caisse d\'élite',
        description = 'Le haut du panier : armes Mk II, snipers lourds et véhicules blindés.',
        price = 12000,
        level = 12,
        rewards = {
            { item = 'money', count = { 5000, 8000 }, weight = 18, rarity = 'common' },
            { item = 'heavy_kevlar', count = 2, weight = 14, rarity = 'common' },
            { item = 'ammo_762', count = { 40, 80 }, weight = 14, rarity = 'common' },
            { item = 'weapon_carbinerifle_mk2', weight = 10, rarity = 'uncommon' },
            { item = 'weapon_mg', weight = 8, rarity = 'uncommon' },
            { item = 'weapon_heavysniper', weight = 5, rarity = 'rare' },
            { item = 'weapon_combatmg', weight = 5, rarity = 'rare' },
            { item = 'weapon_specialcarbine_mk2', weight = 2, rarity = 'epic' },
            { item = 'vehicle_nightshark', weight = 1.5, rarity = 'epic' },
            { item = 'vehicle_insurgent', weight = 1, rarity = 'epic' },
            { item = 'weapon_rpg', weight = 0.5, rarity = 'legendary' },
            { item = 'vehicle_buzzard2', weight = 0.3, rarity = 'legendary' },
            { item = 'vehicle_deluxo', weight = 0.2, rarity = 'legendary' },
        },
    },
}

for _, case in ipairs(Config.Cases) do
    Config.Items[case.id] = {
        label = case.label,
        type = 'case',
        weight = Config.CaseOptions.weight,
    }
end
