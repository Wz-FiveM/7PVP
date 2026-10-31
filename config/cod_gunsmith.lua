-- Call of Duty : accessoires et camouflages des armes principales et secondaires.
-- Chaque arme progresse avec ses propres kills (pvp_cod_profiles.weapon_progress). Cette progression reste après un Prestige.
-- Les choix sont gardés dans chaque classe, par arme : changer d'arme dans une classe retire ses accessoires et son camouflage.
Config.CodGunsmith = {
    -- Passer du niveau n au niveau n+1 demande base + growth * (n - 1) kills avec cette arme
    levels = { max = 7, base = 15, growth = 10 },

    -- Un accessoire par emplacement, sur chaque arme
    slots = {
        { id = 'optic', label = 'Optique' },
        { id = 'muzzle', label = 'Bouche du canon' },
        { id = 'grip', label = 'Poignée' },
        { id = 'magazine', label = 'Chargeur' },
        { id = 'light', label = 'Lampe' },
    },

    -- level : niveau de l'arme qui débloque l'accessoire ; une arme n'a que ceux listés dans `weapons`
    attachments = {
        { id = 'light', slot = 'light', level = 2, label = 'Lampe tactique', description = 'Éclaire devant toi quand tu vises.' },
        { id = 'scope', slot = 'optic', level = 3, label = 'Lunette', description = 'Un viseur pour mieux cadrer tes cibles.' },
        { id = 'scope_max', slot = 'optic', level = 3, label = 'Lunette avancée', description = 'Grossit plus que la lunette d\'origine.' },
        { id = 'mag', slot = 'magazine', level = 4, label = 'Chargeur étendu', description = 'Plus de balles avant de recharger.' },
        { id = 'grip', slot = 'grip', level = 5, label = 'Poignée avant', description = 'Une arme plus stable au tir.' },
        { id = 'suppressor', slot = 'muzzle', level = 6, label = 'Silencieux', description = 'Étouffe le bruit et la flamme de tes tirs.' },
        { id = 'drum', slot = 'magazine', level = 7, label = 'Grand chargeur', description = 'Encore plus de balles avant de recharger.' },
    },

    -- Teintes de GTA (SetPedWeaponTintIndex) : tint = indice, color = pastille du menu.
    -- kills et headshots : ce qu'il faut avoir fait avec cette arme, les deux si les deux sont donnés.
    camos = {
        { id = 'army', tint = 4, color = '#6b6a3a', label = 'Armée', kills = 25 },
        { id = 'green', tint = 1, color = '#3f7d3a', label = 'Vert', kills = 50 },
        { id = 'police', tint = 5, color = '#2f4f8f', label = 'Police', headshots = 25 },
        { id = 'orange', tint = 6, color = '#d9772b', label = 'Orange', headshots = 50 },
        { id = 'pink', tint = 3, color = '#d65c93', label = 'Rose', kills = 150, headshots = 75 },
        { id = 'gold', tint = 2, color = '#d4af37', label = 'Or', kills = 300, headshots = 100 },
        { id = 'platinum', tint = 7, color = '#cfd4d8', label = 'Platine', kills = 600, headshots = 200 },
    },

    -- Composants de GTA de chaque arme du catalogue (Config.Cod.weapons)
    weapons = {
        WEAPON_CARBINERIFLE = { light = 'COMPONENT_AT_AR_FLSH', scope = 'COMPONENT_AT_SCOPE_MEDIUM', mag = 'COMPONENT_CARBINERIFLE_CLIP_02', grip = 'COMPONENT_AT_AR_AFGRIP', suppressor = 'COMPONENT_AT_AR_SUPP', drum = 'COMPONENT_CARBINERIFLE_CLIP_03' },
        WEAPON_ASSAULTRIFLE = { light = 'COMPONENT_AT_AR_FLSH', scope = 'COMPONENT_AT_SCOPE_MACRO', mag = 'COMPONENT_ASSAULTRIFLE_CLIP_02', grip = 'COMPONENT_AT_AR_AFGRIP', suppressor = 'COMPONENT_AT_AR_SUPP_02', drum = 'COMPONENT_ASSAULTRIFLE_CLIP_03' },
        WEAPON_SPECIALCARBINE = { light = 'COMPONENT_AT_AR_FLSH', scope = 'COMPONENT_AT_SCOPE_MEDIUM', mag = 'COMPONENT_SPECIALCARBINE_CLIP_02', grip = 'COMPONENT_AT_AR_AFGRIP', suppressor = 'COMPONENT_AT_AR_SUPP_02', drum = 'COMPONENT_SPECIALCARBINE_CLIP_03' },
        WEAPON_BULLPUPRIFLE = { light = 'COMPONENT_AT_AR_FLSH', scope = 'COMPONENT_AT_SCOPE_SMALL', mag = 'COMPONENT_BULLPUPRIFLE_CLIP_02', grip = 'COMPONENT_AT_AR_AFGRIP', suppressor = 'COMPONENT_AT_AR_SUPP' },
        WEAPON_ADVANCEDRIFLE = { light = 'COMPONENT_AT_AR_FLSH', scope = 'COMPONENT_AT_SCOPE_SMALL', mag = 'COMPONENT_ADVANCEDRIFLE_CLIP_02', suppressor = 'COMPONENT_AT_AR_SUPP' },
        WEAPON_SMG = { light = 'COMPONENT_AT_AR_FLSH', scope = 'COMPONENT_AT_SCOPE_MACRO_02', mag = 'COMPONENT_SMG_CLIP_02', suppressor = 'COMPONENT_AT_PI_SUPP', drum = 'COMPONENT_SMG_CLIP_03' },
        WEAPON_MICROSMG = { light = 'COMPONENT_AT_PI_FLSH', scope = 'COMPONENT_AT_SCOPE_MACRO', mag = 'COMPONENT_MICROSMG_CLIP_02', suppressor = 'COMPONENT_AT_AR_SUPP_02' },
        WEAPON_ASSAULTSMG = { light = 'COMPONENT_AT_AR_FLSH', scope = 'COMPONENT_AT_SCOPE_MACRO', mag = 'COMPONENT_ASSAULTSMG_CLIP_02', suppressor = 'COMPONENT_AT_AR_SUPP_02' },
        WEAPON_COMBATPDW = { light = 'COMPONENT_AT_AR_FLSH', scope = 'COMPONENT_AT_SCOPE_SMALL', mag = 'COMPONENT_COMBATPDW_CLIP_02', grip = 'COMPONENT_AT_AR_AFGRIP', drum = 'COMPONENT_COMBATPDW_CLIP_03' },
        WEAPON_PUMPSHOTGUN = { light = 'COMPONENT_AT_AR_FLSH', suppressor = 'COMPONENT_AT_SR_SUPP' },
        WEAPON_ASSAULTSHOTGUN = { light = 'COMPONENT_AT_AR_FLSH', mag = 'COMPONENT_ASSAULTSHOTGUN_CLIP_02', grip = 'COMPONENT_AT_AR_AFGRIP', suppressor = 'COMPONENT_AT_AR_SUPP' },
        WEAPON_HEAVYSHOTGUN = { light = 'COMPONENT_AT_AR_FLSH', mag = 'COMPONENT_HEAVYSHOTGUN_CLIP_02', grip = 'COMPONENT_AT_AR_AFGRIP', suppressor = 'COMPONENT_AT_AR_SUPP_02', drum = 'COMPONENT_HEAVYSHOTGUN_CLIP_03' },
        WEAPON_MG = { scope = 'COMPONENT_AT_SCOPE_SMALL_02', mag = 'COMPONENT_MG_CLIP_02' },
        WEAPON_COMBATMG = { scope = 'COMPONENT_AT_SCOPE_MEDIUM', mag = 'COMPONENT_COMBATMG_CLIP_02', grip = 'COMPONENT_AT_AR_AFGRIP' },
        WEAPON_SNIPERRIFLE = { scope_max = 'COMPONENT_AT_SCOPE_MAX', suppressor = 'COMPONENT_AT_AR_SUPP_02' },
        WEAPON_MARKSMANRIFLE = { light = 'COMPONENT_AT_AR_FLSH', mag = 'COMPONENT_MARKSMANRIFLE_CLIP_02', grip = 'COMPONENT_AT_AR_AFGRIP', suppressor = 'COMPONENT_AT_AR_SUPP' },
        WEAPON_HEAVYSNIPER = { scope_max = 'COMPONENT_AT_SCOPE_MAX' },

        WEAPON_PISTOL = { light = 'COMPONENT_AT_PI_FLSH', mag = 'COMPONENT_PISTOL_CLIP_02', suppressor = 'COMPONENT_AT_PI_SUPP_02' },
        WEAPON_COMBATPISTOL = { light = 'COMPONENT_AT_PI_FLSH', mag = 'COMPONENT_COMBATPISTOL_CLIP_02', suppressor = 'COMPONENT_AT_PI_SUPP' },
        WEAPON_HEAVYPISTOL = { light = 'COMPONENT_AT_PI_FLSH', mag = 'COMPONENT_HEAVYPISTOL_CLIP_02', suppressor = 'COMPONENT_AT_PI_SUPP' },
        WEAPON_PISTOL50 = { light = 'COMPONENT_AT_PI_FLSH', mag = 'COMPONENT_PISTOL50_CLIP_02', suppressor = 'COMPONENT_AT_AR_SUPP_02' },
        WEAPON_REVOLVER = {},
        WEAPON_MACHINEPISTOL = { mag = 'COMPONENT_MACHINEPISTOL_CLIP_02', suppressor = 'COMPONENT_AT_PI_SUPP', drum = 'COMPONENT_MACHINEPISTOL_CLIP_03' },
    },
}
