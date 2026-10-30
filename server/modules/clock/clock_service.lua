---Publie l'heure du jeu à tous les clients (shared/modules/clock.lua) et gère /heure (admins).
---    /heure 22      → 22:00 pour tout le monde
---    /heure 6 30    → 06:30
---    /heure reset   → retour au cycle normal
---@class ClockServiceModule
local ClockService = PVP.define('ClockService')
local Clock = PVP.use('Clock')
local PlayerService = PVP.use('PlayerService')
local AdminService = PVP.use('AdminService')
local Locale = PVP.use('Locale')

-- Republication régulière : recale les clients (une seule valeur, très léger)
ClockService.PUBLISH_INTERVAL = 30000

function ClockService.init()
    ClockService.publish()
    CreateThread(ClockService.loop)
    RegisterCommand('heure', function(source, args)
        ClockService.command(source, args)
    end, false)
end

function ClockService.loop()
    while true do
        Wait(ClockService.PUBLISH_INTERVAL)
        ClockService.publish()
    end
end

function ClockService.publish()
    GlobalState[Clock.STATE_KEY] = { minutes = Clock.exactMinutes() }
end

---Règle l'heure du jeu pour tout le monde ; le cycle continue à partir de là.
---@param hour integer
---@param minute integer
function ClockService.set(hour, minute)
    local target = (hour * 60 + minute) % 1440
    Clock.offset = 0
    Clock.offset = (target - Clock.exactMinutes()) % 1440
    ClockService.publish()
end

---@param source integer 0 = console
---@param args string[]
function ClockService.command(source, args)
    if source > 0 and not AdminService.isAdmin(source) then
        return ClockService.reply(source, Locale.t('Commande réservée aux admins.'), 'error')
    end
    if args[1] == 'reset' then
        Clock.offset = 0
        ClockService.publish()
        return ClockService.reply(source, Locale.t('Heure du jeu revenue au cycle normal.'), 'success')
    end

    local hour, minute = tonumber(args[1]), tonumber(args[2] or 0)
    if not hour or not minute or hour < 0 or hour > 23 or minute < 0 or minute > 59 then
        return ClockService.reply(source, Locale.t('Utilisation : /heure <0-23> [minutes], ou /heure reset'), 'error')
    end
    ClockService.set(math.floor(hour), math.floor(minute))
    ClockService.reply(source, Locale.t('Heure du jeu réglée sur %02d:%02d pour tout le monde.', hour, minute), 'success')
end

---@param source integer
---@param message string|table message à traduire (Locale.t), en français dans la console
---@param kind 'success'|'error'
function ClockService.reply(source, message, kind)
    local player = source > 0 and PlayerService.get(source)
    if player then return player:notify(message, kind) end
    print(('[7PVP] %s'):format(Locale.resolve(message, Locale.SOURCE)))
end
