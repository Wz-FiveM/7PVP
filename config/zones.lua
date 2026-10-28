-- Tout ce qui n'est pas dans une zone est en PvP libre.
-- type = 'safe' : pas de tir, invincible, boutique accessible, points de spawn
-- type = 'pve'  : PvP + zombies (réglages communs dans Config.Zombie, config/main.lua)
-- Les coordonnées sont approximatives : ajuste-les en jeu avec /pvp_coords
Config.Zones = {
    {
        id = 'legion',
        type = 'safe',
        label = 'Zone safe - Legion Square',
        coords = vector3(195.2, -933.8, 30.7),
        radius = 80.0,
        blip = { sprite = 487, color = 2 },
        spawns = {
            vector4(195.2, -933.8, 30.7, 144.0),
            vector4(210.0, -920.0, 30.7, 160.0),
            vector4(180.0, -945.0, 30.1, 300.0),
            vector4(200.0, -905.0, 30.7, 180.0),
        },
    },
    {
        id = 'sandy_airfield',
        type = 'pve',
        label = 'Aérodrome de Sandy Shores',
        coords = vector3(1735.0, 3295.0, 41.2),
        radius = 150.0,
        blip = { sprite = 310, color = 47 },
        npc = {
            max = 10,
            respawn = 45, -- secondes
            health = 200,
            speed = 1.0, -- 1.0 marche, 2.0 course, 3.0 sprint
            loot = 'gang',
            models = { 'u_m_y_zombie_01', 'a_m_m_tramp_01', 'a_m_o_tramp_01', 'a_m_y_methhead_01', 'a_m_m_hillbilly_01' },
            spawns = {
                vector4(1730.0, 3295.0, 41.2, 0.0),
                vector4(1755.0, 3310.0, 41.2, 90.0),
                vector4(1710.0, 3270.0, 41.2, 180.0),
                vector4(1770.0, 3280.0, 41.2, 270.0),
                vector4(1690.0, 3285.0, 41.2, 45.0),
            },
        },
    },
    {
        id = 'port',
        type = 'pve',
        label = 'Port de Los Santos',
        coords = vector3(1050.0, -3100.0, 5.9),
        radius = 140.0,
        blip = { sprite = 310, color = 1 },
        npc = {
            max = 14,
            respawn = 60,
            health = 300,
            speed = 2.0, -- zombies plus rapides et plus résistants : meilleur butin
            loot = 'military',
            models = { 'u_m_y_zombie_01', 's_m_y_dockwork_01', 'a_m_m_tramp_01', 's_m_m_dockwork_01', 'a_m_y_methhead_01' },
            spawns = {
                vector4(1020.0, -3080.0, 5.9, 0.0),
                vector4(1060.0, -3120.0, 5.9, 90.0),
                vector4(1100.0, -3050.0, 5.9, 180.0),
                vector4(985.0, -3150.0, 5.9, 270.0),
                vector4(1040.0, -3180.0, 5.9, 45.0),
            },
        },
    },
}
