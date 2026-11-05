---Décor des zones safe du PvP (config/safe_decor.lua) : un coin aménagé autour de chaque PNJ de
---service. Les objets sont créés localement quand le joueur approche d'une zone, dans le repère
---du PNJ : ils le suivent quand un admin le déplace (la zone est refaite dès que ses PNJ ou ses
---points d'apparition changent).
---
---Chaque objet est posé au sol avec sa vraie taille (GetModelDimensions). Il est laissé de côté
---s'il gêne (PNJ, place devant un PNJ, point d'apparition, repère du mécanicien, autre objet du
---décor), s'il touche un mur ou un objet de la carte, ou si le sol n'est pas à la hauteur du PNJ.
---@class SafeDecorModule
local SafeDecor = PVP.define('SafeDecor')
local State = PVP.use('State')
local Zones = PVP.use('Zones')
local Logger = PVP.use('Logger')

SafeDecor.LOOP_INTERVAL = 1000
SafeDecor.MODEL_TIMEOUT = 5000
SafeDecor.GROUND_TRIES = 10 -- passages de la boucle à attendre le sol sous les PNJ, puis on pose quand même
SafeDecor.PROBE_FLAGS = 1 + 16 -- carte et objets (pas les véhicules ni les personnages)
SafeDecor.PROBE_HEIGHT = 0.5 -- hauteur des rayons de contrôle au-dessus du sol (au-dessus des trottoirs)
SafeDecor.OVERLAP_TOLERANCE = 0.05 -- deux objets qui se touchent à moins de 5 cm ne se gênent pas
SafeDecor.PER_FRAME = 8 -- objets créés par image

---@type table<string, { objects: integer[], signature: string, report: string[] }> id de zone -> décor posé
SafeDecor.built = {}
---@type table<string, boolean>
SafeDecor.building = {}
---@type table<string, integer>
SafeDecor.groundWaits = {}
---@type table<string, boolean> modèles absents du jeu, signalés une fois
SafeDecor.missing = {}

function SafeDecor.init()
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then SafeDecor.clearAll() end
    end)
    -- /pvp_decor : refait le décor des zones proches et écrit dans F8 ce qui a été posé ou écarté
    RegisterCommand('pvp_decor', function()
        for _, built in pairs(SafeDecor.built) do built.signature = '' end
        SafeDecor.printReport = true
    end, false)
    CreateThread(SafeDecor.loop)
end

-- ---------------------------------------------------------------------------
-- Géométrie (2D, sans natif) : repère du PNJ, boîtes orientées
-- ---------------------------------------------------------------------------

---Rotation d'un cap GTA (degrés, sens inverse des aiguilles d'une montre) : (0, 1) devient l'avant.
---@return number, number
function SafeDecor.rotate(x, y, degrees)
    local r = math.rad(degrees)
    local c, s = math.cos(r), math.sin(r)
    return x * c - y * s, x * s + y * c
end

---Largeur et profondeur (le long de x et de y) d'une boîte sx × sy tournée de `degrees`.
---@return number, number
function SafeDecor.extents(sx, sy, degrees)
    local r = math.rad(degrees)
    local c, s = math.abs(math.cos(r)), math.abs(math.sin(r))
    return sx * c + sy * s, sx * s + sy * c
end

---@class DecorBox
---@field x number centre
---@field y number
---@field hx number demi-largeur (axe x de l'objet)
---@field hy number demi-profondeur
---@field angle number cap en degrés

---@param box DecorBox
---@param cx number
---@param cy number
---@param radius number
---@return boolean le cercle touche la boîte
function SafeDecor.boxHitsCircle(box, cx, cy, radius)
    local lx, ly = SafeDecor.rotate(cx - box.x, cy - box.y, -box.angle)
    local nx = math.max(-box.hx, math.min(box.hx, lx))
    local ny = math.max(-box.hy, math.min(box.hy, ly))
    local dx, dy = lx - nx, ly - ny
    return dx * dx + dy * dy < radius * radius
end

---Séparation des axes : deux boîtes orientées se chevauchent si aucun de leurs 4 axes ne les sépare.
---@param a DecorBox
---@param b DecorBox
---@param tolerance number réduit chaque boîte d'autant
---@return boolean
function SafeDecor.boxesOverlap(a, b, tolerance)
    local ahx, ahy = math.max(a.hx - tolerance, 0), math.max(a.hy - tolerance, 0)
    local bhx, bhy = math.max(b.hx - tolerance, 0), math.max(b.hy - tolerance, 0)
    local aux, auy = SafeDecor.rotate(1, 0, a.angle)
    local avx, avy = SafeDecor.rotate(0, 1, a.angle)
    local bux, buy = SafeDecor.rotate(1, 0, b.angle)
    local bvx, bvy = SafeDecor.rotate(0, 1, b.angle)
    local dx, dy = b.x - a.x, b.y - a.y
    for _, axis in ipairs({ { aux, auy }, { avx, avy }, { bux, buy }, { bvx, bvy } }) do
        local px, py = axis[1], axis[2]
        local ra = ahx * math.abs(aux * px + auy * py) + ahy * math.abs(avx * px + avy * py)
        local rb = bhx * math.abs(bux * px + buy * py) + bhy * math.abs(bvx * px + bvy * py)
        if math.abs(dx * px + dy * py) >= ra + rb then return false end
    end
    return true
end

---@param box DecorBox
---@return { [1]: number, [2]: number }[] les 4 coins
function SafeDecor.corners(box)
    local list = {}
    for _, sign in ipairs({ { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }) do
        local ox, oy = SafeDecor.rotate(box.hx * sign[1], box.hy * sign[2], box.angle)
        list[#list + 1] = { box.x + ox, box.y + oy }
    end
    return list
end

-- ---------------------------------------------------------------------------
-- Plan d'une station, dans le repère du PNJ
-- ---------------------------------------------------------------------------

---@class DecorDims
---@field sx number taille le long de l'axe x du modèle
---@field sy number
---@field cx number centre de la boîte du modèle par rapport à son origine
---@field cy number
---@field minZ number
---@field maxZ number

---@class DecorItem
---@field model string
---@field x number origine de l'objet (repère du PNJ)
---@field y number
---@field h number cap par rapport au PNJ
---@field box DecorBox emprise (repère du PNJ)
---@field dims DecorDims
---@field top DecorItem[]|nil objets posés dessus

---Objet centré sur (bx, by) : origine décalée du centre de sa boîte.
---@param model string
---@param dims DecorDims
---@param bx number
---@param by number
---@param h number
---@return DecorItem
function SafeDecor.placeItem(model, dims, bx, by, h)
    local ox, oy = SafeDecor.rotate(dims.cx, dims.cy, h)
    return {
        model = model,
        x = bx - ox,
        y = by - oy,
        h = h,
        dims = dims,
        box = { x = bx, y = by, hx = dims.sx / 2, hy = dims.sy / 2, angle = h },
    }
end

---Objets posés sur `base`, répartis sur sa largeur.
---@param base DecorItem
---@param tops (string|table)[]
---@param dimsOf fun(model: string): DecorDims|nil
---@return DecorItem[]
function SafeDecor.layoutTop(base, tops, dimsOf)
    local list = {}
    local count = #tops
    for index, entry in ipairs(tops) do
        local spec = type(entry) == 'table' and entry or { entry }
        local dims = dimsOf(spec[1])
        if dims then
            -- Point sur le dessus de la base, dans le repère du modèle de la base
            local mx = base.dims.cx - base.dims.sx / 2 + base.dims.sx * (index - 0.5) / count
            local my = base.dims.cy
            local ox, oy = SafeDecor.rotate(mx, my, base.h)
            list[#list + 1] = SafeDecor.placeItem(spec[1], dims, base.x + ox, base.y + oy, base.h + (spec.h or 0))
        end
    end
    return list
end

---Tous les objets d'une station (rangées et objets seuls), dans l'ordre de la config.
---@param station table Config.SafeDecor.stations[rôle]
---@param dimsOf fun(model: string): DecorDims|nil nil : modèle absent
---@param gap number
---@return DecorItem[]
function SafeDecor.layout(station, dimsOf, gap)
    local items = {}
    local back = nil -- bord arrière de la dernière rangée de fond (y le plus petit)
    for _, part in ipairs(station) do
        if part.model then
            local dims = dimsOf(part.model)
            if dims then items[#items + 1] = SafeDecor.placeItem(part.model, dims, part.at.x, part.at.y, part.h or 0) end
        elseif part.items then
            back = SafeDecor.layoutRow(part, dimsOf, part.gap or gap, back, items)
        end
    end
    return items
end

---@param part table rangée de la config
---@param dimsOf fun(model: string): DecorDims|nil
---@param gap number
---@param back number|nil bord arrière de la rangée de fond précédente
---@param items DecorItem[] complétée
---@return number|nil nouveau bord arrière
function SafeDecor.layoutRow(part, dimsOf, gap, back, items)
    local axis = part.axis or 'x'
    local rowH = part.h or 0
    local at = part.at or { x = 0.0, y = 0.0 }
    local alongStart = axis == 'x' and at.x or at.y
    local line = axis == 'x' and at.y or at.x
    if part.behind then
        if not back then return back end
        line = back - gap * 2
    end
    local away = line > 0 and 1 or -1

    local entries, total = {}, 0
    for _, entry in ipairs(part.items) do
        local spec = type(entry) == 'table' and entry or { entry }
        local dims = dimsOf(spec[1])
        if dims then
            local h = rowH + (spec.h or 0)
            local width, depth = SafeDecor.extents(dims.sx, dims.sy, h)
            local along = axis == 'x' and width or depth
            local across = axis == 'x' and depth or width
            entries[#entries + 1] = { spec = spec, dims = dims, h = h, along = along, across = across }
            total = total + along
        end
    end
    if #entries == 0 then return back end
    total = total + gap * (#entries - 1)

    local dir = part.dir or 1
    local cursor = part.dir and alongStart or alongStart - total / 2
    for _, entry in ipairs(entries) do
        local centerAlong = cursor + dir * entry.along / 2
        local centerAcross = line + away * entry.across / 2
        cursor = cursor + dir * (entry.along + gap)
        local bx = axis == 'x' and centerAlong or centerAcross
        local by = axis == 'x' and centerAcross or centerAlong
        local item = SafeDecor.placeItem(entry.spec[1], entry.dims, bx, by, entry.h)
        if entry.spec.top then item.top = SafeDecor.layoutTop(item, entry.spec.top, dimsOf) end
        items[#items + 1] = item
        if axis == 'x' and away < 0 then
            local edge = by - entry.across / 2
            if not back or edge < back then back = edge end
        end
    end
    return back
end

-- ---------------------------------------------------------------------------
-- Zone : stations, places à garder libres, signature
-- ---------------------------------------------------------------------------

---@param npc table
---@param lx number
---@param ly number
---@return number, number position monde d'un point du repère du PNJ
function SafeDecor.toWorld(npc, lx, ly)
    local ox, oy = SafeDecor.rotate(lx, ly, npc.coords.w)
    return npc.coords.x + ox, npc.coords.y + oy
end

---@param zone table
---@return { npc: table, station: table }[]
function SafeDecor.stationsOf(zone)
    local list = {}
    for _, npc in ipairs(Config.SafeNpcs.npcs) do
        local station = npc.zone == zone.id and Config.SafeDecor.stations[npc.role]
        if station then list[#list + 1] = { npc = npc, station = station } end
    end
    return list
end

---Cercles à garder libres dans la zone : chaque PNJ et la place devant lui, les points
---d'apparition et le repère du mécanicien.
---@param zone table
---@return { x: number, y: number, r: number, label: string }[]
function SafeDecor.clearings(zone)
    local clear = Config.SafeDecor.clear
    local list = {}
    for _, npc in ipairs(Config.SafeNpcs.npcs) do
        if npc.zone == zone.id then
            list[#list + 1] = { x = npc.coords.x, y = npc.coords.y, r = clear.npc, label = 'PNJ ' .. npc.role }
            local fx, fy = SafeDecor.toWorld(npc, 0.0, clear.front.y)
            list[#list + 1] = { x = fx, y = fy, r = clear.front.radius, label = 'devant le PNJ ' .. npc.role }
            if npc.role == Config.VehicleCustom.role then
                local vx, vy = SafeDecor.toWorld(npc, 0.0, Config.VehicleCustom.spotOffset)
                list[#list + 1] = { x = vx, y = vy, r = Config.VehicleCustom.spotRadius + clear.vehicle, label = 'repère du mécanicien' }
            end
        end
    end
    for _, spawn in ipairs(zone.spawns or {}) do
        list[#list + 1] = { x = spawn.x, y = spawn.y, r = clear.spawn, label = 'point d\'apparition' }
    end
    return list
end

---@param zone table
---@return string change dès qu'un PNJ, un point d'apparition ou la zone bouge
function SafeDecor.signature(zone)
    local parts = { ('%.2f,%.2f'):format(zone.coords.x, zone.coords.y) }
    for _, npc in ipairs(Config.SafeNpcs.npcs) do
        if npc.zone == zone.id then
            local c = npc.coords
            parts[#parts + 1] = ('%s:%.2f,%.2f,%.2f,%.1f'):format(npc.role, c.x, c.y, c.z, c.w)
        end
    end
    for _, spawn in ipairs(zone.spawns or {}) do
        parts[#parts + 1] = ('%.2f,%.2f'):format(spawn.x, spawn.y)
    end
    return table.concat(parts, '|')
end

---Plan de la zone en coordonnées monde : chaque objet de base est gardé s'il ne touche ni une
---place libre ni un objet déjà retenu (premier arrivé, premier servi). Sans natif.
---@param zone table
---@param stations { npc: table, station: table }[]
---@param dimsOf fun(model: string): DecorDims|nil
---@return { npc: table, item: DecorItem, box: DecorBox }[] retenus
---@return string[] écartés (raison)
function SafeDecor.plan(zone, stations, dimsOf)
    local clearings = SafeDecor.clearings(zone)
    local kept, rejected = {}, {}
    for _, entry in ipairs(stations) do
        local npc = entry.npc
        for _, item in ipairs(SafeDecor.layout(entry.station, dimsOf, Config.SafeDecor.gap)) do
            local wx, wy = SafeDecor.toWorld(npc, item.box.x, item.box.y)
            local box = { x = wx, y = wy, hx = item.box.hx, hy = item.box.hy, angle = npc.coords.w + item.h }
            local reason = nil
            for _, spot in ipairs(clearings) do
                if SafeDecor.boxHitsCircle(box, spot.x, spot.y, spot.r) then reason = spot.label break end
            end
            if not reason then
                for _, other in ipairs(kept) do
                    if SafeDecor.boxesOverlap(box, other.box, SafeDecor.OVERLAP_TOLERANCE) then reason = 'touche ' .. other.item.model break end
                end
            end
            if reason then
                rejected[#rejected + 1] = ('%s %s : %s'):format(npc.role, item.model, reason)
            else
                kept[#kept + 1] = { npc = npc, item = item, box = box }
            end
        end
    end
    return kept, rejected
end

-- ---------------------------------------------------------------------------
-- Dans le jeu : modèles, sol, rayons, création
-- ---------------------------------------------------------------------------

---@param stations { npc: table, station: table }[]
---@return table<string, DecorDims> modèles chargés
function SafeDecor.loadModels(stations)
    local names = {}
    local function add(entry)
        local name = type(entry) == 'table' and (entry.model or entry[1]) or entry
        if name then names[name] = true end
        if type(entry) == 'table' and entry.top then
            for _, top in ipairs(entry.top) do add(top) end
        end
    end
    for _, entry in ipairs(stations) do
        for _, part in ipairs(entry.station) do
            if part.items then
                for _, item in ipairs(part.items) do add(item) end
            else
                add(part)
            end
        end
    end

    local pending = {}
    for name in pairs(names) do
        local hash = GetHashKey(name)
        if IsModelInCdimage(hash) then
            RequestModel(hash)
            pending[name] = hash
        elseif not SafeDecor.missing[name] then
            SafeDecor.missing[name] = true
            Logger.warn('Décor des zones safe : modèle %s introuvable', name)
        end
    end
    local deadline = GetGameTimer() + SafeDecor.MODEL_TIMEOUT
    local loaded = {}
    while next(pending) and GetGameTimer() < deadline do
        for name, hash in pairs(pending) do
            if HasModelLoaded(hash) then
                local min, max = GetModelDimensions(hash)
                if max.x - min.x > 0.01 and max.y - min.y > 0.01 then
                    loaded[name] = {
                        hash = hash,
                        sx = max.x - min.x, sy = max.y - min.y,
                        cx = (min.x + max.x) / 2, cy = (min.y + max.y) / 2,
                        minZ = min.z, maxZ = max.z,
                    }
                end
                pending[name] = nil
            end
        end
        Wait(0)
    end
    return loaded
end

---@return number|nil hauteur du sol sous (x, y), cherchée depuis `fromZ`
function SafeDecor.groundAt(x, y, fromZ)
    local found, z = GetGroundZFor_3dCoord(x, y, fromZ, false)
    if found then return z end
    return nil
end

---@return boolean un mur ou un objet de la carte coupe le segment
function SafeDecor.blocked(x1, y1, z1, x2, y2, z2)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(x1, y1, z1, x2, y2, z2, SafeDecor.PROBE_FLAGS, 0, 7)
    local _, hit = GetShapeTestResult(handle)
    return hit == 1 or hit == true
end

---Contrôles dans le monde : sol à la hauteur du PNJ, rien entre le PNJ et l'objet, rien dans
---l'emprise de l'objet (bords et diagonales).
---@param box DecorBox monde
---@param npc table
---@param npcGround number
---@return number|nil sol sous l'objet
---@return string|nil raison si écarté
function SafeDecor.checkWorld(box, npc, npcGround)
    local ground = SafeDecor.groundAt(box.x, box.y, npcGround + 2.0)
    if not ground then return nil, 'pas de sol' end
    if math.abs(ground - npcGround) > Config.SafeDecor.maxStep then return nil, ('sol à %.1f m du PNJ'):format(ground - npcGround) end

    local z = ground + SafeDecor.PROBE_HEIGHT
    local fromZ = npcGround + SafeDecor.PROBE_HEIGHT
    if SafeDecor.blocked(npc.coords.x, npc.coords.y, fromZ, box.x, box.y, z) then return nil, 'mur entre le PNJ et l\'objet' end
    local shrunk = { x = box.x, y = box.y, hx = math.max(box.hx - 0.05, 0.01), hy = math.max(box.hy - 0.05, 0.01), angle = box.angle }
    local c = SafeDecor.corners(shrunk)
    local segments = { { c[1], c[2] }, { c[2], c[3] }, { c[3], c[4] }, { c[4], c[1] }, { c[1], c[3] }, { c[2], c[4] } }
    for _, segment in ipairs(segments) do
        local a, b = segment[1], segment[2]
        if SafeDecor.blocked(a[1], a[2], z, b[1], b[2], z) then return nil, 'objet ou mur de la carte dans l\'emprise' end
    end
    return ground, nil
end

---@param dims DecorDims
---@param wx number origine monde
---@param wy number
---@param bottom number hauteur où poser le bas de l'objet
---@param heading number
---@return integer|nil
function SafeDecor.spawn(dims, wx, wy, bottom, heading)
    local object = CreateObjectNoOffset(dims.hash, wx, wy, bottom - dims.minZ, false, false, false)
    if not object or object == 0 then return nil end
    SetEntityHeading(object, heading % 360.0)
    FreezeEntityPosition(object, true)
    SetEntityInvincible(object, true)
    SetEntityCanBeDamaged(object, false)
    return object
end

---Dessus d'un objet posé, sous (x, y) : rayon vers le bas sur l'objet, sinon le haut de sa boîte.
---@return number
function SafeDecor.surfaceOf(object, dims, x, y, bottom)
    local top = bottom + (dims.maxZ - dims.minZ)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(x, y, top + 0.5, x, y, bottom, 16, 0, 7)
    local _, hit, coords, _, entity = GetShapeTestResult(handle)
    if (hit == 1 or hit == true) and entity == object then return coords.z end
    return top
end

---@param zone table
---@param signature string
function SafeDecor.build(zone, signature)
    local stations = SafeDecor.stationsOf(zone)
    local grounds = {}
    for _, entry in ipairs(stations) do
        local c = entry.npc.coords
        local ground = SafeDecor.groundAt(c.x, c.y, c.z + 2.0)
        if not ground then
            local waits = (SafeDecor.groundWaits[zone.id] or 0) + 1
            SafeDecor.groundWaits[zone.id] = waits
            if waits < SafeDecor.GROUND_TRIES then return end
            ground = c.z
        end
        grounds[entry.npc] = ground
    end
    SafeDecor.groundWaits[zone.id] = nil

    -- L'ancien décor part d'abord : les rayons de contrôle ne doivent pas le toucher
    SafeDecor.clear(zone.id)
    local models = SafeDecor.loadModels(stations)
    local kept, report = SafeDecor.plan(zone, stations, function(name) return models[name] end)

    -- Tous les contrôles avant de créer quoi que ce soit : les rayons ne doivent toucher que la carte
    local accepted = {}
    for index, entry in ipairs(kept) do
        local ground, reason = SafeDecor.checkWorld(entry.box, entry.npc, grounds[entry.npc])
        if reason then
            report[#report + 1] = ('%s %s : %s'):format(entry.npc.role, entry.item.model, reason)
        else
            entry.ground = ground
            accepted[#accepted + 1] = entry
        end
        if index % SafeDecor.PER_FRAME == 0 then Wait(0) end
    end

    local objects = {}
    local tops = {}
    for index, entry in ipairs(accepted) do
        local npc, item = entry.npc, entry.item
        local wx, wy = SafeDecor.toWorld(npc, item.x, item.y)
        local object = SafeDecor.spawn(item.dims, wx, wy, entry.ground, npc.coords.w + item.h)
        if object then
            objects[#objects + 1] = object
            if item.top then tops[#tops + 1] = { npc = npc, base = item, object = object, ground = entry.ground } end
        end
        if index % SafeDecor.PER_FRAME == 0 then Wait(0) end
    end

    -- Objets posés dessus, une fois les bases créées (leurs collisions servent à trouver le dessus)
    Wait(0)
    for _, entry in ipairs(tops) do
        for _, item in ipairs(entry.base.top) do
            local wx, wy = SafeDecor.toWorld(entry.npc, item.x, item.y)
            local bx, by = SafeDecor.toWorld(entry.npc, item.box.x, item.box.y)
            local surface = SafeDecor.surfaceOf(entry.object, entry.base.dims, bx, by, entry.ground)
            local object = SafeDecor.spawn(item.dims, wx, wy, surface + 0.01, entry.npc.coords.w + item.h)
            if object then objects[#objects + 1] = object end
        end
    end

    for _, dims in pairs(models) do SetModelAsNoLongerNeeded(dims.hash) end
    SafeDecor.built[zone.id] = { objects = objects, signature = signature, report = report }
    Logger.debug('Décor %s : %d objets, %d écartés', zone.id, #objects, #report)
    if SafeDecor.printReport then SafeDecor.print(zone.id) end
end

---@param zoneId string
function SafeDecor.print(zoneId)
    local built = SafeDecor.built[zoneId]
    if not built then return end
    print(('[7PVP] Décor %s : %d objets posés, %d écartés'):format(zoneId, #built.objects, #built.report))
    for _, line in ipairs(built.report) do print('  - ' .. line) end
end

---@param zone table
---@return boolean le décor de la zone doit exister autour du joueur
function SafeDecor.wanted(zone, pos)
    local config = Config.SafeDecor
    return config.enabled and State.mode ~= nil and config.modes[State.mode] == true
        and zone.type == 'safe' and Zones.inMode(zone, State.mode)
        and #(pos.xy - zone.coords.xy) <= zone.radius + config.buildDistance
end

function SafeDecor.loop()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for _, zone in ipairs(Config.Zones) do
            local built = SafeDecor.built[zone.id]
            if not SafeDecor.wanted(zone, pos) then
                if built and not SafeDecor.building[zone.id] then SafeDecor.clear(zone.id) end
            elseif not SafeDecor.building[zone.id] then
                local signature = SafeDecor.signature(zone)
                if not built or built.signature ~= signature then
                    SafeDecor.building[zone.id] = true
                    CreateThread(function()
                        local ok, err = pcall(SafeDecor.build, zone, signature)
                        if not ok then Logger.error('Décor %s : %s', zone.id, tostring(err)) end
                        SafeDecor.building[zone.id] = nil
                    end)
                end
            end
        end
        if SafeDecor.printReport and not next(SafeDecor.building) then SafeDecor.printReport = false end
        Wait(SafeDecor.LOOP_INTERVAL)
    end
end

---@param zoneId string
function SafeDecor.clear(zoneId)
    local built = SafeDecor.built[zoneId]
    if not built then return end
    for _, object in ipairs(built.objects) do
        if DoesEntityExist(object) then DeleteObject(object) end
    end
    SafeDecor.built[zoneId] = nil
end

function SafeDecor.clearAll()
    for zoneId in pairs(SafeDecor.built) do SafeDecor.clear(zoneId) end
end
