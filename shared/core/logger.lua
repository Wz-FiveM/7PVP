---@class LoggerModule
local Logger = PVP.define('Logger')

---@param level string
---@param message string
---@return string
function Logger.format(level, message, ...)
    return ('^5[7PVP]^7 [%s] %s'):format(level, select('#', ...) > 0 and message:format(...) or message)
end

function Logger.info(message, ...)
    print(Logger.format('INFO', message, ...))
end

function Logger.warn(message, ...)
    print(Logger.format('^3WARN^7', message, ...))
end

function Logger.error(message, ...)
    print(Logger.format('^1ERROR^7', message, ...))
end

function Logger.debug(message, ...)
    if Config.Debug then
        print(Logger.format('DEBUG', message, ...))
    end
end
