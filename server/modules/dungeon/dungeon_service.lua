---Donjons du mode PvP : salles d'attente, invitations, clés, entrée et sortie de l'instance, vies et commandes.
---Le déroulement d'une partie est dans DungeonRoom. Dans l'instance, le joueur compte comme dans
---le monde zombies (pas de PvP, zombies, équilibrage PvE) : voir PveWorldService.
---@class DungeonServiceModule
local DungeonService = PVP.define('DungeonService')
local DungeonRoom = PVP.use('DungeonRoom')
local PlayerService = PVP.use('PlayerService')
local PveWorldService = PVP.use('PveWorldService')
local CombatTagService = PVP.use('CombatTagService')
local AntiCheatService = PVP.use('AntiCheatService')
local AdminService = PVP.use('AdminService')
local LootService = PVP.use('LootService')
local SafeNpcs = PVP.use('SafeNpcs')
local Zones = PVP.use('Zones')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

DungeonService.TICK_INTERVAL = 1000
DungeonService.STATE = 'dungeonBucket'
-- Temps laissé au retour : le joueur est encore loin de la zone safe pendant sa téléportation
DungeonService.RETURN_GRACE = 8000

---@type table<integer, DungeonRoom>
DungeonService.rooms = {}
---@type table<integer, DungeonRoom> salle de chaque joueur
DungeonService.roomOf = {}
---@type table<integer, integer> GetGameTimer de fin du retour, par joueur
DungeonService.returning = {}

-- Sous-commandes de /donjon et /dungeon
DungeonService.ACTIONS = {
    ouvrir = 'open', open = 'open',
    invite = 'invite', inviter = 'invite',
    pret = 'ready', ['prêt'] = 'ready', ready = 'ready',
    lancer = 'launch', start = 'launch',
    quitter = 'quit', quit = 'quit',
}

function DungeonService.init()
    Callback.register(Events.callbacks.dungeonCommand, DungeonService.command)
    Callback.register(Events.callbacks.dungeonMenu, DungeonService.menu)
    RegisterNetEvent(Events.server.dungeonWallHit, function(hits)
        DungeonService.onWallHit(source, hits)
    end)
    RegisterNetEvent(Events.server.dungeonBarrelHit, function(index)
        DungeonService.onBarrelHit(source, index)
    end)

    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        DungeonService.onPlayerLeft(playerSource)
    end)
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
            for _, room in pairs(DungeonService.rooms) do room:despawnPeds() end
        end
    end)

    CreateThread(DungeonService.loop)
end

function DungeonService.loop()
    while true do
        Wait(DungeonService.TICK_INTERVAL)
        -- Une copie : créer un zombie attend, une salle peut s'ouvrir ou se fermer entre-temps
        local rooms = {}
        for _, room in pairs(DungeonService.rooms) do rooms[#rooms + 1] = room end
        for _, room in ipairs(rooms) do
            if not room.closed then DungeonService.tick(room) end
        end
    end
end

---@param room DungeonRoom
function DungeonService.tick(room)
    if GetGameTimer() >= room.endsAt then
        if room.status == 'waiting' then
            DungeonService.notifyRoom(room, Locale.t('Salle d\'attente fermée : le donjon n\'a pas été lancé.'), 'error')
        elseif room.status == 'running' then
            DungeonService.notifyRoom(room, Locale.t('Temps écoulé : le donjon est perdu.'), 'error')
        end
        return DungeonService.close(room)
    end
    if room.status == 'running' then room:tick() end
end

---@param room DungeonRoom
---@param text table Locale.t
---@param kind string
function DungeonService.notifyRoom(room, text, kind)
    for source in pairs(room.players) do
        local player = PlayerService.get(source)
        if player then player:notify(text, kind) end
    end
end

-- ---------------------------------------------------------------------------
-- Ce que les autres modules demandent
-- ---------------------------------------------------------------------------

---@param source integer|string
---@return boolean dans l'instance d'un donjon (pas dans une salle d'attente)
function DungeonService.isInRun(source)
    local room = DungeonService.roomOf[tonumber(source)]
    return room ~= nil and room.status ~= 'waiting'
end

---@param source integer
---@return boolean le monde du joueur est géré ici, PveWorldService n'y touche pas
function DungeonService.holdsWorld(source)
    return DungeonService.isInRun(source) or GetGameTimer() < (DungeonService.returning[source] or 0)
end

---@param ped integer
---@return DungeonRoom|nil salle du zombie
function DungeonService.roomOfPed(ped)
    local id = Entity(ped).state.dungeonRoom
    return id and DungeonService.rooms[id] or nil
end

---@param player PvpPlayer
function DungeonService.onPlayerDied(player)
    local room = DungeonService.roomOf[player.source]
    local entry = room and room.status ~= 'waiting' and room.players[player.source]
    if not entry then return end
    entry.lives = entry.lives - 1
    if entry.lives > 0 then
        player:notify(Locale.t('Il te reste %d vie(s).', entry.lives), 'error')
    else
        entry.out = true
        player:notify(Locale.t('Plus de vie : tu quittes le donjon à la réapparition.'), 'error')
    end
    room:sync()
end

---Appelé à la réapparition : le point de reprise, ou nil s'il n'a plus de vie (zone safe).
---@param player PvpPlayer
---@return vector4|nil
function DungeonService.respawnPoint(player)
    local room = DungeonService.roomOf[player.source]
    if not room or room.status == 'waiting' then return nil end
    if room.players[player.source].out then
        DungeonService.leave(player.source, false)
        return nil
    end
    AntiCheatService.grace(player.source)
    return room:checkpoint()
end

---@param source integer
function DungeonService.onPlayerLeft(source)
    DungeonService.returning[source] = nil
    if DungeonService.roomOf[source] then DungeonService.leave(source, false) end
end

-- ---------------------------------------------------------------------------
-- Commandes (/donjon)
-- ---------------------------------------------------------------------------

---@param source integer
---@param word any sous-commande
---@param argument any id du joueur invité
---@return table { ok, message? }
function DungeonService.command(source, word, argument)
    local player = PlayerService.get(source)
    if not player then return { ok = false } end
    if not Config.Dungeon.enabled then return { ok = false, message = Locale.t('Les donjons sont désactivés.') } end
    local action = word and DungeonService.ACTIONS[tostring(word):lower()]
    if action == 'open' then return DungeonService.create(player) end
    if action == 'invite' then return DungeonService.invite(player, argument) end
    if action == 'ready' then return DungeonService.ready(player) end
    if action == 'launch' then return DungeonService.launch(player) end
    if action == 'quit' then return DungeonService.quit(player) end
    return { ok = false, message = Locale.t('Commandes : /donjon invite <id>, /donjon pret, /donjon lancer, /donjon quitter.') }
end

---Ce que le menu de James affiche.
---@param source integer
---@return table|nil
function DungeonService.menu(source)
    local player = PlayerService.get(source)
    if not player then return nil end
    return {
        label = Config.Dungeon.label,
        keys = player:getItemCount(Config.Dungeon.keys.item),
        required = Config.Dungeon.keys.count,
        free = AdminService.isAdmin(source),
        maxPlayers = Config.Dungeon.maxPlayers,
    }
end

---@param player PvpPlayer
---@return boolean assez de clés sur lui pour entrer
function DungeonService.hasKeys(player)
    return AdminService.isAdmin(player.source) or player:getItemCount(Config.Dungeon.keys.item) >= Config.Dungeon.keys.count
end

---@return table message de refus, faute de clés
function DungeonService.keysMessage()
    return Locale.t('Il te faut %d clés de donjon sur toi pour entrer.', Config.Dungeon.keys.count)
end

---@param player PvpPlayer
---@return table|nil message de refus
function DungeonService.refusal(player)
    if player.mode ~= 'pvp' then return Locale.t('Donjon disponible en mode PvP.') end
    if player.dead then return Locale.t('Attends de réapparaître.') end
    if CombatTagService.isTagged(player) then
        return Locale.t('Tu es en combat : attends %d s.', CombatTagService.remaining(player))
    end
    if not DungeonService.hasKeys(player) then return DungeonService.keysMessage() end
    return nil
end

---@return integer|nil numéro de salle libre
function DungeonService.freeRoomId()
    for id = 1, Config.Dungeon.maxRooms do
        if not DungeonService.rooms[id] then return id end
    end
    return nil
end

---Ouvre une salle d'attente, à côté de James (les admins peuvent le faire de partout, pour tester).
---@param player PvpPlayer
---@return table
function DungeonService.create(player)
    if DungeonService.roomOf[player.source] then return { ok = false, message = Locale.t('Tu es déjà dans un donjon.') } end
    if not AdminService.isAdmin(player.source) and not SafeNpcs.isNear(player:getCoords(), 'dungeon', Config.SafeNpcs.useDistance + 2.0) then
        return { ok = false, message = Locale.t('Va voir James en zone safe pour ouvrir un donjon.') }
    end
    local refusal = DungeonService.refusal(player)
    if refusal then return { ok = false, message = refusal } end
    local id = DungeonService.freeRoomId()
    if not id then return { ok = false, message = Locale.t('Tous les donjons sont occupés.') } end

    local room = DungeonRoom.new(id, player.source)
    DungeonService.rooms[id] = room
    DungeonService.addPlayer(room, player.source)
    room:sync()
    return { ok = true, message = Locale.t('Donjon ouvert : /donjon invite <id> pour tes coéquipiers, /donjon lancer pour entrer.') }
end

---@param room DungeonRoom
---@param source integer
function DungeonService.addPlayer(room, source)
    room:add(source)
    DungeonService.roomOf[source] = room
end

---Le chef invite un joueur par son numéro ; celui-ci confirme avec /donjon pret.
---@param player PvpPlayer
---@param argument any
---@return table
function DungeonService.invite(player, argument)
    local room = DungeonService.roomOf[player.source]
    if not room or room.status ~= 'waiting' then return { ok = false, message = Locale.t('Parle à James pour ouvrir un donjon.') } end
    if room.leader ~= player.source then return { ok = false, message = Locale.t('Seul celui qui a ouvert le donjon peut inviter.') } end
    if room:count() >= Config.Dungeon.maxPlayers then return { ok = false, message = Locale.t('Ce donjon est complet.') } end

    local target = PlayerService.getByCharId(argument)
    if not target or target.mode ~= 'pvp' then return { ok = false, message = Locale.t('Ce joueur n\'est pas en mode PvP.') } end
    if DungeonService.roomOf[target.source] then return { ok = false, message = Locale.t('Ce joueur est déjà dans un donjon.') } end

    room.invited[target.source] = true
    target:notify(Locale.t('%s t\'invite dans son donjon : /donjon pret pour le rejoindre (%d clés).', player:displayName(), Config.Dungeon.keys.count), 'info')
    return { ok = true, message = Locale.t('Invitation envoyée à %s.', target:displayName()) }
end

---Rejoint la salle d'attente où l'on a été invité.
---@param player PvpPlayer
---@return table
function DungeonService.ready(player)
    if DungeonService.roomOf[player.source] then return { ok = false, message = Locale.t('Tu es déjà dans un donjon.') } end
    local refusal = DungeonService.refusal(player)
    if refusal then return { ok = false, message = refusal } end

    for _, room in pairs(DungeonService.rooms) do
        if room.status == 'waiting' and room.invited[player.source] then
            if room:count() >= Config.Dungeon.maxPlayers then return { ok = false, message = Locale.t('Ce donjon est complet.') } end
            DungeonService.addPlayer(room, player.source)
            DungeonService.notifyRoom(room, Locale.t('%s est prêt.', player:displayName()), 'info')
            room:sync()
            return { ok = true }
        end
    end
    return { ok = false, message = Locale.t('Personne ne t\'a invité dans un donjon.') }
end

---Entrée dans l'instance de tous ceux qui peuvent y aller : leurs clés sont retirées ici.
---@param player PvpPlayer
---@return table
function DungeonService.launch(player)
    local room = DungeonService.roomOf[player.source]
    if not room or room.status ~= 'waiting' then return { ok = false, message = Locale.t('Parle à James pour ouvrir un donjon.') } end
    if room.leader ~= player.source then return { ok = false, message = Locale.t('Seul celui qui a ouvert le donjon peut le lancer.') } end

    SetRoutingBucketPopulationEnabled(room.bucket, false)
    local members = {}
    for source in pairs(room.players) do members[#members + 1] = source end
    for _, source in ipairs(members) do
        local member = PlayerService.get(source)
        local refusal = member and DungeonService.refusal(member)
        if refusal then
            member:notify(refusal, 'error')
            DungeonService.leave(source, false)
        elseif member and not AdminService.isAdmin(source) then
            member:removeItem(Config.Dungeon.keys.item, Config.Dungeon.keys.count)
            member:sync()
        end
    end
    -- Plus personne (le chef lui-même refusé) : la salle s'est fermée avec son dernier joueur
    if not DungeonService.rooms[room.id] then return { ok = false } end

    room:start()
    for source in pairs(room.players) do DungeonService.enter(room, source) end
    room:sync()
    return { ok = true }
end

---@param room DungeonRoom
---@param source integer
function DungeonService.enter(room, source)
    AntiCheatService.grace(source)
    SetPlayerRoutingBucket(source, room.bucket)
    PveWorldService.setInside(source, true)
    Player(source).state:set(DungeonService.STATE, room.bucket, true)
    TriggerClientEvent(Events.client.teleport, source, room:checkpoint(), Config.Dungeon.zone.label)
end

---@param player PvpPlayer
---@return table
function DungeonService.quit(player)
    if not DungeonService.roomOf[player.source] then return { ok = false, message = Locale.t('Tu n\'es dans aucun donjon.') } end
    if player.dead then return { ok = false, message = Locale.t('Attends de réapparaître.') } end
    DungeonService.leave(player.source, true)
    return { ok = true, message = Locale.t('Tu as quitté le donjon.') }
end

---Sort un joueur de sa salle ; la salle se ferme avec son dernier joueur.
---@param source integer
---@param sendHome boolean le ramener en zone safe (sinon sa réapparition ou le changement de mode s'en charge)
function DungeonService.leave(source, sendHome)
    local room = DungeonService.roomOf[source]
    if not room then return end
    local wasInside = room.status ~= 'waiting'
    DungeonService.roomOf[source] = nil
    room:removePlayer(source)
    if GetPlayerName(source) then DungeonService.release(source, wasInside, sendHome) end

    if next(room.players) then
        room:sync()
    else
        DungeonService.close(room)
    end
end

---@param source integer
---@param wasInside boolean il était dans l'instance
---@param sendHome boolean
function DungeonService.release(source, wasInside, sendHome)
    TriggerClientEvent(Events.client.dungeonState, source, false)
    if not wasInside then return end

    DungeonService.returning[source] = GetGameTimer() + DungeonService.RETURN_GRACE
    AntiCheatService.grace(source)
    Player(source).state:set(DungeonService.STATE, nil, true)
    PveWorldService.setInside(source, false)
    SetPlayerRoutingBucket(source, PveWorldService.pvpBucket())
    if sendHome then
        TriggerClientEvent(Events.client.teleport, source, Zones.randomSpawn('pvp'), 'Zone safe')
    end
end

---Ferme la salle : ses joueurs rentrent, ses zombies et ses butins disparaissent.
---@param room DungeonRoom
function DungeonService.close(room)
    room.closed = true
    DungeonService.rooms[room.id] = nil
    local members = {}
    for source in pairs(room.players) do members[#members + 1] = source end
    local wasInside = room.status ~= 'waiting'
    for _, source in ipairs(members) do
        DungeonService.roomOf[source] = nil
        local player = PlayerService.get(source)
        -- Mort : la réapparition le ramènera en zone safe
        DungeonService.release(source, wasInside, player ~= nil and not player.dead)
    end
    room.players = {}
    room:despawnPeds()
    if room.boss and DoesEntityExist(room.boss) then DeleteEntity(room.boss) end
    for id, bag in pairs(LootService.bags) do
        if bag.bucket == room.bucket then LootService.remove(id) end
    end
end

-- ---------------------------------------------------------------------------
-- Tirs dans la salle
-- ---------------------------------------------------------------------------

---@param source integer
---@param hits any
function DungeonService.onWallHit(source, hits)
    if not AntiCheatService.allow(source, 'dungeonHit') then return end
    local player = PlayerService.get(source)
    local room = DungeonService.roomOf[source]
    if player and room and room.status == 'running' then room:onWallHit(player, hits) end
end

---@param source integer
---@param index any numéro de la bonbonne
function DungeonService.onBarrelHit(source, index)
    if not AntiCheatService.allow(source, 'dungeonBarrel') then return end
    local player = PlayerService.get(source)
    local room = DungeonService.roomOf[source]
    if player and room and room.status == 'running' then room:onBarrelHit(player, index) end
end

-- ---------------------------------------------------------------------------
-- Panneau admin
-- ---------------------------------------------------------------------------

---@param source integer admin
---@return DungeonRoom|nil sa salle, sinon la seule en cours
function DungeonService.roomForAdmin(source)
    local own = DungeonService.roomOf[source]
    if own and own.status ~= 'waiting' then return own end
    local found, count = nil, 0
    for _, room in pairs(DungeonService.rooms) do
        if room.status ~= 'waiting' then found, count = room, count + 1 end
    end
    return count == 1 and found or nil
end

---Passe l'étape en cours (une étape ratée ne bloque pas un test du parcours).
---@param source integer
---@return boolean, table
function DungeonService.adminSkip(source)
    local room = DungeonService.roomForAdmin(source)
    if not room then return false, Locale.t('Aucun donjon en cours (ou plusieurs : entres-y).') end
    if room.status ~= 'running' then return false, Locale.t('Ce donjon est déjà terminé.') end
    local step = room:step()
    if step.type == 'boss' and room.boss then
        if DoesEntityExist(room.boss) then DeleteEntity(room.boss) end
        room.boss = nil
    end
    room:despawnPeds()
    room:nextStep()
    return true, Locale.t('Étape passée : %s.', Locale.t(room:step().label))
end

---@param source integer
---@return boolean, table
function DungeonService.adminStop(source)
    local room = DungeonService.roomForAdmin(source)
    if not room then return false, Locale.t('Aucun donjon en cours (ou plusieurs : entres-y).') end
    DungeonService.notifyRoom(room, Locale.t('Un admin a arrêté le donjon.'), 'error')
    DungeonService.close(room)
    return true, Locale.t('Donjon arrêté.')
end
