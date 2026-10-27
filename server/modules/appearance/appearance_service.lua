---Création et modification de l'apparence des personnages.
---@class AppearanceServiceModule
local AppearanceService = PVP.define('AppearanceService')
local PlayerService = PVP.use('PlayerService')
local PlayerRepository = PVP.use('PlayerRepository')
local SpawnService = PVP.use('SpawnService')
local AppearanceSchema = PVP.use('AppearanceSchema')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')

-- Chaque joueur en création a son propre bucket : il ne voit personne et personne ne le voit
AppearanceService.BUCKET_OFFSET = 1000

function AppearanceService.init()
    Callback.register(Events.callbacks.saveAppearance, AppearanceService.save)
end

---@param player PvpPlayer
function AppearanceService.startCreator(player)
    player.creating = true
    SetPlayerRoutingBucket(player.source, AppearanceService.BUCKET_OFFSET + player.source)
    TriggerClientEvent(Events.client.openCreator, player.source, 'create', nil)
end

---@param player PvpPlayer
function AppearanceService.finishCreator(player)
    player.creating = false
    SetPlayerRoutingBucket(player.source, 0)
    SpawnService.spawn(player)
end

---@param source integer
---@param data table apparence envoyée par le créateur
---@return { ok: boolean, message?: string }
function AppearanceService.save(source, data)
    local player = PlayerService.get(source)
    if not player then return { ok = false } end

    local appearance = AppearanceSchema.sanitize(data)
    if not appearance then
        return { ok = false, message = 'Apparence invalide.' }
    end

    if player.creating then
        player.appearance = appearance
        PlayerRepository.save(player)
        AppearanceService.finishCreator(player)
        return { ok = true }
    end

    if player.dead or not player:isInSafeZone() then
        return { ok = false, message = 'L\'apparence ne se modifie qu\'en zone safe.' }
    end

    player.appearance = appearance
    PlayerRepository.save(player)
    return { ok = true, message = 'Apparence enregistrée.' }
end
