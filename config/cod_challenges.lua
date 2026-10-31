-- Call of Duty : défis du jour et de la semaine, les mêmes pour tous les joueurs (tirés au sort par période).
-- Le jour change à minuit UTC, la semaine le lundi à minuit UTC. La progression repart de zéro à chaque nouvelle période.
--   stat   : ce qui est compté (kills, headshots, assists, objective, matches, wins, multikills, knife, streaks)
--   target : nombre à atteindre ; xp : gain dès qu'il est atteint (compte dans le bonus d'XP /codxp)
Config.CodChallenges = {
    daily = {
        count = 3, -- défis tirés chaque jour
        pool = {
            { id = 'd_kills', stat = 'kills', target = 25, xp = 1000, label = 'Élimine 25 ennemis' },
            { id = 'd_headshots', stat = 'headshots', target = 8, xp = 1200, label = 'Réussis 8 tirs à la tête' },
            { id = 'd_assists', stat = 'assists', target = 8, xp = 800, label = 'Obtiens 8 assistances' },
            { id = 'd_objective', stat = 'objective', target = 5, xp = 1200, label = 'Accomplis 5 objectifs (drapeau, point, plaque, bombe)' },
            { id = 'd_matches', stat = 'matches', target = 3, xp = 800, label = 'Termine 3 parties' },
            { id = 'd_wins', stat = 'wins', target = 1, xp = 1000, label = 'Gagne une partie' },
            { id = 'd_multikills', stat = 'multikills', target = 3, xp = 1200, label = 'Réussis 3 doublés ou mieux' },
            { id = 'd_knife', stat = 'knife', target = 2, xp = 1000, label = 'Élimine 2 ennemis au couteau' },
            { id = 'd_streaks', stat = 'streaks', target = 2, xp = 800, label = 'Utilise 2 séries' },
        },
    },
    weekly = {
        count = 3,
        pool = {
            { id = 'w_kills', stat = 'kills', target = 200, xp = 6000, label = 'Élimine 200 ennemis' },
            { id = 'w_headshots', stat = 'headshots', target = 60, xp = 7000, label = 'Réussis 60 tirs à la tête' },
            { id = 'w_assists', stat = 'assists', target = 50, xp = 5000, label = 'Obtiens 50 assistances' },
            { id = 'w_objective', stat = 'objective', target = 40, xp = 7000, label = 'Accomplis 40 objectifs (drapeau, point, plaque, bombe)' },
            { id = 'w_matches', stat = 'matches', target = 15, xp = 5000, label = 'Termine 15 parties' },
            { id = 'w_wins', stat = 'wins', target = 7, xp = 7000, label = 'Gagne 7 parties' },
            { id = 'w_multikills', stat = 'multikills', target = 20, xp = 7000, label = 'Réussis 20 doublés ou mieux' },
            { id = 'w_knife', stat = 'knife', target = 10, xp = 5000, label = 'Élimine 10 ennemis au couteau' },
            { id = 'w_streaks', stat = 'streaks', target = 15, xp = 5000, label = 'Utilise 15 séries' },
        },
    },
}
