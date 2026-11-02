-- Parcours de bienvenue du mode PvP : quelques gestes de base, dans n'importe quel ordre, chacun payé une fois.
-- `stat` : étape validée par ce compteur (Config.AchievementStats) ; sans `stat`, validée par le service concerné
-- (voir TutorialService.complete). Textes passés par t(variable) : à ajouter à la main dans locales/.
Config.Tutorial = {
    veteranKills = 50, -- kills + zombies : un joueur d'avant le parcours au-delà de ce total ne le voit pas
    steps = {
        { id = 'class', label = 'Choisis une classe', hint = 'Menu (Verr. Maj) > Classe, en zone safe', money = 200 },
        { id = 'protected', label = 'Range un objet au conteneur protégé', hint = 'Il te reste à la mort, le sac tombe', money = 200 },
        { id = 'npcKill', stat = 'npcKill', label = 'Tue un zombie', hint = 'Dans une zone infestée, repérée sur la carte', money = 200 },
        { id = 'lootCorpse', stat = 'lootCorpse', label = 'Fouille un corps de zombie', hint = 'Approche-toi du corps et appuie sur E', money = 200 },
        { id = 'stash', label = 'Dépose un objet au coffre', hint = 'Parle au banquier, en zone safe', money = 300 },
        { id = 'shop', label = 'Achète à la boutique', hint = 'Parle à l\'armurier, en zone safe', money = 300 },
        { id = 'contracts', stat = 'contracts', label = 'Termine un contrat', hint = 'Parle au recruteur à Legion Square', money = 500 },
        { id = 'team', label = 'Rejoins une équipe', hint = 'Menu Équipe, ou demande une invitation', money = 300 },
        { id = 'playerKill', stat = 'playerKill', label = 'Abats un joueur', hint = 'Hors des zones safe', money = 500 },
    },
    finalReward = { money = 2000, xp = 500 },
}
