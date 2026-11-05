-- Décor des zones safe du mode PvP : un coin aménagé autour de chaque PNJ de service
-- (armurerie, atelier d'armes, garage, coffre, vestiaire...). Les objets sont créés par chaque
-- joueur, localement, quand il approche d'une zone safe.
--
-- Tout se place dans le repère du PNJ : il est à (0, 0) et regarde vers +y (x : sa droite,
-- y : devant lui). Le décor suit donc le PNJ quand un admin le déplace (F10 > Positions).
--
--   rangée : { at = vector2(x, y), axis = 'x' ou 'y', h = cap, items = { ... } }
--     Les objets sont posés côte à côte le long de l'axe, avec leur vraie taille, et s'étendent
--     du côté opposé au PNJ (une rangée en y = -0.9 part vers l'arrière). Sans `dir`, la rangée
--     est centrée sur `at` ; avec dir = 1 (ou -1), elle part de `at` vers les y (ou x) croissants.
--     behind = true : la rangée se met juste derrière la précédente (rangées de fond, axe x).
--   objet seul : { model = '...', at = vector2(x, y), h = cap }
--   un objet de rangée peut être { 'modèle', h = cap en plus, top = { 'modèle', ... } } :
--     les objets de `top` sont posés dessus, répartis sur sa largeur.
--   h : cap par rapport au PNJ, en degrés. La face avant des objets de GTA est le plus souvent
--     vers leur -y : h = 180 les tourne vers le devant du PNJ, -90 (à sa droite) et 90 (à sa
--     gauche) vers le centre.
--
-- Un objet est laissé de côté s'il gênerait : le PNJ et la place devant lui (pour lui parler),
-- un point d'apparition, le repère du mécanicien, un autre objet, un mur ou un objet de la
-- carte, une marche (sol trop haut ou trop bas). /pvp_decor (F8) refait le décor de la zone
-- et y écrit ce qui a été posé ou écarté.
Config.SafeDecor = {
    enabled = true,
    modes = { pvp = true }, -- modes de jeu où le décor existe
    buildDistance = 60.0, -- mètres au-delà du rayon de la zone : le décor est créé en approchant
    gap = 0.15, -- espace entre deux objets d'une rangée
    maxStep = 0.6, -- écart de sol toléré entre un objet et son PNJ (au-delà : marche, mur, trottoir)
    clear = {
        npc = 0.8, -- autour de chaque PNJ
        front = { y = 1.6, radius = 1.3 }, -- devant chaque PNJ : la place du joueur qui lui parle
        spawn = 2.2, -- autour des points d'apparition de la zone
        vehicle = 0.5, -- ajouté au rayon du repère du mécanicien (Config.VehicleCustom)
    },

    -- Décor de chaque rôle (Config.SafeNpcs.roles)
    stations = {
        -- Armurier : établis et casiers d'armes au fond, caisses d'armes et de munitions sur les côtés
        shop = {
            { at = vector2(0.0, -0.9), h = 180, items = {
                'gr_prop_gr_gunlocker_01a',
                { 'gr_prop_gr_bench_04a', top = { 'prop_box_guncase_01a', 'prop_box_ammo03a' } },
                { 'gr_prop_gr_bench_04b', top = { 'prop_box_ammo04a' } },
                'gr_prop_gr_gunlocker_01a',
            } },
            { behind = true, h = 180, items = { 'gr_prop_gr_cratespile_01a', 'gr_prop_gr_crates_sam_01a', 'gr_prop_gr_cratespile_01a' } },
            { at = vector2(-1.8, -0.6), axis = 'y', dir = 1, h = 90, items = {
                { 'gr_prop_gr_crates_rifles_01a', top = { 'gr_prop_gr_crate_mag_01a' } },
                'gr_prop_gr_crates_weapon_mix_01a',
                'prop_mil_crate_01',
            } },
            { at = vector2(1.8, -0.6), axis = 'y', dir = 1, h = -90, items = {
                { 'gr_prop_gr_crates_pistols_01a', top = { 'prop_box_ammo07a' } },
                'ex_prop_crate_ammo_sc',
                'gr_prop_gr_rsply_crate04a',
            } },
            { model = 'prop_worklight_03a', at = vector2(-3.6, 3.8), h = 135 },
        },

        -- Customiseur : atelier d'armurier (établi, fraiseuse, servantes, armoires à fusils)
        weaponcustom = {
            { at = vector2(0.0, -0.9), h = 180, items = {
                'gr_prop_gr_tool_draw_01a',
                { 'gr_prop_gr_bench_02a', top = { 'gr_prop_gr_gunsmithsupl_01a' } },
                'gr_prop_gr_cnc_01a',
                'gr_prop_gr_tool_chest_01a',
            } },
            { behind = true, h = 180, items = { 'bkr_prop_gunlocker_01a', 'bkr_prop_gunlocker_ammo_01a', 'gr_prop_gr_gunlocker_01a' } },
            { at = vector2(-1.8, -0.6), axis = 'y', dir = 1, h = 90, items = {
                { 'gr_prop_gr_bench_01a', top = { 'gr_prop_gr_gunsmithsupl_02a' } },
                'gr_prop_gr_drill_crate_01a',
            } },
            { at = vector2(1.8, -0.6), axis = 'y', dir = 1, h = -90, items = {
                'gr_prop_gr_crate_gun_01a',
                'gr_prop_gr_gunsmithsupl_03a',
                'gr_prop_gr_crate_pistol_02a',
            } },
            { model = 'prop_worklight_03b', at = vector2(3.6, 3.8), h = -135 },
        },

        -- Mécanicien : garage de casse. Le repère du véhicule, devant lui, reste libre :
        -- établi et étagères de pièces au fond, outils sur les côtés (écartés du repère), épaves plus loin.
        custom = {
            { at = vector2(0.0, -0.9), h = 180, items = {
                'imp_prop_tool_cabinet_01a',
                { 'imp_prop_impexp_mechbench', top = { 'imp_prop_impexp_gearbox_01', 'imp_prop_impexp_radiator_02' } },
                'imp_prop_tool_chest_01a',
                'imp_prop_impexp_parts_rack_01a',
            } },
            { behind = true, h = 180, items = { 'prop_tyre_rack_01', 'imp_prop_impexp_half_cut_rack_01a', 'prop_tyre_wall_01b' } },
            { at = vector2(-3.2, -0.6), axis = 'y', dir = 1, h = 90, items = {
                'prop_engine_hoist',
                'prop_compressor_03',
                'prop_gascyl_01a',
            } },
            { at = vector2(3.2, -0.6), axis = 'y', dir = 1, h = -90, items = {
                'imp_prop_car_jack_01a',
                'prop_toolchest_05',
                'prop_wheel_tyre',
            } },
            { model = 'prop_rub_carwreck_3', at = vector2(-6.8, 4.5), h = 8 },
            { model = 'prop_rub_carwreck_9', at = vector2(7.0, 6.5), h = -12 },
            { model = 'prop_rub_carwreck_2', at = vector2(-6.4, -2.6), h = 80 },
            { model = 'prop_rub_tyre_01', at = vector2(4.6, -1.8), h = 30 },
            { model = 'prop_rub_tyre_03', at = vector2(5.6, -0.4), h = 0 },
            { model = 'prop_worklight_04b', at = vector2(-4.8, 2.8), h = 60 },
        },

        -- Banquier : armoires de sécurité et coffre-fort, argent compté sur une table
        stash = {
            { at = vector2(0.0, -0.9), h = 180, items = {
                'ch_prop_ch_sec_cabinet_01a',
                'prop_ld_int_safe_01',
                'ch_prop_ch_sec_cabinet_02a',
                'ch_prop_ch_sec_cabinet_01b',
            } },
            { at = vector2(-1.8, -0.6), axis = 'y', dir = 1, h = 90, items = { 'ex_prop_crate_money_sc', 'prop_cash_trolly' } },
            { at = vector2(1.8, -0.6), axis = 'y', dir = 1, h = -90, items = {
                { 'prop_table_03', top = { 'bkr_prop_money_counter', 'prop_cash_case_02' } },
                'hei_prop_cash_crate_half_full',
            } },
        },

        -- Tailleur : portants de vêtements et caisses de textile
        clothing = {
            { at = vector2(0.0, -0.9), h = 180, items = { 'prop_clothes_rail_01', 'prop_clothes_rail_02', 'prop_clothes_rail_03' } },
            { at = vector2(-1.8, -0.6), axis = 'y', dir = 1, h = 90, items = { 'prop_clothes_rail_2b', 'ex_prop_crate_clothing_sc' } },
            { at = vector2(1.8, -0.6), axis = 'y', dir = 1, h = -90, items = {
                'h4_prop_h4_crate_cloth_01a',
                'prop_cs_clothes_box',
                'ex_prop_crate_furjacket_sc',
            } },
        },

        -- Artisan : établis, servantes, groupe électrogène et matériaux
        crafting = {
            { at = vector2(0.0, -0.9), h = 180, items = {
                'prop_toolchest_05',
                { 'prop_tool_bench02', top = { 'prop_tool_box_04' } },
                'gr_prop_gr_bench_03a',
                'prop_toolchest_03',
            } },
            { behind = true, h = 180, items = { 'prop_generator_03a', 'prop_cons_crate', 'prop_barrel_02a' } },
            { at = vector2(-1.8, -0.6), axis = 'y', dir = 1, h = 90, items = { 'gr_prop_gr_rsply_crate02a', 'prop_gascyl_02a', 'prop_barrel_01a' } },
            { at = vector2(1.8, -0.6), axis = 'y', dir = 1, h = -90, items = { 'imp_prop_tool_draw_01a', 'imp_prop_tool_box_01a' } },
            { model = 'prop_worklight_03b', at = vector2(-3.2, 2.4), h = 135 },
        },

        -- Recruteur : poste de commandement (tableaux de mission, table et ordinateur, caisses militaires)
        contracts = {
            { at = vector2(0.0, -0.9), h = 180, items = {
                'ch_prop_whiteboard',
                { 'h4_prop_h4_table_01a', top = { 'prop_laptop_01a', 'prop_cs_tablet' } },
                'h4_prop_h4_board_01a',
            } },
            { at = vector2(-1.8, -0.6), axis = 'y', dir = 1, h = 90, items = { 'prop_mil_crate_02', 'h4_prop_h4_mil_crate_02' } },
            { at = vector2(1.8, -0.6), axis = 'y', dir = 1, h = -90, items = { 'ch_prop_mil_crate_02b', 'prop_box_ammo06a' } },
        },

        -- Commissaire-priseur : étals et caisses d'objets de valeur
        market = {
            { at = vector2(0.0, -0.9), h = 180, items = {
                { 'prop_ven_market_table1', top = { 'prop_cash_case_01', 'prop_till_01' } },
                { 'prop_ven_market_table1', top = { 'ex_prop_crate_jewels_sc' } },
            } },
            { behind = true, h = 180, items = { 'ex_prop_crate_art_bc', 'ba_prop_battle_crate_m_antiques', 'ex_prop_crate_gems_bc' } },
            { at = vector2(-1.8, -0.6), axis = 'y', dir = 1, h = 90, items = { 'ba_prop_battle_crate_m_jewellery', 'ex_prop_crate_watch' } },
            { at = vector2(1.8, -0.6), axis = 'y', dir = 1, h = -90, items = { 'ex_prop_crate_art_02_sc' } },
            { model = 'prop_parasol_04b', at = vector2(3.0, 2.2), h = 0 },
        },

        -- Receleur : planque de marchandise (cartons, caisses, réchaud de fortune)
        resale = {
            { at = vector2(0.0, -0.9), h = 180, items = { 'prop_boxpile_06a', 'hei_prop_hei_warehousetrolly', 'prop_boxpile_07a' } },
            { at = vector2(-1.8, -0.6), axis = 'y', dir = 1, h = 90, items = { 'ex_prop_crate_elec_sc', 'ex_prop_crate_tob_sc', 'prop_cs_cardbox_01' } },
            { at = vector2(1.8, -0.6), axis = 'y', dir = 1, h = -90, items = { 'gr_prop_gr_hobo_stove_01', 'prop_barrel_02a', 'bkr_prop_duffel_bag_01a' } },
            { model = 'prop_rub_trolley01a', at = vector2(-3.6, 3.6), h = 30 },
        },

        -- James (donjons) : campement militaire
        dungeon = {
            { at = vector2(0.0, -0.9), h = 180, items = { 'prop_mil_crate_01', 'prop_generator_01a', 'prop_mil_crate_02' } },
            { behind = true, h = 180, items = { 'hei_prop_carrier_cargo_02a', 'hei_prop_carrier_crate_01a' } },
            { at = vector2(-1.8, -0.6), axis = 'y', dir = 1, h = 90, items = { 'h4_prop_h4_box_ammo_01a', 'prop_box_ammo05b', 'gr_prop_gr_rsply_crate03a' } },
            { at = vector2(1.8, -0.6), axis = 'y', dir = 1, h = -90, items = { 'prop_barrier_work05', 'h4_prop_h4_mb_crate_01a' } },
            { model = 'prop_worklight_04b', at = vector2(3.4, 2.2), h = -60 },
        },
    },
}
