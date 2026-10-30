---Colis des séries du mode Call of Duty (Config.Cod.crates) : ils tombent en parachute et s'ouvrent sur place,
---plus vite pour celui qui les a appelés, plus lentement pour les autres, ennemis compris. Chacun contient une
---série tirée au sort. Le serveur tire le contenu et vérifie la distance et le temps d'ouverture.
---@class CodCratesModule
local CodCrates = PVP.define('CodCrates')
local CodStreaks = PVP.use('CodStreaks')
local CodProfileService = PVP.use('CodProfileService')
local Events = PVP.use('Events')

---@param match table
function CodCrates.setup(match)
    match.crates = {}
    match.nextCrate = 1
end

---@param crate table
---@param now integer
---@return table
function CodCrates.describe(crate, now)
    return {
        type = 'crateDrop',
        id = crate.id,
        owner = crate.owner,
        x = crate.x, y = crate.y, z = crate.z,
        fall = math.max(0, (crate.landAt - now) / 1000),
    }
end

---@param match table
---@param source integer
---@param point vector3
---@param count integer
function CodCrates.drop(match, source, point, count)
    local settings = Config.Cod.crates
    local now = GetGameTimer()
    for index = 1, count do
        local angle = 2 * math.pi * index / count
        local distance = count > 1 and settings.spread or 0.0
        local crate = {
            id = match.nextCrate,
            owner = source,
            x = point.x + math.cos(angle) * distance,
            y = point.y + math.sin(angle) * distance,
            z = point.z,
            landAt = now + settings.fallTime * 1000,
            endsAt = now + (settings.fallTime + settings.lifetime) * 1000,
        }
        match.nextCrate = match.nextCrate + 1
        match.crates[crate.id] = crate
        match:broadcast(Events.client.codEffect, CodCrates.describe(crate, now))
    end
end

---@param match table
---@param id integer
function CodCrates.remove(match, id)
    match.crates[id] = nil
    match:broadcast(Events.client.codEffect, { type = 'crateGone', id = id })
end

---@param match table
---@param now integer
function CodCrates.tick(match, now)
    for id, crate in pairs(match.crates) do
        if now >= crate.endsAt then CodCrates.remove(match, id) end
    end
end

---@param match table
function CodCrates.clear(match)
    for id in pairs(match.crates) do CodCrates.remove(match, id) end
end

---Partie rejointe en cours : les colis déjà largués.
---@param match table
---@param source integer
function CodCrates.sendActive(match, source)
    local now = GetGameTimer()
    for _, crate in pairs(match.crates) do
        TriggerClientEvent(Events.client.codEffect, source, CodCrates.describe(crate, now))
    end
end

---@return table série tirée au sort selon les poids de Config.Cod.crates.contents
function CodCrates.pick()
    local contents = Config.Cod.crates.contents
    local total = 0
    for _, entry in ipairs(contents) do total = total + entry.weight end
    local roll = math.random() * total
    for _, entry in ipairs(contents) do
        roll = roll - entry.weight
        if roll <= 0 then return CodProfileService.streaks[entry.id] end
    end
    return CodProfileService.streaks[contents[1].id]
end

---Le joueur a fini d'ouvrir le colis.
---@param match table
---@param source integer
---@param id any
function CodCrates.take(match, source, id)
    local settings = Config.Cod.crates
    local crate = match.crates[tonumber(id)]
    local stats = match.stats[source]
    if match.phase ~= 'running' or not crate or not stats or not stats.alive then return end
    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped).xy - vector2(crate.x, crate.y)) > settings.takeRange then return end
    local hold = crate.owner == source and settings.ownerHold or settings.otherHold
    if GetGameTimer() < crate.landAt + hold * 1000 then return end

    CodCrates.remove(match, crate.id)
    CodStreaks.give(match, source, CodCrates.pick())
    CodStreaks.sendState(match, source)
end
