-- Place de marché entre joueurs (PNJ « commissaire-priseur » de la zone safe, voir config/npcs.lua).
-- On met en vente des objets portés (sac ou conteneur protégé) : ils quittent l'inventaire
-- jusqu'à la vente ou au retrait. L'argent des ventes est versé sur un solde à récupérer
-- auprès du commissaire-priseur, même si le vendeur n'était pas connecté.
Config.Market = {
    fee = 0.05, -- taxe prélevée sur chaque vente (5 %)
    maxListings = 10, -- annonces actives par joueur
    maxPrice = 10000000,
    -- Objets interdits à la vente
    blocked = { money = true },
}
