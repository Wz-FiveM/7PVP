-- Hauts faits du mode PvP : objectifs permanents, récompense versée dès que l'objectif est atteint.
-- stat : compteur suivi (Config.AchievementStats), goal : valeur à atteindre.
-- title = true : le nom du haut fait devient un titre, à choisir dans le menu Hauts faits.
-- Aucun haut fait ne donne d'avantage en combat.
-- Les textes passent par t(variable) : à ajouter à la main dans locales/ (voir tools/locales.js).

-- Texte de chaque compteur. max = true : garde la meilleure valeur au lieu d'additionner.
Config.AchievementStats = {
    playerKill = { text = 'Tue {goal} joueurs' },
    headshots = { text = 'Fais {goal} kills en pleine tête' },
    assists = { text = 'Fais {goal} assistances' },
    bestStreak = { text = 'Enchaîne {goal} kills sans mourir', max = true },
    bounties = { text = 'Encaisse {goal} primes' },
    revenges = { text = 'Venge-toi {goal} fois' },
    nemeses = { text = 'Abats {goal} némésis' },
    longShot = { text = 'Tue un joueur à {goal} m ou plus', max = true },
    npcKill = { text = 'Tue {goal} zombies' },
    lootCorpse = { text = 'Fouille {goal} corps de zombies' },
    lootAirdrop = { text = 'Fouille {goal} largages' },
    craft = { text = 'Fabrique {goal} objets' },
    hordeSurvive = { text = 'Repousse {goal} hordes' },
    contracts = { text = 'Termine {goal} contrats' },
    captures = { text = 'Prends {goal} territoires avec ton crew' },
    conflictWins = { text = 'Gagne {goal} zones de conflit' },
}

Config.Achievements = {
    { id = 'kills_1', label = 'Premier sang', stat = 'playerKill', goal = 1, reward = { money = 200, xp = 50 } },
    { id = 'kills_50', label = 'Chasseur', stat = 'playerKill', goal = 50, reward = { money = 1000, xp = 300 }, title = true },
    { id = 'kills_250', label = 'Prédateur', stat = 'playerKill', goal = 250, reward = { money = 5000, xp = 1000 }, title = true },
    { id = 'kills_1000', label = 'Légende du PvP', stat = 'playerKill', goal = 1000, reward = { money = 20000, xp = 5000 }, title = true },
    { id = 'head_25', label = 'Tireur précis', stat = 'headshots', goal = 25, reward = { money = 1000, xp = 250 } },
    { id = 'head_200', label = 'Œil de lynx', stat = 'headshots', goal = 200, reward = { money = 6000, xp = 1200 }, title = true },
    { id = 'assist_50', label = 'Bon équipier', stat = 'assists', goal = 50, reward = { money = 1000, xp = 300 } },
    { id = 'assist_300', label = 'Frère d\'armes', stat = 'assists', goal = 300, reward = { money = 6000, xp = 1200 }, title = true },
    { id = 'streak_5', label = 'En série', stat = 'bestStreak', goal = 5, reward = { money = 500, xp = 150 } },
    { id = 'streak_15', label = 'Intouchable', stat = 'bestStreak', goal = 15, reward = { money = 5000, xp = 1000 }, title = true },
    { id = 'bounty_5', label = 'Chasseur de primes', stat = 'bounties', goal = 5, reward = { money = 1500, xp = 400 }, title = true },
    { id = 'revenge_10', label = 'Rancunier', stat = 'revenges', goal = 10, reward = { money = 1000, xp = 300 } },
    { id = 'nemesis_3', label = 'Justicier', stat = 'nemeses', goal = 3, reward = { money = 1500, xp = 400 }, title = true },
    { id = 'long_200', label = 'Longue portée', stat = 'longShot', goal = 200, reward = { money = 1500, xp = 400 }, title = true },
    { id = 'zombies_100', label = 'Nettoyeur', stat = 'npcKill', goal = 100, reward = { money = 500, xp = 200 } },
    { id = 'zombies_1000', label = 'Fléau des morts', stat = 'npcKill', goal = 1000, reward = { money = 5000, xp = 1500 }, title = true },
    { id = 'loot_100', label = 'Charognard', stat = 'lootCorpse', goal = 100, reward = { money = 800, xp = 250 } },
    { id = 'air_10', label = 'Pilleur du ciel', stat = 'lootAirdrop', goal = 10, reward = { money = 2000, xp = 500 }, title = true },
    { id = 'craft_50', label = 'Bricoleur', stat = 'craft', goal = 50, reward = { money = 800, xp = 250 } },
    { id = 'horde_10', label = 'Rempart', stat = 'hordeSurvive', goal = 10, reward = { money = 2000, xp = 500 }, title = true },
    { id = 'contracts_30', label = 'Mercenaire fidèle', stat = 'contracts', goal = 30, reward = { money = 3000, xp = 800 }, title = true },
    { id = 'capture_5', label = 'Conquérant', stat = 'captures', goal = 5, reward = { money = 2000, xp = 500 }, title = true },
    { id = 'conflict_5', label = 'Roi de la zone', stat = 'conflictWins', goal = 5, reward = { money = 3000, xp = 800 }, title = true },
}
