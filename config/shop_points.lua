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
