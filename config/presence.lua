-- Discord Rich Presence : ce que les amis Discord d'un joueur voient sous son nom pendant qu'il joue.
-- L'application Discord est celle du bot (D:\7PVP\bot). Pour afficher le logo, l'image doit être
-- envoyée dans le portail développeur Discord : application > Rich Presence > Art Assets,
-- sous le même nom que `largeImage` ci-dessous.
Config.Presence = {
    enabled = true,
    appId = '1564919764814659604', -- ID de l'application Discord (vide = Rich Presence désactivé)
    interval = 15000, -- ms entre deux mises à jour (Discord en ignore de toute façon au-delà de ~1 / 15 s)

    largeImage = 'logo', -- nom de l'Art Asset dans le portail Discord
    largeText = '7PVP · PvP / PvE',

    -- Boutons sous le statut (2 maximum). URL en https:// ou fivem://connect/ uniquement.
    buttons = {
        { label = 'Rejoindre le serveur', url = 'fivem://connect/145.239.149.134:30121' },
    },

    -- Textes du statut
    lobby = 'Dans le lobby',
    pvp = 'PvP',
    pvpFree = 'Zone libre',
    freeroam = 'Freeroam',
    cod = 'Call of Duty',
    dead = 'Mort',
    players = '%d/%d joueurs',
}
