---Modes de jeu du Freeroam, lancés depuis les PNJ de la zone safe (Config.FreeroamActivities).
---Chaque mode s'enregistre ici avec la fonction qui le lance :
---    ActivityService.register('cvc', function(player) return true, 'Tu rejoins la file.' end)
---Tant qu'un mode n'est pas enregistré ou pas activé (enabled), il est « bientôt disponible ».
---@class ActivityServiceModule
local ActivityService = PVP.define('ActivityService')
local PlayerService = PVP.use('PlayerService')
local SpectateService = PVP.use('SpectateService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

ActivityService.MODE = 'freeroam'

---@type table<string, fun(player: PvpPlayer): boolean, string|nil>
ActivityService.handlers = {}

function ActivityService.init()
    Callback.register(Events.callbacks.activityStart, ActivityService.start)
end

---@param id string clé de Config.FreeroamActivities
---@param handler fun(player: PvpPlayer): boolean, string|nil
function ActivityService.register(id, handler)
    ActivityService.handlers[id] = handler
end

---@param source integer
---@param id any
---@return { ok: boolean, message?: string }
function ActivityService.start(source, id)
    local player = PlayerService.get(source)
    if not player or player.dead or player.mode ~= ActivityService.MODE then
        return { ok = false, message = Locale.t('Disponible en Freeroam.') }
    end
    if SpectateService.isWatching(source) then
        return { ok = false, message = Locale.t('Quitte d\'abord le mode spectateur.') }
    end
    local activity = type(id) == 'string' and Config.FreeroamActivities[id]
    if not activity then return { ok = false, message = Locale.t('Mode de jeu inconnu.') } end
    if not player:isInSafeZone() then
        return { ok = false, message = Locale.t('Va voir l\'organisateur dans la zone safe.') }
    end

    local handler = ActivityService.handlers[id]
    if not activity.enabled or not handler then
        return { ok = false, message = Locale.t('%s arrive bientôt.', Locale.t(activity.label)) }
    end
    local ok, message = handler(player)
    return { ok = ok == true, message = message }
end
