---Outils de développement.
---@class DevModule
local Dev = PVP.define('Dev')
local Nui = PVP.use('Nui')
local Locale = PVP.use('Locale')

function Dev.init()
    -- /coords : copie sa position, pour la coller dans une config (zones, donjon, PNJ...)
    for _, name in ipairs({ 'coords', 'pvp_coords' }) do
        RegisterCommand(name, function()
            Dev.copyCoords()
        end, false)
    end
end

---@return string vector4 de la position et du cap du joueur
function Dev.coordsText()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z, GetEntityHeading(ped))
end

---Dans le presse-papiers, et dans F8 si la copie échoue.
function Dev.copyCoords()
    local text = Dev.coordsText()
    print(text)
    Nui.send('copy', {
        text = text,
        copied = Locale.t('Position copiée : %s', text),
        failed = Locale.t('Copie impossible, ta position est dans F8 : %s', text),
    })
end
