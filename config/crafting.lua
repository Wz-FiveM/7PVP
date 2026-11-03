-- Fabrication (menu Tab > Fabrication, auprès de l'artisan).
-- Les ingrédients sont pris dans le sac puis le conteneur protégé ; le résultat va dans le sac.
-- level : niveau minimum du joueur.
Config.Recipes = {
    { id = 'bandage', result = { item = 'bandage', count = 2 }, ingredients = { mat_cloth = 3 }, level = 1 },
    { id = 'mag_9mm', result = { item = 'mag_9mm', count = 2 }, ingredients = { mat_powder = 4, mat_scrap = 1 }, level = 1 },
    { id = 'mag_45acp', result = { item = 'mag_45acp', count = 1 }, ingredients = { mat_powder = 6, mat_scrap = 2 }, level = 2 },
    { id = 'mag_12g', result = { item = 'mag_12g', count = 1 }, ingredients = { mat_powder = 5, mat_scrap = 2 }, level = 3 },
    { id = 'mag_556', result = { item = 'mag_556', count = 1 }, ingredients = { mat_powder = 8, mat_scrap = 3 }, level = 4 },
    { id = 'medkit', result = { item = 'medkit', count = 1 }, ingredients = { mat_cloth = 4, mat_chemicals = 2 }, level = 3 },
    { id = 'armor', result = { item = 'armor', count = 1 }, ingredients = { mat_scrap = 8, mat_cloth = 6 }, level = 5 },
}
