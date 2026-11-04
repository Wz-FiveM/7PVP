---Outils de développement.
---@class DevModule
local Dev = PVP.define('Dev')
local Nui = PVP.use('Nui')
local PedUtils = PVP.use('PedUtils')
local Locale = PVP.use('Locale')

function Dev.init()
    -- /coords : copie sa position, pour la coller dans une config (zones, donjon, PNJ...)
    for _, name in ipairs({ 'coords', 'pvp_coords' }) do
        RegisterCommand(name, function()
            local text = Dev.coordsText()
            Dev.copy(text, Locale.t('Position copiée : %s', text))
        end, false)
    end
    -- /interieur : ce que le jeu sait de l'intérieur où l'on est (souterrains du donjon)
    RegisterCommand('interieur', function()
        CreateThread(function()
            Dev.copy(Dev.interiorReport(), Locale.t('Diagnostic de l\'intérieur copié (aussi dans F8).'))
        end)
    end, false)
end

---@return string vector4 de la position et du cap du joueur
function Dev.coordsText()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z, GetEntityHeading(ped))
end

---Dans le presse-papiers, et dans F8 dans tous les cas.
---@param text string
---@param copied string notification si la copie a marché
function Dev.copy(text, copied)
    print(text)
    Nui.send('copy', {
        text = text,
        copied = copied,
        failed = Locale.t('Copie impossible : le texte est dans F8.'),
    })
end

---@return string
function Dev.interiorReport()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local lines = {
        Dev.coordsText(),
        ('personnage : intérieur %d, pièce %d'):format(GetInteriorFromEntity(ped), GetRoomKeyFromEntity(ped)),
    }
    local interior = GetInteriorAtCoords(coords.x, coords.y, coords.z)
    if interior == 0 then
        lines[#lines + 1] = 'aucun intérieur à cette position'
    else
        local px, py, pz = GetInteriorPosition(interior)
        local qx, qy, qz, qw = GetInteriorRotation(interior)
        lines[#lines + 1] = ('intérieur %d : valide %s, prêt %s, désactivé %s, origine %.2f %.2f %.2f, rotation %.3f %.3f %.3f %.3f')
            :format(interior, tostring(IsValidInterior(interior)), tostring(IsInteriorReady(interior)),
                tostring(IsInteriorDisabled(interior)), px, py, pz, qx, qy, qz, qw)
        local count = GetInteriorRoomCount(interior) or 0
        local inside = PedUtils.roomIndexAt(interior, coords)
        for index = 0, count - 1 do
            local minX, minY, minZ, maxX, maxY, maxZ = GetInteriorRoomExtents(interior, index)
            lines[#lines + 1] = ('  pièce %d %s (%d) : %.1f %.1f %.1f -> %.1f %.1f %.1f%s'):format(index,
                GetInteriorRoomName(interior, index), GetHashKey(GetInteriorRoomName(interior, index)),
                minX, minY, minZ, maxX, maxY, maxZ, inside == index and '  <- ici' or '')
        end
        for _, inverse in ipairs({ true, false }) do
            local point = PedUtils.toInterior(interior, coords, inverse)
            lines[#lines + 1] = ('  repère local (%s) : %.1f %.1f %.1f'):format(inverse and 'inverse' or 'direct', point.x, point.y, point.z)
        end
    end
    local found, ground, covered = PedUtils.findFloor(coords.x, coords.y, coords.z)
    lines[#lines + 1] = ('sol : trouvé %s, z %.2f, dans une pièce %s'):format(tostring(found), ground, tostring(covered))
    local ix, iy, iz = PedUtils.findIndoorFloor(coords.x, coords.y, coords.z)
    lines[#lines + 1] = ix and ('sol d\'intérieur le plus proche : %.2f, %.2f, %.2f'):format(ix, iy, iz)
        or 'aucun sol d\'intérieur à moins de 15 m'
    local active, total = 0, 0
    for _, name in ipairs(Config.Ipls.load) do
        if name:find('x17dlc_int_placement', 1, true) then
            total = total + 1
            if IsIplActive(name) then active = active + 1 end
        end
    end
    lines[#lines + 1] = ('IPL du donjon actifs : %d / %d'):format(active, total)
    return table.concat(lines, '\n')
end
