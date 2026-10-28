-- Tous les objets du jeu. Armes, munitions et argent sont des objets comme les autres.
--
-- type   : 'weapon' | 'ammo' | 'consumable' | 'money' | 'attachment' | 'material'
-- weight : poids d'une unité, en kg
-- weapon : (armes) nom GTA de l'arme
-- ammo   : (armes) objet de munitions utilisé. Les armes qui partagent un objet de
--          munitions doivent partager le même type de munitions GTA (pistolets, SMG, fusils...)
-- heal / armor : (consommables) points de vie / d'armure rendus
-- effect       : (consommables) effet à durée, affiché à l'écran avec son compte à rebours :
--                { id = clé de Config.Effects, duration = secondes, perSecond = (regen) PV par seconde }
-- repair       : (consommables) répare le véhicule du joueur (dedans, ou à côté du dernier conduit)
-- throwable    : (armes) arme de jet, l'objet sert lui-même de munition (`ammo` = son propre nom) :
--                une grenade lancée retire une grenade de l'inventaire
--
-- Image : dépose un PNG dans web/public/items/<nom>.png (ex: weapon_pistol.png).
-- Sans image, l'interface affiche une icône selon le type.
Config.Items = {
    money = { label = 'Argent', type = 'money', weight = 0.0 },

    -- Munitions : une par « pool » de munitions GTA (deux objets ne peuvent pas partager un pool)
    ammo_9mm = { label = 'Munitions de pistolet', type = 'ammo', weight = 0.01 }, -- AMMO_PISTOL
    ammo_45acp = { label = 'Munitions de SMG', type = 'ammo', weight = 0.012 }, -- AMMO_SMG
    ammo_556 = { label = 'Munitions de fusil', type = 'ammo', weight = 0.012 }, -- AMMO_RIFLE
    ammo_12g = { label = 'Cartouches calibre 12', type = 'ammo', weight = 0.04 }, -- AMMO_SHOTGUN
    ammo_762 = { label = 'Munitions de sniper', type = 'ammo', weight = 0.025 }, -- AMMO_SNIPER
    ammo_mg = { label = 'Bande de mitrailleuse', type = 'ammo', weight = 0.02 }, -- AMMO_MG
    ammo_flare = { label = 'Fusées éclairantes', type = 'ammo', weight = 0.1 }, -- AMMO_FLAREGUN
    ammo_grenade40 = { label = 'Grenades 40 mm', type = 'ammo', weight = 0.25 }, -- AMMO_GRENADELAUNCHER
    ammo_rocket = { label = 'Roquettes', type = 'ammo', weight = 2.0 }, -- AMMO_RPG
    ammo_homing = { label = 'Missiles guidés', type = 'ammo', weight = 2.5 }, -- AMMO_HOMINGLAUNCHER
    ammo_minigun = { label = 'Bande de minigun', type = 'ammo', weight = 0.02 }, -- AMMO_MINIGUN
    ammo_firework = { label = 'Feux d\'artifice', type = 'ammo', weight = 0.5 }, -- AMMO_FIREWORK
    ammo_railgun = { label = 'Charges de railgun', type = 'ammo', weight = 1.0 }, -- AMMO_RAILGUN

    -- Armes blanches
    weapon_knife = { label = 'Couteau', type = 'weapon', weight = 0.3, weapon = 'WEAPON_KNIFE' },
    weapon_dagger = { label = 'Dague', type = 'weapon', weight = 0.4, weapon = 'WEAPON_DAGGER' },
    weapon_switchblade = { label = 'Cran d\'arrêt', type = 'weapon', weight = 0.2, weapon = 'WEAPON_SWITCHBLADE' },
    weapon_machete = { label = 'Machette', type = 'weapon', weight = 0.8, weapon = 'WEAPON_MACHETE' },
    weapon_hatchet = { label = 'Hachette', type = 'weapon', weight = 0.9, weapon = 'WEAPON_HATCHET' },
    weapon_stone_hatchet = { label = 'Hachette en pierre', type = 'weapon', weight = 1.0, weapon = 'WEAPON_STONE_HATCHET' },
    weapon_battleaxe = { label = 'Hache de combat', type = 'weapon', weight = 1.5, weapon = 'WEAPON_BATTLEAXE' },
    weapon_bat = { label = 'Batte de baseball', type = 'weapon', weight = 1.0, weapon = 'WEAPON_BAT' },
    weapon_golfclub = { label = 'Club de golf', type = 'weapon', weight = 0.8, weapon = 'WEAPON_GOLFCLUB' },
    weapon_poolcue = { label = 'Queue de billard', type = 'weapon', weight = 0.6, weapon = 'WEAPON_POOLCUE' },
    weapon_crowbar = { label = 'Pied-de-biche', type = 'weapon', weight = 1.2, weapon = 'WEAPON_CROWBAR' },
    weapon_hammer = { label = 'Marteau', type = 'weapon', weight = 0.8, weapon = 'WEAPON_HAMMER' },
    weapon_wrench = { label = 'Clé à molette', type = 'weapon', weight = 1.0, weapon = 'WEAPON_WRENCH' },
    weapon_nightstick = { label = 'Matraque', type = 'weapon', weight = 0.6, weapon = 'WEAPON_NIGHTSTICK' },
    weapon_knuckle = { label = 'Poing américain', type = 'weapon', weight = 0.3, weapon = 'WEAPON_KNUCKLE' },
    weapon_bottle = { label = 'Bouteille cassée', type = 'weapon', weight = 0.4, weapon = 'WEAPON_BOTTLE' },
    weapon_flashlight = { label = 'Lampe torche', type = 'weapon', weight = 0.5, weapon = 'WEAPON_FLASHLIGHT' },

    -- Pistolets et revolvers (munitions de pistolet)
    weapon_pistol = { label = 'Pistolet', type = 'weapon', weight = 1.0, weapon = 'WEAPON_PISTOL', ammo = 'ammo_9mm' },
    weapon_pistol_mk2 = { label = 'Pistolet Mk II', type = 'weapon', weight = 1.0, weapon = 'WEAPON_PISTOL_MK2', ammo = 'ammo_9mm' },
    weapon_combatpistol = { label = 'Pistolet de combat', type = 'weapon', weight = 1.0, weapon = 'WEAPON_COMBATPISTOL', ammo = 'ammo_9mm' },
    weapon_appistol = { label = 'Pistolet automatique', type = 'weapon', weight = 1.2, weapon = 'WEAPON_APPISTOL', ammo = 'ammo_9mm' },
    weapon_pistol50 = { label = 'Pistolet .50', type = 'weapon', weight = 1.4, weapon = 'WEAPON_PISTOL50', ammo = 'ammo_9mm' },
    weapon_heavypistol = { label = 'Pistolet lourd', type = 'weapon', weight = 1.3, weapon = 'WEAPON_HEAVYPISTOL', ammo = 'ammo_9mm' },
    weapon_snspistol = { label = 'Pistolet de poche', type = 'weapon', weight = 0.7, weapon = 'WEAPON_SNSPISTOL', ammo = 'ammo_9mm' },
    weapon_snspistol_mk2 = { label = 'Pistolet de poche Mk II', type = 'weapon', weight = 0.7, weapon = 'WEAPON_SNSPISTOL_MK2', ammo = 'ammo_9mm' },
    weapon_vintagepistol = { label = 'Pistolet vintage', type = 'weapon', weight = 1.0, weapon = 'WEAPON_VINTAGEPISTOL', ammo = 'ammo_9mm' },
    weapon_ceramicpistol = { label = 'Pistolet en céramique', type = 'weapon', weight = 0.8, weapon = 'WEAPON_CERAMICPISTOL', ammo = 'ammo_9mm' },
    weapon_marksmanpistol = { label = 'Pistolet de précision', type = 'weapon', weight = 1.2, weapon = 'WEAPON_MARKSMANPISTOL', ammo = 'ammo_9mm' },
    weapon_machinepistol = { label = 'Pistolet-mitrailleur', type = 'weapon', weight = 1.6, weapon = 'WEAPON_MACHINEPISTOL', ammo = 'ammo_9mm' },
    weapon_revolver = { label = 'Revolver lourd', type = 'weapon', weight = 1.6, weapon = 'WEAPON_REVOLVER', ammo = 'ammo_9mm' },
    weapon_revolver_mk2 = { label = 'Revolver lourd Mk II', type = 'weapon', weight = 1.7, weapon = 'WEAPON_REVOLVER_MK2', ammo = 'ammo_9mm' },
    weapon_doubleaction = { label = 'Revolver double action', type = 'weapon', weight = 1.3, weapon = 'WEAPON_DOUBLEACTION', ammo = 'ammo_9mm' },
    weapon_navyrevolver = { label = 'Revolver de la Navy', type = 'weapon', weight = 1.4, weapon = 'WEAPON_NAVYREVOLVER', ammo = 'ammo_9mm' },
    weapon_stungun = { label = 'Taser', type = 'weapon', weight = 0.6, weapon = 'WEAPON_STUNGUN' },
    weapon_flaregun = { label = 'Pistolet de détresse', type = 'weapon', weight = 0.8, weapon = 'WEAPON_FLAREGUN', ammo = 'ammo_flare' },

    -- Mitraillettes (munitions de SMG)
    weapon_microsmg = { label = 'Micro SMG', type = 'weapon', weight = 2.0, weapon = 'WEAPON_MICROSMG', ammo = 'ammo_45acp' },
    weapon_minismg = { label = 'Mini SMG', type = 'weapon', weight = 1.8, weapon = 'WEAPON_MINISMG', ammo = 'ammo_45acp' },
    weapon_smg = { label = 'SMG', type = 'weapon', weight = 2.5, weapon = 'WEAPON_SMG', ammo = 'ammo_45acp' },
    weapon_smg_mk2 = { label = 'SMG Mk II', type = 'weapon', weight = 2.6, weapon = 'WEAPON_SMG_MK2', ammo = 'ammo_45acp' },
    weapon_assaultsmg = { label = 'SMG d\'assaut', type = 'weapon', weight = 2.7, weapon = 'WEAPON_ASSAULTSMG', ammo = 'ammo_45acp' },
    weapon_combatpdw = { label = 'PDW de combat', type = 'weapon', weight = 2.6, weapon = 'WEAPON_COMBATPDW', ammo = 'ammo_45acp' },

    -- Fusils à pompe (cartouches calibre 12)
    weapon_pumpshotgun = { label = 'Fusil à pompe', type = 'weapon', weight = 3.5, weapon = 'WEAPON_PUMPSHOTGUN', ammo = 'ammo_12g' },
    weapon_pumpshotgun_mk2 = { label = 'Fusil à pompe Mk II', type = 'weapon', weight = 3.6, weapon = 'WEAPON_PUMPSHOTGUN_MK2', ammo = 'ammo_12g' },
    weapon_sawnoffshotgun = { label = 'Fusil à canon scié', type = 'weapon', weight = 2.5, weapon = 'WEAPON_SAWNOFFSHOTGUN', ammo = 'ammo_12g' },
    weapon_dbshotgun = { label = 'Fusil à double canon', type = 'weapon', weight = 2.4, weapon = 'WEAPON_DBSHOTGUN', ammo = 'ammo_12g' },
    weapon_bullpupshotgun = { label = 'Fusil à pompe bullpup', type = 'weapon', weight = 3.4, weapon = 'WEAPON_BULLPUPSHOTGUN', ammo = 'ammo_12g' },
    weapon_assaultshotgun = { label = 'Fusil à pompe d\'assaut', type = 'weapon', weight = 4.2, weapon = 'WEAPON_ASSAULTSHOTGUN', ammo = 'ammo_12g' },
    weapon_autoshotgun = { label = 'Fusil à pompe automatique', type = 'weapon', weight = 3.8, weapon = 'WEAPON_AUTOSHOTGUN', ammo = 'ammo_12g' },
    weapon_heavyshotgun = { label = 'Fusil à pompe lourd', type = 'weapon', weight = 4.5, weapon = 'WEAPON_HEAVYSHOTGUN', ammo = 'ammo_12g' },
    weapon_combatshotgun = { label = 'Fusil à pompe de combat', type = 'weapon', weight = 3.9, weapon = 'WEAPON_COMBATSHOTGUN', ammo = 'ammo_12g' },
    weapon_musket = { label = 'Mousquet', type = 'weapon', weight = 4.0, weapon = 'WEAPON_MUSKET', ammo = 'ammo_12g' },

    -- Fusils d'assaut (munitions de fusil)
    weapon_carbinerifle = { label = 'Carabine', type = 'weapon', weight = 3.5, weapon = 'WEAPON_CARBINERIFLE', ammo = 'ammo_556' },
    weapon_carbinerifle_mk2 = { label = 'Carabine Mk II', type = 'weapon', weight = 3.6, weapon = 'WEAPON_CARBINERIFLE_MK2', ammo = 'ammo_556' },
    weapon_assaultrifle = { label = 'Fusil d\'assaut', type = 'weapon', weight = 3.5, weapon = 'WEAPON_ASSAULTRIFLE', ammo = 'ammo_556' },
    weapon_assaultrifle_mk2 = { label = 'Fusil d\'assaut Mk II', type = 'weapon', weight = 3.6, weapon = 'WEAPON_ASSAULTRIFLE_MK2', ammo = 'ammo_556' },
    weapon_advancedrifle = { label = 'Fusil avancé', type = 'weapon', weight = 3.3, weapon = 'WEAPON_ADVANCEDRIFLE', ammo = 'ammo_556' },
    weapon_specialcarbine = { label = 'Carabine spéciale', type = 'weapon', weight = 3.4, weapon = 'WEAPON_SPECIALCARBINE', ammo = 'ammo_556' },
    weapon_specialcarbine_mk2 = { label = 'Carabine spéciale Mk II', type = 'weapon', weight = 3.5, weapon = 'WEAPON_SPECIALCARBINE_MK2', ammo = 'ammo_556' },
    weapon_bullpuprifle = { label = 'Fusil bullpup', type = 'weapon', weight = 3.2, weapon = 'WEAPON_BULLPUPRIFLE', ammo = 'ammo_556' },
    weapon_bullpuprifle_mk2 = { label = 'Fusil bullpup Mk II', type = 'weapon', weight = 3.3, weapon = 'WEAPON_BULLPUPRIFLE_MK2', ammo = 'ammo_556' },
    weapon_compactrifle = { label = 'Fusil compact', type = 'weapon', weight = 2.8, weapon = 'WEAPON_COMPACTRIFLE', ammo = 'ammo_556' },
    weapon_militaryrifle = { label = 'Fusil militaire', type = 'weapon', weight = 3.7, weapon = 'WEAPON_MILITARYRIFLE', ammo = 'ammo_556' },
    weapon_heavyrifle = { label = 'Fusil lourd', type = 'weapon', weight = 4.0, weapon = 'WEAPON_HEAVYRIFLE', ammo = 'ammo_556' },
    weapon_tacticalrifle = { label = 'Fusil tactique', type = 'weapon', weight = 3.4, weapon = 'WEAPON_TACTICALRIFLE', ammo = 'ammo_556' },

    -- Mitrailleuses (bande de mitrailleuse)
    weapon_mg = { label = 'Mitrailleuse', type = 'weapon', weight = 7.0, weapon = 'WEAPON_MG', ammo = 'ammo_mg' },
    weapon_combatmg = { label = 'Mitrailleuse de combat', type = 'weapon', weight = 7.5, weapon = 'WEAPON_COMBATMG', ammo = 'ammo_mg' },
    weapon_combatmg_mk2 = { label = 'Mitrailleuse de combat Mk II', type = 'weapon', weight = 7.6, weapon = 'WEAPON_COMBATMG_MK2', ammo = 'ammo_mg' },
    weapon_gusenberg = { label = 'Gusenberg', type = 'weapon', weight = 4.5, weapon = 'WEAPON_GUSENBERG', ammo = 'ammo_mg' },
    weapon_raycarbine = { label = 'Carabine laser', type = 'weapon', weight = 4.0, weapon = 'WEAPON_RAYCARBINE', ammo = 'ammo_mg' },

    -- Fusils de précision (munitions de sniper)
    weapon_sniperrifle = { label = 'Sniper', type = 'weapon', weight = 5.0, weapon = 'WEAPON_SNIPERRIFLE', ammo = 'ammo_762' },
    weapon_heavysniper = { label = 'Sniper lourd', type = 'weapon', weight = 7.0, weapon = 'WEAPON_HEAVYSNIPER', ammo = 'ammo_762' },
    weapon_heavysniper_mk2 = { label = 'Sniper lourd Mk II', type = 'weapon', weight = 7.2, weapon = 'WEAPON_HEAVYSNIPER_MK2', ammo = 'ammo_762' },
    weapon_marksmanrifle = { label = 'Fusil de tireur d\'élite', type = 'weapon', weight = 4.5, weapon = 'WEAPON_MARKSMANRIFLE', ammo = 'ammo_762' },
    weapon_marksmanrifle_mk2 = { label = 'Fusil de tireur d\'élite Mk II', type = 'weapon', weight = 4.6, weapon = 'WEAPON_MARKSMANRIFLE_MK2', ammo = 'ammo_762' },
    weapon_precisionrifle = { label = 'Fusil de précision', type = 'weapon', weight = 4.2, weapon = 'WEAPON_PRECISIONRIFLE', ammo = 'ammo_762' },

    -- Armes lourdes (largages et admins seulement)
    weapon_grenadelauncher = { label = 'Lance-grenades', type = 'weapon', weight = 6.0, weapon = 'WEAPON_GRENADELAUNCHER', ammo = 'ammo_grenade40' },
    weapon_compactlauncher = { label = 'Lance-grenades compact', type = 'weapon', weight = 3.5, weapon = 'WEAPON_COMPACTLAUNCHER', ammo = 'ammo_grenade40' },
    weapon_rpg = { label = 'Lance-roquettes', type = 'weapon', weight = 8.0, weapon = 'WEAPON_RPG', ammo = 'ammo_rocket' },
    weapon_hominglauncher = { label = 'Lance-missiles guidés', type = 'weapon', weight = 9.0, weapon = 'WEAPON_HOMINGLAUNCHER', ammo = 'ammo_homing' },
    weapon_minigun = { label = 'Minigun', type = 'weapon', weight = 15.0, weapon = 'WEAPON_MINIGUN', ammo = 'ammo_minigun' },
    weapon_rayminigun = { label = 'Minigun laser', type = 'weapon', weight = 15.0, weapon = 'WEAPON_RAYMINIGUN', ammo = 'ammo_minigun' },
    weapon_firework = { label = 'Lanceur de feux d\'artifice', type = 'weapon', weight = 4.0, weapon = 'WEAPON_FIREWORK', ammo = 'ammo_firework' },
    weapon_railgun = { label = 'Railgun', type = 'weapon', weight = 10.0, weapon = 'WEAPON_RAILGUN', ammo = 'ammo_railgun' },

    -- Armes de jet : chaque objet est une munition
    weapon_grenade = { label = 'Grenade', type = 'weapon', weight = 0.4, weapon = 'WEAPON_GRENADE', ammo = 'weapon_grenade', throwable = true },
    weapon_stickybomb = { label = 'Bombe collante', type = 'weapon', weight = 0.5, weapon = 'WEAPON_STICKYBOMB', ammo = 'weapon_stickybomb', throwable = true },
    weapon_proxmine = { label = 'Mine de proximité', type = 'weapon', weight = 0.6, weapon = 'WEAPON_PROXMINE', ammo = 'weapon_proxmine', throwable = true },
    weapon_pipebomb = { label = 'Bombe artisanale', type = 'weapon', weight = 0.5, weapon = 'WEAPON_PIPEBOMB', ammo = 'weapon_pipebomb', throwable = true },
    weapon_molotov = { label = 'Cocktail Molotov', type = 'weapon', weight = 0.6, weapon = 'WEAPON_MOLOTOV', ammo = 'weapon_molotov', throwable = true },
    weapon_bzgas = { label = 'Grenade lacrymogène', type = 'weapon', weight = 0.4, weapon = 'WEAPON_BZGAS', ammo = 'weapon_bzgas', throwable = true },
    weapon_smokegrenade = { label = 'Grenade fumigène', type = 'weapon', weight = 0.4, weapon = 'WEAPON_SMOKEGRENADE', ammo = 'weapon_smokegrenade', throwable = true },
    weapon_flare = { label = 'Fusée de signalisation', type = 'weapon', weight = 0.2, weapon = 'WEAPON_FLARE', ammo = 'weapon_flare', throwable = true },
    weapon_ball = { label = 'Balle', type = 'weapon', weight = 0.1, weapon = 'WEAPON_BALL', ammo = 'weapon_ball', throwable = true },
    weapon_snowball = { label = 'Boule de neige', type = 'weapon', weight = 0.1, weapon = 'WEAPON_SNOWBALL', ammo = 'weapon_snowball', throwable = true },

    bandage = { label = 'Bandage', type = 'consumable', weight = 0.1, heal = 25 },
    firstaid = { label = 'Kit de premiers secours', type = 'consumable', weight = 0.3, heal = 50 },
    medkit = { label = 'Trousse de soins', type = 'consumable', weight = 0.5, heal = 100 },
    antizin = { label = 'Antizin', type = 'consumable', weight = 0.1, heal = 15, effect = { id = 'antizin', duration = 120 } },
    drug_health = { label = 'Stimulant de santé', type = 'consumable', weight = 0.1, effect = { id = 'regen', duration = 30, perSecond = 2 } },
    drug_stamina = { label = 'Stimulant d\'endurance', type = 'consumable', weight = 0.1, effect = { id = 'stamina', duration = 60 } },
    light_kevlar = { label = 'Gilet léger', type = 'consumable', weight = 1.5, armor = 25 },
    armor = { label = 'Gilet pare-balles', type = 'consumable', weight = 3.0, armor = 50 },
    heavy_kevlar = { label = 'Gilet lourd', type = 'consumable', weight = 5.0, armor = 100 },
    repairkit = { label = 'Kit de réparation', type = 'consumable', weight = 2.0, repair = true },

    -- Accessoires : se fixent sur une arme compatible (voir Config.Attachments ci-dessous)
    att_suppressor = { label = 'Silencieux', type = 'attachment', weight = 0.4 },
    att_scope = { label = 'Lunette', type = 'attachment', weight = 0.4 },
    att_extclip = { label = 'Chargeur grande capacité', type = 'attachment', weight = 0.5 },
    att_flashlight = { label = 'Lampe tactique', type = 'attachment', weight = 0.2 },
    att_grip = { label = 'Poignée', type = 'attachment', weight = 0.3 },

    -- Matériaux de fabrication (voir config/crafting.lua), récupérés sur les zombies
    mat_cloth = { label = 'Tissu', type = 'material', weight = 0.05 },
    mat_scrap = { label = 'Ferraille', type = 'material', weight = 0.2 },
    mat_powder = { label = 'Poudre', type = 'material', weight = 0.02 },
    mat_chemicals = { label = 'Produits chimiques', type = 'material', weight = 0.1 },
}

-- Effets à durée des stimulants (client/modules/effects/effects.lua), affichés à l'écran avec
-- leur compte à rebours. Reprendre le même stimulant relance la durée ; tout s'arrête à la mort.
-- label : nom complet ; short : nom court sous l'icône ; icon : image (web/public/items/<icon>.png)
Config.Effects = {
    regen = { label = 'Régénération', short = 'Régén.', icon = 'drug_health' },
    stamina = { label = 'Endurance illimitée', short = 'Endurance', icon = 'drug_stamina' },
    antizin = { label = 'Immunité au vomi', short = 'Antizin', icon = 'antizin' },
    -- Pas un objet : donné en sortant d'une zone safe (Config.PassiveMode)
    passive = { label = 'Mode passif', short = 'Passif', icon = 'armor' },
}

-- Accessoires d'armes : accessoire -> { arme -> composant GTA }.
-- Une arme ne prend un accessoire que si elle figure dans sa liste.
Config.Attachments = {
    att_suppressor = {
        weapon_pistol = 'COMPONENT_AT_PI_SUPP_02',
        weapon_combatpistol = 'COMPONENT_AT_PI_SUPP',
        weapon_microsmg = 'COMPONENT_AT_AR_SUPP_02',
        weapon_smg = 'COMPONENT_AT_PI_SUPP',
        weapon_pumpshotgun = 'COMPONENT_AT_SR_SUPP',
        weapon_carbinerifle = 'COMPONENT_AT_AR_SUPP',
        weapon_assaultrifle = 'COMPONENT_AT_AR_SUPP_02',
        weapon_sniperrifle = 'COMPONENT_AT_AR_SUPP_02',
    },
    att_scope = {
        weapon_microsmg = 'COMPONENT_AT_SCOPE_MACRO',
        weapon_smg = 'COMPONENT_AT_SCOPE_MACRO_02',
        weapon_carbinerifle = 'COMPONENT_AT_SCOPE_MEDIUM',
        weapon_assaultrifle = 'COMPONENT_AT_SCOPE_MACRO',
        weapon_sniperrifle = 'COMPONENT_AT_SCOPE_MAX',
    },
    att_extclip = {
        weapon_pistol = 'COMPONENT_PISTOL_CLIP_02',
        weapon_combatpistol = 'COMPONENT_COMBATPISTOL_CLIP_02',
        weapon_microsmg = 'COMPONENT_MICROSMG_CLIP_02',
        weapon_smg = 'COMPONENT_SMG_CLIP_02',
        weapon_carbinerifle = 'COMPONENT_CARBINERIFLE_CLIP_02',
        weapon_assaultrifle = 'COMPONENT_ASSAULTRIFLE_CLIP_02',
    },
    att_flashlight = {
        weapon_pistol = 'COMPONENT_AT_PI_FLSH',
        weapon_combatpistol = 'COMPONENT_AT_PI_FLSH',
        weapon_microsmg = 'COMPONENT_AT_PI_FLSH',
        weapon_smg = 'COMPONENT_AT_AR_FLSH',
        weapon_pumpshotgun = 'COMPONENT_AT_AR_FLSH',
        weapon_carbinerifle = 'COMPONENT_AT_AR_FLSH',
        weapon_assaultrifle = 'COMPONENT_AT_AR_FLSH',
    },
    att_grip = {
        weapon_carbinerifle = 'COMPONENT_AT_AR_AFGRIP',
        weapon_assaultrifle = 'COMPONENT_AT_AR_AFGRIP',
    },
}

-- Conteneurs de l'inventaire
-- bag       : perdu à la mort (tombe dans un sac de butin)
-- protected : conservé à la mort
-- stash     : coffre personnel, conservé, accessible seulement près du banquier (safeOnly, config/npcs.lua).
--             Son contenu ne compte pas comme porté (armes, munitions, argent à dépenser).
Config.Containers = {
    bag = { label = 'Mon sac', capacity = 50.0 },
    protected = { label = 'Conteneur protégé', capacity = 40.0 },
    stash = { label = 'Coffre', capacity = 500.0, safeOnly = true },
}

-- Nombre d'emplacements de raccourcis (touches 1 à N)
Config.ShortcutSlots = 7

-- Inventaire d'un nouveau joueur
Config.NewPlayerKit = {
    bag = { money = 500, weapon_pistol = 1, ammo_9mm = 48, bandage = 2 },
    protected = {},
}

-- Contenu du sac donné à chaque respawn (le conteneur protégé est conservé)
Config.RespawnKit = { weapon_pistol = 1, ammo_9mm = 24, bandage = 1 }
