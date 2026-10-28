---Notification d'aide (touche + texte) dans le style de l'interface, à la place de l'aide de GTA.
---Comme l'aide native, on l'appelle à chaque image tant qu'elle doit rester affichée :
---    HelpNotify.show(HelpNotify.controlKey(38), 'Fouiller le corps')
---Elle disparaît d'elle-même dès qu'on arrête de l'appeler. Seuls les changements sont
---envoyés à l'interface, pas chaque image.
---@class HelpNotifyModule
local HelpNotify = PVP.define('HelpNotify')
local Nui = PVP.use('Nui')

HelpNotify.CHECK_INTERVAL = 50
-- Sans nouvel appel pendant ce délai (ms), l'aide est masquée
HelpNotify.TIMEOUT = 150

---@type { key: string, text: string }|nil
HelpNotify.current = nil
HelpNotify.lastCall = 0
HelpNotify.shown = ''

function HelpNotify.init()
    CreateThread(HelpNotify.loop)
end

---@param key string touche affichée (ex : E)
---@param text string action (ex : Fouiller le corps)
function HelpNotify.show(key, text)
    HelpNotify.current = { key = key, text = text }
    HelpNotify.lastCall = GetGameTimer()
end

---Masque l'aide tout de suite (sinon elle disparaît seule après TIMEOUT).
function HelpNotify.hide()
    HelpNotify.current = nil
end

---Touche réellement associée à un contrôle GTA (selon la disposition du clavier du joueur).
---@param control integer ex : 38 (INPUT_CONTEXT, E par défaut)
---@param fallback? string
---@return string
function HelpNotify.controlKey(control, fallback)
    local button = GetControlInstructionalButton(0, control, true) or ''
    return button:match('^t_(.+)$') or fallback or 'E'
end

function HelpNotify.loop()
    while true do
        Wait(HelpNotify.CHECK_INTERVAL)
        local current = HelpNotify.current
        local active = current ~= nil and GetGameTimer() - HelpNotify.lastCall < HelpNotify.TIMEOUT
        local id = active and (current.key .. '|' .. current.text) or ''
        if id ~= HelpNotify.shown then
            HelpNotify.shown = id
            Nui.send('helpNotify', { help = active and current or false })
        end
    end
end
