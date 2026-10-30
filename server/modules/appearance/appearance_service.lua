---Création et modification de l'apparence des personnages.
---@class AppearanceServiceModule
local AppearanceService = PVP.define('AppearanceService')
local PlayerService = PVP.use('PlayerService')
local PlayerRepository = PVP.use('PlayerRepository')
local LobbyService = PVP.use('LobbyService')
local WorldService = PVP.use('WorldService')
local AppearanceSchema = PVP.use('AppearanceSchema')
local Callback = PVP.use('Callback')
local SafeNpcs = PVP.use('SafeNpcs')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

-- Chaque joueur en création a son propre bucket : il ne voit personne et personne ne le voit
AppearanceService.BUCKET_OFFSET = 1000
AppearanceService.FINISH_DELAY = 300 -- ms

function AppearanceService.init()
    Callback.register(Events.callbacks.saveAppearance, AppearanceService.save)
end

---@param player PvpPlayer
function AppearanceService.startCreator(player)
    player.creating = true
    local bucket = AppearanceService.BUCKET_OFFSET + player.source
    WorldService.setupBucket(bucket)
    SetPlayerRoutingBucket(player.source, bucket)
    TriggerClientEvent(Events.client.openCreator, player.source, 'create', nil)
end

---Personnage créé : direction le lobby pour choisir son mode.
---@param player PvpPlayer
function AppearanceService.finishCreator(player)
    player.creating = false
    LobbyService.open(player)
end

---@param source integer
---@param data table apparence envoyée par le créateur
---@return { ok: boolean, message?: string }
function AppearanceService.save(source, data)
    local player = PlayerService.get(source)
    if not player then return { ok = false } end

    local appearance = AppearanceSchema.sanitize(data)
    if not appearance then
        return { ok = false, message = Locale.t('Apparence invalide.') }
    end

    if player.creating then
        player.appearance = appearance
        PlayerRepository.save(player)
        -- Après la réponse : le client ferme le créateur avant d'ouvrir le lobby
        SetTimeout(AppearanceService.FINISH_DELAY, function()
            if PlayerService.get(source) == player then
                AppearanceService.finishCreator(player)
            end
        end)
        return { ok = true }
    end

    if player.dead or not SafeNpcs.isNear(player:getCoords(), 'clothing', Config.SafeNpcs.useDistance + 2.0) then
        return { ok = false, message = SafeNpcs.hint('clothing') }
    end

    player.appearance = appearance
    PlayerRepository.save(player)
    return { ok = true, message = Locale.t('Apparence enregistrée.') }
end
