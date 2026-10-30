-- VIP : statut à durée limitée, accordé par Tebex ou un admin. Gardé en base à part de l'inventaire
-- (table pvp_vip), il court aussi quand le joueur est hors ligne. Ce qu'il débloque est décidé par
-- chaque système : pour l'instant, tous les personnages du mode Call of Duty (config/cod_operators.lua).
--
-- Crédit depuis Tebex : commande serveur exécutée par le plugin Tebex (joueur en ligne requis)
--     addvip {sid} 30 {transaction}
-- La référence ({transaction}) empêche de créditer deux fois le même paiement.
-- Remboursement / rétrofacturation : removevip {sid}
Config.Vip = {
    maxDays = 36500, -- garde-fou : durée maximum d'un addvip (100 ans = à vie)
}
