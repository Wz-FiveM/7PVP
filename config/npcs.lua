-- PNJ de service des zones safe : on leur parle avec E.
-- Le coffre, la boutique, la fabrication et la tenue ne s'utilisent qu'à côté du PNJ concerné
-- (vérifié par le serveur). Les positions sont approximatives : ajuste-les avec /pvp_coords
-- (la hauteur est recalée sur le sol par le client).
Config.SafeNpcs = {
    interactDistance = 2.0, -- distance pour parler au PNJ (E)
    useDistance = 5.0, -- distance pour utiliser le service une fois le menu ouvert
    drawDistance = 60.0, -- les PNJ n'existent que près du joueur
    -- Rôles : nom affiché, texte de l'action, page du menu ouverte (`page`), icône de l'étiquette 3D
    -- (noms d'icônes de l'interface), repère sur la carte
    roles = {
        stash = { label = 'Banquier', action = 'Ouvrir mon coffre', page = 'inventory', icon = 'lock', blip = { sprite = 108, color = 2 } },
        shop = { label = 'Armurier', action = 'Voir la boutique', page = 'shop', icon = 'weapon', blip = { sprite = 110, color = 1 } },
        clothing = { label = 'Tailleur', action = 'Changer de tenue', icon = 'profile', blip = { sprite = 73, color = 3 } },
        crafting = { label = 'Artisan', action = 'Fabriquer', page = 'crafting', icon = 'craft', blip = { sprite = 566, color = 5 } },
        contracts = { label = 'Recruteur', action = 'Voir les contrats', page = 'contracts', icon = 'contract', blip = { sprite = 498, color = 47 } },
        market = { label = 'Commissaire-priseur', action = 'Ouvrir la place de marché', page = 'market', icon = 'money', blip = { sprite = 52, color = 46 } },
        resale = { label = 'Receleur', action = 'Revendre des objets', page = 'resale', icon = 'money', blip = { sprite = 378, color = 25 } },
        -- Custom des véhicules : au volant, sur le repère au sol devant lui (voir config/vehicle_custom.lua)
        custom = { label = 'Mécanicien', action = 'Customiser un véhicule', icon = 'craft', blip = { sprite = 72, color = 17 } },
        -- Custom des armes portées (voir config/weapon_custom.lua)
        weaponcustom = { label = 'Customiseur', action = 'Customiser mes armes', icon = 'weapon', blip = { sprite = 313, color = 17 } },
        -- Ouvre les donjons (config/dungeon.lua)
        dungeon = { label = 'James', action = 'Voir les donjons', icon = 'flag', blip = { sprite = 501, color = 1 } },
        -- Freeroam : lance un mode de jeu (Config.FreeroamActivities) ; nom, icône et repère viennent du mode
        activity = { label = 'Organisateur', action = 'Voir le mode de jeu', icon = 'flag', blip = { sprite = 280, color = 5 } },
    },
    -- Un PNJ n'existe que dans les modes de jeu de sa zone (config/zones.lua)
    npcs = {
        -- Freeroam : PNJ des modes de jeu (activity = clé de Config.FreeroamActivities)
        { zone = 'freeroam_hub', role = 'activity', activity = 'chase', model = 's_m_y_cop_01', coords = vector4(213.4, -943.0, 30.7, 60.0), scenario = 'WORLD_HUMAN_COP_IDLES' },
        { zone = 'freeroam_hub', role = 'activity', activity = 'cvc', model = 's_m_y_blackops_01', coords = vector4(202.6, -925.5, 30.7, 150.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'freeroam_hub', role = 'activity', activity = 'gunfight', model = 's_m_y_swat_01', coords = vector4(196.6, -912.6, 30.7, 180.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'freeroam_hub', role = 'activity', activity = 'bike', model = 'g_m_y_lost_01', coords = vector4(190.0, -914.0, 30.7, 180.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
        { zone = 'freeroam_hub', role = 'activity', activity = 'gungame', model = 's_m_y_marine_01', coords = vector4(184.0, -915.5, 30.7, 180.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },

        { zone = 'legion', role = 'dungeon', model = 's_m_y_blackops_01', coords = vector4(210.87, -948.66, 30.69, 140.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'airport', role = 'dungeon', model = 's_m_y_blackops_01', coords = vector4(-1039.77, -2746.5, 21.36, 240.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'sandy', role = 'dungeon', model = 's_m_y_blackops_01', coords = vector4(1859.0, 3674.0, 33.64, 90.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'paleto', role = 'dungeon', model = 's_m_y_blackops_01', coords = vector4(-451.79, 5999.74, 31.34, 280.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'legion', role = 'stash', model = 'cs_bankman', coords = vector4(187.04, -943.59, 30.09, 340.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'legion', role = 'shop', model = 's_m_y_ammucity_01', coords = vector4(202.6, -925.5, 30.69, 150.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'legion', role = 'clothing', model = 's_f_y_shop_mid', coords = vector4(174.32, -922.46, 30.69, 150.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
        { zone = 'legion', role = 'crafting', model = 's_m_m_autoshop_01', coords = vector4(209.68, -941.53, 30.69, 300.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'legion', role = 'contracts', model = 's_m_m_highsec_01', coords = vector4(194.4, -917.09, 30.69, 180.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'legion', role = 'market', model = 'a_m_y_business_02', coords = vector4(183.09, -949.97, 30.09, 0.0), scenario = 'WORLD_HUMAN_STAND_MOBILE' },
        { zone = 'legion', role = 'resale', model = 's_m_y_dealer_01', coords = vector4(194.0, -952.13, 30.09, 320.0), scenario = 'WORLD_HUMAN_SMOKING' },
        { zone = 'legion', role = 'custom', model = 's_m_m_autoshop_02', coords = vector4(221.37, -909.25, 30.69, 0.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'legion', role = 'weaponcustom', model = 's_m_m_ammucountry', coords = vector4(169.21, -938.88, 30.09, 330.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },

        -- Autres zones safe : coffre, boutique, tenue, revente et customs (fabrication, contrats et marché à Legion)
        { zone = 'airport', role = 'stash', model = 'cs_bankman', coords = vector4(-1040.36, -2722.49, 20.19, 150.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'airport', role = 'shop', model = 's_m_y_ammucity_01', coords = vector4(-1029.0, -2732.0, 20.12, 180.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'airport', role = 'clothing', model = 's_f_y_shop_mid', coords = vector4(-1038.83, -2727.42, 20.07, 90.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
        { zone = 'airport', role = 'resale', model = 's_m_y_dealer_01', coords = vector4(-1027.03, -2739.79, 20.17, 60.0), scenario = 'WORLD_HUMAN_SMOKING' },
        { zone = 'airport', role = 'custom', model = 's_m_m_autoshop_02', coords = vector4(-1018.62, -2733.24, 20.2, 240.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'airport', role = 'weaponcustom', model = 's_m_m_ammucountry', coords = vector4(-1050.08, -2720.47, 20.09, 120.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },

        { zone = 'sandy', role = 'stash', model = 'cs_bankman', coords = vector4(1853.89, 3666.88, 34.06, 330.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'sandy', role = 'shop', model = 's_m_y_ammucity_01', coords = vector4(1866.28, 3681.14, 33.63, 120.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'sandy', role = 'clothing', model = 's_f_y_shop_mid', coords = vector4(1864.37, 3701.01, 33.55, 90.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
        { zone = 'sandy', role = 'resale', model = 's_m_y_dealer_01', coords = vector4(1834.22, 3697.57, 34.22, 120.0), scenario = 'WORLD_HUMAN_SMOKING' },
        { zone = 'sandy', role = 'custom', model = 's_m_m_autoshop_02', coords = vector4(1873.1, 3693.84, 33.52, 210.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'sandy', role = 'weaponcustom', model = 's_m_m_ammucountry', coords = vector4(1850.58, 3672.83, 33.73, 30.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },

        { zone = 'paleto', role = 'stash', model = 'cs_bankman', coords = vector4(-446.98, 5994.32, 31.34, 315.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'paleto', role = 'shop', model = 's_m_y_ammucity_01', coords = vector4(-457.84, 6024.12, 31.34, 225.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'paleto', role = 'clothing', model = 's_f_y_shop_mid', coords = vector4(-441.25, 6026.0, 31.34, 165.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
        { zone = 'paleto', role = 'resale', model = 's_m_y_dealer_01', coords = vector4(-459.97, 6007.51, 31.34, 315.0), scenario = 'WORLD_HUMAN_SMOKING' },
        { zone = 'paleto', role = 'custom', model = 's_m_m_autoshop_02', coords = vector4(-472.0, 6021.0, 31.34, 225.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'paleto', role = 'weaponcustom', model = 's_m_m_ammucountry', coords = vector4(-431.94, 6014.41, 31.57, 120.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
    },
}
