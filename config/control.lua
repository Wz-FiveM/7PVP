-- Zones de contrôle (PvP) : reste seul dans le cercle (toi ou ton groupe) pour la capturer.
-- Tant qu'elle t'appartient, elle rapporte de l'argent à toi et à ton groupe, où que vous soyez.
-- Plusieurs camps dans le cercle = zone contestée, la capture est figée.
-- Territoires (crew = true) : réservés aux crews et gardés en base. Un crew les capture sans adversaire
-- dans le cercle ; n'importe quel autre joueur vivant fige la capture. Ils paient chaque membre
-- connecté en PvP, et restent au crew jusqu'à ce qu'un autre les prenne ou qu'il soit dissous.
-- Les hauteurs (z) servent au marqueur : le client le recale sur le sol.
Config.ControlZones = {
    captureTime = 60, -- secondes pour capturer une zone neutre (le double pour une zone ennemie)
    incomeInterval = 120, -- secondes entre deux versements
    blip = { sprite = 543, neutral = 4, mine = 2, enemy = 1 },
    territories = {
        captureTime = 180, -- secondes pour capturer un territoire libre (le double s'il a un propriétaire)
        incomeInterval = 300, -- secondes entre deux versements
        protection = 900, -- secondes sans capture possible après une prise
        maxPerCrew = 2,
        alertDelay = 120, -- secondes entre deux alertes « territoire attaqué » au crew propriétaire
        sprite = 38,
    },
    zones = {
        { id = 'quarry', label = 'Carrière de Davis', coords = vector3(2950.0, 2790.0, 41.0), radius = 90.0, income = 150 },
        { id = 'powerplant', label = 'Centrale Palmer-Taylor', coords = vector3(2700.0, 1600.0, 24.5), radius = 90.0, income = 150 },
        { id = 'refinery', label = 'Raffinerie de Murrieta', coords = vector3(1450.0, -2150.0, 60.0), radius = 80.0, income = 200 },
        { id = 'casino', crew = true, label = 'Casino Diamond', coords = vector3(925.0, 45.0, 81.0), radius = 100.0, income = 500 },
        { id = 'del_perro', crew = true, label = 'Jetée de Del Perro', coords = vector3(-1690.0, -1110.0, 13.2), radius = 100.0, income = 500 },
        { id = 'sawmill', crew = true, label = 'Scierie de Paleto', coords = vector3(-570.0, 5330.0, 71.0), radius = 100.0, income = 500 },
        { id = 'zancudo', crew = true, label = 'Fort Zancudo', coords = vector3(-2110.0, 3130.0, 33.0), radius = 100.0, income = 500 },
    },
}
