-- Décor des zones safe du mode PvP : un coin aménagé autour de chaque PNJ de service
-- (armurerie, atelier d'armes, garage de casse, coffre, vestiaire, atelier, poste du recruteur,
-- étals, planque du receleur, campement de James).
--
-- Le décor est une carte (ymap) par zone, dans stream/safe_decor/, faite avec CodeWalker
-- d'après le relevé de la carte de GTA (sol, plafonds, murs et objets autour de chaque PNJ).
-- Les PNJ (config/npcs.lua) et les points d'apparition (config/zones.lua) ont été placés en
-- même temps que le décor : déplacer un PNJ depuis F10 > Positions ne déplace pas son stand.
--
-- Les ymaps sont chargés par le jeu comme ceux de GTA ; le client les retire hors des modes
-- listés ici (la zone de Legion sert aussi de hub au Freeroam).
Config.SafeDecor = {
    enabled = true,
    modes = { pvp = true },
    -- id de zone (config/zones.lua) -> nom du ymap (sans l'extension)
    ymaps = {
        legion = '7pvp_safe_legion',
        airport = '7pvp_safe_airport',
        sandy = '7pvp_safe_sandy',
        paleto = '7pvp_safe_paleto',
    },
}
