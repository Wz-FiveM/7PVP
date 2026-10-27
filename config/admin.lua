Config.Admin = {}

-- Permission ACE requise pour toutes les actions admin (vérifiée côté serveur).
-- Dans server.cfg :
--   add_ace group.admin 7pvp.admin allow
--   add_principal identifier.license:XXXXXXXX group.admin
Config.Admin.Ace = '7pvp.admin'

Config.Admin.Key = 'F10' -- ouvrir le panneau
Config.Admin.NoclipKey = 'F11' -- activer / couper le noclip

-- Noclip : vitesse en m/s (Maj = rapide, Alt = lent)
Config.Admin.NoclipSpeed = 12.0
Config.Admin.NoclipFastMultiplier = 4.0
Config.Admin.NoclipSlowMultiplier = 0.25

-- Limites des dons
Config.Admin.MaxGiveCount = 10000
Config.Admin.MaxGiveMoney = 10000000
