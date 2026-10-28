---Largages aériens côté client : repère sur la carte, caisse qui descend en parachute,
---fumigène et compte à rebours avant l'ouverture. La caisse ouverte devient un butin
---affiché par client/modules/loot/loot.lua.
---@class ClientAirdrop
---@field coords vector3 point d'atterrissage (z recalé sur le sol une fois chargé)
---@field landAt integer GetGameTimer() de l'atterrissage
---@field unlockAt integer GetGameTimer() de l'ouverture
---@field blip integer
---@field crate integer|nil
---@field chute integer|nil
---@field smoke integer|nil
---@field grounded boolean hauteur du sol trouvée

---@class AirdropModule
local Airdrop = PVP.define('Airdrop')
local State = PVP.use('State')
local Events = PVP.use('Events')

Airdrop.STREAM_DISTANCE = 450.0
Airdrop.TEXT_DISTANCE = 60.0

---@type table<integer, ClientAirdrop>
Airdrop.drops = {}

function Airdrop.init()
    RegisterNetEvent(Events.client.airdropSpawn, function(data)
        Airdrop.add(data)
    end)
    RegisterNetEvent(Events.client.airdropRemove, function(id)
        Airdrop.remove(id)
    end)
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
            for id in pairs(Airdrop.drops) do Airdrop.remove(id) end
        end
    end)
    CreateThread(Airdrop.renderLoop)
end

---@param data { id: integer, coords: vector3, landIn: integer, unlockIn: integer }
function Airdrop.add(data)
    Airdrop.remove(data.id)
    local now = GetGameTimer()
    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, Config.Airdrops.blip.sprite)
    SetBlipColour(blip, Config.Airdrops.blip.color)
    SetBlipScale(blip, 1.1)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Largage aérien')
    EndTextCommandSetBlipName(blip)

    Airdrop.drops[data.id] = {
        coords = data.coords,
        landAt = now + data.landIn * 1000,
        unlockAt = now + data.unlockIn * 1000,
        blip = blip,
        grounded = false,
    }
end

---@param id integer
function Airdrop.remove(id)
    local drop = Airdrop.drops[id]
    if not drop then return end
    if DoesBlipExist(drop.blip) then RemoveBlip(drop.blip) end
    Airdrop.deleteProps(drop)
    Airdrop.drops[id] = nil
end

---@param drop ClientAirdrop
function Airdrop.deleteProps(drop)
    for _, key in ipairs({ 'crate', 'chute' }) do
        if drop[key] and DoesEntityExist(drop[key]) then DeleteObject(drop[key]) end
        drop[key] = nil
    end
    if drop.smoke then
        StopParticleFxLooped(drop.smoke, false)
        drop.smoke = nil
    end
end

function Airdrop.renderLoop()
    while true do
        local needsFrame = false
        if State.inPvp() then
            local pos = GetEntityCoords(PlayerPedId())
            for _, drop in pairs(Airdrop.drops) do
                if Airdrop.render(drop, pos) then needsFrame = true end
            end
        else
            for _, drop in pairs(Airdrop.drops) do Airdrop.deleteProps(drop) end
        end
        Wait(needsFrame and 0 or 500)
    end
end

---@param drop ClientAirdrop
---@param pos vector3
---@return boolean true si le largage doit être mis à jour à chaque image
function Airdrop.render(drop, pos)
    local dist = #(pos.xy - drop.coords.xy)
    if dist > Airdrop.STREAM_DISTANCE then
        Airdrop.deleteProps(drop)
        return false
    end

    if not drop.grounded then Airdrop.findGround(drop) end
    if not drop.crate then Airdrop.createProps(drop) end

    local now = GetGameTimer()
    local falling = now < drop.landAt
    local height = falling and (drop.landAt - now) / (Config.Airdrops.fallTime * 1000) * Config.Airdrops.fallHeight or 0.0
    local z = drop.coords.z + height
    SetEntityCoords(drop.crate, drop.coords.x, drop.coords.y, z, false, false, false, false)

    if falling then
        SetEntityCoords(drop.chute, drop.coords.x, drop.coords.y, z + 1.0, false, false, false, false)
    elseif drop.chute then
        DeleteObject(drop.chute)
        drop.chute = nil
        Airdrop.startSmoke(drop)
    end

    if dist < Airdrop.TEXT_DISTANCE then
        local seconds = math.max(0, math.ceil((drop.unlockAt - now) / 1000))
        Airdrop.drawText(vector3(drop.coords.x, drop.coords.y, z + 1.6),
            falling and 'Largage en chute' or ('Ouverture dans %d s'):format(seconds))
    end
    return true
end

---Recale la caisse sur le sol une fois le terrain chargé autour du point.
---@param drop ClientAirdrop
function Airdrop.findGround(drop)
    local found, ground = GetGroundZFor_3dCoord(drop.coords.x, drop.coords.y, drop.coords.z + 50.0, false)
    if found then
        drop.coords = vector3(drop.coords.x, drop.coords.y, ground)
        drop.grounded = true
    end
end

---@param drop ClientAirdrop
function Airdrop.createProps(drop)
    local crateModel = GetHashKey(Config.Airdrops.model)
    local chuteModel = GetHashKey(Config.Airdrops.parachute)
    RequestModel(crateModel)
    RequestModel(chuteModel)
    local limit = GetGameTimer() + 3000
    while (not HasModelLoaded(crateModel) or not HasModelLoaded(chuteModel)) and GetGameTimer() < limit do Wait(0) end

    drop.crate = CreateObject(crateModel, drop.coords.x, drop.coords.y, drop.coords.z, false, false, false)
    FreezeEntityPosition(drop.crate, true)
    SetEntityCollision(drop.crate, false, false)
    if GetGameTimer() < drop.landAt then
        drop.chute = CreateObject(chuteModel, drop.coords.x, drop.coords.y, drop.coords.z, false, false, false)
        FreezeEntityPosition(drop.chute, true)
        SetEntityCollision(drop.chute, false, false)
    else
        Airdrop.startSmoke(drop)
    end
    SetModelAsNoLongerNeeded(crateModel)
    SetModelAsNoLongerNeeded(chuteModel)
end

---Fumigène jaune au sol pour repérer la caisse de loin.
---@param drop ClientAirdrop
function Airdrop.startSmoke(drop)
    if drop.smoke then return end
    RequestNamedPtfxAsset('core')
    local limit = GetGameTimer() + 2000
    while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < limit do Wait(0) end
    UseParticleFxAssetNextCall('core')
    drop.smoke = StartParticleFxLoopedAtCoord('exp_grd_flare', drop.coords.x, drop.coords.y, drop.coords.z + 0.2,
        0.0, 0.0, 0.0, 1.5, false, false, false, false)
end

---@param coords vector3
---@param text string
function Airdrop.drawText(coords, text)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextColour(255, 216, 74, 230)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end
