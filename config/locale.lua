-- Langues de l'interface et des messages. Le français est la langue d'origine : chaque texte
-- français sert de clé dans locales/<langue>.json (« texte français » -> traduction).
-- Un texte absent d'un fichier reste affiché en français.
-- Chaque joueur choisit sa langue (menu pause, lobby ou /langue) ; le choix est gardé sur son PC.
Config.Locale = {
    default = 'fr',
    -- Première connexion : langue de GTA V si elle fait partie de la liste (sinon `default`)
    detectGameLanguage = true,

    -- Ordre d'affichage dans le sélecteur ; `label` est écrit dans la langue elle-même
    languages = {
        { id = 'fr', label = 'Français' },
        { id = 'en', label = 'English' },
        { id = 'es', label = 'Español' },
        { id = 'de', label = 'Deutsch' },
        { id = 'it', label = 'Italiano' },
        { id = 'pt', label = 'Português' },
    },
}
