-- À terre et réanimation (PvP) : un joueur tué à portée d'un allié (équipe ou crew) reste à terre au lieu de
-- mourir. Un allié peut le relever ; un ennemi peut l'achever ; sinon il meurt à la fin du temps.
-- Sans allié assez près, ou en véhicule, la mort reste immédiate.
Config.Downed = {
    enabled = true,
    duration = 20, -- secondes à terre
    allyRange = 150.0, -- mètres : au moins un allié vivant à cette distance
    health = 30, -- points de vie à terre, au-dessus du seuil de mort de GTA (100)
    reviveTime = 5, -- secondes à maintenir E
    reviveDistance = 2.5, -- mètres
    reviveHealth = 50, -- points de vie après avoir été relevé, au-dessus du seuil de mort
    cooldown = 60, -- secondes avant de pouvoir être à terre à nouveau
    reviveReward = 100, -- argent pour celui qui relève
}
