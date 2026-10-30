-- Personnages du mode Call of Duty : modèles de ped additionnels, accessibles aux VIP (config/vip.lua) ou
-- achetés pour toujours en points boutique (config/shop_points.lua). Sans choix, le joueur garde son personnage.
--
-- id     : identifiant enregistré en base, à ne pas changer une fois en ligne
-- model  : nom du modèle dans la ressource 7PVP_operators (voir son LISEZ-MOI). Un modèle absent du jeu
--          s'affiche « Bientôt disponible », sans pouvoir être acheté ni porté
-- price  : prix en points boutique
-- credit : auteur du modèle, affiché dans le menu
Config.CodOperators = {
    list = {
        -- Call of Duty
        { id = 'ghost_desert', label = 'Ghost Desert', universe = 'Call of Duty', model = 'Ghost_Desert', price = 1000, credit = 'oliver8979' },
        { id = 'ghost_nightwar', label = 'Ghost NightWar', universe = 'Call of Duty', model = 'lee_ghost_nightwar', price = 1200, credit = 'Lee_Costumes' },
        { id = 'price_mw4', label = 'John Price', universe = 'Call of Duty', model = 'ywr_mw4price', price = 1200, credit = 'YourWelshRaptor' },
        { id = 'venerated', label = 'Venerated US Army', universe = 'Call of Duty', model = 'ywr_vet250', price = 1000, credit = 'YourWelshRaptor' },
        { id = 'horangi', label = 'Horangi', universe = 'Call of Duty', model = 'Horangi', price = 1000, credit = 'oliver8979' },
        { id = 'nikto', label = 'Nikto Dark Side', universe = 'Call of Duty', model = 'NiktoDarkSideCODM', price = 1000, credit = 'kritbualad' },
        { id = 'templar', label = 'Templar', universe = 'Call of Duty', model = 'TemplarCODM', price = 1000, credit = 'kritbualad' },
        { id = 'witch_warden', label = 'Witch Warden', universe = 'Call of Duty', model = 'witch_warden', price = 1000, credit = 'oliver8979' },
        -- Marvel
        { id = 'spiderman', label = 'Spider-Man', universe = 'Marvel', model = 'Ada_Spiderman4', price = 1500, credit = 'zio321' },
        { id = 'ultron', label = 'Ultron', universe = 'Marvel', model = 'Ultron_15_Ada', price = 1500, credit = 'zio321' },
        -- Fortnite
        { id = 'black_knight', label = 'Black Knight', universe = 'Fortnite', model = 'knight', price = 1200, credit = 'kazuya4x4' },
        { id = 'drakon', label = 'Silverwing Drakon', universe = 'Fortnite', model = 'silverwing_drakon', price = 1200, credit = 'zio321' },
        -- Autres univers
        { id = 'naruto', label = 'Naruto Akatsuki', universe = 'Naruto', model = 'naruto', price = 1200, credit = 'Kong2545' },
        { id = 'bull', label = 'Bull Comes', universe = 'Original', model = 'Bull_Comes', price = 800, credit = 'NcNc' },
    },
}
