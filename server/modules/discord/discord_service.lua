---Logs vers le Discord de 7PVP par webhooks : killfeed, connexions, actions admin, sanctions, chat.
---Les URLs viennent des convars 7pvp_discord_<salon> (voir config/discord.lua) ; un salon sans
---convar est simplement ignoré. Les messages sont mis en file et regroupés par salon pour
---respecter la limite d'envoi de Discord.
---@class DiscordServiceModule
local DiscordService = PVP.define('DiscordService')
local ModeRegistry = PVP.use('ModeRegistry')
local Logger = PVP.use('Logger')

DiscordService.CHANNELS = { 'killfeed', 'sanctions', 'connexions', 'admin', 'chat' }

-- Couleurs de l'interface (web/src/styles/global.css)
DiscordService.COLORS = {
    hazard = 0xff6b1a,
    toxine = 0xb5f23d,
    critique = 0xffd84a,
    danger = 0xe5383b,
    brume = 0x8c969b,
}

DiscordService.ADMIN_LABELS = {
    lootConfig = 'Butin modifié',
    freeroamConfig = 'Réglages du Freeroam modifiés',
    spectate = 'Mode spectateur',
    spectateStop = 'Fin du mode spectateur',
    giveItem = 'Don d\'objet',
    giveMoney = 'Don d\'argent',
    heal = 'Soin',
    revive = 'Réanimation',
    kill = 'Mise à mort',
    freeze = 'Gel',
    gotoPlayer = 'Téléportation sur un joueur',
    bringPlayer = 'Joueur ramené',
    sendToLobby = 'Renvoi au lobby',
    kick = 'Expulsion',
    announce = 'Annonce',
    clearLoot = 'Nettoyage du butin',
    airdrop = 'Largage',
    horde = 'Horde',
}

-- Limites Discord : 10 embeds et 2000 caractères de texte par message
DiscordService.MAX_EMBEDS = 10
DiscordService.MAX_CONTENT = 2000

---@type table<string, string> salon -> URL du webhook
DiscordService.webhooks = {}
---@type table<string, { embeds: table[], lines: string[] }>
DiscordService.queues = {}
---@type table<string, integer> salon -> GetGameTimer avant lequel ne rien envoyer (limite atteinte)
DiscordService.retryAt = {}
---@type table<string, boolean> requête en cours par salon
DiscordService.sending = {}
---@type table<integer, integer> heure de connexion (os.time) par joueur
DiscordService.joinedAt = {}

function DiscordService.init()
    local count = 0
    for _, channel in ipairs(DiscordService.CHANNELS) do
        local url = GetConvar(Config.Discord.ConvarPrefix .. channel, '')
        if url ~= '' then
            DiscordService.webhooks[channel] = url
            DiscordService.queues[channel] = { embeds = {}, lines = {} }
            count = count + 1
        end
    end

    if count == 0 then
        return Logger.info('Discord : aucun webhook configuré (voir config/discord.lua)')
    end
    Logger.info('Discord : %d salon(s) relié(s)', count)

    AddEventHandler('playerJoining', function()
        DiscordService.onJoining(source)
    end)
    AddEventHandler('playerDropped', function(reason)
        DiscordService.onDropped(source, reason)
    end)

    CreateThread(DiscordService.flushLoop)
end

-- ---------------------------------------------------------------------------
-- File d'envoi
-- ---------------------------------------------------------------------------

---Neutralise la mise en forme Discord et les mentions (@everyone) d'un texte venant d'un joueur.
---@param text any
---@return string
function DiscordService.escape(text)
    local escaped = tostring(text or ''):gsub('([\\*_~`|>])', '\\%1'):gsub('@', '@\u{200B}')
    return escaped
end

---@param channel string
---@param embed table
function DiscordService.send(channel, embed)
    local queue = DiscordService.queues[channel]
    if not queue then return end
    embed.color = embed.color or DiscordService.COLORS.brume
    embed.timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    queue.embeds[#queue.embeds + 1] = embed
    if #queue.embeds > Config.Discord.MaxQueue then table.remove(queue.embeds, 1) end
end

---Ligne de texte simple, regroupée avec les suivantes dans un même message (chat).
---@param channel string
---@param line string
function DiscordService.sendLine(channel, line)
    local queue = DiscordService.queues[channel]
    if not queue then return end
    queue.lines[#queue.lines + 1] = line:sub(1, DiscordService.MAX_CONTENT - 100)
    if #queue.lines > Config.Discord.MaxQueue then table.remove(queue.lines, 1) end
end

function DiscordService.flushLoop()
    while true do
        Wait(Config.Discord.FlushInterval)
        for channel in pairs(DiscordService.webhooks) do
            DiscordService.flush(channel)
        end
    end
end

---Envoie d'un coup le début de la file d'un salon (10 embeds et/ou 2000 caractères de lignes).
---@param channel string
function DiscordService.flush(channel)
    local queue = DiscordService.queues[channel]
    if #queue.embeds == 0 and #queue.lines == 0 then return end
    if DiscordService.sending[channel] or GetGameTimer() < (DiscordService.retryAt[channel] or 0) then return end

    local embeds = {}
    while #embeds < DiscordService.MAX_EMBEDS and #queue.embeds > 0 do
        embeds[#embeds + 1] = table.remove(queue.embeds, 1)
    end
    local lines, length = {}, 0
    while #queue.lines > 0 and length + #queue.lines[1] + 1 <= DiscordService.MAX_CONTENT do
        local line = table.remove(queue.lines, 1)
        lines[#lines + 1] = line
        length = length + #line + 1
    end

    local payload = {
        content = #lines > 0 and table.concat(lines, '\n') or nil,
        embeds = #embeds > 0 and embeds or nil,
    }

    DiscordService.sending[channel] = true
    PerformHttpRequest(DiscordService.webhooks[channel], function(status, body)
        DiscordService.sending[channel] = false
        if status == 429 then
            -- Limite atteinte : on remet le lot en tête de file et on attend le délai demandé
            local ok, data = pcall(json.decode, body or '')
            local wait = ok and type(data) == 'table' and tonumber(data.retry_after) or 2
            DiscordService.retryAt[channel] = GetGameTimer() + math.ceil(wait * 1000)
            for i = #embeds, 1, -1 do table.insert(queue.embeds, 1, embeds[i]) end
            for i = #lines, 1, -1 do table.insert(queue.lines, 1, lines[i]) end
        elseif status < 200 or status >= 300 then
            Logger.warn('Discord : envoi vers #%s refusé (HTTP %s) %s', channel, status, body or '')
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

-- ---------------------------------------------------------------------------
-- Mise en forme
-- ---------------------------------------------------------------------------

---« **Pseudo** (ID 3) · @discord », ou « console » pour la console du serveur.
---@param source integer
---@param name? string nom connu si le joueur est déjà en train de partir
---@return string
function DiscordService.playerTag(source, name)
    if source == 0 then return 'console' end
    local tag = ('**%s** (ID %s)'):format(DiscordService.escape(name or GetPlayerName(source) or '?'), source)
    local discord = GetPlayerIdentifierByType(source, 'discord')
    if discord then
        tag = ('%s · <@%s>'):format(tag, (discord:gsub('^discord:', '')))
    end
    return tag
end

---@param seconds integer
---@return string
function DiscordService.formatDuration(seconds)
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return ('%d min'):format(minutes) end
    return ('%d h %02d'):format(minutes // 60, minutes % 60)
end

-- ---------------------------------------------------------------------------
-- Événements envoyés
-- ---------------------------------------------------------------------------

---@param killerName string|nil
---@param victimName string
---@param reason? 'disconnect'
---@param recap? table récapitulatif de mort (CombatService.buildRecap)
function DiscordService.killfeed(killerName, victimName, reason, recap)
    local killer, victim = DiscordService.escape(killerName), DiscordService.escape(victimName)
    local description, color

    if reason == 'disconnect' then
        description = killerName
            and ('💨 **%s** s\'est déconnecté en combat · kill pour **%s**'):format(victim, killer)
            or ('💨 **%s** s\'est déconnecté en combat'):format(victim)
        color = DiscordService.COLORS.critique
    elseif killerName then
        local details = {}
        if recap and recap.weapon then details[#details + 1] = recap.weapon end
        if recap and recap.distance then details[#details + 1] = ('%d m'):format(recap.distance) end
        description = ('🔫 **%s** a tué **%s**'):format(killer, victim)
        if #details > 0 then description = description .. '\n' .. table.concat(details, ' · ') end
        color = DiscordService.COLORS.hazard
    elseif Config.Discord.KillfeedDeaths then
        local cause = recap and (recap.zombie and 'tué par un zombie' or recap.weapon and ('mort (%s)'):format(recap.weapon)) or 'mort'
        description = ('☠️ **%s** %s'):format(victim, cause)
    else
        return
    end

    DiscordService.send('killfeed', { description = description, color = color })
end

---@param source integer
function DiscordService.onJoining(source)
    DiscordService.joinedAt[source] = os.time()
    DiscordService.send('connexions', {
        description = ('📥 %s a rejoint le serveur\nLicence : `%s`'):format(
            DiscordService.playerTag(source), GetPlayerIdentifierByType(source, 'license') or '?'),
        color = DiscordService.COLORS.toxine,
        footer = { text = ('%d joueur(s) en ligne'):format(#GetPlayers()) },
    })
end

---@param source integer
---@param reason string|nil
function DiscordService.onDropped(source, reason)
    local joinedAt = DiscordService.joinedAt[source]
    DiscordService.joinedAt[source] = nil
    local session = joinedAt and (' · %s de jeu'):format(DiscordService.formatDuration(os.time() - joinedAt)) or ''
    DiscordService.send('connexions', {
        description = ('📤 %s a quitté le serveur%s\nRaison : %s'):format(
            DiscordService.playerTag(source), session, DiscordService.escape(reason or 'inconnue')),
    })
end

---Action du panneau admin réussie (AdminService.handleAction).
---@param source integer admin
---@param action string
---@param target PvpPlayer|nil
---@param data table
---@param message string|nil
function DiscordService.adminAction(source, action, target, data, message)
    local fields = { { name = 'Admin', value = DiscordService.playerTag(source), inline = true } }
    if target then
        fields[#fields + 1] = { name = 'Cible', value = DiscordService.playerTag(target.source, target.name), inline = true }
    end
    if action == 'announce' and type(data.text) == 'string' then
        fields[#fields + 1] = { name = 'Message', value = DiscordService.escape(data.text):sub(1, 1000) }
    end

    DiscordService.send('admin', {
        title = '🛠️ ' .. (DiscordService.ADMIN_LABELS[action] or action),
        description = message and DiscordService.escape(message) or nil,
        color = DiscordService.COLORS.hazard,
        fields = fields,
    })

    if action == 'kick' and target then
        local reason = type(data.reason) == 'string' and data.reason:sub(1, 120) or ''
        DiscordService.sanction('Expulsion', source, target, reason ~= '' and reason or 'Aucune raison')
    end
end

---Tentative d'action admin sans en avoir les droits.
---@param source integer
function DiscordService.adminDenied(source)
    DiscordService.send('admin', {
        title = '🚫 Action admin refusée',
        description = ('%s a tenté une action admin sans en avoir les droits.'):format(DiscordService.playerTag(source)),
        color = DiscordService.COLORS.danger,
    })
end

---setadmin / removeadmin
---@param source integer 0 = console
---@param command string
---@param label string joueur ciblé (nom ou licence)
function DiscordService.adminCommand(source, command, label)
    DiscordService.send('admin', {
        title = command == 'setadmin' and '🔑 Droits admin donnés' or '🔒 Droits admin retirés',
        description = ('**%s** par %s'):format(DiscordService.escape(label), DiscordService.playerTag(source)),
        color = DiscordService.COLORS.critique,
    })
end

---addpoints / removepoints (achats Tebex compris : exécutés depuis la console)
---@param source integer 0 = console
---@param label string joueur ciblé (nom ou licence)
---@param amount integer négatif pour un retrait
---@param reference string|nil référence du paiement
function DiscordService.shopPoints(source, label, amount, reference)
    DiscordService.send('admin', {
        title = amount > 0 and '💎 Points boutique crédités' or '💎 Points boutique retirés',
        description = ('**%s** : %+d par %s%s'):format(
            DiscordService.escape(label), amount, DiscordService.playerTag(source),
            reference and (' (réf. `%s`)'):format(DiscordService.escape(reference)) or ''
        ),
        color = amount > 0 and DiscordService.COLORS.toxine or DiscordService.COLORS.danger,
    })
end

---@param kind string ex : « Expulsion »
---@param source integer admin (0 = console)
---@param target PvpPlayer
---@param reason string
function DiscordService.sanction(kind, source, target, reason)
    DiscordService.send('sanctions', {
        title = '⛔ ' .. kind,
        color = DiscordService.COLORS.danger,
        fields = {
            { name = 'Joueur', value = ('%s\n`%s`'):format(DiscordService.playerTag(target.source, target.name), target.identifier) },
            { name = 'Par', value = DiscordService.playerTag(source), inline = true },
            { name = 'Raison', value = DiscordService.escape(reason), inline = true },
        },
    })
end

---@param player PvpPlayer
---@param text string message déjà nettoyé (ChatService.sanitize)
function DiscordService.chat(player, text)
    local mode = ModeRegistry.getConfig(player.mode)
    DiscordService.sendLine('chat', ('`%s` **%s** : %s'):format(
        mode and mode.label or player.mode, DiscordService.escape(player.name), DiscordService.escape(text)))
end
