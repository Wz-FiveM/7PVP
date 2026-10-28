---Menu d'interaction, inspiré de ContextMenu (Kiminaze) : on maintient la touche
---(Config.InteractionKey, Alt gauche), un curseur apparaît et la cible survolée est entourée.
---Un clic ouvre, à l'endroit du clic, le menu de ce qu'on vise :
---  soi-même (ou le vide) : ID, niveau, équipe
---  un joueur : ID, prime, inviter / exclure de l'équipe
---  un sac, un corps de zombie, une caisse de largage : fouiller
---  un PNJ de la zone safe : lui parler ; un véhicule : monter
---Le menu est une liste d'éléments envoyée à l'interface ; chaque clic revient ici
---(Interaction.run) puis la liste est renvoyée à jour (cases cochées...).
---Types d'éléments : info (libellé + valeur), action, toggle (case à cocher), submenu, separator.
---@class InteractionModule
local Interaction = PVP.define('Interaction')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Group = PVP.use('Group')
local Loot = PVP.use('Loot')
local Npcs = PVP.use('Npcs')
local Vehicles = PVP.use('Vehicles')
local Bounty = PVP.use('Bounty')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')

Interaction.NEAREST_DISTANCE = 5.0
Interaction.RAY_DISTANCE = 60.0
-- Portée des actions sur une cible (fouiller, parler, monter)
Interaction.USE_DISTANCE = 3.5
-- Curseur affiché : on garde le clavier (marcher) mais pas la caméra ni le tir (la souris clique)
Interaction.BLOCKED_CONTROLS = { 1, 2, 24, 25, 68, 69, 70, 91, 92, 106, 140, 141, 142, 257, 263 }
Interaction.OUTLINE = { 240, 195, 60, 255 } -- jaune signal de la D.A

Interaction.open = false -- curseur affiché (touche maintenue ou menu ouvert)
Interaction.menuShown = false -- un menu de cible est affiché
---@type table|nil cible du menu affiché { kind, entity, serverId, lootId, npcIndex }
Interaction.target = nil
Interaction.outlined = nil

function Interaction.init()
    RegisterCommand('+pvp_interaction', function()
        Interaction.start()
    end, false)
    RegisterCommand('-pvp_interaction', function()
        Interaction.release()
    end, false)
    -- Nom de commande nouveau : la touche par défaut s'applique aussi à ceux qui avaient F1
    RegisterKeyMapping('+pvp_interaction', 'Menu d\'interaction 7PVP (maintenir)', 'keyboard', Config.InteractionKey)

    RegisterNUICallback('interactionClose', function(_, cb)
        Interaction.close()
        cb({})
    end)
    RegisterNUICallback('interactionPick', function(data, cb)
        cb({})
        Interaction.pick(tonumber(data.x) or 0.5, tonumber(data.y) or 0.5)
    end)
    RegisterNUICallback('interactionAction', function(data, cb)
        cb({})
        CreateThread(function()
            Interaction.run(type(data) == 'table' and data.id or nil)
        end)
    end)
end

-- ---------------------------------------------------------------------------
-- Curseur et ciblage
-- ---------------------------------------------------------------------------

---Touche enfoncée : curseur et contour de la cible survolée.
function Interaction.start()
    if Interaction.open then return end
    if State.mode ~= 'pvp' or not State.isAlive() or State.menuOpen or State.noclip or IsNuiFocused() then return end
    Interaction.open = true
    Interaction.menuShown = false
    SetNuiFocus(true, true)
    -- Le jeu continue derrière : on peut marcher en visant
    SetNuiFocusKeepInput(true)
    Nui.send('interaction', { open = true, items = false })
    CreateThread(Interaction.targetLoop)
end

---Touche relâchée : le curseur et le menu se ferment (on garde Alt pour choisir une action).
function Interaction.release()
    Interaction.close()
end

function Interaction.targetLoop()
    while Interaction.open do
        for _, control in ipairs(Interaction.BLOCKED_CONTROLS) do
            DisableControlAction(0, control, true)
        end
        if not Interaction.menuShown then
            local x, y = Interaction.cursor()
            local target = Interaction.resolve(Interaction.raycast(x, y))
            Interaction.setOutline(target and target.entity or nil)
        end
        Wait(0)
    end
    Interaction.setOutline(nil)
end

function Interaction.close()
    if not Interaction.open then return end
    Interaction.open = false
    Interaction.menuShown = false
    Interaction.target = nil
    Interaction.setOutline(nil)
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    Nui.send('interaction', { open = false })
end

---@return number, number position du curseur, de 0 à 1
function Interaction.cursor()
    local x, y = GetNuiCursorPosition()
    local width, height = GetActiveScreenResolution()
    return x / width, y / height
end

---Contour jaune sur la cible survolée (un seul à la fois).
---@param entity integer|nil
function Interaction.setOutline(entity)
    if Interaction.outlined == entity then return end
    if Interaction.outlined and DoesEntityExist(Interaction.outlined) then
        SetEntityDrawOutline(Interaction.outlined, false)
    end
    Interaction.outlined = entity
    if entity then
        SetEntityDrawOutlineColor(table.unpack(Interaction.OUTLINE))
        SetEntityDrawOutlineShader(1)
        SetEntityDrawOutline(entity, true)
    end
end

---@param rotation vector3 rotation de la caméra (degrés)
---@return vector3 direction
function Interaction.rotationToDirection(rotation)
    local x, z = math.rad(rotation.x), math.rad(rotation.z)
    return vector3(-math.sin(z) * math.abs(math.cos(x)), math.cos(z) * math.abs(math.cos(x)), math.sin(x))
end

---Rayon de la caméra passant par un point de l'écran : on mesure où tombent à l'écran deux
---points connus devant la caméra, puis on interpole jusqu'au curseur.
---@param x number 0 à 1
---@param y number 0 à 1
---@return vector3 origine, vector3 direction
function Interaction.screenRay(x, y)
    local camCoords = GetFinalRenderedCamCoord()
    local camRot = GetFinalRenderedCamRot(2)
    local forward = Interaction.rotationToDirection(camRot)
    local right = Interaction.rotationToDirection(camRot + vector3(0.0, 0.0, -10.0))
        - Interaction.rotationToDirection(camRot + vector3(0.0, 0.0, 10.0))
    local up = Interaction.rotationToDirection(camRot + vector3(10.0, 0.0, 0.0))
        - Interaction.rotationToDirection(camRot + vector3(-10.0, 0.0, 0.0))
    local roll = -math.rad(camRot.y)
    local rightRoll = right * math.cos(roll) - up * math.sin(roll)
    local upRoll = right * math.sin(roll) + up * math.cos(roll)

    local center = camCoords + forward
    local corner = center + rightRoll + upRoll
    local _, cornerX, cornerY = GetScreenCoordFromWorldCoord(corner.x, corner.y, corner.z)
    local _, centerX, centerY = GetScreenCoordFromWorldCoord(center.x, center.y, center.z)
    if math.abs(cornerX - centerX) < 0.001 or math.abs(cornerY - centerY) < 0.001 then
        return camCoords, forward
    end

    local point = center + rightRoll * ((x - centerX) / (cornerX - centerX)) + upRoll * ((y - centerY) / (cornerY - centerY))
    local direction = point - camCoords
    return camCoords, direction / #direction
end

---@param x number
---@param y number
---@return integer|nil entité touchée par le rayon
function Interaction.raycast(x, y)
    local origin, direction = Interaction.screenRay(x, y)
    local finish = origin + direction * Interaction.RAY_DISTANCE
    local ray = StartExpensiveSynchronousShapeTestLosProbe(origin.x, origin.y, origin.z, finish.x, finish.y, finish.z,
        -1, PlayerPedId(), 7)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    if hit == 1 and entity and entity ~= 0 and DoesEntityExist(entity) then return entity end
    return nil
end

---Ce que représente l'entité visée, ou nil si elle n'a pas de menu (décor, zombie vivant...).
---@param entity integer|nil
---@return table|nil { kind, entity, serverId?, lootId?, npcIndex? }
function Interaction.resolve(entity)
    if not entity then return nil end

    local lootId = Loot.findByEntity(entity)
    if lootId then return { kind = 'loot', entity = entity, lootId = lootId } end

    local npcIndex = Npcs.findByEntity(entity)
    if npcIndex then return { kind = 'npc', entity = entity, npcIndex = npcIndex } end

    if IsEntityAPed(entity) and IsPedAPlayer(entity) and entity ~= PlayerPedId() then
        local player = NetworkGetPlayerIndexFromPed(entity)
        return { kind = 'player', entity = entity, serverId = GetPlayerServerId(player), name = GetPlayerName(player) }
    end
    if IsEntityAVehicle(entity) then return { kind = 'vehicle', entity = entity } end
    return nil
end

---Clic : menu de la cible sous le curseur (ou de soi-même si rien de particulier n'est visé).
---@param x number 0 à 1
---@param y number 0 à 1
function Interaction.pick(x, y)
    if not Interaction.open then return end
    Interaction.target = Interaction.resolve(Interaction.raycast(x, y)) or { kind = 'self' }
    Interaction.menuShown = true
    Interaction.setOutline(Interaction.target.entity)
    Interaction.send()
end

function Interaction.send()
    if not Interaction.target then return end
    Nui.send('interaction', { open = true, items = Interaction.build(Interaction.target) })
end

---@param entity integer|nil
---@return boolean assez près pour agir sur la cible
---@param distance? number défaut : Interaction.USE_DISTANCE
function Interaction.inReach(entity, distance)
    return entity ~= nil and DoesEntityExist(entity)
        and #(GetEntityCoords(entity) - GetEntityCoords(PlayerPedId())) <= (distance or Interaction.USE_DISTANCE)
end

-- ---------------------------------------------------------------------------
-- Contenu
-- ---------------------------------------------------------------------------

---@param target table
---@return table[]
function Interaction.build(target)
    if target.kind == 'player' then return Interaction.playerItems(target) end
    if target.kind == 'loot' then return Interaction.lootItems(target) end
    if target.kind == 'npc' then return Interaction.npcItems(target) end
    if target.kind == 'vehicle' then return Interaction.vehicleItems(target) end
    return Interaction.selfItems()
end

---@return table[]
function Interaction.selfItems()
    local player = State.player or {}
    return {
        -- Première ligne « :name » : affichée en en-tête du menu
        { kind = 'info', id = 'self:name', label = player.name or GetPlayerName(PlayerId()), icon = 'profile' },
        { kind = 'info', id = 'serverId', label = 'ID Serveur', icon = 'contract', value = tostring(GetPlayerServerId(PlayerId())) },
        { kind = 'info', id = 'level', label = 'Niveau', icon = 'trophy', value = tostring(player.level or 1) },
        { kind = 'separator', id = 'separator' },
        { kind = 'submenu', id = 'team', label = 'Équipe', icon = 'group', children = Interaction.teamItems() },
    }
end

---@param target table
---@return table[]
function Interaction.playerItems(target)
    local items = {
        { kind = 'info', id = 'player:name', label = target.name or 'Joueur', icon = 'profile', value = ('ID %d'):format(target.serverId) },
    }
    for _, entry in ipairs(Bounty.list) do
        if entry.id == target.serverId then
            items[#items + 1] = { kind = 'info', id = 'player:bounty', label = 'Prime', icon = 'money', value = ('$%d'):format(entry.amount) }
        end
    end
    items[#items + 1] = { kind = 'separator', id = 'separator' }

    local me = GetPlayerServerId(PlayerId())
    local isMate = Group.isMember(target.serverId)
    local isLeader = Group.data and Group.data.leader == me
    if isMate then
        items[#items + 1] = { kind = 'info', id = 'player:mate', label = 'Coéquipier', icon = 'group' }
        if isLeader then
            items[#items + 1] = { kind = 'action', id = 'player:kick', label = 'Exclure de l\'équipe', icon = 'exit' }
        end
    else
        items[#items + 1] = {
            kind = 'action', id = 'player:invite', label = 'Inviter dans l\'équipe', icon = 'group',
            disabled = Group.data ~= false and not isLeader,
        }
    end
    return items
end

---@param target table
---@return table[]
function Interaction.lootItems(target)
    local bag = Loot.bags[target.lootId]
    local label = bag and (bag.label or (bag.netId and 'Corps de zombie' or 'Sac de butin')) or 'Butin'
    return {
        { kind = 'info', id = 'loot:name', label = label, icon = 'crate' },
        { kind = 'separator', id = 'separator' },
        { kind = 'action', id = 'loot:take', label = 'Fouiller', icon = 'inventory', disabled = not Interaction.inReach(target.entity) },
    }
end

---@param target table
---@return table[]
function Interaction.npcItems(target)
    local npc = Config.SafeNpcs.npcs[target.npcIndex]
    local role = npc and Config.SafeNpcs.roles[npc.role] or {}
    return {
        { kind = 'info', id = 'npc:name', label = role.label or 'PNJ', icon = role.icon or 'profile' },
        { kind = 'separator', id = 'separator' },
        -- Même portée que les services du PNJ (coffre, boutique...), vérifiée par le serveur
        {
            kind = 'action', id = 'npc:talk', label = role.action or 'Parler', icon = 'help',
            disabled = not Interaction.inReach(target.entity, Config.SafeNpcs.useDistance),
        },
    }
end

---@param target table
---@return table[]
function Interaction.vehicleItems(target)
    local model = GetEntityModel(target.entity)
    local name = GetLabelText(GetDisplayNameFromVehicleModel(model))
    local near = Interaction.inReach(target.entity)
    local items = {
        { kind = 'info', id = 'vehicle:name', label = name ~= 'NULL' and name or 'Véhicule', icon = 'crate' },
        { kind = 'separator', id = 'separator' },
        { kind = 'action', id = 'vehicle:driver', label = 'Monter (conducteur)', icon = 'exit', disabled = not near or not IsVehicleSeatFree(target.entity, -1) },
        { kind = 'action', id = 'vehicle:passenger', label = 'Monter (passager)', icon = 'exit', disabled = not near or not IsVehicleSeatFree(target.entity, 0) },
    }
    -- Véhicule sorti d'un objet par le joueur : il peut le remettre dans son inventaire
    if Vehicles.isMine(target.entity) then
        items[#items + 1] = { kind = 'separator', id = 'separator:store' }
        items[#items + 1] = { kind = 'action', id = 'vehicle:store', label = 'Ranger le véhicule', icon = 'inventory', disabled = not near }
    end
    return items
end

---@return table[]
function Interaction.teamItems()
    local nearest = Interaction.nearestPlayer()
    local items = {
        {
            kind = 'action',
            id = 'team:invite',
            label = nearest and ('Inviter %s'):format(GetPlayerName(nearest)) or 'Inviter le joueur le plus proche',
            icon = 'group',
            disabled = nearest == nil,
        },
    }
    if Group.data then
        table.insert(items, 1, { kind = 'info', id = 'team:size', label = 'Membres', icon = 'group', value = tostring(#Group.data.members) })
        items[#items + 1] = { kind = 'action', id = 'team:leave', label = 'Quitter l\'équipe', icon = 'exit' }
    end
    return items
end

---@return integer|nil joueur (index client) le plus proche à moins de NEAREST_DISTANCE
function Interaction.nearestPlayer()
    local me = PlayerId()
    local coords = GetEntityCoords(PlayerPedId())
    local best, bestDistance = nil, Interaction.NEAREST_DISTANCE
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= me then
            local distance = #(GetEntityCoords(GetPlayerPed(player)) - coords)
            if distance <= bestDistance then best, bestDistance = player, distance end
        end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

---@param id any
function Interaction.run(id)
    if type(id) ~= 'string' or not Interaction.open then return end
    if id == 'team:invite' then
        Interaction.inviteNearest()
    elseif id == 'team:leave' then
        Interaction.report(Callback.await(Events.callbacks.groupLeave))
    elseif id:find(':') then
        return Interaction.runOnTarget(id)
    end
    if Interaction.open then Interaction.send() end
end

---Action sur la cible du menu (joueur, butin, PNJ, véhicule) : le menu se ferme ensuite.
---@param id string
function Interaction.runOnTarget(id)
    local target = Interaction.target
    if not target then return end
    Interaction.close()

    if id == 'player:invite' then
        Interaction.report(Callback.await(Events.callbacks.groupInvite, target.serverId))
    elseif id == 'player:kick' then
        Interaction.report(Callback.await(Events.callbacks.groupKick, target.serverId))
    elseif id == 'loot:take' then
        TriggerServerEvent(Events.server.lootPickup, target.lootId)
    elseif id == 'npc:talk' then
        Npcs.interact(Config.SafeNpcs.npcs[target.npcIndex])
    elseif id == 'vehicle:driver' then
        TaskEnterVehicle(PlayerPedId(), target.entity, 10000, -1, 1.0, 1, 0)
    elseif id == 'vehicle:passenger' then
        TaskEnterVehicle(PlayerPedId(), target.entity, 10000, 0, 1.0, 1, 0)
    elseif id == 'vehicle:store' then
        Vehicles.store()
    end
end

---@param result table|nil { ok, message }
function Interaction.report(result)
    if result and result.message then Nui.notify(result.message, result.ok and 'success' or 'error') end
end

function Interaction.inviteNearest()
    local nearest = Interaction.nearestPlayer()
    if not nearest then return Nui.notify('Personne à côté de toi.', 'error') end
    Interaction.report(Callback.await(Events.callbacks.groupInvite, GetPlayerServerId(nearest)))
end
