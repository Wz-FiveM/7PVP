-- Décor des zones safe du mode PvP : un coin aménagé autour de chaque PNJ de service
-- (armurerie, atelier d'armes, garage de casse, coffre, vestiaire, atelier, poste du recruteur,
-- étals, planque du receleur, campement de James).
--
-- Les stands ont été composés avec CodeWalker d'après le relevé de la carte de GTA (sol, plafonds,
-- murs et objets autour de chaque PNJ). Les objets sont dans config/safe_decor_props.lua (généré) ;
-- les mêmes stands en ymap, à ouvrir dans CodeWalker, sont dans tools/safe_decor/.
-- Les PNJ (config/npcs.lua et F10 > Positions) ont été placés en même temps que le décor :
-- déplacer un PNJ depuis F10 ne déplace pas son stand.
--
-- Chaque joueur crée les objets en local (rien sur le réseau) quand il approche d'une zone, dans
-- les modes listés ici seulement (la zone de Legion sert aussi de hub au Freeroam).
Config.SafeDecor = {
    enabled = true,
    modes = { pvp = true },
    buildDistance = 200.0, -- distance au centre du décor d'une zone pour le créer (et +50 m pour le retirer)
    perFrame = 10, -- objets créés par image
}
