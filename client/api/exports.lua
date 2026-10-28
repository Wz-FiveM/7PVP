---API publique client, accessible depuis les autres ressources :
---    exports['7PVP']:isInSafeZone()
---@class ClientApiModule
local ClientApi = PVP.define('ClientApi')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Zones = PVP.use('Zones')
local HelpNotify = PVP.use('HelpNotify')

ClientApi.EXPORTS = {
    'getPlayer', 'isDead', 'getZone', 'isInSafeZone', 'openMenu', 'closeMenu', 'notify',
    'showHelpNotification', 'hideHelpNotification',
}

function ClientApi.init()
    for _, name in ipairs(ClientApi.EXPORTS) do
        exports(name, ClientApi[name])
    end
end

---@return table|nil dernière synchro serveur du joueur local
function ClientApi.getPlayer()
    return State.player
end

---@return boolean
function ClientApi.isDead()
    return State.dead
end

---@return ZoneInfo
function ClientApi.getZone()
    return Zones.toInfo(State.zone)
end

---@return boolean
function ClientApi.isInSafeZone()
    return State.isInSafeZone()
end

function ClientApi.openMenu()
    Nui.setMenu(true)
end

function ClientApi.closeMenu()
    Nui.setMenu(false)
end

---@param text string
---@param kind? 'info'|'success'|'error'
function ClientApi.notify(text, kind)
    Nui.notify(text, kind)
end

---Aide (touche + texte) dans le style de 7PVP. À appeler à chaque image tant qu'elle doit rester :
---    exports['7PVP']:showHelpNotification('Ouvrir le coffre', 'E')
---@param text string
---@param key? string touche affichée (défaut : la touche d'interaction, E)
function ClientApi.showHelpNotification(text, key)
    HelpNotify.show(key or HelpNotify.controlKey(38), text)
end

function ClientApi.hideHelpNotification()
    HelpNotify.hide()
end
