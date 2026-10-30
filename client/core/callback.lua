---Callbacks client : envoie une requête au serveur et attend sa réponse.
---    local result = Callback.await(Events.callbacks.buy, index)
---@class ClientCallbackModule
local Callback = PVP.define('Callback')
local Events = PVP.use('Events')
local Logger = PVP.use('Logger')
local Locale = PVP.use('Locale')

Callback.TIMEOUT = 10000
Callback.nextId = 0
---@type table<integer, promise>
Callback.pending = {}

function Callback.init()
    RegisterNetEvent(Events.transport.response, function(requestId, result)
        Callback.resolve(requestId, result)
    end)
end

---Les messages à traduire de la réponse (Locale.t côté serveur) arrivent traduits.
---@param name string
---@return any
function Callback.await(name, ...)
    Callback.nextId = Callback.nextId + 1
    local requestId = Callback.nextId
    local p = promise.new()
    Callback.pending[requestId] = p

    TriggerServerEvent(Events.transport.request, name, requestId, ...)
    SetTimeout(Callback.TIMEOUT, function()
        if Callback.pending[requestId] then
            Logger.warn('Callback "%s" sans réponse', name)
            Callback.resolve(requestId, nil)
        end
    end)

    return Locale.resolve(Citizen.Await(p))
end

---@param requestId integer
---@param result any
function Callback.resolve(requestId, result)
    local p = Callback.pending[requestId]
    if not p then return end
    Callback.pending[requestId] = nil
    p:resolve(result)
end
