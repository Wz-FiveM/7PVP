---Mode Sabotage côté client (server/modules/tactical/) : menu du mode, placement à chaque manche, équipement
---acheté, zone de départ pendant l'achat, pose et désamorçage de la charge, sites, tableau des scores, mort.
---Le serveur décide des achats, des kills, des manches et de la fin de partie.
---@class TacticalModule
local Tactical = PVP.define('Tactical')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Lobby = PVP.use('Lobby')
local Spawn = PVP.use('Spawn')
local Death = PVP.use('Death')
local Zone = PVP.use('Zone')
local Cod = PVP.use('Cod')
local PedUtils = PVP.use('PedUtils')
local HelpNotify = PVP.use('HelpNotify')
local TacticalAbilities = PVP.use('TacticalAbilities')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')
local Pause = PVP.use('Pause')

Tactical.MODE = 'tactical'
Tactical.FADE = 300
Tactical.CONTROL_SCOREBOARD = 37 -- INPUT_SELECT_WEAPON (TAB, comme la touche du menu)
Tactical.CONTROL_ACTION = 38 -- INPUT_PICKUP (E)
-- Touches de GTA prises par les capacités et l'achat (C : regarder derrière, Q : couverture, X, B)
Tactical.FREED_CONTROLS = { 26, 29, 44, 73, 58 }
-- Fin de partie et pose en cours : pas de déplacement ni de tir
Tactical.LOCKED_CONTROLS = { 21, 22, 24, 25, 30, 31, 32, 33, 34, 35, 44, 140, 141, 142, 257 }
-- Phase d'achat : pas de tir
Tactical.BUY_CONTROLS = { 24, 25, 47, 58, 140, 141, 142, 143, 257, 263, 264 }
Tactical.ANIM_DICT = 'mini@repair'
Tactical.ANIM_NAME = 'fixing_a_ped'
Tactical.SITE_COLOR = { 240, 195, 60 }
Tactical.BOMB_COLOR = { 255, 90, 60 }
Tactical.MATE_COLOR = { 95, 209, 232 }

Tactical.menuOpen = false
---@type table|nil partie en cours (données de tacStart)
Tactical.match = nil
---@type table|nil manche en cours (données de tacRound)
Tactical.round = nil
---@type table|nil argent, équipement, charges (tacSelf)
Tactical.self = nil
Tactical.phase = nil
Tactical.state = nil
Tactical.ended = false
Tactical.buyOpen = false
Tactical.scoreboard = false
Tactical.holding = false
Tactical.acting = false
Tactical.applied = nil -- équipement posé sur le personnage (clé)
Tactical.lastInside = nil -- dernière position dans la zone de départ
Tactical.outside = false
Tactical.nextOutsideDamage = 0
Tactical.blips = {}
Tactical.mateBlips = {}
Tactical.mates = {}
Tactical.bomb = nil
Tactical.nextBeep = 0
---@type table<string, table> arme -> entrée de Config.Tactical.weapons
Tactical.weapons = {}

function Tactical.init()
    for _, entry in ipairs(Config.Tactical.weapons) do Tactical.weapons[entry.id] = entry end

    RegisterNetEvent(Events.client.tacOpen, function(data) Tactical.openMenu(data) end)
    RegisterNetEvent(Events.client.tacCleanup, function() Tactical.cleanup() end)
    RegisterNetEvent(Events.client.tacQueue, function(data) Nui.send('tacQueue', data or false) end)
    RegisterNetEvent(Events.client.tacStart, function(data) Tactical.start(data) end)
    -- Présentation des équipes : l'interface la garde jusqu'à la première manche
    RegisterNetEvent(Events.client.tacLineup, function(data) Nui.send('tacLineup', data) end)
    RegisterNetEvent(Events.client.tacRound, function(data) Tactical.onRound(data) end)
    RegisterNetEvent(Events.client.tacSelf, function(data) Tactical.onSelf(data) end)
    RegisterNetEvent(Events.client.tacState, function(data) Tactical.onState(data) end)
    RegisterNetEvent(Events.client.tacKill, function(data)
        if Tactical.isActive() then Nui.send('tacKill', data) end
    end)
    RegisterNetEvent(Events.client.tacDead, function(data) Tactical.onDead(data) end)
    RegisterNetEvent(Events.client.tacRoundEnd, function(data) Tactical.onRoundEnd(data) end)
    RegisterNetEvent(Events.client.tacEnd, function(data) Tactical.finish(data) end)
    RegisterNetEvent(Events.client.tacAction, function(data) Tactical.onAction(data) end)
    RegisterNetEvent(Events.client.tacNotice, function(data)
        if Tactical.isActive() then Nui.send('tacNotice', data) end
    end)

    local keys = Config.Tactical.keys
    RegisterCommand('pvp_tac_buy', function() Tactical.toggleBuy() end, false)
    RegisterKeyMapping('pvp_tac_buy', Locale.t('Sabotage : menu d\'achat'), 'keyboard', keys.buy)
    RegisterCommand('pvp_tac_ability_c', function() TacticalAbilities.use('c') end, false)
    RegisterKeyMapping('pvp_tac_ability_c', Locale.t('Sabotage : capacité 1'), 'keyboard', keys.abilityC)
    RegisterCommand('pvp_tac_ability_q', function() TacticalAbilities.use('q') end, false)
    RegisterKeyMapping('pvp_tac_ability_q', Locale.t('Sabotage : capacité 2'), 'keyboard', keys.abilityQ)
    RegisterCommand('pvp_tac_ultimate', function() TacticalAbilities.use('x') end, false)
    RegisterKeyMapping('pvp_tac_ultimate', Locale.t('Sabotage : capacité ultime'), 'keyboard', keys.ultimate)
    for slot, key in pairs({ primary = '1', secondary = '2', knife = '3' }) do
        RegisterCommand('pvp_tac_' .. slot, function() Tactical.selectWeapon(slot) end, false)
        RegisterKeyMapping('pvp_tac_' .. slot, Locale.t('Sabotage : arme %s', key), 'keyboard', key)
    end

    RegisterNUICallback('tacQueue', function(_, cb)
        cb(Callback.await(Events.callbacks.tacQueue) or { ok = false })
    end)
    RegisterNUICallback('tacSelectRole', function(data, cb)
        cb(Callback.await(Events.callbacks.tacSelectRole, data.role) or { ok = false })
    end)
    RegisterNUICallback('tacBuy', function(data, cb)
        cb(Callback.await(Events.callbacks.tacBuy, data.item) or { ok = false })
    end)
    RegisterNUICallback('tacSell', function(data, cb)
        cb(Callback.await(Events.callbacks.tacSell, data.key) or { ok = false })
    end)
    RegisterNUICallback('tacLeaderboard', function(_, cb)
        cb(Callback.await(Events.callbacks.tacLeaderboard) or { rows = {} })
    end)
    RegisterNUICallback('tacContinue', function(_, cb)
        if not Tactical.ended then return cb({ ok = false }) end
        cb(Callback.await(Events.callbacks.tacLeaveMatch) or { ok = false })
    end)
    RegisterNUICallback('tacBuyClose', function(_, cb)
        Tactical.setBuy(false)
        cb({ ok = true })
    end)

    CreateThread(Tactical.loop)
end

---@return boolean dans une partie de Sabotage
function Tactical.isActive()
    return State.mode == Tactical.MODE and Tactical.match ~= nil
end

---@return table catalogue envoyé à l'interface (rôles, armes, gilets, touches)
function Tactical.catalog()
    local settings = Config.Tactical
    return {
        roles = settings.roles,
        weapons = settings.weapons,
        armor = settings.armor,
        keys = settings.keys,
        roundsToWin = settings.roundsToWin,
        divisions = settings.divisions,
    }
end

-- ---------------------------------------------------------------------------
-- Menu du mode
-- ---------------------------------------------------------------------------

---@param data { profile: table, maps: integer }
function Tactical.openMenu(data)
    if not IsScreenFadedOut() then
        DoScreenFadeOut(Tactical.FADE)
        while not IsScreenFadedOut() do Wait(0) end
    end
    Tactical.clearMatch()
    State.spawned = false
    State.dead = false
    Lobby.hidePlayer()
    Lobby.startCamera()
    DisplayRadar(false)
    Tactical.menuOpen = true
    SetNuiFocus(true, true)
    Nui.send('tacMenu', { open = true, profile = data.profile, maps = data.maps, catalog = Tactical.catalog() })
    DoScreenFadeIn(500)
end

function Tactical.closeMenu()
    if not Tactical.menuOpen then return end
    Tactical.menuOpen = false
    Nui.send('tacMenu', { open = false })
    Lobby.close()
end

-- ---------------------------------------------------------------------------
-- Partie et manches
-- ---------------------------------------------------------------------------

---@param data table self, team, role, map, arena, sites, siteRadius, roundsToWin, loadTime
function Tactical.start(data)
    DoScreenFadeOut(Tactical.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    Tactical.closeMenu()
    Tactical.match = data
    Tactical.ended = false
    Tactical.drawMap(data)
    Nui.send('tacHud', {
        open = true,
        self = data.self,
        team = data.team,
        role = data.role,
        map = data.map,
        roundsToWin = data.roundsToWin,
        catalog = Tactical.catalog(),
    })
end

---Nouvelle manche (ou retour au point de départ après une chute pendant l'achat).
---@param data table round, attackers, attacking, spawn, buyTime, buyRadius, scores, overtime
function Tactical.onRound(data)
    if not Tactical.isActive() then return end
    Tactical.round = data
    Tactical.phase = 'buy'
    Tactical.bomb = nil
    Tactical.stopHolding()
    TacticalAbilities.clear()
    Death.stopSpectate()
    Pause.close()
    Nui.send('tacRound', data)
    Tactical.placeAt(data.spawn, true)
    Tactical.lastInside = vector3(data.spawn.x, data.spawn.y, data.spawn.z)
    Tactical.setBuy(false)
end

---@param spawn vector4
---@param fullHealth boolean
function Tactical.placeAt(spawn, fullHealth)
    Spawn.spawnAt(spawn)
    if not Tactical.isActive() then return end
    Cod.applyTeam(Tactical.match.team)
    Tactical.applied = nil
    Tactical.applyLoadout(true)
    local ped = PlayerPedId()
    if fullHealth then SetEntityHealth(ped, GetEntityMaxHealth(ped)) end
    -- Personne ne se touche pendant l'achat (le serveur annule aussi les tirs)
    SetEntityInvincible(ped, Tactical.phase == 'buy')
end

---Relève : le joueur revient à côté du soigneur, avec ses armes.
---@param spawn vector4
function Tactical.revive(spawn)
    if not Tactical.isActive() or Tactical.ended then return end
    Tactical.placeAt(spawn, true)
    SetEntityInvincible(PlayerPedId(), false)
end

---@param data table money, loadout, bought, charges, ult, ultCost, role, alive
function Tactical.onSelf(data)
    if not Tactical.isActive() then return end
    Tactical.self = data
    Nui.send('tacSelf', data)
    if State.isAlive() then Tactical.applyLoadout(false) end
end

---@param loadout table
---@return string
function Tactical.loadoutKey(loadout)
    return ('%s|%s|%s'):format(tostring(loadout.primary), tostring(loadout.secondary), tostring(loadout.armor))
end

---Armes et gilet achetés. Seulement si l'équipement a changé (achat, revente, nouvelle manche).
---@param force boolean
function Tactical.applyLoadout(force)
    local data = Tactical.self
    if not data or not data.loadout then return end
    local loadout = data.loadout
    local key = Tactical.loadoutKey(loadout)
    if not force and key == Tactical.applied then return end
    Tactical.applied = key

    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    SetPedInfiniteAmmoClip(ped, false)
    GiveWeaponToPed(ped, GetHashKey(Config.Tactical.knife), 0, false, false)
    local selected = nil
    for _, slot in ipairs({ 'secondary', 'primary' }) do
        local entry = loadout[slot] and Tactical.weapons[loadout[slot]]
        if entry then
            local hash = GetHashKey(entry.id)
            GiveWeaponToPed(ped, hash, entry.ammo, false, false)
            SetPedInfiniteAmmo(ped, false, hash)
            SetPedAmmo(ped, hash, entry.ammo)
            selected = hash
        end
    end
    if selected then SetCurrentPedWeapon(ped, selected, true) end
    SetPedArmour(ped, loadout.armor or 0)
end

---@param slot 'primary'|'secondary'|'knife'
function Tactical.selectWeapon(slot)
    if not Tactical.isActive() or Tactical.ended or not State.isAlive() or IsNuiFocused() or Tactical.acting then return end
    local id = slot == 'knife' and Config.Tactical.knife or (Tactical.self and Tactical.self.loadout[slot])
    if not id then return end
    SetCurrentPedWeapon(PlayerPedId(), GetHashKey(id), true)
end

---@param data table phase, round, remaining, attackers, scores, bomb, board
function Tactical.onState(data)
    if not Tactical.isActive() then return end
    Tactical.state = data
    if data.phase ~= Tactical.phase then
        local previous = Tactical.phase
        Tactical.phase = data.phase
        if previous == 'buy' and data.phase == 'running' then
            Tactical.setBuy(false)
            if State.isAlive() then SetEntityInvincible(PlayerPedId(), false) end
        end
    end
    Nui.send('tacState', data)
    Tactical.updateMates(data.board)
end

---@param data table result, reason, scores, round
function Tactical.onRoundEnd(data)
    if not Tactical.isActive() then return end
    Tactical.phase = 'round_end'
    Tactical.stopHolding()
    Tactical.bomb = nil
    Nui.send('tacRoundEnd', data)
end

-- ---------------------------------------------------------------------------
-- Achat
-- ---------------------------------------------------------------------------

function Tactical.toggleBuy()
    if not Tactical.isActive() or Tactical.ended then return end
    if Tactical.buyOpen then return Tactical.setBuy(false) end
    if Tactical.phase ~= 'buy' or not State.isAlive() or IsNuiFocused() then return end
    Tactical.setBuy(true)
end

---@param open boolean
function Tactical.setBuy(open)
    if open == Tactical.buyOpen then return end
    Tactical.buyOpen = open
    SetNuiFocus(open, open)
    Nui.send('tacBuy', { open = open })
end

-- ---------------------------------------------------------------------------
-- Carte : zone de jeu, sites, coéquipiers
-- ---------------------------------------------------------------------------

---@param data table arena, sites
function Tactical.drawMap(data)
    Tactical.clearBlips()
    local arena = data.arena
    local zone = AddBlipForRadius(arena.center.x, arena.center.y, arena.center.z, arena.radius)
    SetBlipColour(zone, 1)
    SetBlipAlpha(zone, 50)
    Tactical.blips[#Tactical.blips + 1] = zone
    for _, site in ipairs(data.sites) do
        local blip = AddBlipForCoord(site.x, site.y, site.z)
        SetBlipSprite(blip, 486)
        SetBlipColour(blip, 46)
        SetBlipScale(blip, 0.9)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Locale.t('Site %s', site.id))
        EndTextCommandSetBlipName(blip)
        Tactical.blips[#Tactical.blips + 1] = blip
    end
end

function Tactical.clearBlips()
    for _, blip in ipairs(Tactical.blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    Tactical.blips = {}
end

---@param board table[]
function Tactical.updateMates(board)
    local team = Tactical.match.team
    local mates, wanted = {}, {}
    for _, entry in ipairs(board) do
        if entry.team == team and entry.id ~= Tactical.match.self and entry.alive then
            mates[#mates + 1] = entry.id
            wanted[entry.id] = true
            local player = GetPlayerFromServerId(entry.id)
            if not Tactical.mateBlips[entry.id] and player ~= -1 then
                local blip = AddBlipForEntity(GetPlayerPed(player))
                SetBlipColour(blip, 3)
                SetBlipScale(blip, 0.7)
                Tactical.mateBlips[entry.id] = blip
            end
        end
    end
    for id, blip in pairs(Tactical.mateBlips) do
        if not wanted[id] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            Tactical.mateBlips[id] = nil
        end
    end
    Tactical.mates = mates
end

function Tactical.clearMateBlips()
    for id, blip in pairs(Tactical.mateBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        Tactical.mateBlips[id] = nil
    end
    Tactical.mates = {}
end

-- ---------------------------------------------------------------------------
-- Boucle
-- ---------------------------------------------------------------------------

function Tactical.loop()
    while true do
        if Tactical.isActive() then
            local now = GetGameTimer()
            for _, control in ipairs(Tactical.FREED_CONTROLS) do DisableControlAction(0, control, true) end
            if Tactical.ended or Tactical.acting then
                for _, control in ipairs(Tactical.LOCKED_CONTROLS) do DisableControlAction(0, control, true) end
            end
            Tactical.updateScoreboard()
            if not Tactical.ended then
                Tactical.drawSites()
                Tactical.drawMates()
                TacticalAbilities.frame(now)
                if State.isAlive() then
                    if Tactical.phase == 'buy' then
                        Tactical.keepInBuyZone()
                    elseif Tactical.phase == 'running' then
                        Tactical.updateObjective()
                        Tactical.checkArena(now)
                    end
                end
                if Tactical.bomb then Tactical.beep(now) end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end

function Tactical.updateScoreboard()
    DisableControlAction(0, Tactical.CONTROL_SCOREBOARD, true)
    local held = IsDisabledControlPressed(0, Tactical.CONTROL_SCOREBOARD) and not IsNuiFocused()
    if held == Tactical.scoreboard then return end
    Tactical.scoreboard = held
    Nui.send('tacScoreboard', { open = held })
end

---Pendant l'achat : pas de tir, et ramené dans sa zone de départ s'il s'en éloigne.
function Tactical.keepInBuyZone()
    for _, control in ipairs(Tactical.BUY_CONTROLS) do DisableControlAction(0, control, true) end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local spawn = Tactical.round.spawn
    if #(coords.xy - vector2(spawn.x, spawn.y)) <= Tactical.round.buyRadius then
        Tactical.lastInside = coords
    elseif Tactical.lastInside then
        SetEntityCoordsNoOffset(ped, Tactical.lastInside.x, Tactical.lastInside.y, Tactical.lastInside.z, false, false, false)
    end
    if not Tactical.buyOpen then
        HelpNotify.show(Config.Tactical.keys.buy, Locale.t('Phase d\'achat : ouvre le menu d\'achat'))
    end
end

---@param now integer
function Tactical.checkArena(now)
    local arena = Tactical.match.arena
    local ped = PlayerPedId()
    local outside = #(GetEntityCoords(ped).xy - vector2(arena.center.x, arena.center.y)) > arena.radius
    if outside ~= Tactical.outside then
        Tactical.outside = outside
        Nui.send('tacOutside', { outside = outside })
    end
    if outside and now >= Tactical.nextOutsideDamage then
        Tactical.nextOutsideDamage = now + 1000
        ApplyDamageToPed(ped, Config.Tactical.outsideDamage, false)
    end
end

function Tactical.drawSites()
    local radius = Tactical.match.siteRadius
    for _, site in ipairs(Tactical.match.sites) do
        local planted = Tactical.bomb and Tactical.bomb.site == site.id
        local color = planted and Tactical.BOMB_COLOR or Tactical.SITE_COLOR
        DrawMarker(1, site.x, site.y, site.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, radius * 2.0, radius * 2.0, 0.6,
            color[1], color[2], color[3], planted and 90 or 45, false, false, 2, false, nil, nil, false)
    end
end

function Tactical.drawMates()
    local color = Tactical.MATE_COLOR
    for _, id in ipairs(Tactical.mates) do
        local player = GetPlayerFromServerId(id)
        if player ~= -1 then
            local coords = GetEntityCoords(GetPlayerPed(player))
            DrawMarker(2, coords.x, coords.y, coords.z + 1.25, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.18, 0.18, 0.18,
                color[1], color[2], color[3], 200, false, true, 2, false, nil, nil, false)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Charge : pose et désamorçage (touche maintenue, le serveur compte le temps)
-- ---------------------------------------------------------------------------

---@return string|nil texte d'aide si le joueur peut poser ou désamorcer ici
function Tactical.availableAction()
    local state = Tactical.state
    if not state then return nil end
    local coords = GetEntityCoords(PlayerPedId())
    local attacking = Tactical.match.team == state.attackers
    for _, site in ipairs(Tactical.match.sites) do
        if #(coords - vector3(site.x, site.y, site.z)) <= Tactical.match.siteRadius then
            if attacking and not state.bomb then return Locale.t('Maintiens pour poser la charge') end
            if not attacking and state.bomb and state.bomb.site == site.id then return Locale.t('Maintiens pour désamorcer la charge') end
        end
    end
    return nil
end

function Tactical.updateObjective()
    local text = Tactical.availableAction()
    if text and not Tactical.acting then
        HelpNotify.show(HelpNotify.controlKey(Tactical.CONTROL_ACTION), text)
    end
    local pressed = text ~= nil and IsControlPressed(0, Tactical.CONTROL_ACTION) and not IsNuiFocused()
    if pressed ~= Tactical.holding then
        Tactical.holding = pressed
        TriggerServerEvent(Events.server.tacObjective, pressed)
    end
end

function Tactical.stopHolding()
    if Tactical.holding then
        Tactical.holding = false
        TriggerServerEvent(Events.server.tacObjective, false)
    end
    Tactical.onAction(false)
end

---@param data { kind: string, seconds: number }|false
function Tactical.onAction(data)
    local acting = data ~= false and data ~= nil
    if acting == Tactical.acting then return end
    Tactical.acting = acting
    Nui.send('tacAction', acting and data or { kind = false })
    local ped = PlayerPedId()
    if acting then
        CreateThread(function()
            RequestAnimDict(Tactical.ANIM_DICT)
            local timeout = GetGameTimer() + 2000
            while not HasAnimDictLoaded(Tactical.ANIM_DICT) and GetGameTimer() < timeout do Wait(0) end
            if Tactical.acting then
                TaskPlayAnim(ped, Tactical.ANIM_DICT, Tactical.ANIM_NAME, 8.0, -8.0, -1, 1, 0.0, false, false, false)
            end
        end)
    else
        StopAnimTask(ped, Tactical.ANIM_DICT, Tactical.ANIM_NAME, 2.0)
    end
end

---@param data table site, x, y, z
function Tactical.onBombPlanted(data)
    Tactical.bomb = { site = data.site, coords = vector3(data.x, data.y, data.z) }
    Tactical.nextBeep = 0
end

---Bip de la charge, de plus en plus rapide.
---@param now integer
function Tactical.beep(now)
    if now < Tactical.nextBeep then return end
    local remaining = Tactical.state and Tactical.state.remaining or 10
    Tactical.nextBeep = now + (remaining > 20 and 1000 or (remaining > 8 and 500 or 250))
    local coords = Tactical.bomb.coords
    PlaySoundFromCoord(-1, 'Beep_Red', coords.x, coords.y, coords.z, 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false, 40, false)
end

-- ---------------------------------------------------------------------------
-- Mort et fin
-- ---------------------------------------------------------------------------

---Appelé à la mort (Death.check) : le serveur compte le kill. On revient à la manche suivante.
function Tactical.onDeath()
    State.dead = true
    Tactical.setBuy(false)
    Tactical.stopHolding()
    if Tactical.outside then
        Tactical.outside = false
        Nui.send('tacOutside', { outside = false })
    end
    TacticalAbilities.onDeath()
    local ped = PlayerPedId()
    TriggerServerEvent(Events.server.tacDied, PedUtils.getKillerServerId(ped), GetPedCauseOfDeath(ped), Death.getCause(ped).headshot)
end

---@param data { killer: string|nil, weapon: string|nil, spectate: integer|nil }
function Tactical.onDead(data)
    if not Tactical.isActive() then return end
    Nui.send('tacDead', data)
    if data.spectate then
        SetTimeout(1500, function()
            if Tactical.isActive() and State.dead then Death.spectate(data.spectate) end
        end)
    end
end

---@param data table result, reason, team, scores, board, mvp, summary, seconds
function Tactical.finish(data)
    if not Tactical.isActive() then return end
    Tactical.ended = true
    Tactical.setBuy(false)
    Tactical.stopHolding()
    Pause.close()
    Death.stopSpectate()
    Nui.send('tacHud', { open = false })
    Nui.send('tacEnd', data)
    -- Bouton « Continuer » des résultats (retour au menu sans attendre)
    SetNuiFocus(true, true)
end

---Oublie la partie en cours (retour au menu ou au lobby).
function Tactical.clearMatch()
    if Tactical.match then Cod.applyTeam(false) end
    TacticalAbilities.clear()
    Tactical.stopHolding()
    Tactical.setBuy(false)
    Tactical.clearBlips()
    Tactical.clearMateBlips()
    Death.stopSpectate()
    Tactical.match = nil
    Tactical.round = nil
    Tactical.self = nil
    Tactical.state = nil
    Tactical.phase = nil
    Tactical.bomb = nil
    Tactical.ended = false
    Tactical.applied = nil
    if Tactical.scoreboard then Nui.send('tacScoreboard', { open = false }) end
    Tactical.scoreboard = false
    if Tactical.outside then Nui.send('tacOutside', { outside = false }) end
    Tactical.outside = false
    Nui.send('tacHud', { open = false })
    Nui.send('tacEnd', false)
end

---Retour au lobby.
function Tactical.cleanup()
    Tactical.clearMatch()
    Tactical.closeMenu()
    Zone.applyProtection()
    SetNuiFocus(false, false)
    Nui.send('tacQueue', false)
end
