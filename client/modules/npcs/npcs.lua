---PNJ des zones safe (config/npcs.lua) : services du PvP (banquier, armurier, tailleur...)
---et organisateurs des modes de jeu du Freeroam. Un PNJ n'existe que dans les modes de jeu
---de sa zone ; il est créé localement près du joueur, avec un repère sur la carte.
---E ouvre le service : la bonne page du menu, l'éditeur de tenue, ou le mode de jeu.
---@class NpcsModule
local Npcs = PVP.define('Npcs')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local DuiLabels = PVP.use('DuiLabels')
local HelpNotify = PVP.use('HelpNotify')
local Creator = PVP.use('Creator')
local PedUtils = PVP.use('PedUtils')
local Zones = PVP.use('Zones')
local Activities = PVP.use('Activities')

Npcs.CONTROL_TALK = 38 -- E
Npcs.LABEL_DISTANCE = 12.0

---@type table<integer, integer> index dans Config.SafeNpcs.npcs -> ped
Npcs.peds = {}
---@type integer[]
Npcs.blips = {}
---@type string|nil|false mode dont les repères sont affichés (false : pas encore créés)
Npcs.blipMode = false

function Npcs.init()
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then Npcs.deleteAll() end
    end)
    CreateThread(Npcs.loop)
end

---Nom, action, icône et repère d'un PNJ (ceux d'un organisateur viennent de son mode de jeu).
---@param npc table
---@return { label: string, action: string, icon: string, blip: table }
function Npcs.describe(npc)
    local role = Config.SafeNpcs.roles[npc.role]
    local activity = npc.activity and Config.FreeroamActivities[npc.activity]
    if not activity then return role end
    return {
        label = activity.label,
        action = activity.enabled and 'Lancer le mode' or 'Bientôt disponible',
        icon = activity.icon or role.icon,
        blip = activity.blip or role.blip,
    }
end

---@param npc table
---@return boolean le PNJ existe dans le mode de jeu en cours
function Npcs.visible(npc)
    local zone = Zones.byId(npc.zone)
    return zone ~= nil and Zones.inMode(zone, State.mode)
end

---Repères des PNJ du mode en cours (refaits quand on change de mode).
function Npcs.refreshBlips()
    for _, blip in ipairs(Npcs.blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    Npcs.blips = {}
    Npcs.blipMode = State.mode
    for _, npc in ipairs(Config.SafeNpcs.npcs) do
        if Npcs.visible(npc) then Npcs.createBlip(npc) end
    end
end

---@param npc table
function Npcs.createBlip(npc)
    local role = Npcs.describe(npc)
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

function Npcs.loop()
    while true do
        local needsFrame = false
        if State.mode ~= Npcs.blipMode then Npcs.refreshBlips() end
        if State.mode then
            local pos = GetEntityCoords(PlayerPedId())
            for index, npc in ipairs(Config.SafeNpcs.npcs) do
                if not Npcs.visible(npc) then
                    Npcs.delete(index)
                elseif Npcs.update(index, npc, pos) then
                    needsFrame = true
                end
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
    local role = Npcs.describe(npc)
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
    if npc.activity then
        Activities.open(npc.activity)
    elseif npc.role == 'clothing' then
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

