-- Tables de butin des PNJ
-- money = { min, max } ; count = { min, max } ; chance en %
Config.LootTables = {
    gang = {
        money = { 20, 80 },
        drops = {
            { item = 'bandage', count = { 1, 2 }, chance = 40 },
            { item = 'ammo_9mm', count = { 12, 36 }, chance = 35 },
            { item = 'ammo_45acp', count = { 15, 40 }, chance = 15 },
            { item = 'weapon_pistol', count = { 1, 1 }, chance = 10 },
            { item = 'weapon_microsmg', count = { 1, 1 }, chance = 4 },
            { item = 'mat_cloth', count = { 1, 4 }, chance = 55 },
            { item = 'mat_scrap', count = { 1, 3 }, chance = 40 },
            { item = 'mat_powder', count = { 2, 6 }, chance = 25 },
            { item = 'att_flashlight', count = { 1, 1 }, chance = 3 },
        },
    },
    military = {
        money = { 60, 200 },
        drops = {
            { item = 'bandage', count = { 1, 3 }, chance = 50 },
            { item = 'medkit', count = { 1, 1 }, chance = 15 },
            { item = 'armor', count = { 1, 1 }, chance = 10 },
            { item = 'ammo_45acp', count = { 30, 60 }, chance = 30 },
            { item = 'ammo_556', count = { 30, 60 }, chance = 25 },
            { item = 'weapon_smg', count = { 1, 1 }, chance = 8 },
            { item = 'weapon_carbinerifle', count = { 1, 1 }, chance = 3 },
            { item = 'mat_scrap', count = { 2, 5 }, chance = 55 },
            { item = 'mat_powder', count = { 3, 8 }, chance = 45 },
            { item = 'mat_chemicals', count = { 1, 2 }, chance = 30 },
            { item = 'att_extclip', count = { 1, 1 }, chance = 6 },
            { item = 'att_scope', count = { 1, 1 }, chance = 4 },
        },
    },
    -- Largages aériens : le meilleur butin du serveur
    airdrop = {
        money = { 600, 1500 },
        drops = {
            { item = 'medkit', count = { 2, 4 }, chance = 90 },
            { item = 'armor', count = { 1, 3 }, chance = 85 },
            { item = 'ammo_556', count = { 90, 180 }, chance = 70 },
            { item = 'ammo_762', count = { 60, 120 }, chance = 45 },
            { item = 'weapon_carbinerifle', count = { 1, 1 }, chance = 45 },
            { item = 'weapon_assaultrifle', count = { 1, 1 }, chance = 30 },
            { item = 'weapon_smg', count = { 1, 1 }, chance = 35 },
            { item = 'att_suppressor', count = { 1, 1 }, chance = 40 },
            { item = 'att_scope', count = { 1, 1 }, chance = 40 },
            { item = 'att_grip', count = { 1, 1 }, chance = 30 },
            { item = 'mat_chemicals', count = { 2, 5 }, chance = 60 },
        },
    },
}
