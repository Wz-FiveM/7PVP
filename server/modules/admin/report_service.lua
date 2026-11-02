---Signalements entre joueurs (Config.Reports) : le rapport part sur Discord et reste en base (pvp_reports),
---avec ce que le serveur a vu du joueur signalé : derniers kills et alertes anti-triche depuis sa connexion.
---Les preuves viennent du serveur : celui qui signale ne donne qu'une raison.
---@class ReportServiceModule
local ReportService = PVP.define('ReportService')
local PlayerService = PVP.use('PlayerService')
local AdminService = PVP.use('AdminService')
local DiscordService = PVP.use('DiscordService')
local ChatService = PVP.use('ChatService')
local Callback = PVP.use('Callback')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

ReportService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_reports (
    id INT NOT NULL AUTO_INCREMENT,
    reporter VARCHAR(64) NOT NULL,
    reporter_name VARCHAR(64) NOT NULL,
    target VARCHAR(64) NOT NULL,
    target_name VARCHAR(64) NOT NULL,
    reason VARCHAR(255) NOT NULL,
    evidence TEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_reports_target (target)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

---@type table<string, table[]> licence -> derniers kills, du plus récent au plus ancien
ReportService.kills = {}
---@type table<string, table[]> licence -> dernières alertes anti-triche
ReportService.alerts = {}
---@type table<string, integer> licence -> os.time() de son dernier signalement
ReportService.lastReport = {}
---@type table<string, integer> 'licence:licence' -> os.time() du dernier signalement de cette personne
ReportService.lastTarget = {}

function ReportService.init()
    MySQL.ready(function() MySQL.query.await(ReportService.SCHEMA) end)
    Callback.register(Events.callbacks.reportPlayer, ReportService.report)
    AddEventHandler(Events.internal.playerUnloading, function(source)
        local player = PlayerService.get(source)
        if not player then return end
        ReportService.kills[player.identifier] = nil
        ReportService.alerts[player.identifier] = nil
    end)
end

---@param list table[]
---@param entry table
---@param size integer
function ReportService.push(list, entry, size)
    table.insert(list, 1, entry)
    while #list > size do table.remove(list) end
end

---Appelé à chaque kill entre joueurs (voir CombatService.onPlayerDied).
---@param killer PvpPlayer
---@param victim PvpPlayer
---@param recap table récapitulatif de mort de la victime
function ReportService.recordKill(killer, victim, recap)
    local taken = recap.taken or {}
    local list = ReportService.kills[killer.identifier] or {}
    ReportService.kills[killer.identifier] = list
    ReportService.push(list, {
        at = os.time(),
        victim = victim.name,
        weapon = recap.weapon or '?',
        distance = recap.distance or 0,
        hits = taken.hits or 0,
        headshots = taken.headshots or 0,
    }, Config.Reports.killHistory)
end

---Appelé à chaque alerte de l'anti-triche (voir AntiCheatService.flag).
---@param player PvpPlayer
---@param label string
---@param details string
function ReportService.recordAlert(player, label, details)
    local list = ReportService.alerts[player.identifier] or {}
    ReportService.alerts[player.identifier] = list
    ReportService.push(list, { at = os.time(), label = label, details = details }, Config.Reports.alertHistory)
end

---@param at integer os.time()
---@return string
function ReportService.ago(at)
    return ('il y a %d min'):format(math.floor((os.time() - at) / 60))
end

---@param target PvpPlayer
---@return string
function ReportService.killLines(target)
    local lines = {}
    for _, kill in ipairs(ReportService.kills[target.identifier] or {}) do
        lines[#lines + 1] = ('%s : %s, %s, %d m, %d touches dont %d à la tête'):format(
            ReportService.ago(kill.at), DiscordService.escape(kill.victim), kill.weapon, kill.distance, kill.hits, kill.headshots)
    end
    return #lines > 0 and table.concat(lines, '\n') or 'Aucun depuis sa connexion'
end

---@param target PvpPlayer
---@return string
function ReportService.alertLines(target)
    local lines = {}
    for _, alert in ipairs(ReportService.alerts[target.identifier] or {}) do
        lines[#lines + 1] = ('%s : %s (%s)'):format(ReportService.ago(alert.at), alert.label, DiscordService.escape(alert.details))
    end
    return #lines > 0 and table.concat(lines, '\n') or 'Aucune depuis sa connexion'
end

---@param source integer
---@param data any { target, reason }
---@return { ok: boolean, message?: string }
function ReportService.report(source, data)
    local reporter = PlayerService.get(source)
    if not reporter or type(data) ~= 'table' then return { ok = false } end
    local settings = Config.Reports

    local target = PlayerService.get(tonumber(data.target))
    if not target then return { ok = false, message = Locale.t('Joueur introuvable. Usage : /signaler ID raison') } end
    if target == reporter then return { ok = false, message = Locale.t('Tu ne peux pas te signaler toi-même.') } end

    local reason = ChatService.sanitize(data.reason)
    if not reason or #reason < settings.reasonMinLength then return { ok = false, message = Locale.t('Donne une raison. Usage : /signaler ID raison') } end
    reason = reason:sub(1, settings.reasonMaxLength)

    local now = os.time()
    local last = ReportService.lastReport[reporter.identifier]
    if last and now - last < settings.cooldown then
        return { ok = false, message = Locale.t('Attends %d s avant un nouveau signalement.', settings.cooldown - (now - last)) }
    end
    local pair = reporter.identifier .. ':' .. target.identifier
    local lastPair = ReportService.lastTarget[pair]
    if lastPair and now - lastPair < settings.targetCooldown then
        return { ok = false, message = Locale.t('Tu as déjà signalé ce joueur.') }
    end
    ReportService.lastReport[reporter.identifier] = now
    ReportService.lastTarget[pair] = now

    ReportService.save(reporter, target, reason)
    ReportService.send(reporter, target, reason)
    for _, player in pairs(PlayerService.all()) do
        if player ~= target and AdminService.isAdmin(player.source) then
            ChatService.system(player.source, Locale.t('Signalement : %s (ID %d) par %s : %s', target.name, target.source, reporter.name, reason))
        end
    end
    Logger.info('[signalement] %s signale %s : %s', reporter.name, target.name, reason)
    return { ok = true, message = Locale.t('Signalement envoyé à l\'équipe. Merci.') }
end

---@param reporter PvpPlayer
---@param target PvpPlayer
---@param reason string
function ReportService.save(reporter, target, reason)
    local evidence = json.encode({
        kills = ReportService.kills[target.identifier] or {},
        alerts = ReportService.alerts[target.identifier] or {},
        totalKills = target.kills,
        totalDeaths = target.deaths,
    })
    MySQL.insert(
        'INSERT INTO pvp_reports (reporter, reporter_name, target, target_name, reason, evidence) VALUES (?, ?, ?, ?, ?, ?)',
        { reporter.identifier, reporter.name, target.identifier, target.name, reason, evidence }
    )
end

---@param reporter PvpPlayer
---@param target PvpPlayer
---@param reason string
function ReportService.send(reporter, target, reason)
    DiscordService.send(Config.Reports.channel, {
        title = '🚩 Signalement',
        color = DiscordService.COLORS.hazard,
        fields = {
            { name = 'Joueur signalé', value = ('%s\n`%s`'):format(DiscordService.playerTag(target.source, target.name), target.identifier) },
            { name = 'Par', value = DiscordService.playerTag(reporter.source, reporter.name), inline = true },
            { name = 'Raison', value = DiscordService.escape(reason), inline = true },
            { name = 'Total', value = ('%d kills, %d morts'):format(target.kills, target.deaths), inline = true },
            { name = 'Derniers kills', value = ReportService.killLines(target) },
            { name = 'Alertes anti-triche', value = ReportService.alertLines(target) },
        },
    })
end
