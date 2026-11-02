---Tournoi de crews (Config.Crews.tournament), une fois par semaine : les chefs inscrivent leur crew, puis
---les kills entre crews inscrits comptent pendant la durée du tournoi. Le crew en tête prend le prix dans
---son coffre. Inscriptions et scores sont en base ; les lignes supprimées à la fin évitent de payer deux fois.
---@class CrewTournamentServiceModule
local CrewTournamentService = PVP.define('CrewTournamentService')
local CrewService = PVP.use('CrewService')
local CrewStashService = PVP.use('CrewStashService')
local PlayerService = PVP.use('PlayerService')
local ChatService = PVP.use('ChatService')
local Callback = PVP.use('Callback')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CrewTournamentService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_crew_tournament (
    start_at INT NOT NULL,
    crew_tag VARCHAR(3) NOT NULL,
    kills INT NOT NULL DEFAULT 0,
    PRIMARY KEY (start_at, crew_tag)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]
CrewTournamentService.CHECK_INTERVAL = 15000
CrewTournamentService.SECONDS_PER_DAY = 86400

---@type integer os.time() du début du prochain tournoi, ou de celui en cours
CrewTournamentService.startAt = 0
---@type boolean le début a été traité
CrewTournamentService.running = false
---@type table<string, integer> label -> kills
CrewTournamentService.crews = {}

function CrewTournamentService.init()
    Callback.register(Events.callbacks.crewTournamentGet, CrewTournamentService.get)
    Callback.register(Events.callbacks.crewTournamentJoin, CrewTournamentService.join)
end

---Inscriptions en base : appelé par CrewService une fois crews et coffres chargés.
function CrewTournamentService.restore()
    MySQL.query.await(CrewTournamentService.SCHEMA)
    local now = os.time()
    local rows = MySQL.query.await('SELECT start_at, crew_tag, kills FROM pvp_crew_tournament') or {}

    -- Tournois finis serveur éteint : payés maintenant
    local past = {}
    for _, row in ipairs(rows) do
        if row.start_at + Config.Crews.tournament.duration <= now then
            past[row.start_at] = past[row.start_at] or {}
            past[row.start_at][row.crew_tag] = row.kills
        end
    end
    for startAt, crews in pairs(past) do CrewTournamentService.settle(startAt, crews) end

    CrewTournamentService.startAt = CrewTournamentService.nextStart(now)
    for _, row in ipairs(rows) do
        if row.start_at == CrewTournamentService.startAt then CrewTournamentService.crews[row.crew_tag] = row.kills end
    end
    CrewTournamentService.running = now >= CrewTournamentService.startAt

    CreateThread(function()
        while true do
            Wait(CrewTournamentService.CHECK_INTERVAL)
            CrewTournamentService.tick(os.time())
        end
    end)
end

---@param now integer os.time()
---@return integer début du tournoi en cours, sinon du prochain
function CrewTournamentService.nextStart(now)
    local settings = Config.Crews.tournament
    local date = os.date('*t', now)
    local days = (settings.weekday - date.wday) % 7
    local start = os.time({ year = date.year, month = date.month, day = date.day + days, hour = settings.hour, min = 0, sec = 0 })
    -- Le créneau de cette semaine est déjà fini : semaine suivante
    if start + settings.duration <= now then
        start = os.time({ year = date.year, month = date.month, day = date.day + days + 7, hour = settings.hour, min = 0, sec = 0 })
    end
    return start
end

---@return integer nombre de crews inscrits encore existants
function CrewTournamentService.count()
    local count = 0
    for tag in pairs(CrewTournamentService.crews) do
        if CrewService.crews[tag] then count = count + 1 end
    end
    return count
end

---@param now integer
function CrewTournamentService.tick(now)
    local settings = Config.Crews.tournament
    if not CrewTournamentService.running then
        if now < CrewTournamentService.startAt then return end
        if CrewTournamentService.count() < settings.minCrews then
            if CrewTournamentService.count() > 0 then
                ChatService.announce('pvp', Locale.t('Tournoi de crews annulé : pas assez de crews inscrits.'))
            end
            CrewTournamentService.reset()
            return
        end
        CrewTournamentService.running = true
        ChatService.announce('pvp', Locale.t('Le tournoi de crews commence : %d minutes, $%d pour le crew en tête !', math.floor(settings.duration / 60), settings.prize))
        return
    end
    if now >= CrewTournamentService.startAt + settings.duration then
        CrewTournamentService.settle(CrewTournamentService.startAt, CrewTournamentService.crews)
        CrewTournamentService.reset()
    end
end

---Passe au tournoi suivant et oublie les inscriptions.
function CrewTournamentService.reset()
    MySQL.update('DELETE FROM pvp_crew_tournament WHERE start_at = ?', { CrewTournamentService.startAt })
    CrewTournamentService.crews = {}
    CrewTournamentService.running = false
    CrewTournamentService.startAt = CrewTournamentService.nextStart(CrewTournamentService.startAt + Config.Crews.tournament.duration)
end

---Verse le prix : partagé en cas d'égalité, rien si personne n'a fait de kill.
---@param startAt integer
---@param crews table<string, integer>
function CrewTournamentService.settle(startAt, crews)
    MySQL.update('DELETE FROM pvp_crew_tournament WHERE start_at = ?', { startAt })
    local best, winners = 0, {}
    for tag, kills in pairs(crews) do
        if CrewService.crews[tag] and kills > 0 then
            if kills > best then best, winners = kills, { tag } elseif kills == best then winners[#winners + 1] = tag end
        end
    end
    if #winners == 0 then
        ChatService.announce('pvp', Locale.t('Tournoi de crews terminé : aucun gagnant.'))
        return
    end
    table.sort(winners)
    local share = math.floor(Config.Crews.tournament.prize / #winners)
    local labels = {}
    for _, tag in ipairs(winners) do
        CrewStashService.moveMoney(tag, share, 'Tournoi de crews')
        CrewService.sync(CrewService.crews[tag])
        labels[#labels + 1] = '[' .. tag .. ']'
    end
    ChatService.announce('pvp', Locale.t('%s remporte le tournoi de crews avec %d kills et prend $%d !', table.concat(labels, ' '), best, share))
    Logger.info('[crew] tournoi : %s, %d kills', table.concat(labels, ' '), best)
end

---Kill entre crews déjà compté au classement (voir CrewStatsService.onPlayerKill).
---@param killerTag string
---@param victimTag string
function CrewTournamentService.onKill(killerTag, victimTag)
    if not CrewTournamentService.running then return end
    local kills = CrewTournamentService.crews[killerTag]
    if not kills or not CrewTournamentService.crews[victimTag] then return end
    CrewTournamentService.crews[killerTag] = kills + 1
    MySQL.update('UPDATE pvp_crew_tournament SET kills = ? WHERE start_at = ? AND crew_tag = ?', { kills + 1, CrewTournamentService.startAt, killerTag })
end

---Crew dissous : retiré du tournoi.
---@param tag string
function CrewTournamentService.onDissolve(tag)
    if CrewTournamentService.crews[tag] == nil then return end
    CrewTournamentService.crews[tag] = nil
    MySQL.update('DELETE FROM pvp_crew_tournament WHERE start_at = ? AND crew_tag = ?', { CrewTournamentService.startAt, tag })
end

---@param source integer chef
---@return { ok: boolean, message?: string }
function CrewTournamentService.join(source)
    local player = PlayerService.get(source)
    local crew = CrewService.crewOf(source)
    if not player or not crew or crew.leader ~= player.identifier then
        return { ok = false, message = Locale.t('Seul le chef du crew peut l\'inscrire.') }
    end
    if CrewTournamentService.running then return { ok = false, message = Locale.t('Le tournoi a déjà commencé.') } end
    if CrewTournamentService.crews[crew.tag] then return { ok = false, message = Locale.t('Ton crew est déjà inscrit.') } end

    CrewTournamentService.crews[crew.tag] = 0
    MySQL.insert('INSERT IGNORE INTO pvp_crew_tournament (start_at, crew_tag) VALUES (?, ?)', { CrewTournamentService.startAt, crew.tag })
    CrewService.notifyMembers(crew, Locale.t('Ton crew est inscrit au tournoi.'), player.identifier)
    return { ok = true, message = Locale.t('Crew inscrit au tournoi.') }
end

---@param source integer
---@return table pour le menu Crew
function CrewTournamentService.get(source)
    local now = os.time()
    local crew = CrewService.crewOf(source)
    local rows = {}
    for tag, kills in pairs(CrewTournamentService.crews) do
        local entry = CrewService.crews[tag]
        if entry then rows[#rows + 1] = { tag = tag, name = entry.name, kills = kills, mine = crew == entry } end
    end
    table.sort(rows, function(a, b)
        if a.kills ~= b.kills then return a.kills > b.kills end
        return a.tag < b.tag
    end)
    local settings = Config.Crews.tournament
    return {
        running = CrewTournamentService.running,
        startsIn = math.max(0, CrewTournamentService.startAt - now),
        endsIn = math.max(0, CrewTournamentService.startAt + settings.duration - now),
        prize = settings.prize,
        minCrews = settings.minCrews,
        crews = rows,
    }
end
