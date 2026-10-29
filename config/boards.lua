-- Classements ELO des modes de jeu du Freeroam (table pvp_activity_ratings, une cote par mode) et
-- tableaux qui les affichent dans la zone safe (écrans DUI posés dans le monde, un par mode).
-- La cote est recalculée à la fin de chaque partie : victoire 1, égalité 0,5, défaite 0 ;
-- quitter une partie en cours compte comme une défaite.
-- CVC (par équipe) : chaque joueur gagne ou perd selon la cote moyenne des deux équipes.
Config.FreeroamBoards = {
    elo = {
        start = 1000, -- cote de départ
        k = 32, -- points en jeu par partie (plus haut = la cote bouge plus vite)
    },
    size = 10, -- joueurs affichés sur chaque tableau
    width = 5.0, -- mètres (la hauteur suit le format de la page : 4/3)
    elevation = 0.6, -- mètres entre le sol et le bas de l'écran
    drawDistance = 60.0, -- mètres : au-delà, l'écran n'est plus dessiné

    -- Un tableau par mode (activity = clé de Config.FreeroamActivities), juste derrière son PNJ.
    -- coords = pied de l'écran, heading = direction vers laquelle il fait face. Déplaçables depuis
    -- le panneau admin (F10, onglet Freeroam, « Positions »).
    boards = {
        { activity = 'chase', coords = vector3(216.4, -944.8, 30.7), heading = 60.0 },
        { activity = 'cvc', coords = vector3(204.1, -922.9, 30.7), heading = 150.0 },
        { activity = 'gunfight', coords = vector3(196.6, -909.6, 30.7), heading = 180.0 },
        { activity = 'bike', coords = vector3(190.0, -911.0, 30.7), heading = 180.0 },
        { activity = 'gungame', coords = vector3(184.0, -912.5, 30.7), heading = 180.0 },
    },
}
