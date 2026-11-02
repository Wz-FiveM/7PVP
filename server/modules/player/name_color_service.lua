---Couleurs du nom en PvP (Config.NameColors) : gamertags et killfeed. Gardées en base avec le profil du joueur.
---@class NameColorServiceModule
local NameColorService = PVP.define('NameColorService')
local NameColors = PVP.use('NameColors')
local PlayerService = PVP.use('PlayerService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

function NameColorService.init()
    Callback.register(Events.callbacks.nameColorSelect, NameColorService.select)
    AddEventHandler(Events.internal.playerLoaded, function(source)
        NameColorService.publish(PlayerService.get(source))
    end)
end

---@param player PvpPlayer|nil
function NameColorService.publish(player)
    if not player then return end
    Player(player.source).state:set(NameColors.STATE_KEY, player.nameColor or false, true)
end

---@param source integer
---@param colors any un code par lettre (voir NameColors), chaîne vide pour tout retirer
---@return { ok: boolean, message?: string }
function NameColorService.select(source, colors)
    local player = PlayerService.get(source)
    if not player or not NameColors.isValid(colors) then return { ok = false } end

    local chosen = NameColors.sanitize(colors)
    if player.nameColor == chosen then return { ok = true } end

    player.nameColor = chosen
    NameColorService.publish(player)
    player:sync()
    return { ok = true, message = chosen and Locale.t('Couleurs du nom enregistrées.') or Locale.t('Couleurs du nom retirées.') }
end
