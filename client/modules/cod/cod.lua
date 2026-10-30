---Mode Call of Duty côté client (server/modules/cod/) : menu du mode, placement aux apparitions, classe
---(armes et atouts), santé qui remonte, limite de la zone de combat, signalement de sa mort, HUD.
---Le serveur décide des kills, des scores et de la fin de partie. Les touches qu'il annule désynchronisent
---les joueurs : la protection d'apparition et le tir allié sont donc d'abord bloqués ici, côté jeu.
---@class CodModule
local Cod = PVP.define('Cod')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Lobby = PVP.use('Lobby')
local Spawn = PVP.use('Spawn')
local Death = PVP.use('Death')
local Zone = PVP.use('Zone')
local PedUtils = PVP.use('PedUtils')
local CodObjectives = PVP.use('CodObjectives')
local CodEffects = PVP.use('CodEffects')
local CodPredator = PVP.use('CodPredator')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')
local Pause = PVP.use('Pause')

Cod.FADE = 300
Cod.MODE = 'cod'
Cod.CONTROL_SCOREBOARD = 37 -- INPUT_SELECT_WEAPON (TAB, comme la touche du menu)
-- Pendant le compte à rebours : pas de déplacement ni de tir
Cod.LOCKED_CONTROLS = { 21, 22, 24, 25, 30, 31, 32, 33, 34, 35, 44, 140, 141, 142, 257 }
Cod.REGEN_INTERVAL = 250
Cod.PED_HEIGHT = 1.0 -- m entre les pieds et le centre du personnage
-- Position par défaut de la carte (common:/data/ui/frontend.xml)
Cod.MINIMAP_PARTS = {
    { name = 'minimap', x = -0.0045, y = 0.002, width = 0.150, height = 0.188888 },
    { name = 'minimap_mask', x = 0.020, y = 0.032, width = 0.111, height = 0.159 },
    { name = 'minimap_blur', x = -0.03, y = 0.022, width = 0.266, height = 0.237 },
}
Cod.MATE_COLOR = { 95, 209, 232 }
Cod.GHOST_DELAY = 4000 -- ms à voir mort un joueur vivant pour le serveur (une vraie mort est connue bien avant)

---@type table|nil partie en cours (données envoyées par le serveur : arena, team, ...)
Cod.match = nil
Cod.ended = false
Cod.menuOpen = false
Cod.pickerOpen = false
Cod.scoreboard = false
Cod.profile = nil
Cod.lockedUntil = 0
Cod.arenaBlip = nil
Cod.outside = false
Cod.nextOutsideDamage = 0
Cod.perks = {} -- atouts de la vie en cours : [id] = true
Cod.streakItems = {} -- séries disponibles (la dernière est utilisée en premier)
Cod.mates = {} -- server ids des coéquipiers
Cod.mateBlips = {} -- server id -> repère
Cod.teamGroups = {} -- équipe -> groupe de relations du personnage
Cod.protectedUntil = 0 -- GetGameTimer() de fin de la protection d'apparition, 0 sans protection
Cod.ghosts = {} -- server id -> GetGameTimer() depuis lequel ce joueur vivant apparaît mort ici
Cod.lastHealth = 0
Cod.lastArmor = 0
Cod.lastDamageAt = 0
Cod.nextRegen = 0
Cod.busy = false
Cod.cam = nil -- caméra du menu
Cod.minimapMoved = false
---@type table<string, table> arme -> entrée du catalogue
Cod.weapons = {}

function Cod.init()
    for _, list in pairs(Config.Cod.weapons) do
        for _, entry in ipairs(list) do Cod.weapons[entry.id] = entry end
    end
    for _, team in ipairs({ 'alpha', 'bravo' }) do
        local _, group = AddRelationshipGroup('PVP_COD_' .. team:upper())
        Cod.teamGroups[team] = group
    end
    local alpha, bravo = Cod.teamGroups.alpha, Cod.teamGroups.bravo
    SetRelationshipBetweenGroups(0, alpha, alpha)
    SetRelationshipBetweenGroups(0, bravo, bravo)
    SetRelationshipBetweenGroups(5, alpha, bravo)
    SetRelationshipBetweenGroups(5, bravo, alpha)

    RegisterNetEvent(Events.client.codOpen, function(data)
        Cod.exclusive(function() Cod.openMenu(data) end)
    end)
    RegisterNetEvent(Events.client.codCleanup, function()
        Cod.cleanup()
    end)
    RegisterNetEvent(Events.client.codQueue, function(data)
        Nui.send('codQueue', data or { count = 0 })
    end)
    RegisterNetEvent(Events.client.codStart, function(data)
        Cod.exclusive(function() Cod.start(data) end)
    end)
    RegisterNetEvent(Events.client.codSpawn, function(data)
        if not Cod.match then return end
        Cod.exclusive(function() Cod.respawn(data) end)
    end)
    RegisterNetEvent(Events.client.codState, function(data)
        Cod.onState(data)
    end)
    RegisterNetEvent(Events.client.codKill, function(data)
        Nui.send('codKill', data)
    end)
    RegisterNetEvent(Events.client.codDead, function(data)
        Cod.onDead(data)
    end)
    RegisterNetEvent(Events.client.codScore, function(data)
        Nui.send('codScore', data)
    end)
    RegisterNetEvent(Events.client.codScavenge, function()
        Cod.refillAmmo()
    end)
    RegisterNetEvent(Events.client.codStreak, function(data)
        Cod.streakItems = data.items
        Nui.send('codStreak', data)
    end)
    RegisterNetEvent(Events.client.codNotice, function(data)
        Nui.send('codNotice', data)
    end)
    RegisterNetEvent(Events.client.codRoundEnd, function(data)
        Nui.send('codRoundEnd', data)
    end)
    RegisterNetEvent(Events.client.codEnd, function(data)
        Cod.finish(data)
    end)

    RegisterCommand('pvp_cod_streak', function()
        Cod.useStreak()
    end, false)
    RegisterKeyMapping('pvp_cod_streak', Locale.t('Call of Duty : utiliser une série'), 'keyboard', Config.Cod.streakKey)
    RegisterCommand('pvp_cod_class', function()
        Cod.setPicker(not Cod.pickerOpen)
    end, false)
    RegisterKeyMapping('pvp_cod_class', Locale.t('Call of Duty : changer de classe'), 'keyboard', Config.Cod.classKey)

    RegisterNUICallback('codQueue', function(data, cb)
        cb(Callback.await(Events.callbacks.codQueue, data.playlist) or { ok = false })
    end)
    RegisterNUICallback('codVote', function(data, cb)
        cb(Callback.await(Events.callbacks.codVote, data.map) or { ok = false })
    end)
    RegisterNUICallback('codSaveClass', function(data, cb)
        cb(Cod.storeProfile(Callback.await(Events.callbacks.codSaveClass, data.index, data.class)))
    end)
    RegisterNUICallback('codSaveStreaks', function(data, cb)
        cb(Cod.storeProfile(Callback.await(Events.callbacks.codSaveStreaks, data.streaks)))
    end)
    RegisterNUICallback('codSelectClass', function(data, cb)
        cb(Cod.storeProfile(Callback.await(Events.callbacks.codSelectClass, data.index)))
    end)
    RegisterNUICallback('codLeaderboard', function(_, cb)
        cb(Callback.await(Events.callbacks.codLeaderboard) or { rows = {} })
    end)
    RegisterNUICallback('codPickerClose', function(_, cb)
        Cod.setPicker(false)
        cb({})
    end)

    CreateThread(Cod.loop)
end

---Les changements d'écran (fondus, attentes) s'exécutent l'un après l'autre : le serveur peut
---envoyer le retour au menu et le lancement de la partie suivante presque en même temps.
---@param task function
function Cod.exclusive(task)
    CreateThread(function()
        while Cod.busy do Wait(0) end
        Cod.busy = true
        local ok, message = pcall(task)
        Cod.busy = false
        if not ok then print(('[7PVP] Call of Duty : %s'):format(message)) end
    end)
end

---@param result table|nil réponse du serveur, avec le profil à jour s'il a changé
---@return table
function Cod.storeProfile(result)
    if result and result.profile then
        Cod.profile = result.profile
        Cod.previewClass()
    end
    return result or { ok = false }
end

---@return boolean
function Cod.isActive()
    return State.mode == Cod.MODE and Cod.match ~= nil
end

-- ---------------------------------------------------------------------------
-- Menu du mode
-- ---------------------------------------------------------------------------

---Personnage du joueur au centre, de face, avec l'arme de sa classe (Config.Cod.menuScene).
---@param data { profile: table, catalog: table, appearance: table|nil }
function Cod.openMenu(data)
    -- Arrivée depuis le lobby : il se ferme juste après, et reprendrait le focus
    while Lobby.active do Wait(0) end
    if State.mode ~= Cod.MODE then return end
    Cod.profile = data.profile

    DoScreenFadeOut(Cod.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    Cod.clearMatch()

    Cod.menuOpen = true
    SetNuiFocus(true, true)
    Nui.send('codMenu', { open = true, profile = data.profile, catalog = data.catalog })

    local scene = Config.Cod.menuScene
    Spawn.spawnAt(scene.ped, data.appearance)
    -- Ni la mort, ni le HUD, ni les zones ne concernent le personnage du menu
    State.spawned = false
    local ped = PlayerPedId()
    -- Spawn.spawnAt le pose à la hauteur du sol et compte sur la physique pour le remonter : figé, il y resterait
    local coords = GetEntityCoords(ped)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z + Cod.PED_HEIGHT, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    Cod.previewClass()
    Cod.startMenuCamera(ped, scene)
    DisplayRadar(false)
end

---@param ped integer
---@param scene table
function Cod.startMenuCamera(ped, scene)
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    if not Cod.cam then Cod.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true) end
    SetCamCoord(Cod.cam, coords.x + forward.x * scene.cameraDistance, coords.y + forward.y * scene.cameraDistance, coords.z + scene.cameraHeight)
    PointCamAtCoord(Cod.cam, coords.x, coords.y, coords.z + scene.lookHeight)
    SetCamFov(Cod.cam, scene.fov)
    SetCamActive(Cod.cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

function Cod.stopMenuCamera()
    if not Cod.cam then return end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(Cod.cam, false)
    Cod.cam = nil
end

---Le personnage du menu tient l'arme principale de la classe choisie.
function Cod.previewClass()
    local class = Cod.profile and Cod.profile.classes[Cod.profile.selected]
    if not Cod.menuOpen or not class then return end
    local ped = PlayerPedId()
    local hash = GetHashKey(class.primary)
    RemoveAllPedWeapons(ped, true)
    GiveWeaponToPed(ped, hash, 1, false, true)
    SetCurrentPedWeapon(ped, hash, true)
end

function Cod.closeMenu()
    if not Cod.menuOpen then return end
    Cod.menuOpen = false
    SetNuiFocus(false, false)
    Nui.send('codMenu', { open = false })
    Cod.stopMenuCamera()
    DisplayRadar(true)
end

---Sélecteur de classe en partie : s'applique à la prochaine apparition.
---@param open boolean
function Cod.setPicker(open)
    if open and (not Cod.isActive() or Cod.ended or IsNuiFocused() or CodPredator.isActive()) then return end
    if open == Cod.pickerOpen then return end
    Cod.pickerOpen = open
    SetNuiFocus(open, open)
    Nui.setGameInput(open)
    Nui.send('codPicker', { open = open, profile = Cod.profile })
end

---Menu pause : la carte, en haut à gauche pendant les parties, resterait visible derrière son titre.
---@param open boolean
function Cod.onPause(open)
    if not Cod.isActive() then return end
    DisplayRadar(not open and not CodEffects.jammed)
end

-- ---------------------------------------------------------------------------
-- Partie
-- ---------------------------------------------------------------------------

---Arrivée dans la partie (lancement ou partie rejointe en cours).
---@param data table self, playlist, map, team, teams, arena, countdown, remaining, spawn, class, objectives, ...
function Cod.start(data)
    DoScreenFadeOut(Cod.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    Cod.closeMenu()

    Cod.match = data
    Cod.ended = false
    Cod.lockedUntil = GetGameTimer() + data.countdown * 1000
    Cod.drawArena(data.arena)
    Cod.setMinimapTop(true)
    CodObjectives.setup(data.objectives, data.team)
    Nui.send('codHud', {
        open = true,
        self = data.self,
        playlist = data.playlist,
        map = data.map,
        team = data.team,
        teams = data.teams,
        countdown = data.countdown,
        remaining = data.remaining,
    })
    Cod.placeAt(data.spawn, data.class, data.appearance, data.countdown + data.protection)
end

---@param data { spawn: vector4, class: table, protection: integer }
function Cod.respawn(data)
    if not Cod.match then return end
    Cod.placeAt(data.spawn, data.class, nil, data.protection)
end

---@param spawn vector4
---@param class table
---@param appearance table|nil
---@param protection integer secondes de protection affichées
function Cod.placeAt(spawn, class, appearance, protection)
    CodPredator.stop()
    Spawn.spawnAt(spawn, appearance)
    if not Cod.match then return end
    Cod.applyClass(class)
    Cod.applyTeam(Cod.match.team)
    Cod.protectedUntil = GetGameTimer() + protection * 1000
    SetEntityInvincible(PlayerPedId(), true)
    Cod.outside = false
    Nui.send('codOutside', { outside = false })
    Nui.send('codSpawn', { protection = protection })
end

---Le jeu refuse lui-même le tir sur un allié : le serveur n'a pas de touche à annuler. Il faut les trois
---réglages ensemble ; sans l'hostilité entre équipes (Cod.init), les ennemis seraient protégés aussi.
---@param team string|false 'alpha', 'bravo', false en chacun pour soi ou hors partie
function Cod.applyTeam(team)
    local ped = PlayerPedId()
    SetPedRelationshipGroupHash(ped, Cod.teamGroups[team] or GetHashKey('PLAYER'))
    SetCanAttackFriendly(ped, not team, false)
    NetworkSetFriendlyFireOption(not team)
end

---Fin de la protection d'apparition : au bout du temps, ou au premier tir du joueur.
---@param now integer
function Cod.updateProtection(now)
    local ped = PlayerPedId()
    if now < Cod.protectedUntil and not IsPedShooting(ped) then
        -- Redemandé à chaque image : Zone.update retire l'invincibilité juste après une apparition
        SetEntityInvincible(ped, true)
    else
        Cod.endProtection()
    end
end

function Cod.endProtection()
    Cod.protectedUntil = 0
    Zone.applyProtection()
end

---Armes et atouts de la classe, munitions et vie au maximum.
---@param class table
function Cod.applyClass(class)
    Cod.class = class
    Cod.perks = {}
    for _, perk in ipairs(class.perks) do Cod.perks[perk] = true end
    CodEffects.applyPerks(Cod.perks)

    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    SetPedInfiniteAmmoClip(ped, false)
    GiveWeaponToPed(ped, GetHashKey(Config.Cod.knife), 0, false, false)
    if class.equipment then Cod.giveWeapon(ped, class.equipment) end
    Cod.giveWeapon(ped, class.secondary)
    local primary = Cod.giveWeapon(ped, class.primary)
    SetCurrentPedWeapon(ped, primary, true)

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, Cod.perks.flak and Config.Cod.flakArmor or 0)
    Cod.lastHealth = GetEntityHealth(ped)
    Cod.lastArmor = GetPedArmour(ped)
    Cod.lastDamageAt = 0
end

---@param ped integer
---@param id string arme du catalogue
---@return integer hash
function Cod.giveWeapon(ped, id)
    local hash = GetHashKey(id)
    local entry = Cod.weapons[id]
    GiveWeaponToPed(ped, hash, entry and entry.ammo or 0, false, false)
    SetPedInfiniteAmmo(ped, false, hash)
    SetPedAmmo(ped, hash, entry and entry.ammo or 0)
    return hash
end

---Atout Charognard : chaque kill recharge les munitions de la classe.
function Cod.refillAmmo()
    if not Cod.isActive() or not Cod.class then return end
    local ped = PlayerPedId()
    for _, id in ipairs({ Cod.class.primary, Cod.class.secondary, Cod.class.equipment }) do
        local entry = id and Cod.weapons[id]
        if entry then SetPedAmmo(ped, GetHashKey(id), entry.ammo) end
    end
end

---@param arena { center: vector3, radius: number }
function Cod.drawArena(arena)
    if Cod.arenaBlip and DoesBlipExist(Cod.arenaBlip) then RemoveBlip(Cod.arenaBlip) end
    Cod.arenaBlip = AddBlipForRadius(arena.center.x, arena.center.y, arena.center.z, arena.radius)
    SetBlipColour(Cod.arenaBlip, 1)
    SetBlipAlpha(Cod.arenaBlip, 60)
end

---Carte en haut à gauche pendant les parties, à sa place habituelle ensuite.
---Les trois composants restent alignés en bas à gauche et bougent du même décalage, sinon le masque se décale.
---@param top boolean
function Cod.setMinimapTop(top)
    if top == Cod.minimapMoved then return end
    Cod.minimapMoved = top
    local shift = Config.Cod.minimapShift
    local x, y = top and shift.x or 0.0, top and shift.y or 0.0
    for _, part in ipairs(Cod.MINIMAP_PARTS) do
        SetMinimapComponentPosition(part.name, 'L', 'B', part.x + x, part.y + y, part.width, part.height)
    end
    -- Le jeu ne prend la nouvelle position qu'en basculant le radar
    SetRadarBigmapEnabled(true, false)
    SetRadarBigmapEnabled(false, false)
end

---@param data table remaining, scores, board, objective
function Cod.onState(data)
    if not Cod.isActive() then return end
    Nui.send('codState', data)
    CodObjectives.onState(data.objective)
    Cod.updateMates(data.board)
    if not Cod.ended then Cod.checkGhosts(data.board) end
end

---Un joueur vivant pour le serveur mais mort sur cet écran (touche perdue en route) : sa copie locale
---ne reviendra pas seule, le serveur la fait recréer (CodMatch:resync).
---@param board table[]
function Cod.checkGhosts(board)
    local now = GetGameTimer()
    local ghosts = {}
    for _, entry in ipairs(board) do
        local player = entry.alive and entry.id ~= Cod.match.self and GetPlayerFromServerId(entry.id) or -1
        if player ~= -1 and IsPedDeadOrDying(GetPlayerPed(player), true) then
            ghosts[entry.id] = Cod.ghosts[entry.id] or now
            if now - ghosts[entry.id] >= Cod.GHOST_DELAY then
                TriggerServerEvent(Events.server.codResync, entry.id)
                Cod.clearMateBlips()
                ghosts = {}
                break
            end
        end
    end
    Cod.ghosts = ghosts
end

---Coéquipiers vivants : repère sur la carte et marque au-dessus de la tête (voir Cod.drawMates).
---@param board table[]
function Cod.updateMates(board)
    local team = Cod.match.team
    local mates = {}
    for _, entry in ipairs(board) do
        if team and entry.team == team and entry.id ~= Cod.match.self and entry.alive then
            mates[#mates + 1] = entry.id
        end
    end
    Cod.mates = mates

    local wanted = {}
    for _, id in ipairs(mates) do
        wanted[id] = true
        local player = GetPlayerFromServerId(id)
        if not Cod.mateBlips[id] and player ~= -1 then
            local blip = AddBlipForEntity(GetPlayerPed(player))
            SetBlipColour(blip, 3)
            SetBlipScale(blip, 0.7)
            Cod.mateBlips[id] = blip
        end
    end
    for id, blip in pairs(Cod.mateBlips) do
        if not wanted[id] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            Cod.mateBlips[id] = nil
        end
    end
end

function Cod.clearMateBlips()
    for id, blip in pairs(Cod.mateBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        Cod.mateBlips[id] = nil
    end
end

function Cod.drawMates()
    local color = Cod.MATE_COLOR
    for _, id in ipairs(Cod.mates) do
        local player = GetPlayerFromServerId(id)
        if player ~= -1 then
            local coords = GetEntityCoords(GetPlayerPed(player))
            DrawMarker(2, coords.x, coords.y, coords.z + 1.25, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.18, 0.18, 0.18,
                color[1], color[2], color[3], 200, false, true, 2, false, nil, nil, false)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Boucle
-- ---------------------------------------------------------------------------

function Cod.loop()
    while true do
        if Cod.isActive() then
            local now = GetGameTimer()
            if Cod.ended or now < Cod.lockedUntil or CodObjectives.acting then
                for _, control in ipairs(Cod.LOCKED_CONTROLS) do DisableControlAction(0, control, true) end
            end
            Cod.updateScoreboard()
            Cod.drawMates()
            if Cod.protectedUntil ~= 0 then Cod.updateProtection(now) end
            if not Cod.ended then
                CodObjectives.frame()
                CodEffects.frame(now)
                if State.isAlive() then
                    Cod.checkArena(now)
                    Cod.regenerate(now)
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end

---Tableau des scores : tant que la touche est maintenue.
function Cod.updateScoreboard()
    DisableControlAction(0, Cod.CONTROL_SCOREBOARD, true)
    local held = IsDisabledControlPressed(0, Cod.CONTROL_SCOREBOARD)
    if held == Cod.scoreboard then return end
    Cod.scoreboard = held
    Nui.send('codScoreboard', { open = held })
end

---@param now integer
function Cod.checkArena(now)
    local arena = Cod.match.arena
    local ped = PlayerPedId()
    local outside = #(GetEntityCoords(ped).xy - arena.center.xy) > arena.radius
    if outside ~= Cod.outside then
        Cod.outside = outside
        Nui.send('codOutside', { outside = outside })
    end
    if outside and now >= Cod.nextOutsideDamage then
        Cod.nextOutsideDamage = now + 1000
        ApplyDamageToPed(ped, Cod.match.outsideDamage, false)
    end
end

---La santé remonte seule après quelques secondes sans dégâts (l'armure, non).
---@param now integer
function Cod.regenerate(now)
    local ped = PlayerPedId()
    local health, armor = GetEntityHealth(ped), GetPedArmour(ped)
    if health < Cod.lastHealth or armor < Cod.lastArmor then Cod.lastDamageAt = now end
    Cod.lastHealth, Cod.lastArmor = health, armor

    local regen = Config.Cod.regen
    local delay = (Cod.perks.vitality and regen.fastDelay or regen.delay) * 1000
    local maxHealth = GetEntityMaxHealth(ped)
    if health < maxHealth and now - Cod.lastDamageAt >= delay and now >= Cod.nextRegen then
        Cod.nextRegen = now + Cod.REGEN_INTERVAL
        local gained = math.ceil(regen.perSecond * Cod.REGEN_INTERVAL / 1000)
        SetEntityHealth(ped, math.min(maxHealth, health + gained))
        Cod.lastHealth = GetEntityHealth(ped)
    end
end

-- ---------------------------------------------------------------------------
-- Mort
-- ---------------------------------------------------------------------------

---Appelé à la mort (Death.check) : le serveur compte le kill et renvoie un point de réapparition.
function Cod.onDeath()
    State.dead = true
    CodPredator.stop()
    if Cod.outside then
        Cod.outside = false
        Nui.send('codOutside', { outside = false })
    end
    CodObjectives.stopHolding()
    local ped = PlayerPedId()
    TriggerServerEvent(Events.server.codDied, PedUtils.getKillerServerId(ped), GetPedCauseOfDeath(ped), Death.getCause(ped).headshot)
end

---@param data { killer: string|nil, weapon: string|nil, respawn: integer|false, spectate: integer|nil, revenge: vector3|nil }
function Cod.onDead(data)
    Nui.send('codDead', { killer = data.killer, weapon = data.weapon, respawn = data.respawn })
    if data.spectate then Death.spectate(data.spectate) end
    if data.revenge then CodEffects.markRevenge(data.revenge) end
end

-- ---------------------------------------------------------------------------
-- Séries
-- ---------------------------------------------------------------------------

---Touche des séries : la dernière gagnée.
function Cod.useStreak()
    if not Cod.isActive() or Cod.ended or not State.isAlive() or IsNuiFocused() then return end
    if CodPredator.isActive() or CodObjectives.acting or #Cod.streakItems == 0 then return end
    TriggerServerEvent(Events.server.codUseStreak)
end

-- ---------------------------------------------------------------------------
-- Fin
-- ---------------------------------------------------------------------------

---Résultats : le joueur reste figé en attendant le retour au menu (envoyé par le serveur).
---@param data table result, reason, scores, board, summary, seconds
function Cod.finish(data)
    if not Cod.isActive() then return end
    Cod.ended = true
    CodPredator.stop()
    Cod.setPicker(false)
    Pause.close()
    CodObjectives.stopHolding()
    Nui.send('codHud', { open = false })
    Nui.send('codEnd', data)
end

---Oublie la partie en cours (retour au menu ou au lobby).
function Cod.clearMatch()
    CodPredator.stop()
    Cod.setPicker(false)
    Pause.close()
    Cod.match = nil
    Cod.ended = false
    Cod.class = nil
    Cod.perks = {}
    Cod.streakItems = {}
    Cod.mates = {}
    Cod.lockedUntil = 0
    if Cod.outside then Nui.send('codOutside', { outside = false }) end
    Cod.outside = false
    if Cod.scoreboard then Nui.send('codScoreboard', { open = false }) end
    Cod.scoreboard = false
    if Cod.arenaBlip and DoesBlipExist(Cod.arenaBlip) then RemoveBlip(Cod.arenaBlip) end
    Cod.arenaBlip = nil
    Cod.clearMateBlips()
    Cod.ghosts = {}
    if Cod.protectedUntil ~= 0 then Cod.endProtection() end
    Cod.applyTeam(false)
    Death.stopSpectate()
    CodObjectives.clear()
    CodEffects.clear()
    Cod.setMinimapTop(false)
    Nui.send('codHud', { open = false })
end

---Retour au lobby : il reprend le focus et cache le personnage juste après.
function Cod.cleanup()
    Cod.clearMatch()
    Cod.stopMenuCamera()
    Cod.menuOpen = false
    SetNuiFocus(false, false)
    Nui.send('codMenu', { open = false })
    Nui.send('codQueue', { count = 0 })
end
