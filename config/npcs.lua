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
        -- Freeroam : lance un mode de jeu (Config.FreeroamActivities) ; nom, icône et repère viennent du mode
        activity = { label = 'Organisateur', action = 'Voir le mode de jeu', icon = 'flag', blip = { sprite = 280, color = 5 } },
    },
    -- Un PNJ n'existe que dans les modes de jeu de sa zone (config/zones.lua)
    npcs = {
        -- Freeroam : PNJ des modes de jeu (activity = clé de Config.FreeroamActivities)
        { zone = 'freeroam_hub', role = 'activity', activity = 'chase', model = 's_m_y_cop_01', coords = vector4(213.4, -943.0, 30.7, 60.0), scenario = 'WORLD_HUMAN_COP_IDLES' },
        { zone = 'freeroam_hub', role = 'activity', activity = 'cvc', model = 's_m_y_blackops_01', coords = vector4(202.6, -925.5, 30.7, 150.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'freeroam_hub', role = 'activity', activity = 'gunfight', model = 's_m_y_swat_01', coords = vector4(196.6, -912.6, 30.7, 180.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },

        { zone = 'legion', role = 'stash', model = 'cs_bankman', coords = vector4(186.8, -941.6, 30.1, 340.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'legion', role = 'shop', model = 's_m_y_ammucity_01', coords = vector4(202.6, -925.5, 30.7, 150.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'legion', role = 'clothing', model = 's_f_y_shop_mid', coords = vector4(171.4, -925.2, 30.7, 240.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
        { zone = 'legion', role = 'crafting', model = 's_m_m_autoshop_01', coords = vector4(213.4, -943.0, 30.7, 60.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'legion', role = 'contracts', model = 's_m_m_highsec_01', coords = vector4(196.6, -912.6, 30.7, 180.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'legion', role = 'market', model = 'a_m_y_business_02', coords = vector4(178.5, -948.0, 30.1, 30.0), scenario = 'WORLD_HUMAN_STAND_MOBILE' },

        -- Autres zones safe : coffre, boutique et tenue (fabrication, contrats et marché à Legion)
        { zone = 'airport', role = 'stash', model = 'cs_bankman', coords = vector4(-1042.0, -2725.0, 20.2, 150.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'airport', role = 'shop', model = 's_m_y_ammucity_01', coords = vector4(-1028.0, -2732.0, 20.2, 120.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'airport', role = 'clothing', model = 's_f_y_shop_mid', coords = vector4(-1048.0, -2738.0, 20.2, 240.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },

        { zone = 'sandy', role = 'stash', model = 'cs_bankman', coords = vector4(1849.0, 3680.0, 34.3, 300.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'sandy', role = 'shop', model = 's_m_y_ammucity_01', coords = vector4(1861.0, 3684.0, 34.3, 120.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'sandy', role = 'clothing', model = 's_f_y_shop_mid', coords = vector4(1855.0, 3692.0, 34.3, 210.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },

        { zone = 'paleto', role = 'stash', model = 'cs_bankman', coords = vector4(-444.0, 6008.0, 31.7, 45.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
        { zone = 'paleto', role = 'shop', model = 's_m_y_ammucity_01', coords = vector4(-452.0, 6016.0, 31.7, 225.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
        { zone = 'paleto', role = 'clothing', model = 's_f_y_shop_mid', coords = vector4(-441.0, 6016.0, 31.7, 135.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
    },
}
