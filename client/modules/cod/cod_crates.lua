---Colis des séries du mode Call of Duty, côté client : copie locale qui tombe en parachute, repère sur la carte,
---touche maintenue pour l'ouvrir. Le serveur vérifie la distance et le temps, et tire le contenu au sort.
---@class CodCratesModule
local CodCrates = PVP.define('CodCrates')
local Cod = PVP.use('Cod')
local CodEffects = PVP.use('CodEffects')
local CodTablet = PVP.use('CodTablet')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local HelpNotify = PVP.use('HelpNotify')
local PedUtils = PVP.use('PedUtils')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CodCrates.CONTROL_ACTION = 38 -- INPUT_PICKUP (E)
CodCrates.FALL_HEIGHT = 120.0 -- m au-dessus du sol au départ de la chute
CodCrates.BLIP_SPRITE = 478
CodCrates.BLIP_COLOR = 5
CodCrates.MARKER = { 255, 196, 60, 120 }

---@type table<integer, table> id -> colis (données du serveur, landAt, ground, crate, chute, blip)
CodCrates.crates = {}
---@type table|nil colis en cours d'ouverture : crate, doneAt
CodCrates.opening = nil

function CodCrates.init()
    CodEffects.EXTERNAL.crateDrop = CodCrates.onDrop
    CodEffects.EXTERNAL.crateGone = CodCrates.onGone
end

---@param data { id: integer, owner: integer, x: number, y: number, z: number, fall: number }
function CodCrates.onDrop(data)
    local crate = data
    crate.landAt = GetGameTimer() + data.fall * 1000
    crate.ground = data.z
    CodCrates.crates[data.id] = crate
    crate.blip = AddBlipForCoord(data.x, data.y, data.z)
    SetBlipSprite(crate.blip, CodCrates.BLIP_SPRITE)
    SetBlipColour(crate.blip, CodCrates.BLIP_COLOR)
    CreateThread(function()
        CodCrates.createModels(crate)
    end)
end

---@param crate table
function CodCrates.createModels(crate)
    -- Se pose sur ce qui se trouve le plus haut à cet endroit : le point visé peut être sous un toit
    local found, ground = GetGroundZFor_3dCoord(crate.x, crate.y, crate.z + 50.0, false)
    if found then crate.ground = ground end

    local crateModel, chuteModel = GetHashKey(Config.Airdrops.model), GetHashKey(Config.Airdrops.parachute)
    if not PedUtils.loadModel(crateModel) or not PedUtils.loadModel(chuteModel) then return end
    if CodCrates.crates[crate.id] ~= crate then return end
    crate.crate = CreateObject(crateModel, crate.x, crate.y, crate.ground, false, false, false)
    FreezeEntityPosition(crate.crate, true)
    SetEntityCollision(crate.crate, false, false)
    if GetGameTimer() < crate.landAt then
        crate.chute = CreateObject(chuteModel, crate.x, crate.y, crate.ground, false, false, false)
        FreezeEntityPosition(crate.chute, true)
        SetEntityCollision(crate.chute, false, false)
    end
    SetModelAsNoLongerNeeded(crateModel)
    SetModelAsNoLongerNeeded(chuteModel)
end

---@param data { id: integer }
function CodCrates.onGone(data)
    local crate = CodCrates.crates[data.id]
    if crate then CodCrates.remove(crate) end
end

---@param crate table
function CodCrates.remove(crate)
    CodCrates.crates[crate.id] = nil
    if CodCrates.opening and CodCrates.opening.crate == crate then CodCrates.stopOpening() end
    if crate.blip and DoesBlipExist(crate.blip) then RemoveBlip(crate.blip) end
    if crate.crate and DoesEntityExist(crate.crate) then DeleteObject(crate.crate) end
    if crate.chute and DoesEntityExist(crate.chute) then DeleteObject(crate.chute) end
end

function CodCrates.clear()
    for _, crate in pairs(CodCrates.crates) do CodCrates.remove(crate) end
    CodCrates.stopOpening()
end

function CodCrates.stopOpening()
    if not CodCrates.opening then return end
    CodCrates.opening = nil
    Nui.send('codAction', { kind = false })
end

---@param now integer
function CodCrates.frame(now)
    if not next(CodCrates.crates) then return end
    local coords = GetEntityCoords(PlayerPedId())
    local nearby = nil
    for _, crate in pairs(CodCrates.crates) do
        CodCrates.update(crate, now)
        if now >= crate.landAt and #(coords.xy - vector2(crate.x, crate.y)) <= Config.Cod.crates.takeRange then
            nearby = crate
        end
    end
    CodCrates.updateOpening(nearby, now)
end

---Chute, puis le colis devient solide au sol et le parachute disparaît.
---@param crate table
---@param now integer
function CodCrates.update(crate, now)
    if now >= crate.landAt then
        if crate.chute then
            DeleteObject(crate.chute)
            crate.chute = nil
        end
        if crate.crate and not crate.landed then
            crate.landed = true
            SetEntityCoords(crate.crate, crate.x, crate.y, crate.ground, false, false, false, false)
            PlaceObjectOnGroundProperly(crate.crate)
            FreezeEntityPosition(crate.crate, true)
            SetEntityCollision(crate.crate, true, true)
        end
        local color = CodCrates.MARKER
        DrawMarker(1, crate.x, crate.y, crate.ground - 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 1.5,
            color[1], color[2], color[3], color[4], false, false, 2, false, nil, nil, false)
        return
    end
    local height = (crate.landAt - now) / (Config.Cod.crates.fallTime * 1000) * CodCrates.FALL_HEIGHT
    if crate.crate then SetEntityCoords(crate.crate, crate.x, crate.y, crate.ground + height, false, false, false, false) end
    if crate.chute then SetEntityCoords(crate.chute, crate.x, crate.y, crate.ground + height + 1.5, false, false, false, false) end
end

---@param nearby table|nil colis à portée
---@param now integer
function CodCrates.updateOpening(nearby, now)
    local settings = Config.Cod.crates
    if not nearby or not State.isAlive() or CodTablet.isActive() or Cod.ended then return CodCrates.stopOpening() end
    if not CodCrates.opening then
        HelpNotify.show(HelpNotify.controlKey(CodCrates.CONTROL_ACTION), Locale.t('Maintiens pour ouvrir le colis'))
    end
    if not IsControlPressed(0, CodCrates.CONTROL_ACTION) or IsNuiFocused() then return CodCrates.stopOpening() end

    if not CodCrates.opening or CodCrates.opening.crate ~= nearby then
        local hold = nearby.owner == Cod.match.self and settings.ownerHold or settings.otherHold
        CodCrates.opening = { crate = nearby, doneAt = now + hold * 1000 }
        Nui.send('codAction', { kind = 'crate', seconds = hold })
    elseif now >= CodCrates.opening.doneAt then
        CodCrates.stopOpening()
        TriggerServerEvent(Events.server.codCrateTake, nearby.id)
    end
end
