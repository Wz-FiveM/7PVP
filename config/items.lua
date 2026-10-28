-- Tous les objets du jeu. Armes, munitions et argent sont des objets comme les autres.
--
-- type   : 'weapon' | 'ammo' | 'consumable' | 'money' | 'attachment' | 'material'
-- weight : poids d'une unité, en kg
-- weapon : (armes) nom GTA de l'arme
-- ammo   : (armes) objet de munitions utilisé. Les armes qui partagent un objet de
--          munitions doivent partager le même type de munitions GTA (pistolets, SMG, fusils...)
-- heal / armor : (consommables) points de vie / d'armure rendus
--
-- Image : dépose un PNG dans web/public/items/<nom>.png (ex: weapon_pistol.png).
-- Sans image, l'interface affiche une icône selon le type.
Config.Items = {
    money = { label = 'Argent', type = 'money', weight = 0.0 },

    ammo_9mm = { label = '9mm', type = 'ammo', weight = 0.01 },
    ammo_45acp = { label = '.45 ACP', type = 'ammo', weight = 0.012 },
    ammo_556 = { label = '5.56mm', type = 'ammo', weight = 0.012 },
    ammo_12g = { label = 'Calibre 12', type = 'ammo', weight = 0.04 },
    ammo_762 = { label = '7.62mm', type = 'ammo', weight = 0.025 },

    weapon_knife = { label = 'Couteau', type = 'weapon', weight = 0.3, weapon = 'WEAPON_KNIFE' },
    weapon_pistol = { label = 'Pistolet', type = 'weapon', weight = 1.0, weapon = 'WEAPON_PISTOL', ammo = 'ammo_9mm' },
    weapon_combatpistol = { label = 'Pistolet de combat', type = 'weapon', weight = 1.0, weapon = 'WEAPON_COMBATPISTOL', ammo = 'ammo_9mm' },
    weapon_microsmg = { label = 'Micro SMG', type = 'weapon', weight = 2.0, weapon = 'WEAPON_MICROSMG', ammo = 'ammo_45acp' },
    weapon_smg = { label = 'SMG', type = 'weapon', weight = 2.5, weapon = 'WEAPON_SMG', ammo = 'ammo_45acp' },
    weapon_pumpshotgun = { label = 'Fusil à pompe', type = 'weapon', weight = 3.5, weapon = 'WEAPON_PUMPSHOTGUN', ammo = 'ammo_12g' },
    weapon_carbinerifle = { label = 'Carabine', type = 'weapon', weight = 3.5, weapon = 'WEAPON_CARBINERIFLE', ammo = 'ammo_556' },
    weapon_assaultrifle = { label = 'Fusil d\'assaut', type = 'weapon', weight = 3.5, weapon = 'WEAPON_ASSAULTRIFLE', ammo = 'ammo_556' },
    weapon_sniperrifle = { label = 'Sniper', type = 'weapon', weight = 5.0, weapon = 'WEAPON_SNIPERRIFLE', ammo = 'ammo_762' },

    bandage = { label = 'Bandage', type = 'consumable', weight = 0.1, heal = 25 },
    medkit = { label = 'Trousse de soins', type = 'consumable', weight = 0.5, heal = 100 },
    armor = { label = 'Gilet pare-balles', type = 'consumable', weight = 3.0, armor = 50 },

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
    bag = { label = 'Mon sac', capacity = 40.0 },
    protected = { label = 'Conteneur protégé', capacity = 5.0 },
    stash = { label = 'Coffre', capacity = 250.0, safeOnly = true },
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
