---Connexion au serveur : vérifie la licence Rockstar et transmet des infos à l'écran
---de chargement (pseudo, joueurs en ligne) via deferrals.handover.
---@class ConnectionServiceModule
local ConnectionService = PVP.define('ConnectionService')
local Events = PVP.use('Events')

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

    if not GetPlayerIdentifierByType(source, 'license') then
        return deferrals.done('7PVP : une licence Rockstar est nécessaire. Relance FiveM connecté à ton compte.')
    end

    -- Lu par l'écran de chargement (window.nuiHandoverData)
    deferrals.handover({
        name = name,
        players = #GetPlayers(),
        maxPlayers = GetConvarInt('sv_maxclients', 48),
    })
    deferrals.done()
end
