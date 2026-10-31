---Objectifs du mode Call of Duty : drapeaux de la Domination, sites de bombe de Recherche & Destruction,
---plaques de l'Élimination confirmée. Marqueurs et repères sur la carte, touche maintenue pour poser ou
---désamorcer (le serveur vérifie le rôle, la distance et compte le temps).
---@class CodObjectivesModule
local CodObjectives = PVP.define('CodObjectives')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local HelpNotify = PVP.use('HelpNotify')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CodObjectives.CONTROL_ACTION = 38 -- INPUT_PICKUP (E)
CodObjectives.GROUND_INTERVAL = 2000
CodObjectives.ANIM_DICT = 'mini@repair'
CodObjectives.ANIM_NAME = 'fixing_a_ped'
CodObjectives.TAG_MARKER = 21 -- double chevron, tourne et flotte au-dessus du sol
-- Couleurs : neutre, ami, ennemi (marqueurs : rvb, repères : couleur de GTA)
CodObjectives.COLORS = {
    neutral = { 236, 238, 232, blip = 0 },
    friend = { 95, 209, 232, blip = 3 },
    enemy = { 255, 90, 60, blip = 1 },
}

---@type table|nil { kind, radius, points } envoyé au lancement
CodObjectives.data = nil
CodObjectives.team = false
---@type table|nil état reçu chaque seconde (describe côté serveur)
CodObjectives.state = nil
CodObjectives.holding = false
CodObjectives.acting = false
CodObjectives.nextGround = 0
---@type table<integer, integer> plaque -> repère sur la carte
CodObjectives.tagBlips = {}

function CodObjectives.init()
    RegisterNetEvent(Events.client.codAction, function(data)
        CodObjectives.onAction(data)
    end)
end

---@param objectives table|nil
---@param team string|false
function CodObjectives.setup(objectives, team)
    CodObjectives.clear()
    CodObjectives.team = team
    if not objectives then return end
    CodObjectives.data = objectives
    for index, point in ipairs(objectives.points) do
        point.ground = point.z
        point.blip = AddBlipForCoord(point.x, point.y, point.z)
        SetBlipScale(point.blip, 0.8)
        ShowNumberOnBlip(point.blip, index)
        SetBlipColour(point.blip, CodObjectives.COLORS.neutral.blip)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(objectives.kind == 'flags' and Locale.t('Drapeau %s', point.id) or Locale.t('Site %s', point.id))
        EndTextCommandSetBlipName(point.blip)
    end
end

function CodObjectives.clear()
    CodObjectives.stopHolding()
    if CodObjectives.data then
        for _, point in ipairs(CodObjectives.data.points) do
            if point.blip and DoesBlipExist(point.blip) then RemoveBlip(point.blip) end
        end
    end
    CodObjectives.syncTagBlips({})
    CodObjectives.data = nil
    CodObjectives.state = nil
end

---@param state table|nil
function CodObjectives.onState(state)
    CodObjectives.state = state
    if not state or not CodObjectives.data then return end
    if state.kind == 'tags' then CodObjectives.syncTagBlips(state.tags) end
    for _, point in ipairs(CodObjectives.data.points) do
        SetBlipColour(point.blip, CodObjectives.colorOf(point).blip)
    end
end

---@param tag { team: string }
---@return table couleur de la plaque : allié à sauver, ou ennemi à confirmer
function CodObjectives.tagColor(tag)
    return tag.team == CodObjectives.team and CodObjectives.COLORS.friend or CodObjectives.COLORS.enemy
end

---@param tags table[]
function CodObjectives.syncTagBlips(tags)
    local wanted = {}
    for _, tag in ipairs(tags) do
        wanted[tag.id] = true
        if not CodObjectives.tagBlips[tag.id] then
            local blip = AddBlipForCoord(tag.x, tag.y, tag.z)
            SetBlipScale(blip, 0.5)
            SetBlipColour(blip, CodObjectives.tagColor(tag).blip)
            CodObjectives.tagBlips[tag.id] = blip
        end
    end
    for id, blip in pairs(CodObjectives.tagBlips) do
        if not wanted[id] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            CodObjectives.tagBlips[id] = nil
        end
    end
end

---@param point table
---@return table couleur du point selon l'état
function CodObjectives.colorOf(point)
    local state = CodObjectives.state
    local colors = CodObjectives.COLORS
    if not state then return colors.neutral end
    if state.kind == 'flags' then
        for _, flag in ipairs(state.flags) do
            if flag.id == point.id and flag.owner then
                return flag.owner == CodObjectives.team and colors.friend or colors.enemy
            end
        end
        return colors.neutral
    end
    if state.bomb and state.bomb.site == point.id then return colors.enemy end
    return colors.neutral
end

---À chaque image : marqueurs, lettres, et touche de la bombe.
function CodObjectives.frame()
    local data = CodObjectives.data
    if not data then return end
    local now = GetGameTimer()
    local refreshGround = now >= CodObjectives.nextGround
    if refreshGround then CodObjectives.nextGround = now + CodObjectives.GROUND_INTERVAL end

    for _, point in ipairs(data.points) do
        -- Le sol n'est connu qu'une fois la zone chargée autour du joueur
        if refreshGround then
            local found, ground = GetGroundZFor_3dCoord(point.x, point.y, point.z + 50.0, false)
            if found then point.ground = ground end
        end
        local color = CodObjectives.colorOf(point)
        DrawMarker(1, point.x, point.y, point.ground - 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            data.radius * 2, data.radius * 2, 2.0, color[1], color[2], color[3], 70, false, false, 2, false, nil, nil, false)
        CodObjectives.drawLetter(point, color)
    end
    if data.kind == 'sites' then CodObjectives.updateBombAction() end
    if data.kind == 'tags' then CodObjectives.drawTags() end
end

function CodObjectives.drawTags()
    local state = CodObjectives.state
    if not state or state.kind ~= 'tags' then return end
    for _, tag in ipairs(state.tags) do
        local color = CodObjectives.tagColor(tag)
        DrawMarker(CodObjectives.TAG_MARKER, tag.x, tag.y, tag.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            0.6, 0.6, 0.6, color[1], color[2], color[3], 230, true, false, 2, true, nil, nil, false)
    end
end

---@param point table
---@param color table
function CodObjectives.drawLetter(point, color)
    SetDrawOrigin(point.x, point.y, point.ground + 3.0, 0)
    SetTextFont(4)
    SetTextScale(0.0, 0.6)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(color[1], color[2], color[3], 230)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(point.id)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

---@return string|nil texte de l'aide si le joueur peut agir ici
function CodObjectives.availableAction()
    local state = CodObjectives.state
    if not state or not State.isAlive() or state.kind ~= 'sites' then return nil end
    local coords = GetEntityCoords(PlayerPedId())
    local radius = CodObjectives.data.radius
    for _, point in ipairs(CodObjectives.data.points) do
        if #(coords.xy - vector2(point.x, point.y)) <= radius then
            if CodObjectives.team == state.attackers then
                if not state.bomb then return Locale.t('Maintiens pour poser la bombe') end
            elseif state.bomb and state.bomb.site == point.id then
                return Locale.t('Maintiens pour désamorcer la bombe')
            end
        end
    end
    return nil
end

function CodObjectives.updateBombAction()
    local text = CodObjectives.availableAction()
    if text and not CodObjectives.acting then
        HelpNotify.show(HelpNotify.controlKey(CodObjectives.CONTROL_ACTION), text)
    end
    local pressed = text ~= nil and IsControlPressed(0, CodObjectives.CONTROL_ACTION) and not IsNuiFocused()
    if pressed ~= CodObjectives.holding then
        CodObjectives.holding = pressed
        TriggerServerEvent(Events.server.codObjective, pressed)
    end
end

function CodObjectives.stopHolding()
    if CodObjectives.holding then
        CodObjectives.holding = false
        TriggerServerEvent(Events.server.codObjective, false)
    end
    CodObjectives.onAction(false)
end

---Le serveur a commencé (ou arrêté) de compter la pose ou le désamorçage.
---@param data { kind: string, seconds: integer }|false
function CodObjectives.onAction(data)
    local acting = data ~= false and data ~= nil
    if acting == CodObjectives.acting then return end
    CodObjectives.acting = acting
    Nui.send('codAction', acting and data or { kind = false })

    local ped = PlayerPedId()
    if acting then
        CreateThread(function()
            RequestAnimDict(CodObjectives.ANIM_DICT)
            local timeout = GetGameTimer() + 2000
            while not HasAnimDictLoaded(CodObjectives.ANIM_DICT) and GetGameTimer() < timeout do Wait(0) end
            if CodObjectives.acting then
                TaskPlayAnim(ped, CodObjectives.ANIM_DICT, CodObjectives.ANIM_NAME, 8.0, -8.0, -1, 1, 0.0, false, false, false)
            end
        end)
    else
        StopAnimTask(ped, CodObjectives.ANIM_DICT, CodObjectives.ANIM_NAME, 2.0)
    end
end
