-- Signalement d'un joueur : /signaler ID raison, ou menu d'interaction. Le rapport part sur le salon
-- Discord des sanctions avec les preuves gardées par le serveur (derniers kills, alertes anti-triche).
Config.Reports = {
    channel = 'sanctions',
    cooldown = 120, -- secondes entre deux signalements d'un même joueur
    targetCooldown = 900, -- secondes avant de signaler à nouveau la même personne
    reasonMinLength = 3,
    reasonMaxLength = 120,
    killHistory = 8, -- kills gardés par joueur, depuis sa connexion
    alertHistory = 8, -- alertes anti-triche gardées par joueur, depuis sa connexion
    -- Raisons du menu d'interaction. Passent par t(variable) : à ajouter à la main dans locales/.
    reasons = { 'Triche', 'Insultes', 'Anti-jeu' },
}
