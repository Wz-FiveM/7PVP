---Marchand noir ambulant côté client : repère sur la carte et PNJ local près du joueur, en PvP seulement.
---E ouvre sa page dans le menu ; les achats sont vérifiés par le serveur (voir BlackMarketService).
---@class BlackMarketModule
local BlackMarket = PVP.define('BlackMarket')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local DuiLabels = PVP.use('DuiLabels')
local HelpNotify = PVP.use('HelpNotify')
local PedUtils = PVP.use('PedUtils')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

BlackMarket.CONTROL_TALK = 38 -- E
BlackMarket.LABEL_DISTANCE = 15.0

---@type { id: integer, coords: vector4, endsAt: integer }|nil
BlackMarket.visit = nil
---@type integer|nil
BlackMarket.ped = nil
---@type integer|nil
BlackMarket.blip = nil

function BlackMarket.init()
    RegisterNetEvent(Events.client.blackMarketState, function(data)
        BlackMarket.deletePed()
        BlackMarket.deleteBlip()
        BlackMarket.visit = data and { id = data.id, coords = data.coords, endsAt = GetGameTimer() + data.endsIn * 1000 } or nil
    end)
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
            BlackMarket.deletePed()
            BlackMarket.deleteBlip()
        end
    end)
    CreateThread(BlackMarket.loop)
end

function BlackMarket.loop()
    while true do
        local needsFrame = false
        if BlackMarket.visit and State.inPvp() then
            if not BlackMarket.blip then BlackMarket.createBlip() end
            needsFrame = BlackMarket.update(GetEntityCoords(PlayerPedId()))
        else
            BlackMarket.deletePed()
            BlackMarket.deleteBlip()
        end
        Wait(needsFrame and 0 or 500)
    end
end

---@param pos vector3 position du joueur
---@return boolean true si le PNJ doit être mis à jour à chaque image
function BlackMarket.update(pos)
    local coords = BlackMarket.visit.coords
    local dist = #(pos.xy - coords.xy)
    if dist > Config.BlackMarket.drawDistance then
        BlackMarket.deletePed()
        return false
    end
    if not BlackMarket.ped then BlackMarket.createPed() end
    -- Parti pendant le chargement du modèle, ou modèle pas chargé
    if not BlackMarket.ped or not BlackMarket.visit then return false end
    if dist > BlackMarket.LABEL_DISTANCE then return false end

    local minutes = math.max(0, math.ceil((BlackMarket.visit.endsAt - GetGameTimer()) / 60000))
    DuiLabels.draw('blackMarket', GetEntityCoords(BlackMarket.ped) + vector3(0.0, 0.0, 1.25), {
        title = Locale.t('Marchand noir'),
        subtitle = Locale.t('Reste %d min', minutes),
        accent = 'critique',
        icon = 'money',
    })
    if dist <= Config.BlackMarket.interactDistance and State.isAlive() and not State.menuOpen then
        HelpNotify.show(HelpNotify.controlKey(BlackMarket.CONTROL_TALK), Locale.t('Marchand noir · Voir ses lots'))
        if IsControlJustReleased(0, BlackMarket.CONTROL_TALK) then Nui.setMenu(true, 'blackmarket') end
    end
    return true
end

function BlackMarket.createBlip()
    local coords = BlackMarket.visit.coords
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, Config.BlackMarket.blip.sprite)
    SetBlipColour(blip, Config.BlackMarket.blip.color)
    SetBlipScale(blip, 1.1)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Locale.t('Marchand noir'))
    EndTextCommandSetBlipName(blip)
    BlackMarket.blip = blip
end

function BlackMarket.deleteBlip()
    if BlackMarket.blip and DoesBlipExist(BlackMarket.blip) then RemoveBlip(BlackMarket.blip) end
    BlackMarket.blip = nil
end

function BlackMarket.createPed()
    local visit = BlackMarket.visit
    local model = GetHashKey(Config.BlackMarket.model)
    if not PedUtils.loadModel(model) then return end
    -- Le marchand a pu partir pendant le chargement du modèle
    if BlackMarket.visit ~= visit then
        SetModelAsNoLongerNeeded(model)
        return
    end

    local x, y, z = visit.coords.x, visit.coords.y, visit.coords.z
    local found, ground = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
    if found then z = ground end

    local ped = CreatePed(4, model, x, y, z, visit.coords.w, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedDiesWhenInjured(ped, false)
    TaskStartScenarioInPlace(ped, Config.BlackMarket.scenario, 0, true)
    BlackMarket.ped = ped
end

function BlackMarket.deletePed()
    if BlackMarket.ped and DoesEntityExist(BlackMarket.ped) then DeletePed(BlackMarket.ped) end
    BlackMarket.ped = nil
end
