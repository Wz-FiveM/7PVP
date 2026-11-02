-- Custom des armes (mode PvP) : un customiseur par zone safe (rôle 'weaponcustom', config/npcs.lua).
-- On lui parle avec E : il propose les armes portées dans le sac, à l'essai sur un modèle posé devant soi.
-- La custom est gardée en base, par joueur et par modèle d'arme : toutes ses prochaines Carabines auront
-- la même, qu'elles viennent de la boutique, d'un butin ou d'un échange. Elle ne se perd jamais à la mort.
-- Elle est gratuite et ne change que l'apparence. Les accessoires (silencieux, lunette...) restent des objets :
-- le menu les fixe aussi, tout de suite et sans « Enregistrer », comme le clic droit de l'inventaire.
Config.WeaponCustom = {
    role = 'weaponcustom', -- rôle du PNJ dans Config.SafeNpcs

    -- Teintes des armes classiques (id : indice GTA), hex = aperçu dans le menu
    tints = {
        { id = 0, label = 'D\'origine', hex = '#2a2d30' },
        { id = 1, label = 'Vert', hex = '#3f7d3a' },
        { id = 2, label = 'Or', hex = '#d4af37' },
        { id = 3, label = 'Rose', hex = '#d65c93' },
        { id = 4, label = 'Armée', hex = '#6b6a3a' },
        { id = 5, label = 'Police', hex = '#2f4f8f' },
        { id = 6, label = 'Orange', hex = '#d9772b' },
        { id = 7, label = 'Platine', hex = '#cfd4d8' },
    },
    -- Teintes des armes Mk II
    tintsMk2 = {
        { id = 0, label = 'Noir classique', hex = '#1d1f21' },
        { id = 1, label = 'Gris classique', hex = '#6d7073' },
        { id = 2, label = 'Deux tons classique', hex = '#8a8d80' },
        { id = 3, label = 'Blanc classique', hex = '#d8d8d2' },
        { id = 4, label = 'Beige classique', hex = '#b8a57f' },
        { id = 5, label = 'Vert classique', hex = '#4b5a38' },
        { id = 6, label = 'Bleu classique', hex = '#3a4f6b' },
        { id = 7, label = 'Terre classique', hex = '#6f5a3f' },
        { id = 8, label = 'Marron et noir', hex = '#4a3628' },
        { id = 9, label = 'Rouge contrasté', hex = '#a0241f' },
        { id = 10, label = 'Bleu contrasté', hex = '#1f4fa0' },
        { id = 11, label = 'Jaune contrasté', hex = '#d4b21f' },
        { id = 12, label = 'Orange contrasté', hex = '#d9701f' },
        { id = 13, label = 'Rose vif', hex = '#f21f99' },
        { id = 14, label = 'Violet et jaune', hex = '#7b3fb0' },
        { id = 15, label = 'Orange vif', hex = '#ff7a12' },
        { id = 16, label = 'Vert et violet', hex = '#3fa04f' },
        { id = 17, label = 'Détails rouges', hex = '#e02a2a' },
        { id = 18, label = 'Détails verts', hex = '#2ac24a' },
        { id = 19, label = 'Détails cyan', hex = '#22c8d8' },
        { id = 20, label = 'Détails jaunes', hex = '#f0d020' },
        { id = 21, label = 'Rouge et blanc', hex = '#d8585a' },
        { id = 22, label = 'Bleu et blanc', hex = '#5a84d8' },
        { id = 23, label = 'Or métal', hex = '#d4af37' },
        { id = 24, label = 'Platine métal', hex = '#cfd4d8' },
        { id = 25, label = 'Gris et lilas', hex = '#9a90b0' },
        { id = 26, label = 'Violet et citron vert', hex = '#8f6fc0' },
        { id = 27, label = 'Rouge métal', hex = '#b81c28' },
        { id = 28, label = 'Vert métal', hex = '#1c8f4a' },
        { id = 29, label = 'Bleu métal', hex = '#1c5fb8' },
        { id = 30, label = 'Blanc et turquoise', hex = '#a8e0d8' },
        { id = 31, label = 'Rouge et jaune', hex = '#d8701c' },
    },

    -- Finitions : composants GTA sans effet sur le tir, une seule à la fois.
    -- Seules celles que l'arme accepte réellement sont proposées.
    finishes = {
        weapon_pistol = { { component = 'COMPONENT_PISTOL_VARMOD_LUXE', label = 'Luxe' } },
        weapon_combatpistol = { { component = 'COMPONENT_COMBATPISTOL_VARMOD_LOWRIDER', label = 'Lowrider' } },
        weapon_appistol = { { component = 'COMPONENT_APPISTOL_VARMOD_LUXE', label = 'Luxe' } },
        weapon_pistol50 = { { component = 'COMPONENT_PISTOL50_VARMOD_LUXE', label = 'Luxe' } },
        weapon_heavypistol = { { component = 'COMPONENT_HEAVYPISTOL_VARMOD_LUXE', label = 'Luxe' } },
        weapon_snspistol = { { component = 'COMPONENT_SNSPISTOL_VARMOD_LOWRIDER', label = 'Lowrider' } },
        weapon_revolver = {
            { component = 'COMPONENT_REVOLVER_VARMOD_BOSS', label = 'Boss' },
            { component = 'COMPONENT_REVOLVER_VARMOD_GOON', label = 'Homme de main' },
        },
        weapon_microsmg = { { component = 'COMPONENT_MICROSMG_VARMOD_LUXE', label = 'Luxe' } },
        weapon_smg = { { component = 'COMPONENT_SMG_VARMOD_LUXE', label = 'Luxe' } },
        weapon_assaultsmg = { { component = 'COMPONENT_ASSAULTSMG_VARMOD_LOWRIDER', label = 'Lowrider' } },
        weapon_pumpshotgun = { { component = 'COMPONENT_PUMPSHOTGUN_VARMOD_LOWRIDER', label = 'Lowrider' } },
        weapon_sawnoffshotgun = { { component = 'COMPONENT_SAWNOFFSHOTGUN_VARMOD_LUXE', label = 'Luxe' } },
        weapon_carbinerifle = { { component = 'COMPONENT_CARBINERIFLE_VARMOD_LUXE', label = 'Luxe' } },
        weapon_assaultrifle = { { component = 'COMPONENT_ASSAULTRIFLE_VARMOD_LUXE', label = 'Luxe' } },
        weapon_advancedrifle = { { component = 'COMPONENT_ADVANCEDRIFLE_VARMOD_LUXE', label = 'Luxe' } },
        weapon_specialcarbine = { { component = 'COMPONENT_SPECIALCARBINE_VARMOD_LOWRIDER', label = 'Lowrider' } },
        weapon_bullpuprifle = { { component = 'COMPONENT_BULLPUPRIFLE_VARMOD_LOW', label = 'Lowrider' } },
        weapon_mg = { { component = 'COMPONENT_MG_VARMOD_LOWRIDER', label = 'Lowrider' } },
        weapon_combatmg = { { component = 'COMPONENT_COMBATMG_VARMOD_LOWRIDER', label = 'Lowrider' } },
        weapon_sniperrifle = { { component = 'COMPONENT_SNIPERRIFLE_VARMOD_LUXE', label = 'Luxe' } },
        weapon_marksmanrifle = { { component = 'COMPONENT_MARKSMANRIFLE_VARMOD_LUXE', label = 'Luxe' } },
        weapon_switchblade = {
            { component = 'COMPONENT_SWITCHBLADE_VARMOD_VAR1', label = 'VIP' },
            { component = 'COMPONENT_SWITCHBLADE_VARMOD_VAR2', label = 'Garde du corps' },
        },
        weapon_knuckle = {
            { component = 'COMPONENT_KNUCKLE_VARMOD_PIMP', label = 'Proxénète' },
            { component = 'COMPONENT_KNUCKLE_VARMOD_BALLAS', label = 'Ballas' },
            { component = 'COMPONENT_KNUCKLE_VARMOD_DOLLAR', label = 'Dollar' },
            { component = 'COMPONENT_KNUCKLE_VARMOD_DIAMOND', label = 'Diamant' },
            { component = 'COMPONENT_KNUCKLE_VARMOD_HATE', label = 'Haine' },
            { component = 'COMPONENT_KNUCKLE_VARMOD_LOVE', label = 'Amour' },
            { component = 'COMPONENT_KNUCKLE_VARMOD_PLAYER', label = 'Joueur' },
            { component = 'COMPONENT_KNUCKLE_VARMOD_KING', label = 'Roi' },
            { component = 'COMPONENT_KNUCKLE_VARMOD_VAGOS', label = 'Vagos' },
        },
    },

    -- Armes Mk II : préfixe de leurs camouflages ; le suffixe et le nom viennent de `camos`
    camoPrefixes = {
        weapon_pistol_mk2 = 'COMPONENT_PISTOL_MK2_CAMO',
        weapon_snspistol_mk2 = 'COMPONENT_SNSPISTOL_MK2_CAMO',
        weapon_revolver_mk2 = 'COMPONENT_REVOLVER_MK2_CAMO',
        weapon_smg_mk2 = 'COMPONENT_SMG_MK2_CAMO',
        weapon_pumpshotgun_mk2 = 'COMPONENT_PUMPSHOTGUN_MK2_CAMO',
        weapon_carbinerifle_mk2 = 'COMPONENT_CARBINERIFLE_MK2_CAMO',
        weapon_assaultrifle_mk2 = 'COMPONENT_ASSAULTRIFLE_MK2_CAMO',
        weapon_specialcarbine_mk2 = 'COMPONENT_SPECIALCARBINE_MK2_CAMO',
        weapon_bullpuprifle_mk2 = 'COMPONENT_BULLPUPRIFLE_MK2_CAMO',
        weapon_combatmg_mk2 = 'COMPONENT_COMBATMG_MK2_CAMO',
        weapon_heavysniper_mk2 = 'COMPONENT_HEAVYSNIPER_MK2_CAMO',
        weapon_marksmanrifle_mk2 = 'COMPONENT_MARKSMANRIFLE_MK2_CAMO',
    },
    camos = {
        { suffix = '', label = 'Numérique' },
        { suffix = '_02', label = 'Coups de pinceau' },
        { suffix = '_03', label = 'Forêt' },
        { suffix = '_04', label = 'Têtes de mort' },
        { suffix = '_05', label = 'Sessanta Nove' },
        { suffix = '_06', label = 'Perseus' },
        { suffix = '_07', label = 'Léopard' },
        { suffix = '_08', label = 'Zèbre' },
        { suffix = '_09', label = 'Géométrique' },
        { suffix = '_10', label = 'Boum !' },
        { suffix = '_IND_01', label = 'Patriote' },
    },
}

for weapon, prefix in pairs(Config.WeaponCustom.camoPrefixes) do
    local list = {}
    for _, camo in ipairs(Config.WeaponCustom.camos) do
        list[#list + 1] = { component = prefix .. camo.suffix, label = camo.label }
    end
    Config.WeaponCustom.finishes[weapon] = list
end
