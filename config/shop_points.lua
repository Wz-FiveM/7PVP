-- Points boutique : monnaie premium achetée sur la boutique en ligne (Tebex), dépensée en jeu
-- (caisses...). Le solde est gardé en base à part de l'inventaire (table pvp_shop_points) :
-- il n'est jamais perdu à la mort, ni échangeable, ni lâché au sol.
--
-- Crédit depuis Tebex : commande serveur exécutée par le plugin Tebex (joueur en ligne requis)
--     addpoints {sid} 1000 {transaction}
-- La référence ({transaction}) empêche de créditer deux fois le même paiement.
-- Remboursement / rétrofacturation : removepoints {sid} 1000 (le solde ne descend pas sous 0).
Config.ShopPoints = {
    label = 'Points boutique',
    short = 'PB', -- abréviation affichée sur les boutons
    storeUrl = '', -- lien de la boutique Tebex affiché dans le menu (vide = masqué)
    maxPerCommand = 1000000, -- garde-fou : montant maximum d'un addpoints / removepoints
}

-- Message de kill (menu Profil, en PvP) : acheté pour toujours, le texte se change sans payer.
-- Le message du tueur s'affiche sur l'écran de mort de sa victime.
Config.KillMessage = {
    price = 500, -- points, plus de 0
    maxLength = 60, -- caractères, 80 au plus (taille de la colonne)
}

-- Fonds du killfeed (menu Profil, en PvP) : achetés pour toujours en points boutique.
-- Le fond du tueur s'affiche sur la ligne de son kill, pour tous les joueurs du mode.
-- id : gardé en base (16 caractères au plus). price : prix en points, plus de 0.
-- css : valeur de la propriété CSS background de la ligne, à garder translucide.
Config.KillfeedBackgrounds = {
    -- Unis
    { id = 'nuit', label = 'Bleu nuit', price = 200, css = 'rgba(28, 62, 130, 0.5)' },
    { id = 'bordeaux', label = 'Bordeaux', price = 200, css = 'rgba(105, 22, 40, 0.55)' },
    { id = 'kaki', label = 'Kaki', price = 200, css = 'rgba(66, 84, 40, 0.55)' },
    { id = 'violet', label = 'Violet', price = 200, css = 'rgba(82, 44, 135, 0.5)' },
    -- Dégradés
    { id = 'braise', label = 'Braise', price = 400, css = 'linear-gradient(90deg, rgba(190, 60, 20, 0.6), rgba(90, 20, 15, 0.45))' },
    { id = 'ocean', label = 'Océan', price = 400, css = 'linear-gradient(90deg, rgba(15, 130, 160, 0.55), rgba(20, 45, 110, 0.5))' },
    { id = 'neon', label = 'Néon', price = 400, css = 'linear-gradient(90deg, rgba(190, 30, 130, 0.55), rgba(80, 40, 170, 0.5))' },
    -- Prestige
    { id = 'or', label = 'Or', price = 750, css = 'linear-gradient(90deg, rgba(190, 140, 30, 0.65), rgba(95, 65, 15, 0.5))' },
    { id = 'carbone', label = 'Carbone', price = 750, css = 'repeating-linear-gradient(135deg, rgba(55, 58, 62, 0.65) 0 0.25rem, rgba(15, 16, 18, 0.65) 0.25rem 0.5rem)' },
}
