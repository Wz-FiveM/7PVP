-- Zones de contrôle (PvP) : reste seul dans le cercle (toi ou ton groupe) pour la capturer.
-- Tant qu'elle t'appartient, elle rapporte de l'argent à toi et à ton groupe, où que vous soyez.
-- Plusieurs camps dans le cercle = zone contestée, la capture est figée.
-- Les hauteurs (z) servent au marqueur : le client le recale sur le sol.
Config.ControlZones = {
    captureTime = 60, -- secondes pour capturer une zone neutre (le double pour une zone ennemie)
    incomeInterval = 120, -- secondes entre deux versements
    blip = { sprite = 543, neutral = 4, mine = 2, enemy = 1 },
    zones = {
        { id = 'quarry', label = 'Carrière de Davis', coords = vector3(2950.0, 2790.0, 41.0), radius = 45.0, income = 150 },
        { id = 'powerplant', label = 'Centrale Palmer-Taylor', coords = vector3(2700.0, 1600.0, 24.5), radius = 45.0, income = 150 },
        { id = 'refinery', label = 'Raffinerie de Murrieta', coords = vector3(1450.0, -2150.0, 60.0), radius = 40.0, income = 200 },
    },
}
