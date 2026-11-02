---Couleur du nom en PvP (Config.NameColors) : gamertags et killfeed. Gardée en base avec le profil du joueur.
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
---@param id any couleur choisie, false pour revenir à la couleur par défaut
---@return { ok: boolean, message?: string }
function NameColorService.select(source, id)
    local player = PlayerService.get(source)
    local color = NameColors.get(id)
    if not player or (id and not color) then return { ok = false } end

    local chosen = color and color.id or nil
    if player.nameColor == chosen then return { ok = true } end

    player.nameColor = chosen
    NameColorService.publish(player)
    player:sync()
    if not color then return { ok = true, message = Locale.t('Couleur du nom retirée.') } end
    return { ok = true, message = Locale.t('Couleur du nom : %s', Locale.t(color.label)) }
end
