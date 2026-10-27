Config.Appearance = {}

-- Salle où le joueur crée son personnage (isolé des autres joueurs par un bucket de routage)
Config.Appearance.CreatorLocation = vector4(402.86, -996.75, -99.0, 180.0)

-- Tenue de départ selon le sexe : { drawable, texture } par élément.
-- Les numéros dépendent des vêtements GTA : ajuste-les en jeu dans le créateur.
Config.Appearance.DefaultOutfits = {
    male = {
        top = { 0, 0 },
        undershirt = { 15, 0 },
        arms = { 0, 0 },
        legs = { 0, 0 },
        shoes = { 1, 0 },
    },
    female = {
        top = { 0, 0 },
        undershirt = { 15, 0 },
        arms = { 0, 0 },
        legs = { 0, 0 },
        shoes = { 1, 0 },
    },
}

-- Coiffure de départ selon le sexe
Config.Appearance.DefaultHair = { male = 4, female = 4 }
