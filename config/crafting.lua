-- Fabrication (menu Verr. Maj > Fabrication, auprès de l'artisan).
-- Les ingrédients sont pris dans le sac puis le conteneur protégé ; le résultat va dans le sac.
-- level : niveau minimum du joueur.
Config.Recipes = {
    { id = 'bandage', result = { item = 'bandage', count = 2 }, ingredients = { mat_cloth = 3 }, level = 1 },
    { id = 'ammo_9mm', result = { item = 'ammo_9mm', count = 24 }, ingredients = { mat_powder = 4, mat_scrap = 1 }, level = 1 },
    { id = 'ammo_45acp', result = { item = 'ammo_45acp', count = 30 }, ingredients = { mat_powder = 6, mat_scrap = 2 }, level = 2 },
    { id = 'ammo_12g', result = { item = 'ammo_12g', count = 8 }, ingredients = { mat_powder = 5, mat_scrap = 2 }, level = 3 },
    { id = 'ammo_556', result = { item = 'ammo_556', count = 30 }, ingredients = { mat_powder = 8, mat_scrap = 3 }, level = 4 },
    { id = 'medkit', result = { item = 'medkit', count = 1 }, ingredients = { mat_cloth = 4, mat_chemicals = 2 }, level = 3 },
    { id = 'armor', result = { item = 'armor', count = 1 }, ingredients = { mat_scrap = 8, mat_cloth = 6 }, level = 5 },
    { id = 'att_flashlight', result = { item = 'att_flashlight', count = 1 }, ingredients = { mat_scrap = 4, mat_chemicals = 1 }, level = 4 },
    { id = 'att_extclip', result = { item = 'att_extclip', count = 1 }, ingredients = { mat_scrap = 10 }, level = 6 },
    { id = 'att_suppressor', result = { item = 'att_suppressor', count = 1 }, ingredients = { mat_scrap = 12, mat_chemicals = 4 }, level = 10 },
}
