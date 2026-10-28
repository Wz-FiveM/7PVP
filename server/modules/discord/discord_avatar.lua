---Avatars Discord des joueurs (cartes d'équipe, menu pause), lus avec le token du bot.
---Le token vient de la convar 7pvp_discord_bot_token (voir config/discord.lua) ; sans elle,
---ou pour un joueur sans Discord ouvert, l'interface garde son icône par défaut.
---@class DiscordAvatarModule
local DiscordAvatar = PVP.define('DiscordAvatar')
local PlayerService = PVP.use('PlayerService')
local GroupService = PVP.use('GroupService')
local Events = PVP.use('Events')
local Logger = PVP.use('Logger')

DiscordAvatar.API = 'https://discord.com/api/v10/users/%s'
DiscordAvatar.CDN = 'https://cdn.discordapp.com/avatars/%s/%s.png?size=128'
-- Compte sans photo : l'un des 6 avatars par défaut de Discord
DiscordAvatar.DEFAULT = 'https://cdn.discordapp.com/embed/avatars/%d.png'

DiscordAvatar.token = ''
---@type table<string, { url: string, at: integer }> id Discord -> avatar connu et son heure (os.time)
DiscordAvatar.cache = {}

function DiscordAvatar.init()
    DiscordAvatar.token = GetConvar(Config.Discord.BotTokenConvar, '')
    if DiscordAvatar.token == '' then
        return Logger.info('Discord : pas de token de bot, avatars désactivés (voir config/discord.lua)')
    end

    AddEventHandler(Events.internal.playerLoaded, function(source)
        DiscordAvatar.fetch(source)
    end)
end

---@param id string id Discord (snowflake)
---@param hash string|nil hash de l'avatar (nil = pas de photo)
---@return string
function DiscordAvatar.url(id, hash)
    if hash then return DiscordAvatar.CDN:format(id, hash) end
    local snowflake = math.tointeger(tonumber(id)) or 0
    return DiscordAvatar.DEFAULT:format((snowflake >> 22) % 6)
end

---Lit l'avatar Discord du joueur et le pousse à son interface et à son équipe.
---@param source integer
function DiscordAvatar.fetch(source)
    local discord = GetPlayerIdentifierByType(source, 'discord')
    if not discord then return end
    local id = discord:gsub('^discord:', '')

    local cached = DiscordAvatar.cache[id]
    if cached and os.time() - cached.at < Config.Discord.AvatarCacheTime then
        return DiscordAvatar.apply(source, cached.url)
    end

    PerformHttpRequest(DiscordAvatar.API:format(id), function(status, body)
        if status ~= 200 then
            return Logger.warn('Discord : avatar de %s introuvable (HTTP %s)', GetPlayerName(source) or id, status)
        end
        local ok, user = pcall(json.decode, body or '')
        if not ok or type(user) ~= 'table' then return end
        local url = DiscordAvatar.url(id, type(user.avatar) == 'string' and user.avatar or nil)
        DiscordAvatar.cache[id] = { url = url, at = os.time() }
        DiscordAvatar.apply(source, url)
    end, 'GET', '', {
        Authorization = 'Bot ' .. DiscordAvatar.token,
        ['User-Agent'] = 'DiscordBot (7PVP, 1.0)', -- format demandé par l'API Discord
    })
end

---@param source integer
---@param url string
function DiscordAvatar.apply(source, url)
    local player = PlayerService.get(source)
    if not player then return end -- parti pendant la requête
    player.avatar = url
    player:sync()
    local group = GroupService.getGroupOf(source)
    if group then GroupService.sync(group) end
end
