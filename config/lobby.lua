Config.Lobby = {}

-- Vue affichée derrière l'écran du lobby (le joueur est caché et isolé dans son propre bucket)
Config.Lobby.Camera = {
    coords = vector3(-70.0, -1100.0, 210.0),
    pointAt = vector3(-180.0, -760.0, 160.0),
    fov = 55.0,
}

-- Modes proposés à l'arrivée. bucket = bucket de routage du mode : les joueurs de modes
-- différents ne se voient pas. enabled = false : affiché comme « bientôt disponible ».
Config.Lobby.Modes = {
    {
        id = 'pvp',
        label = 'PvP',
        tagline = 'Survie & butin',
        description = 'Zones PvE, combats entre joueurs, inventaire perdu à la mort. Protège ce qui compte.',
        bucket = 0,
        enabled = true,
    },
    {
        id = 'freeroam',
        label = 'Freeroam',
        tagline = 'Liberté totale',
        description = 'Bac à sable : armes et véhicules gratuits (Verr. Maj), PvP désactivé par défaut, aucune perte.',
        bucket = 2,
        enabled = true,
    },
}
