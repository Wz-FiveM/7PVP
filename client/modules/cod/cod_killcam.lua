---Kill cam du mode Call of Duty : la victime revoit le kill par les yeux du tueur. GTA ne sait pas rejouer une scène
---en pleine partie : chaque client enregistre donc ses dernières secondes, le tueur envoie les siennes à la victime
---(server/modules/cod/cod_match.lua) et celle-ci les rejoue avec des copies locales des deux personnages, sans
---entité réseau, pendant que la vraie partie continue et que les vrais joueurs sont masqués sur son écran.
---@class CodKillcamModule
local CodKillcam = PVP.define('CodKillcam')
local Cod = PVP.use('Cod')
local CodEffects = PVP.use('CodEffects')
local Appearance = PVP.use('Appearance')
local Death = PVP.use('Death')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local PedUtils = PVP.use('PedUtils')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

CodKillcam.FADE = 200
CodKillcam.KILL_SHOT_WINDOW = 1500 -- ms : un tir plus ancien que la demande du serveur n'est pas le tir fatal
CodKillcam.NO_SHOT_DELAY = 200 -- ms avant la demande du serveur : moment du kill sans tir enregistré (couteau, explosif)
CodKillcam.MIN_LENGTH = 800 -- ms d'enregistrement du tueur : en dessous, pas de kill cam
CodKillcam.MAX_STEP = 100 -- ms : avance maximale du replay en une image
CodKillcam.DAMAGE_BULLET = 3 -- GetWeaponDamageType : seules les balles sont rejouées, un explosif exploserait vraiment
CodKillcam.FLAG_AIMING = 1
CodKillcam.FLAG_STEALTH = 2

CodKillcam.MOVE_MIN = 0.4 -- m/s : en dessous, le personnage est immobile
CodKillcam.WALK_MAX = 2.4 -- m/s
CodKillcam.RUN_MAX = 5.6 -- m/s
CodKillcam.BLEND_WALK = 1.0
CodKillcam.BLEND_RUN = 2.0
CodKillcam.BLEND_SPRINT = 3.0
CodKillcam.TASK_INTERVAL = 200 -- ms entre deux changements d'ordre donnés à une copie
CodKillcam.TASK_TURN = 30.0 -- degrés de changement de direction avant un nouvel ordre
CodKillcam.TASK_DISTANCE = 30.0 -- m : point visé par la marche (sa position réelle reste imposée à chaque image)
CodKillcam.AIM_DISTANCE = 30.0 -- m devant la caméra : point visé par la copie
CodKillcam.AIM_MODEL = GetHashKey('prop_golf_ball')
CodKillcam.FIRING_PATTERN = GetHashKey('FIRING_PATTERN_FULL_AUTO')

CodKillcam.FIRST_PERSON_DISTANCE = 0.85 -- m entre la caméra et le personnage : en dessous, le tueur jouait en vue à la 1re personne
CodKillcam.SCOPE_FOV = 25.0 -- champ de vision de la lunette : on garde la vue du tueur, sans son personnage
CodKillcam.SHOULDER_BACK = 1.6 -- m : en vue à la 1re personne, la caméra recule derrière l'épaule
CodKillcam.SHOULDER_SIDE = 0.45 -- m
CodKillcam.BONE_HAND = 57005 -- SKEL_R_Hand
CodKillcam.BONE_CHEST = 24818 -- SKEL_Spine3
CodKillcam.MUZZLE_BONE = 'gun_muzzle'
CodKillcam.MUZZLE_FLASH = 'muz_assault_rifle'
CodKillcam.TRACER_TIME = 70 -- ms d'affichage d'une traçante

---@type table[] relevés du joueur local, du plus ancien au plus récent
CodKillcam.samples = {}
---@type table[] tirs du joueur local
CodKillcam.shots = {}
CodKillcam.nextSample = 0
CodKillcam.deadAt = nil
---@type table|nil kill cam en attente ou en cours : data, own, cam, killer, victim, tracers, faded, shown, skipped
CodKillcam.session = nil
CodKillcam.blackout = false -- écran resté noir après une kill cam, en attendant la réapparition

function CodKillcam.init()
    RegisterNetEvent(Events.client.codKillcamRequest, function(victim)
        CodKillcam.onRequest(victim)
    end)
    RegisterNetEvent(Events.client.codKillcamClip, function(clip)
        CodKillcam.onClip(clip)
    end)
    RegisterNetEvent(Events.client.codKillcamOwn, function()
        TriggerServerEvent(Events.server.codKillcamOwn, CodKillcam.snapshot(CodKillcam.deadAt or GetGameTimer()))
    end)
    RegisterNetEvent(Events.client.codFinalKillcam, function(data)
        CodKillcam.playFinal(data)
    end)
    RegisterCommand('pvp_cod_killcam_skip', function()
        local session = CodKillcam.session
        if session and session.shown and not session.final then session.skipped = true end
    end, false)
    RegisterKeyMapping('pvp_cod_killcam_skip', Locale.t('Call of Duty : passer la kill cam'), 'keyboard', Config.Cod.killcam.skipKey)
end

---@return boolean
function CodKillcam.isPlaying()
    return CodKillcam.session ~= nil and CodKillcam.session.shown == true
end

-- ---------------------------------------------------------------------------
-- Enregistrement
-- ---------------------------------------------------------------------------

---À chaque image de la partie.
---@param now integer
function CodKillcam.record(now)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        CodKillcam.deadAt = CodKillcam.deadAt or now
        return
    end
    CodKillcam.deadAt = nil
    local settings = Config.Cod.killcam
    local keep = settings.before + settings.after + CodKillcam.KILL_SHOT_WINDOW

    local weapon = GetSelectedPedWeapon(ped)
    if IsPedShooting(ped) and GetWeaponDamageType(weapon) == CodKillcam.DAMAGE_BULLET then
        local point = CodEffects.aimPoint()
        CodKillcam.shots[#CodKillcam.shots + 1] = { at = now, x = point.x, y = point.y, z = point.z }
    end
    while CodKillcam.shots[1] and now - CodKillcam.shots[1].at > keep do table.remove(CodKillcam.shots, 1) end

    if now < CodKillcam.nextSample then return end
    CodKillcam.nextSample = now + settings.sampleInterval
    local coords = GetEntityCoords(ped)
    local cam = GetGameplayCamCoord()
    local rotation = GetGameplayCamRot(2)
    local flags = 0
    if IsPlayerFreeAiming(PlayerId()) or IsPedShooting(ped) then flags = flags | CodKillcam.FLAG_AIMING end
    if GetPedStealthMovement(ped) then flags = flags | CodKillcam.FLAG_STEALTH end
    CodKillcam.samples[#CodKillcam.samples + 1] = {
        at = now,
        coords = coords,
        heading = GetEntityHeading(ped),
        cam = cam,
        pitch = rotation.x,
        yaw = rotation.z,
        fov = GetGameplayCamFov(),
        flags = flags,
        weapon = weapon,
    }
    while now - CodKillcam.samples[1].at > keep do table.remove(CodKillcam.samples, 1) end
end

---Après une réapparition : l'enregistrement ne doit pas relier deux vies.
function CodKillcam.resetRecording()
    CodKillcam.samples = {}
    CodKillcam.shots = {}
    CodKillcam.nextSample = 0
    CodKillcam.deadAt = nil
end

---@param value number
---@param scale number
---@return integer
local function pack(value, scale)
    return math.floor(value * scale + 0.5)
end

---Enregistrement compact, à envoyer par le réseau. Les temps comptent à partir du kill.
---@param anchor integer GetGameTimer() du kill
---@return { samples: integer[][], shots: integer[][], weapons: integer[], loadout: table[] }
function CodKillcam.snapshot(anchor)
    local settings = Config.Cod.killcam
    local clip = { samples = {}, shots = {}, weapons = {}, loadout = {} }
    -- Accessoires et camouflage à remontrer sur les armes de la classe
    if Cod.class then
        clip.loadout[1] = { weapon = Cod.class.primary, mods = Cod.class.primaryMods }
        clip.loadout[2] = { weapon = Cod.class.secondary, mods = Cod.class.secondaryMods }
    end
    local weaponIndex = {}
    for _, sample in ipairs(CodKillcam.samples) do
        local t = sample.at - anchor
        if t >= -settings.before and t <= settings.after then
            if not weaponIndex[sample.weapon] then
                clip.weapons[#clip.weapons + 1] = sample.weapon
                weaponIndex[sample.weapon] = #clip.weapons
            end
            clip.samples[#clip.samples + 1] = {
                t,
                pack(sample.coords.x, 100), pack(sample.coords.y, 100), pack(sample.coords.z, 100),
                pack(sample.heading, 10),
                pack(sample.cam.x - sample.coords.x, 100), pack(sample.cam.y - sample.coords.y, 100), pack(sample.cam.z - sample.coords.z, 100),
                pack(sample.pitch, 10), pack(sample.yaw, 10), pack(sample.fov, 10),
                sample.flags,
                weaponIndex[sample.weapon],
            }
        end
    end
    for _, shot in ipairs(CodKillcam.shots) do
        local t = shot.at - anchor
        if t >= -settings.before and t <= 0 then
            clip.shots[#clip.shots + 1] = { t, pack(shot.x, 100), pack(shot.y, 100), pack(shot.z, 100) }
        end
    end
    return clip
end

---@param clip table voir CodKillcam.snapshot
---@return { samples: table[], shots: table[], loadout: table[], cursor: integer }
function CodKillcam.decode(clip)
    local track = { samples = {}, shots = {}, loadout = clip.loadout, cursor = 1 }
    for index, entry in ipairs(clip.samples) do
        local coords = vector3(entry[2] / 100, entry[3] / 100, entry[4] / 100)
        track.samples[index] = {
            t = entry[1],
            coords = coords,
            heading = entry[5] / 10,
            cam = coords + vector3(entry[6] / 100, entry[7] / 100, entry[8] / 100),
            pitch = entry[9] / 10,
            yaw = entry[10] / 10,
            fov = entry[11] / 10,
            flags = entry[12],
            weapon = clip.weapons[entry[13]],
        }
    end
    for index, entry in ipairs(clip.shots) do
        track.shots[index] = { t = entry[1], to = vector3(entry[2] / 100, entry[3] / 100, entry[4] / 100) }
    end
    return track
end

---Le serveur demande notre enregistrement : ce kill vient d'avoir lieu. On enregistre encore un peu pour montrer la
---suite, puis le temps zéro est le dernier tir, sinon un instant avant la demande.
---@param victim integer
function CodKillcam.onRequest(victim)
    local requestedAt = GetGameTimer()
    SetTimeout(Config.Cod.killcam.after, function()
        if not Cod.isActive() then return end
        local anchor = requestedAt - CodKillcam.NO_SHOT_DELAY
        for index = #CodKillcam.shots, 1, -1 do
            local at = CodKillcam.shots[index].at
            if at <= requestedAt then
                if requestedAt - at <= CodKillcam.KILL_SHOT_WINDOW then anchor = at end
                break
            end
        end
        TriggerServerEvent(Events.server.codKillcamClip, victim, CodKillcam.snapshot(anchor))
    end)
end

-- ---------------------------------------------------------------------------
-- Attente de l'enregistrement du tueur
-- ---------------------------------------------------------------------------

---Le serveur a confirmé notre mort : l'enregistrement du tueur arrive après Config.Cod.killcam.after.
---@param data table voir Cod.onDead
function CodKillcam.await(data)
    CodKillcam.stop()
    local session = {
        data = data,
        diedAt = GetGameTimer(),
        own = CodKillcam.decode(CodKillcam.snapshot(CodKillcam.deadAt or GetGameTimer())),
        tracers = {},
        entities = {},
    }
    CodKillcam.session = session
    SetTimeout(Config.Cod.killcam.clipTimeout, function()
        if CodKillcam.session == session and not session.started then CodKillcam.finish(session) end
    end)
end

---@param clip table voir CodKillcam.snapshot
function CodKillcam.onClip(clip)
    local session = CodKillcam.session
    if not session or session.started then return end
    session.started = true
    CreateThread(function()
        local ok, message = pcall(CodKillcam.play, session, clip)
        if not ok then print(('[7PVP] Kill cam : %s'):format(message)) end
        CodKillcam.release(session)
        if CodKillcam.session == session then CodKillcam.finish(session) end
    end)
end

---Fin de partie : tout le monde revoit le dernier kill. L'écran reste noir après le replay : les résultats, envoyés par
---le serveur au bout de Config.Cod.killcam.finalDuration, le rouvrent (Cod.finish).
---@param data table killcam (tueur), victim, killer, weapon, card, clip, own (enregistrement de la victime)
function CodKillcam.playFinal(data)
    if not Cod.isActive() then return end
    CodKillcam.stop()
    local session = {
        data = data,
        final = true,
        started = true,
        diedAt = GetGameTimer(),
        own = CodKillcam.decode(data.own or { samples = {}, shots = {}, weapons = {}, loadout = {} }),
        tracers = {},
        entities = {},
    }
    CodKillcam.session = session
    CreateThread(function()
        local ok, message = pcall(CodKillcam.play, session, data.clip)
        if not ok then print(('[7PVP] Kill cam finale : %s'):format(message)) end
        CodKillcam.release(session)
    end)
end

-- ---------------------------------------------------------------------------
-- Replay
-- ---------------------------------------------------------------------------

---@param session table
---@param clip table
function CodKillcam.play(session, clip)
    local settings = Config.Cod.killcam
    local data = session.data
    local track = CodKillcam.decode(clip)
    local samples = track.samples
    if #samples < 2 or samples[#samples].t - samples[1].t < CodKillcam.MIN_LENGTH then return end
    local player = GetPlayerFromServerId(data.killcam)
    -- Trop loin : le jeu ne l'a pas chargé, pas de personnage à copier
    if player == -1 or not DoesEntityExist(GetPlayerPed(player)) then return end

    session.faded = true
    DoScreenFadeOut(CodKillcam.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    if CodKillcam.session ~= session then return end

    session.killer = CodKillcam.createKiller(session, GetPlayerPed(player), track)
    session.victim = CodKillcam.createVictim(session)
    if CodKillcam.session ~= session then return end

    local clock = math.max(-settings.before, samples[1].t)
    CodKillcam.startCamera(session, clock)
    local timeout = GetGameTimer() + 500
    while CodKillcam.session == session and not HasCollisionLoadedAroundEntity(session.killer.ped) and GetGameTimer() < timeout do
        CodKillcam.frame(session, clock)
        Wait(0)
    end
    if CodKillcam.session ~= session then return end

    session.shown = true
    Nui.send('codKillcam', {
        open = true,
        killer = data.killer,
        weapon = data.weapon,
        card = data.card,
        key = not session.final and settings.skipKey or nil,
        final = session.final,
    })
    DoScreenFadeIn(CodKillcam.FADE)

    -- Le temps du réseau : le ralenti du monde pourrait fausser les autres horloges du jeu
    local last = GetNetworkTime()
    while CodKillcam.session == session and not session.skipped and clock < settings.after do
        local now = GetNetworkTime()
        local rate = (clock >= -settings.slowBefore and clock < settings.slowAfter) and settings.slowRate or 1.0
        clock = clock + math.max(0, math.min(now - last, CodKillcam.MAX_STEP)) * rate
        last = now
        if rate ~= session.rate then
            session.rate = rate
            SetTimeScale(rate)
        end
        CodKillcam.frame(session, clock)
        Wait(0)
    end
    if CodKillcam.session ~= session then return end

    if session.rate ~= 1.0 then
        session.rate = 1.0
        SetTimeScale(1.0)
    end
    DoScreenFadeOut(CodKillcam.FADE)
    while CodKillcam.session == session and not IsScreenFadedOut() do
        CodKillcam.frame(session, clock)
        Wait(0)
    end
end

---@param session table
---@param entity integer
---@return integer entity
function CodKillcam.keep(session, entity)
    session.entities[#session.entities + 1] = entity
    return entity
end

---Personnage sans intelligence, invulnérable, qui ne fait que ce que le replay lui dit.
---@param session table
---@param ped integer
---@param track table
---@return table acteur
function CodKillcam.createActor(session, ped, track)
    CodKillcam.keep(session, ped)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedKeepTask(ped, true)
    StopPedSpeaking(ped, true)
    DisablePedPainAudio(ped, true)
    ClearPedTasksImmediately(ped)

    local given = {}
    for _, sample in ipairs(track.samples) do
        if not given[sample.weapon] then
            given[sample.weapon] = true
            RequestWeaponAsset(sample.weapon, 31, 0)
            GiveWeaponToPed(ped, sample.weapon, 9999, false, false)
        end
    end
    for _, entry in ipairs(track.loadout) do Cod.applyMods(ped, entry.weapon, entry.mods) end

    local actor = { ped = ped, track = track, nextTask = 0 }
    if PedUtils.loadModel(CodKillcam.AIM_MODEL) then
        local first = track.samples[1].coords
        actor.aim = CodKillcam.keep(session, CreateObject(CodKillcam.AIM_MODEL, first.x, first.y, first.z, false, false, false))
        SetEntityVisible(actor.aim, false, false)
        SetEntityCollision(actor.aim, false, false)
        FreezeEntityPosition(actor.aim, true)
        SetModelAsNoLongerNeeded(CodKillcam.AIM_MODEL)
    end
    return actor
end

---@param session table
---@param source integer personnage réel du tueur
---@param track table
---@return table acteur
function CodKillcam.createKiller(session, source, track)
    local ped = ClonePed(source, false, false, true)
    if not DoesEntityExist(ped) then error('copie du tueur impossible') end
    local actor = CodKillcam.createActor(session, ped, track)
    if IsEntityDead(ped) then ResurrectPed(ped) end
    RequestNamedPtfxAsset('core')
    return actor
end

---La victime est recréée d'après son apparence : son personnage réel est déjà mort. Dans la kill cam finale, ce peut
---être n'importe quel joueur : elle est copiée, comme le tueur.
---@param session table
---@return table|nil acteur
function CodKillcam.createVictim(session)
    local track = session.own
    if #track.samples == 0 then return nil end
    if session.final then
        local player = GetPlayerFromServerId(session.data.victim)
        if player == -1 then return nil end
        local copy = ClonePed(GetPlayerPed(player), false, false, true)
        if not DoesEntityExist(copy) then return nil end
        local actor = CodKillcam.createActor(session, copy, track)
        if IsEntityDead(copy) then ResurrectPed(copy) end
        return actor
    end
    local model = GetEntityModel(PlayerPedId())
    if not PedUtils.loadModel(model) then return nil end
    local first = track.samples[1]
    local ped = CreatePed(4, model, first.coords.x, first.coords.y, first.coords.z, first.heading, false, false)
    if State.appearance then Appearance.apply(ped, State.appearance) end
    return CodKillcam.createActor(session, ped, track)
end

---@param track table
---@param t number
---@return table relevé courant, table relevé suivant, number position entre les deux (0 à 1)
function CodKillcam.locate(track, t)
    local samples = track.samples
    while track.cursor < #samples and samples[track.cursor + 1].t <= t do
        track.cursor = track.cursor + 1
    end
    local from = samples[track.cursor]
    local to = samples[math.min(track.cursor + 1, #samples)]
    local span = to.t - from.t
    local alpha = span > 0 and math.max(0.0, math.min(1.0, (t - from.t) / span)) or 0.0
    return from, to, alpha
end

---@param from number degrés
---@param to number degrés
---@return number écart le plus court, de -180 à 180
local function angleGap(from, to)
    return (to - from + 180.0) % 360.0 - 180.0
end

---@param pitch number degrés
---@param yaw number degrés
---@return vector3
local function directionOf(pitch, yaw)
    local p, y = math.rad(pitch), math.rad(yaw)
    return vector3(-math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), math.sin(p))
end

---@param session table
---@param clock number
function CodKillcam.startCamera(session, clock)
    session.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(session.cam, true)
    RenderScriptCams(true, false, 0, true, true)
    CodKillcam.frame(session, clock)
end

---Une image du replay.
---@param session table
---@param clock number ms depuis le kill
function CodKillcam.frame(session, clock)
    HideHudAndRadarThisFrame()
    CodKillcam.hidePlayers()
    CodKillcam.drive(session.killer, clock)
    CodKillcam.fireShots(session, clock)
    local victim = session.victim
    if victim and not victim.dead then
        if clock >= 0 then
            victim.dead = true
            SetEntityInvincible(victim.ped, false)
            SetPedCanRagdoll(victim.ped, true)
            SetEntityHealth(victim.ped, 0)
        else
            CodKillcam.drive(victim, clock)
        end
    end
    CodKillcam.updateCamera(session, clock)
    CodKillcam.drawTracers(session)
end

---Les vrais joueurs (et le corps du joueur local) ne doivent pas se mêler au replay.
function CodKillcam.hidePlayers()
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        SetEntityLocallyInvisible(ped)
        local weapon = GetCurrentPedWeaponEntityIndex(ped)
        if weapon ~= 0 then SetEntityLocallyInvisible(weapon) end
    end
end

---Position et cap imposés à chaque image ; les ordres de marche et de visée ne servent qu'à jouer les bonnes animations.
---@param actor table
---@param clock number
function CodKillcam.drive(actor, clock)
    local from, to, alpha = CodKillcam.locate(actor.track, clock)
    local coords = from.coords + (to.coords - from.coords) * alpha
    SetEntityCoordsNoOffset(actor.ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(actor.ped, from.heading + angleGap(from.heading, to.heading) * alpha)

    if actor.aim then
        local pitch = from.pitch + angleGap(from.pitch, to.pitch) * alpha
        local yaw = from.yaw + angleGap(from.yaw, to.yaw) * alpha
        local cam = from.cam + (to.cam - from.cam) * alpha
        local point = cam + directionOf(pitch, yaw) * CodKillcam.AIM_DISTANCE
        SetEntityCoordsNoOffset(actor.aim, point.x, point.y, point.z, false, false, false)
    end
    if from.weapon ~= actor.weapon then
        actor.weapon = from.weapon
        SetCurrentPedWeapon(actor.ped, from.weapon, true)
    end
    local stealth = (from.flags & CodKillcam.FLAG_STEALTH) ~= 0
    if stealth ~= (actor.stealth or false) then
        actor.stealth = stealth
        SetPedStealthMovement(actor.ped, stealth, 'DEFAULT_ACTION')
    end
    CodKillcam.updateTask(actor, from, to, coords)
end

---@param actor table
---@param from table
---@param to table
---@param coords vector3
function CodKillcam.updateTask(actor, from, to, coords)
    local gap = (to.coords - from.coords).xy
    local span = to.t - from.t
    local speed = span > 0 and #gap / (span / 1000) or 0.0
    local blend = 0.0
    if speed >= CodKillcam.MOVE_MIN then
        blend = speed < CodKillcam.WALK_MAX and CodKillcam.BLEND_WALK
            or (speed < CodKillcam.RUN_MAX and CodKillcam.BLEND_RUN or CodKillcam.BLEND_SPRINT)
    end
    local aiming = actor.aim ~= nil and (from.flags & CodKillcam.FLAG_AIMING) ~= 0
    local direction = blend > 0.0 and GetHeadingFromVector_2d(gap.x, gap.y) or 0.0
    if blend == actor.blend and aiming == actor.aiming and math.abs(angleGap(actor.direction or 0.0, direction)) < CodKillcam.TASK_TURN then return end

    local now = GetGameTimer()
    if now < actor.nextTask then return end
    actor.nextTask = now + CodKillcam.TASK_INTERVAL
    actor.blend, actor.aiming, actor.direction = blend, aiming, direction

    local ped = actor.ped
    if blend > 0.0 then
        local step = gap / #gap * CodKillcam.TASK_DISTANCE
        local x, y = coords.x + step.x, coords.y + step.y
        if aiming then
            TaskGoToCoordWhileAimingAtEntity(ped, x, y, coords.z, actor.aim, blend, false, 0.5, 4.0, false, 0, true, CodKillcam.FIRING_PATTERN, -1)
        else
            TaskGoStraightToCoord(ped, x, y, coords.z, blend, -1, direction, 0.0)
        end
    elseif aiming then
        TaskAimGunAtEntity(ped, actor.aim, -1, true)
    else
        ClearPedTasks(ped)
    end
end

---Balles sans dégâts, pour le bruit et l'impact. Le tir fatal part toujours vers la victime : les deux enregistrements
---viennent de deux écrans et ne coïncident pas au centimètre près.
---@param session table
---@param clock number
function CodKillcam.fireShots(session, clock)
    local track = session.killer.track
    session.nextShot = session.nextShot or 1
    while track.shots[session.nextShot] and track.shots[session.nextShot].t <= clock do
        local shot = track.shots[session.nextShot]
        session.nextShot = session.nextShot + 1
        -- Les tirs déjà passés au début du replay ne sont pas rejoués
        if clock - shot.t < CodKillcam.MAX_STEP then CodKillcam.fire(session, shot) end
    end
end

---@param session table
---@param shot { t: number, to: vector3 }
function CodKillcam.fire(session, shot)
    if GetWeaponDamageType(session.killer.weapon) ~= CodKillcam.DAMAGE_BULLET then return end
    local ped = session.killer.ped
    local victim = session.victim
    local to = shot.to
    if shot.t == 0 and victim and not victim.dead then
        to = GetPedBoneCoords(victim.ped, CodKillcam.BONE_CHEST, 0.0, 0.0, 0.0)
    end
    local start = GetPedBoneCoords(ped, CodKillcam.BONE_HAND, 0.0, 0.0, 0.0)
    local weapon = GetCurrentPedWeaponEntityIndex(ped)
    if weapon ~= 0 then
        local bone = GetEntityBoneIndexByName(weapon, CodKillcam.MUZZLE_BONE)
        if bone ~= -1 then start = GetWorldPositionOfEntityBone(weapon, bone) end
    end
    ShootSingleBulletBetweenCoords(start.x, start.y, start.z, to.x, to.y, to.z, 0, true, session.killer.weapon, ped, true, false, -1.0)
    if HasNamedPtfxAssetLoaded('core') then
        local gap = to - start
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedAtCoord(CodKillcam.MUZZLE_FLASH, start.x, start.y, start.z,
            0.0, 0.0, GetHeadingFromVector_2d(gap.x, gap.y) + 90.0, 1.0, false, false, false)
    end
    session.tracers[#session.tracers + 1] = { from = start, to = to, untilAt = GetGameTimer() + CodKillcam.TRACER_TIME }
end

---@param session table
function CodKillcam.drawTracers(session)
    local now = GetGameTimer()
    for index = #session.tracers, 1, -1 do
        local tracer = session.tracers[index]
        if now >= tracer.untilAt then
            table.remove(session.tracers, index)
        else
            DrawLine(tracer.from.x, tracer.from.y, tracer.from.z, tracer.to.x, tracer.to.y, tracer.to.z, 255, 214, 130, 230)
        end
    end
end

---La caméra du tueur telle qu'il la voyait. En vue à la 1re personne, on ne verrait que l'intérieur de sa tête :
---elle recule derrière son épaule. Sauf à la lunette, où son personnage est masqué.
---@param session table
---@param clock number
function CodKillcam.updateCamera(session, clock)
    local killer = session.killer
    local from, to, alpha = CodKillcam.locate(killer.track, clock)
    local cam = from.cam + (to.cam - from.cam) * alpha
    local pitch = from.pitch + angleGap(from.pitch, to.pitch) * alpha
    local yaw = from.yaw + angleGap(from.yaw, to.yaw) * alpha
    local fov = from.fov + (to.fov - from.fov) * alpha
    local coords = from.coords + (to.coords - from.coords) * alpha

    if #(cam - coords) < CodKillcam.FIRST_PERSON_DISTANCE then
        if fov < CodKillcam.SCOPE_FOV then
            SetEntityLocallyInvisible(killer.ped)
        else
            local forward = directionOf(pitch, yaw)
            local right = vector3(forward.y, -forward.x, 0.0)
            cam = cam - forward * CodKillcam.SHOULDER_BACK + right * CodKillcam.SHOULDER_SIDE
        end
    end
    SetCamCoord(session.cam, cam.x, cam.y, cam.z)
    SetCamRot(session.cam, pitch, 0.0, yaw, 2)
    SetCamFov(session.cam, fov)
    SetFocusPosAndVel(cam.x, cam.y, cam.z, 0.0, 0.0, 0.0)
end

-- ---------------------------------------------------------------------------
-- Fin
-- ---------------------------------------------------------------------------

---Rend la caméra et le temps, retire les copies. Peut être appelé plusieurs fois.
---@param session table
function CodKillcam.release(session)
    if session.rate then
        session.rate = nil
        SetTimeScale(1.0)
    end
    if session.cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(session.cam, false)
        ClearFocus()
        session.cam = nil
    end
    for _, entity in ipairs(session.entities) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    session.entities = {}
    if session.shown then
        session.shown = false
        Nui.send('codKillcam', { open = false })
    end
end

---Fin du replay, ou pas de replay : la réapparition peut avoir lieu. Le serveur y répond aussitôt si le délai normal
---est passé : l'écran reste alors noir, Spawn.spawnAt le rouvre.
---@param session table
function CodKillcam.finish(session)
    CodKillcam.release(session)
    CodKillcam.session = nil
    local data = session.data
    TriggerServerEvent(Events.server.codKillcamDone)

    local remaining = data.respawn and math.max(0, math.ceil(data.respawn - (GetGameTimer() - session.diedAt) / 1000))
    Nui.send('codDead', { killer = data.killer, weapon = data.weapon, respawn = remaining, card = data.card })
    if session.faded and data.respawn then
        CodKillcam.blackout = true
        return
    end
    if session.faded then DoScreenFadeIn(CodKillcam.FADE) end
    if data.spectate then Death.spectate(data.spectate) end
end

---Fin immédiate, quelle qu'en soit la raison (réapparition, fin de partie, retour au menu).
---@param keepBlack boolean|nil l'écran reste noir : la suite le rouvrira
function CodKillcam.stop(keepBlack)
    local session = CodKillcam.session
    local black = CodKillcam.blackout or (session ~= nil and session.faded == true)
    CodKillcam.session = nil
    CodKillcam.blackout = false
    if session then CodKillcam.release(session) end
    if black and not keepBlack then DoScreenFadeIn(CodKillcam.FADE) end
end
