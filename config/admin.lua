Config.Admin = {}

-- Donner les droits depuis la console du serveur (colonne is_admin en base, gardé au redémarrage) :
--   setadmin <id du joueur>      ou   setadmin license:xxxx   (même hors ligne)
--   removeadmin <id | license:xxxx>
--   admins                       liste des admins enregistrés
--
-- Optionnel : cette permission ACE rend aussi admin (server.cfg : add_ace group.admin 7pvp.admin allow)
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
