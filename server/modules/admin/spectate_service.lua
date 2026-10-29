---Mode spectateur des admins (panneau F10) : l'admin passe dans le bucket du joueur qu'il regarde
---(partie de course poursuite, de CVC...) et sa caméra le suit (voir client/modules/admin/spectate.lua).
---Le serveur garde la main sur le bucket : il suit le joueur quand il change de bucket (début ou fin
---de partie) et ramène l'admin dans le bucket de son mode à la fin.
---@class SpectateWatch
---@field target integer joueur regardé
---@field mode string mode de l'admin au départ (le spectateur s'arrête s'il en change)
---@field bucket integer bucket où l'admin a été placé
---@field label string|nil situation du joueur affichée à l'admin

---@class SpectateServiceModule
local SpectateService = PVP.define('SpectateService')
local AdminService = PVP.use('AdminService')
local PlayerService = PVP.use('PlayerService')
local ModeRegistry = PVP.use('ModeRegistry')
local ChaseService = PVP.use('ChaseService')
local CvcService = PVP.use('CvcService')
local GunfightService = PVP.use('GunfightService')
local Events = PVP.use('Events')

-- Position du joueur regardé renvoyée à l'admin à ce rythme (ms) : tant que son personnage
-- n'est pas chargé chez l'admin, c'est elle qui rapproche l'admin de lui
SpectateService.CHECK_INTERVAL = 1000

---@type table<integer, SpectateWatch> admin -> ce qu'il regarde
SpectateService.watching = {}

function SpectateService.init()
    RegisterNetEvent(Events.server.spectateNext, function(direction)
        SpectateService.next(source, direction)
    end)
    RegisterNetEvent(Events.server.spectateStop, function()
        SpectateService.stop(source)
    end)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        SpectateService.watching[playerSource] = nil
    end)
    CreateThread(SpectateService.watchLoop)
end

---@param source integer
---@return boolean
function SpectateService.isWatching(source)
    return SpectateService.watching[source] ~= nil
end

---Dans une partie ou une file de course poursuite / CVC / 1VS1 : son bucket appartient déjà à la partie.
---@param source integer
---@return boolean
function SpectateService.inActivity(source)
    if ChaseService.playerMatch[source] or CvcService.playerMatch[source] or GunfightService.isBusy(source) then return true end
    for _, queue in ipairs({ ChaseService.queue, CvcService.queue }) do
        for _, queued in ipairs(queue) do
            if queued == source then return true end
        end
    end
    return false
end

---@param source integer
---@return string|nil situation du joueur (course, CVC), nil en jeu libre
function SpectateService.describe(source)
    local chase = ChaseService.describePlayer(source)
    if chase then return chase end
    if CvcService.playerMatch[source] then return 'Partie de CVC' end
    if GunfightService.playerMatch[source] then return 'Partie de 1VS1 GunFight' end
    return nil
end

---Commence à regarder un joueur, ou passe à un autre si l'admin regarde déjà quelqu'un.
---@param source integer admin
---@param target PvpPlayer
---@return boolean, string
function SpectateService.start(source, target)
    if target.source == source then return false, 'Tu ne peux pas te regarder toi-même.' end
    local admin = PlayerService.get(source)
    if not admin or not admin.mode or admin.mode ~= target.mode then
        return false, 'Ce joueur est dans un autre mode.'
    end

    local watch = SpectateService.watching[source]
    if not watch then
        if admin.dead then return false, 'Tu es mort.' end
        if SpectateService.inActivity(source) then return false, 'Quitte d\'abord ta partie ou ta file d\'attente.' end
        watch = { mode = admin.mode }
        SpectateService.watching[source] = watch
    end
    watch.target = target.source
    SpectateService.follow(source, watch)
    return true, ('Tu regardes %s.'):format(target.name)
end

---Place l'admin dans le bucket du joueur regardé et lui envoie où il en est.
---@param source integer
---@param watch SpectateWatch
function SpectateService.follow(source, watch)
    local bucket = GetPlayerRoutingBucket(watch.target)
    if bucket ~= watch.bucket then
        watch.bucket = bucket
        SetPlayerRoutingBucket(source, bucket)
    end
    watch.label = SpectateService.describe(watch.target)
    TriggerClientEvent(Events.client.spectate, source, {
        target = watch.target,
        name = GetPlayerName(watch.target) or '?',
        label = watch.label or false,
        coords = GetEntityCoords(GetPlayerPed(watch.target)),
    })
end

---Arrête le mode spectateur et ramène l'admin dans le bucket de son mode.
---@param source integer
---@return boolean, string
function SpectateService.stop(source)
    local watch = SpectateService.watching[source]
    if not watch then return false, 'Tu ne regardes personne.' end
    SpectateService.watching[source] = nil

    local admin = PlayerService.get(source)
    local config = admin and admin.mode == watch.mode and ModeRegistry.getConfig(watch.mode)
    if config then SetPlayerRoutingBucket(source, config.bucket) end
    TriggerClientEvent(Events.client.spectate, source, false)
    return true, 'Mode spectateur arrêté.'
end

---Flèches du spectateur : joueur suivant ou précédent au même endroit (même bucket et même mode),
---ex : l'adversaire dans une course poursuite.
---@param source integer
---@param direction any 1 ou -1
function SpectateService.next(source, direction)
    local watch = SpectateService.watching[source]
    if not watch or not AdminService.isAdmin(source) then return end

    local candidates = {}
    for id, player in pairs(PlayerService.all()) do
        if id ~= source and player.mode == watch.mode and GetPlayerRoutingBucket(id) == watch.bucket then
            candidates[#candidates + 1] = id
        end
    end
    table.sort(candidates)
    if #candidates < 2 then
        return TriggerClientEvent(Events.client.notify, source, 'Personne d\'autre à regarder ici.', 'info')
    end

    local index = 1
    for i, id in ipairs(candidates) do
        if id == watch.target then index = i end
    end
    index = (index - 1 + (direction == -1 and -1 or 1)) % #candidates + 1
    local target = PlayerService.get(candidates[index])
    if target then SpectateService.start(source, target) end
end

---Suit le joueur regardé (changement de bucket, position) ; s'arrête s'il part ou si l'admin change de mode.
function SpectateService.watchLoop()
    while true do
        Wait(SpectateService.CHECK_INTERVAL)
        for source, watch in pairs(SpectateService.watching) do
            local admin = PlayerService.get(source)
            local target = PlayerService.get(watch.target)
            if not admin or admin.mode ~= watch.mode then
                -- Passé au lobby (ou dans un autre mode) : le changement de mode a déjà réglé son bucket
                SpectateService.watching[source] = nil
                TriggerClientEvent(Events.client.spectate, source, false)
            elseif not target or target.mode ~= watch.mode then
                SpectateService.stop(source)
                admin:notify('Le joueur que tu regardais a quitté le mode.', 'info')
            else
                SpectateService.follow(source, watch)
            end
        end
    end
end
