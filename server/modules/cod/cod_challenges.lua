---Défis du mode Call of Duty (config/cod_challenges.lua) : ceux de la période sont les mêmes pour tous, sans table à part.
---La progression vit dans le profil (pvp_cod_profiles.challenges) et repart de zéro quand la période change.
---@class CodChallengeState
---@field period integer
---@field progress table<string, integer> défi -> compteur

---@class CodChallengesModule
local CodChallenges = PVP.define('CodChallenges')
local CodProfileService = PVP.use('CodProfileService')

CodChallenges.KINDS = { 'daily', 'weekly' }
CodChallenges.DAY = 86400
CodChallenges.WEEK = 604800
CodChallenges.WEEK_START = 345600 -- le temps Unix commence un jeudi : premier lundi, le 5 janvier 1970

---@type table<string, table[]> tirage déjà fait : '<type>:<période>' -> défis
CodChallenges.drawn = {}

---@param kind string 'daily' ou 'weekly'
---@param now integer os.time()
---@return integer période, integer secondes avant la suivante
function CodChallenges.period(kind, now)
    if kind == 'daily' then
        return math.floor(now / CodChallenges.DAY), CodChallenges.DAY - now % CodChallenges.DAY
    end
    local since = now - CodChallenges.WEEK_START
    return math.floor(since / CodChallenges.WEEK), CodChallenges.WEEK - since % CodChallenges.WEEK
end

---Tirage qui ne dépend que de la période : tous les joueurs ont les mêmes défis, même après un redémarrage.
---@param kind string
---@param period integer
---@return table[] défis de cette période
function CodChallenges.active(kind, period)
    local key = kind .. ':' .. period
    if CodChallenges.drawn[key] then return CodChallenges.drawn[key] end

    local settings = Config.CodChallenges[kind]
    local list = { table.unpack(settings.pool) }
    local seed = period
    local count = math.min(settings.count, #list)
    for index = 1, count do
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        local other = index + (seed >> 16) % (#list - index + 1)
        list[index], list[other] = list[other], list[index]
    end
    local chosen = { table.unpack(list, 1, count) }
    CodChallenges.drawn[key] = chosen
    return chosen
end

---@param profile CodProfile
---@param kind string
---@param period integer
---@return CodChallengeState état de la période en cours
function CodChallenges.state(profile, kind, period)
    local state = profile.challenges[kind]
    if not state or state.period ~= period then
        state = { period = period, progress = {} }
        profile.challenges[kind] = state
    end
    return state
end

---Compte une action du joueur. La sauvegarde se fait avec le reste du profil (fin de partie, départ).
---@param source integer
---@param stat string
---@param amount integer
---@return table[] défis que cette action termine
function CodChallenges.add(source, stat, amount)
    local profile = CodProfileService.profiles[source]
    local completed = {}
    if not profile then return completed end
    local now = os.time()
    for _, kind in ipairs(CodChallenges.KINDS) do
        local period = CodChallenges.period(kind, now)
        local state = CodChallenges.state(profile, kind, period)
        for _, entry in ipairs(CodChallenges.active(kind, period)) do
            if entry.stat == stat then
                local before = state.progress[entry.id] or 0
                state.progress[entry.id] = before + amount
                if before < entry.target and before + amount >= entry.target then completed[#completed + 1] = entry end
            end
        end
    end
    return completed
end

---@param data table lu en base
---@return table<string, CodChallengeState>
function CodChallenges.clean(data)
    local clean = {}
    for _, kind in ipairs(CodChallenges.KINDS) do
        local state = data[kind]
        local period = type(state) == 'table' and math.tointeger(tonumber(state.period))
        if period then
            local progress = {}
            for id, value in pairs(type(state.progress) == 'table' and state.progress or {}) do
                if type(id) == 'string' and tonumber(value) then progress[id] = math.floor(tonumber(value)) end
            end
            clean[kind] = { period = period, progress = progress }
        end
    end
    return clean
end

---@param profile CodProfile
---@return table défis envoyés à l'interface : daily et weekly, chacun { resetIn, items }
function CodChallenges.describe(profile)
    local now = os.time()
    local described = {}
    for _, kind in ipairs(CodChallenges.KINDS) do
        local period, resetIn = CodChallenges.period(kind, now)
        local state = CodChallenges.state(profile, kind, period)
        local items = {}
        for index, entry in ipairs(CodChallenges.active(kind, period)) do
            items[index] = {
                id = entry.id,
                label = entry.label,
                target = entry.target,
                xp = entry.xp,
                progress = math.min(state.progress[entry.id] or 0, entry.target),
            }
        end
        described[kind] = { resetIn = resetIn, items = items }
    end
    return described
end
