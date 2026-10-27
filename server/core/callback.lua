---Callbacks serveur : le client envoie une requête, le serveur répond.
---Côté client : `Callback.await(name, ...)`.
---@class ServerCallbackModule
local Callback = PVP.define('Callback')
local Events = PVP.use('Events')
local Logger = PVP.use('Logger')

---@type table<string, fun(source: integer, ...): any>
Callback.handlers = {}

function Callback.init()
    RegisterNetEvent(Events.transport.request, function(name, requestId, ...)
        Callback.handle(source, name, requestId, ...)
    end)
end

---@param name string
---@param handler fun(source: integer, ...): any
function Callback.register(name, handler)
    Callback.handlers[name] = handler
end

---@param source integer
---@param name string
---@param requestId integer
function Callback.handle(source, name, requestId, ...)
    local handler = Callback.handlers[name]
    local result

    if handler then
        local ok, response = pcall(handler, source, ...)
        if ok then
            result = response
        else
            Logger.error('Callback "%s" : %s', name, response)
        end
    else
        Logger.warn('Callback inconnu "%s" demandé par %s', name, source)
    end

    TriggerClientEvent(Events.transport.response, source, requestId, result)
end
