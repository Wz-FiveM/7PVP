---Connexion au serveur : vérifie la licence Rockstar et transmet des infos à l'écran
---de chargement (pseudo, joueurs en ligne) via deferrals.handover.
---@class ConnectionServiceModule
local ConnectionService = PVP.define('ConnectionService')
local Events = PVP.use('Events')
local BanRepository = PVP.use('BanRepository')

function ConnectionService.init()
    AddEventHandler('playerConnecting', function(name, _, deferrals)
        ConnectionService.onConnecting(source, name, deferrals)
    end)

    -- Bouton « Quitter » du menu pause (une déconnexion en combat reste une mort)
    RegisterNetEvent(Events.server.quit, function()
        DropPlayer(source, 'Tu as quitté 7PVP. À bientôt !')
    end)
end

---@param source integer
---@param name string
---@param deferrals table
function ConnectionService.onConnecting(source, name, deferrals)
    deferrals.defer()
    Wait(0)

    local license = GetPlayerIdentifierByType(source, 'license')
    if not license then
        return deferrals.done('7PVP : une licence Rockstar est nécessaire. Relance FiveM connecté à ton compte.')
    end

    local ban = BanRepository.find(license)
    if ban then
        local until_ = ban.expires_at and ('jusqu\'au %s'):format(ban.expires_at) or 'définitivement'
        return deferrals.done(('7PVP : tu es banni %s.\nRaison : %s'):format(until_, ban.reason))
    end

    -- Lu par l'écran de chargement (window.nuiHandoverData)
    deferrals.handover({
        name = name,
        players = #GetPlayers(),
        maxPlayers = GetConvarInt('sv_maxclients', 48),
    })
    deferrals.done()
end
