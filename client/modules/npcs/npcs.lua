---PNJ de service des zones safe (config/npcs.lua) : banquier, armurier, tailleur...
---Ils sont créés localement près du joueur (en PvP), avec un repère sur la carte.
---E ouvre le service : la bonne page du menu, ou l'éditeur de tenue.
---@class NpcsModule
local Npcs = PVP.define('Npcs')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local DuiLabels = PVP.use('DuiLabels')
local HelpNotify = PVP.use('HelpNotify')
local Creator = PVP.use('Creator')
local PedUtils = PVP.use('PedUtils')

Npcs.CONTROL_TALK = 38 -- E
Npcs.LABEL_DISTANCE = 12.0

---@type table<integer, integer> index dans Config.SafeNpcs.npcs -> ped
Npcs.peds = {}
---@type integer[]
Npcs.blips = {}

function Npcs.init()
    Npcs.createBlips()
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then Npcs.deleteAll() end
    end)
    CreateThread(Npcs.loop)
end

function Npcs.createBlips()
    for _, npc in ipairs(Config.SafeNpcs.npcs) do
        local role = Config.SafeNpcs.roles[npc.role]
        local blip = AddBlipForCoord(npc.coords.x, npc.coords.y, npc.coords.z)
        SetBlipSprite(blip, role.blip.sprite)
        SetBlipColour(blip, role.blip.color)
        SetBlipScale(blip, 0.75)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(role.label)
        EndTextCommandSetBlipName(blip)
        Npcs.blips[#Npcs.blips + 1] = blip
    end
end

function Npcs.loop()
    while true do
        local needsFrame = false
        if State.inPvp() then
            local pos = GetEntityCoords(PlayerPedId())
            for index, npc in ipairs(Config.SafeNpcs.npcs) do
                if Npcs.update(index, npc, pos) then needsFrame = true end
            end
        elseif next(Npcs.peds) then
            Npcs.deleteAll()
        end
        Wait(needsFrame and 0 or 500)
    end
end

---@param index integer
---@param npc table
---@param pos vector3 position du joueur
---@return boolean true si le PNJ doit être mis à jour à chaque image (texte, interaction)
function Npcs.update(index, npc, pos)
    local dist = #(pos.xy - npc.coords.xy)
    if dist > Config.SafeNpcs.drawDistance then
        Npcs.delete(index)
        return false
    end
    if not Npcs.peds[index] then Npcs.create(index, npc) end
    if dist > Npcs.LABEL_DISTANCE then return false end

    local ped = Npcs.peds[index]
    local role = Config.SafeNpcs.roles[npc.role]
    local head = GetEntityCoords(ped) + vector3(0.0, 0.0, 1.25)
    DuiLabels.draw('npc:' .. index, head, { title = role.label, subtitle = role.action, accent = 'hazard', icon = role.icon })

    if dist <= Config.SafeNpcs.interactDistance and State.isAlive() and not State.menuOpen then
        HelpNotify.show(HelpNotify.controlKey(Npcs.CONTROL_TALK), ('%s · %s'):format(role.label, role.action))
        if IsControlJustReleased(0, Npcs.CONTROL_TALK) then
            Npcs.interact(npc)
        end
    end
    return true
end

---@param npc table
function Npcs.interact(npc)
    local role = Config.SafeNpcs.roles[npc.role]
    if npc.role == 'clothing' then
        Creator.requestEdit()
    elseif role.page then
        Nui.setMenu(true, role.page)
    end
end

---@param index integer
---@param npc table
function Npcs.create(index, npc)
    local model = GetHashKey(npc.model)
    if not PedUtils.loadModel(model) then return end

    local x, y, z = npc.coords.x, npc.coords.y, npc.coords.z
    local found, ground = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
    if found then z = ground end

    local ped = CreatePed(4, model, x, y, z, npc.coords.w, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedDiesWhenInjured(ped, false)
    if npc.scenario then TaskStartScenarioInPlace(ped, npc.scenario, 0, true) end
    Npcs.peds[index] = ped
end

---@param index integer
function Npcs.delete(index)
    local ped = Npcs.peds[index]
    if ped and DoesEntityExist(ped) then DeletePed(ped) end
    Npcs.peds[index] = nil
end

---@param entity integer
---@return integer|nil index du PNJ (Config.SafeNpcs.npcs) si l'entité en est un
function Npcs.findByEntity(entity)
    for index, ped in pairs(Npcs.peds) do
        if ped == entity then return index end
    end
    return nil
end

function Npcs.deleteAll()
    for index in pairs(Npcs.peds) do Npcs.delete(index) end
end

