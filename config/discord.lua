Config.Discord = {}

-- Les URLs des webhooks ne sont pas ici : ce sont des convars serveur, générées par le bot
-- (D:\7PVP\bot, `npm run setup`) dans bot/data/webhooks.cfg. Dans server.cfg, avant `ensure 7PVP` :
--   exec bot/data/webhooks.cfg
-- Convars lues : 7pvp_discord_killfeed, _sanctions, _connexions, _admin, _chat (une absente = salon désactivé)
Config.Discord.ConvarPrefix = '7pvp_discord_'

-- Avatars Discord des joueurs (cartes d'équipe, menu pause) : token du bot (bot/.env, DISCORD_TOKEN).
-- Dans server.cfg, avec `set` (jamais `setr`, qui l'enverrait aux joueurs) :
--   set 7pvp_discord_bot_token "le_token"
Config.Discord.BotTokenConvar = '7pvp_discord_bot_token'

-- Durée en secondes pendant laquelle un avatar lu est réutilisé (reconnexions)
Config.Discord.AvatarCacheTime = 3600

-- Délai entre deux envois vers un même salon, en ms. Les messages en attente sont regroupés
-- (10 par envoi) pour rester sous la limite de Discord (~5 requêtes / 2 s par webhook).
Config.Discord.FlushInterval = 2000

-- Messages gardés en attente au maximum par salon (les plus anciens sont abandonnés au-delà)
Config.Discord.MaxQueue = 200

-- Killfeed : aussi les morts sans tueur (zombies, chutes, véhicules) ? Bavard en zone PvE.
Config.Discord.KillfeedDeaths = false
