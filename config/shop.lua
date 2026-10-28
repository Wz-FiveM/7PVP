-- item : clé de Config.Items ; count : quantité reçue ; price : prix ; level : niveau minimum (défaut 1)
-- Armes lourdes, explosifs puissants et armes « fun » (minigun, railgun, laser...) ne sont pas vendus :
-- largages ou admins seulement (config/loot.lua).
Config.Shop = {
    -- Armes blanches
    { item = 'weapon_knife', count = 1, price = 200 },
    { item = 'weapon_bat', count = 1, price = 150 },
    { item = 'weapon_crowbar', count = 1, price = 150 },
    { item = 'weapon_switchblade', count = 1, price = 250 },
    { item = 'weapon_machete', count = 1, price = 300, level = 2 },
    { item = 'weapon_hatchet', count = 1, price = 350, level = 3 },
    { item = 'weapon_knuckle', count = 1, price = 250, level = 2 },

    -- Pistolets
    { item = 'weapon_snspistol', count = 1, price = 300 },
    { item = 'weapon_pistol', count = 1, price = 400 },
    { item = 'weapon_vintagepistol', count = 1, price = 600, level = 2 },
    { item = 'weapon_combatpistol', count = 1, price = 900, level = 2 },
    { item = 'weapon_heavypistol', count = 1, price = 1200, level = 3 },
    { item = 'weapon_pistol_mk2', count = 1, price = 1500, level = 5 },
    { item = 'weapon_pistol50', count = 1, price = 1600, level = 4 },
    { item = 'weapon_revolver', count = 1, price = 2200, level = 6 },
    { item = 'weapon_appistol', count = 1, price = 2500, level = 7 },

    -- Mitraillettes
    { item = 'weapon_microsmg', count = 1, price = 1800, level = 3 },
    { item = 'weapon_minismg', count = 1, price = 2000, level = 4 },
    { item = 'weapon_machinepistol', count = 1, price = 2200, level = 4 },
    { item = 'weapon_smg', count = 1, price = 2600, level = 5 },
    { item = 'weapon_assaultsmg', count = 1, price = 3200, level = 7 },
    { item = 'weapon_combatpdw', count = 1, price = 3400, level = 8 },
    { item = 'weapon_smg_mk2', count = 1, price = 3800, level = 9 },

    -- Fusils à pompe
    { item = 'weapon_sawnoffshotgun', count = 1, price = 1500, level = 3 },
    { item = 'weapon_pumpshotgun', count = 1, price = 3200, level = 4 },
    { item = 'weapon_dbshotgun', count = 1, price = 2400, level = 5 },
    { item = 'weapon_bullpupshotgun', count = 1, price = 3800, level = 7 },
    { item = 'weapon_pumpshotgun_mk2', count = 1, price = 4500, level = 10 },
    { item = 'weapon_heavyshotgun', count = 1, price = 5000, level = 11 },

    -- Fusils d'assaut
    { item = 'weapon_compactrifle', count = 1, price = 4200, level = 7 },
    { item = 'weapon_carbinerifle', count = 1, price = 5500, level = 8 },
    { item = 'weapon_assaultrifle', count = 1, price = 6000, level = 10 },
    { item = 'weapon_bullpuprifle', count = 1, price = 6200, level = 11 },
    { item = 'weapon_advancedrifle', count = 1, price = 6500, level = 11 },
    { item = 'weapon_specialcarbine', count = 1, price = 6800, level = 12 },
    { item = 'weapon_militaryrifle', count = 1, price = 7500, level = 14 },
    { item = 'weapon_carbinerifle_mk2', count = 1, price = 8000, level = 15 },

    -- Mitrailleuses et précision
    { item = 'weapon_gusenberg', count = 1, price = 7000, level = 13 },
    { item = 'weapon_mg', count = 1, price = 9000, level = 15 },
    { item = 'weapon_combatmg', count = 1, price = 11000, level = 17 },
    { item = 'weapon_sniperrifle', count = 1, price = 9000, level = 12 },
    { item = 'weapon_marksmanrifle', count = 1, price = 11000, level = 15 },
    { item = 'weapon_heavysniper', count = 1, price = 15000, level = 18 },

    -- Armes de jet
    { item = 'weapon_flare', count = 2, price = 50 },
    { item = 'weapon_smokegrenade', count = 1, price = 300, level = 3 },
    { item = 'weapon_bzgas', count = 1, price = 600, level = 6 },
    { item = 'weapon_molotov', count = 1, price = 700, level = 6 },
    { item = 'weapon_grenade', count = 1, price = 900, level = 8 },

    -- Munitions
    { item = 'ammo_9mm', count = 48, price = 80 },
    { item = 'ammo_45acp', count = 60, price = 150 },
    { item = 'ammo_12g', count = 16, price = 120 },
    { item = 'ammo_556', count = 60, price = 250 },
    { item = 'ammo_762', count = 10, price = 300 },
    { item = 'ammo_mg', count = 100, price = 450, level = 13 },

    -- Soins et équipement
    { item = 'bandage', count = 1, price = 100 },
    { item = 'firstaid', count = 1, price = 220 },
    { item = 'medkit', count = 1, price = 350, level = 2 },
    { item = 'drug_stamina', count = 1, price = 300, level = 3 },
    { item = 'light_kevlar', count = 1, price = 400, level = 2 },
    { item = 'armor', count = 1, price = 800, level = 3 },
    { item = 'heavy_kevlar', count = 1, price = 1800, level = 8 },
    { item = 'repairkit', count = 1, price = 500 },

    -- Véhicules (config/vehicles.lua) : les autres modèles se trouvent dans les largages ou via les admins
    { item = 'vehicle_bmx', count = 1, price = 150 },
    { item = 'vehicle_faggio', count = 1, price = 600 },
    { item = 'vehicle_manchez', count = 1, price = 1800, level = 3 },
    { item = 'vehicle_emperor', count = 1, price = 1200, level = 2 },
    { item = 'vehicle_sentinel', count = 1, price = 3500, level = 4 },
    { item = 'vehicle_granger', count = 1, price = 4500, level = 5 },
    { item = 'vehicle_bfinjection', count = 1, price = 3000, level = 5 },
    { item = 'vehicle_kuruma', count = 1, price = 7500, level = 8 },
    { item = 'vehicle_mesa3', count = 1, price = 9000, level = 10 },
    { item = 'vehicle_frogger', count = 1, price = 25000, level = 15 },

    -- Accessoires
    { item = 'att_flashlight', count = 1, price = 300, level = 2 },
    { item = 'att_extclip', count = 1, price = 900, level = 4 },
    { item = 'att_grip', count = 1, price = 1100, level = 6 },
    { item = 'att_scope', count = 1, price = 1500, level = 7 },
    { item = 'att_suppressor', count = 1, price = 2500, level = 9 },
}
