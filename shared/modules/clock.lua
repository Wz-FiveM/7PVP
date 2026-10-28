---Horloge du jeu, la même pour tous les joueurs.
---Le serveur la calcule (heure réelle + décalage réglable par les admins avec /heure) et la publie
---dans un state bag global (server/modules/clock) ; chaque client la fait avancer lui-même
---depuis la dernière publication, à la vitesse du cycle (Config.Time).
---@class ClockModule
local Clock = PVP.define('Clock')

Clock.STATE_KEY = '7pvp:clock'
Clock.offset = 0 -- (serveur) minutes ajoutées par /heure
---@type { minutes: number, receivedAt: integer }|nil (client) dernière heure reçue du serveur
Clock.synced = nil

function Clock.init()
    if IsDuplicityVersion() then return end
    Clock.receive(GlobalState[Clock.STATE_KEY])
    AddStateBagChangeHandler(Clock.STATE_KEY, 'global', function(_, _, value)
        Clock.receive(value)
    end)
end

---@param value any { minutes }
function Clock.receive(value)
    if type(value) ~= 'table' or type(value.minutes) ~= 'number' then return end
    Clock.synced = { minutes = value.minutes, receivedAt = GetGameTimer() }
end

---@return number minutes du jeu qui passent par seconde réelle
function Clock.rate()
    return 1440 / (Config.Time.cycleMinutes * 60)
end

---Heure calculée d'après l'heure réelle (UTC) : référence du serveur, et repli du client
---tant qu'il n'a rien reçu.
---@param now integer secondes UTC
---@return number
function Clock.fromRealTime(now)
    local cycle = Config.Time.cycleMinutes * 60
    local progress = (now % cycle) / cycle
    return (progress * 1440 + Config.Time.offsetHours * 60 + Clock.offset) % 1440
end

---@return number minutes du jeu depuis minuit, décimales comprises (0 à 1440)
function Clock.exactMinutes()
    if IsDuplicityVersion() then return Clock.fromRealTime(os.time()) end
    if not Clock.synced then return Clock.fromRealTime(GetCloudTimeAsInt()) end
    local elapsed = (GetGameTimer() - Clock.synced.receivedAt) / 1000
    return (Clock.synced.minutes + elapsed * Clock.rate()) % 1440
end

---@return integer minutes du jeu depuis minuit (0 à 1439)
function Clock.minutes()
    return math.floor(Clock.exactMinutes()) % 1440
end

---@return integer heure, integer minute
function Clock.time()
    local minutes = Clock.minutes()
    return math.floor(minutes / 60), minutes % 60
end

---@return boolean
function Clock.isNight()
    local hour = Clock.time()
    return hour >= Config.Night.from or hour < Config.Night.to
end
