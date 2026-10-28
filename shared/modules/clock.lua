---Horloge du jeu, commune au serveur et aux clients : l'heure du jeu dépend seulement
---de l'heure réelle (UTC), donc tout le monde voit la même heure sans synchronisation.
---@class ClockModule
local Clock = PVP.define('Clock')

---@return integer secondes UTC
function Clock.now()
    if IsDuplicityVersion() then return os.time() end
    return GetCloudTimeAsInt()
end

---@return integer minutes du jeu depuis minuit (0 à 1439)
function Clock.minutes()
    local cycle = Config.Time.cycleMinutes * 60
    local progress = (Clock.now() % cycle) / cycle
    return math.floor(progress * 1440 + Config.Time.offsetHours * 60) % 1440
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
