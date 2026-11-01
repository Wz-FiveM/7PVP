-- Chat vocal (voix intégrée à FiveM, Mumble). Les joueurs parlent avec la touche de GTA (N par défaut).
--   PvP, Freeroam, Mêlée générale, Course aux armes : proximité
--   Parties Call of Duty en équipes                 : équipe seulement, à toute distance
--   Battle Royale, Résurgence                       : escouade à toute distance, proximité avec les autres
--   Lobby, menu Call of Duty                        : personne
Config.Voice = {
    range = 12.0, -- m : portée à laquelle la voix porte normalement (s'atténue jusqu'à 3 fois cette distance)
    teamVolume = 0.8, -- volume des coéquipiers, de 0.0 à 1.0
}
