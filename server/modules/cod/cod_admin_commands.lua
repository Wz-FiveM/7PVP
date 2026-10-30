---Commandes admin du mode Call of Duty, pour tester les séries et les déblocages.
---    /codserie                     → ses séries choisies
---    /codserie predator 12         → une série, pour le joueur 12
---    /codserie toutes              → toutes les séries
---    /codniveau 5                  → 5 rangs de plus (négatif : de moins)
---    /codniveau 5 12               → pour le joueur 12
---@class CodAdminCommandsModule
local CodAdminCommands = PVP.define('CodAdminCommands')
local CodProfileService = PVP.use('CodProfileService')
local CodService = PVP.use('CodService')
local CodStreaks = PVP.use('CodStreaks')
local AdminService = PVP.use('AdminService')
local DiscordService = PVP.use('DiscordService')
local PlayerService = PVP.use('PlayerService')
local Locale = PVP.use('Locale')
local Logger = PVP.use('Logger')

CodAdminCommands.ALL_STREAKS = 'toutes'

function CodAdminCommands.init()
    RegisterCommand('codserie', function(source, args)
        CodAdminCommands.giveStreaks(source, args)
    end, false)
    RegisterCommand('codniveau', function(source, args)
        CodAdminCommands.giveRanks(source, args)
    end, false)
end

---@param source integer
---@return boolean console ou admin ; sinon le joueur est prévenu
function CodAdminCommands.allowed(source)
    if source == 0 or AdminService.isAdmin(source) then return true end
    CodAdminCommands.reply(source, Locale.t('Commande réservée aux admins.'), 'error')
    return false
end

---@param source integer 0 = console
---@param message string|table message à traduire (Locale.t), en français dans la console
---@param kind 'success'|'error'
function CodAdminCommands.reply(source, message, kind)
    local player = source > 0 and PlayerService.get(source)
    if player then return player:notify(message, kind) end
    print(('[7PVP] %s'):format(Locale.resolve(message, Locale.SOURCE)))
end

---@param source integer
---@param arg string|nil id du joueur visé
---@return integer|nil joueur connecté visé : soi-même par défaut, à préciser depuis la console
function CodAdminCommands.target(source, arg)
    local target = arg and tonumber(arg) or (not arg and source) or nil
    target = target and math.tointeger(target)
    return target and PlayerService.get(target) and target or nil
end

---@param source integer
---@param target integer
---@param command string
---@param text string
function CodAdminCommands.log(source, target, command, text)
    local by = source == 0 and 'console' or GetPlayerName(source)
    Logger.info('[admin] %s : %s %s (%s)', by, command, GetPlayerName(target), text)
    DiscordService.codAdminCommand(source, command, GetPlayerName(target), text)
end

---@param choice string|nil id d'une série, 'toutes', ou rien pour les séries choisies du joueur
---@param target integer
---@return table[]|nil séries demandées, nil si l'id n'existe pas
function CodAdminCommands.streaksFor(choice, target)
    if not choice then return CodStreaks.chosen(target) end
    if choice == CodAdminCommands.ALL_STREAKS then return Config.Cod.streaks end
    local streak = CodProfileService.streaks[choice]
    return streak and { streak } or nil
end

---@param source integer 0 = console
---@param args string[]
function CodAdminCommands.giveStreaks(source, args)
    if not CodAdminCommands.allowed(source) then return end
    local target = CodAdminCommands.target(source, args[2])
    if not target then
        return CodAdminCommands.reply(source, Locale.t('Utilisation : /codserie [id de la série | toutes] [id du joueur]'), 'error')
    end
    local match = CodService.matchOf(target)
    if not match or not match.stats[target] then
        return CodAdminCommands.reply(source, Locale.t('Ce joueur n\'est pas dans une partie Call of Duty.'), 'error')
    end
    local streaks = CodAdminCommands.streaksFor(args[1], target)
    if not streaks or #streaks == 0 then
        local ids = {}
        for _, streak in ipairs(Config.Cod.streaks) do ids[#ids + 1] = streak.id end
        return CodAdminCommands.reply(source, Locale.t('Séries disponibles : %s', table.concat(ids, ', ')), 'error')
    end

    CodStreaks.grant(match, target, streaks)
    CodAdminCommands.log(source, target, 'codserie', args[1] or 'choisies')
    CodAdminCommands.reply(source, Locale.t('%s reçoit %d série(s).', GetPlayerName(target), #streaks), 'success')
end

---@param source integer 0 = console
---@param args string[]
function CodAdminCommands.giveRanks(source, args)
    if not CodAdminCommands.allowed(source) then return end
    local amount = math.tointeger(tonumber(args[1]))
    local target = CodAdminCommands.target(source, args[2])
    if not amount or amount == 0 or not target then
        return CodAdminCommands.reply(source, Locale.t('Utilisation : /codniveau <nombre> [id du joueur]'), 'error')
    end
    if not CodProfileService.profiles[target] then
        return CodAdminCommands.reply(source, Locale.t('Ce joueur n\'est pas dans le mode Call of Duty.'), 'error')
    end

    local before, after = CodProfileService.addRanks(target, amount)
    if before == after then
        return CodAdminCommands.reply(source, Locale.t('%s reste au rang %d.', GetPlayerName(target), after), 'error')
    end
    CodAdminCommands.log(source, target, 'codniveau', ('%d → %d'):format(before, after))
    CodAdminCommands.reply(source, Locale.t('%s passe du rang %d au rang %d.', GetPlayerName(target), before, after), 'success')
    if target ~= source then
        CodAdminCommands.reply(target, Locale.t('Un admin te fait passer au rang %d.', after), 'success')
    end
end
