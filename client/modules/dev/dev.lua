---Outils de développement.
---@class DevModule
local Dev = PVP.define('Dev')
local Nui = PVP.use('Nui')

function Dev.init()
    RegisterCommand('pvp_coords', function()
        Dev.printCoords()
    end, false)
end

function Dev.printCoords()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local text = ('vector4(%.1f, %.1f, %.1f, %.1f)'):format(coords.x, coords.y, coords.z, GetEntityHeading(ped))
    print(text)
    Nui.notify(text, 'info')
end
