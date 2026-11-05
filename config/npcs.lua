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
        { zone = 'airport', role = 'dungeon', model = 's_m_y_blackops_01', coords = vector4(-1036.97, -2741.28, 20.17, 180.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'sandy', role = 'dungeon', model = 's_m_y_blackops_01', coords = vector4(1849.94, 3670.05, 33.75, 30.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'paleto', role = 'dungeon', model = 's_m_y_blackops_01', coords = vector4(-452.15, 5999.83, 31.34, 260.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'legion', role = 'stash', model = 'cs_bankman', coords = vector4(187.39, -943.01, 30.09, 326.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'legion', role = 'shop', model = 's_m_y_ammucity_01', coords = vector4(202.6, -925.5, 30.69, 150.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'legion', role = 'clothing', model = 's_f_y_shop_mid', coords = vector4(194.41, -927.18, 30.69, 350.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
        { zone = 'legion', role = 'crafting', model = 's_m_m_autoshop_01', coords = vector4(209.68, -941.53, 30.69, 300.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'legion', role = 'contracts', model = 's_m_m_highsec_01', coords = vector4(194.57, -914.81, 30.69, 0.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'legion', role = 'market', model = 'a_m_y_business_02', coords = vector4(179.5, -948.0, 30.09, 60.0), scenario = 'WORLD_HUMAN_STAND_MOBILE' },
        { zone = 'legion', role = 'resale', model = 's_m_y_dealer_01', coords = vector4(194.0, -952.13, 30.09, 320.0), scenario = 'WORLD_HUMAN_SMOKING' },
        { zone = 'legion', role = 'custom', model = 's_m_m_autoshop_02', coords = vector4(221.37, -909.25, 30.69, 0.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'legion', role = 'weaponcustom', model = 's_m_m_ammucountry', coords = vector4(187.98, -931.28, 30.69, 236.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },

        -- Autres zones safe : coffre, boutique, tenue, revente et customs (fabrication, contrats et marché à Legion)
        { zone = 'airport', role = 'stash', model = 'cs_bankman', coords = vector4(-1032.88, -2730.96, 20.06, 179.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'airport', role = 'shop', model = 's_m_y_ammucity_01', coords = vector4(-1028.75, -2728.07, 20.21, 150.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'airport', role = 'clothing', model = 's_f_y_shop_mid', coords = vector4(-1036.91, -2727.48, 20.12, 180.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
        { zone = 'airport', role = 'resale', model = 's_m_y_dealer_01', coords = vector4(-1025.5, -2741.13, 20.17, 300.0), scenario = 'WORLD_HUMAN_SMOKING' },
        { zone = 'airport', role = 'custom', model = 's_m_m_autoshop_02', coords = vector4(-1018.62, -2733.24, 20.2, 240.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'airport', role = 'weaponcustom', model = 's_m_m_ammucountry', coords = vector4(-1050.08, -2720.47, 20.09, 120.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },

        { zone = 'sandy', role = 'stash', model = 'cs_bankman', coords = vector4(1851.25, 3674.95, 33.79, 311.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'sandy', role = 'shop', model = 's_m_y_ammucity_01', coords = vector4(1855.86, 3674.29, 33.64, 5.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'sandy', role = 'clothing', model = 's_f_y_shop_mid', coords = vector4(1864.6, 3674.48, 33.82, 308.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
        { zone = 'sandy', role = 'resale', model = 's_m_y_dealer_01', coords = vector4(1843.74, 3666.92, 33.73, 113.0), scenario = 'WORLD_HUMAN_SMOKING' },
        { zone = 'sandy', role = 'custom', model = 's_m_m_autoshop_02', coords = vector4(1871.78, 3694.11, 33.55, 210.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'sandy', role = 'weaponcustom', model = 's_m_m_ammucountry', coords = vector4(1866.76, 3681.28, 33.62, 65.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },

        { zone = 'paleto', role = 'stash', model = 'cs_bankman', coords = vector4(-477.23, 5994.68, 31.34, 92.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'paleto', role = 'shop', model = 's_m_y_ammucity_01', coords = vector4(-470.17, 5997.31, 31.31, 134.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'paleto', role = 'clothing', model = 's_f_y_shop_mid', coords = vector4(-465.7, 5991.49, 31.29, 44.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
        { zone = 'paleto', role = 'resale', model = 's_m_y_dealer_01', coords = vector4(-468.95, 5987.54, 31.34, 32.0), scenario = 'WORLD_HUMAN_SMOKING' },
        { zone = 'paleto', role = 'custom', model = 's_m_m_autoshop_02', coords = vector4(-472.0, 6021.0, 31.34, 225.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'paleto', role = 'weaponcustom', model = 's_m_m_ammucountry', coords = vector4(-477.87, 6000.75, 31.33, 191.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
    },
}
