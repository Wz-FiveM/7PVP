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
        },
    },
}
