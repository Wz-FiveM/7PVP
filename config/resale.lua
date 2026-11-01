-- Revente au receleur (PNJ des zones safe, config/npcs.lua) : il rachète les objets portés (sac ou
-- conteneur protégé) contre de l'argent, versé dans le sac. Prix par unité, modifiables dans le
-- panneau admin F10 (onglet « Revente ») : ce fichier ne donne que les valeurs par défaut.
--
-- Prix par défaut d'un objet, dans l'ordre :
--   1. `prices` ;
--   2. vendu à l'armurier (boutique ou caisse) : `shopRate` de son prix par unité. Reste sous le prix
--      d'achat, sinon acheter puis revendre rapporterait de l'argent sans limite ;
--   3. `byType` selon son type. Absent de `byType` : pas repris (prix 0).
Config.Resale = {
    shopRate = 0.5,
    maxPrice = 1000000, -- prix maximum par unité accepté dans le panneau admin
    prices = {
        -- Trouvés seulement dans les butins et les largages
        weapon_specialcarbine_mk2 = 4500,
        weapon_grenadelauncher = 6000,
        weapon_rpg = 8000,
        weapon_stickybomb = 500,
        ammo_grenade40 = 150,
        ammo_rocket = 500,
        drug_health = 120,
        antizin = 80,
        mat_cloth = 5,
        mat_scrap = 8,
        mat_powder = 4,
        mat_chemicals = 25,
        vehicle_panto = 300,
        vehicle_nightshark = 15000,
        vehicle_insurgent = 20000,
        vehicle_buzzard2 = 30000,
        vehicle_deluxo = 40000,
    },
    byType = {
        weapon = 250,
        ammo = 1,
        attachment = 150,
        consumable = 50,
        vehicle = 500,
        material = 5,
    },
}
