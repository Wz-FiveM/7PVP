---Noms de tous les événements réseau et callbacks, centralisés ici
---pour ne jamais écrire une chaîne d'événement en dur ailleurs.
---@class EventsModule
local Events = PVP.define('Events')

-- Client -> serveur
Events.server = {
    ready = '7pvp:server:ready',
    ammoUsed = '7pvp:server:ammoUsed',
    died = '7pvp:server:died',
    npcDied = '7pvp:server:npcDied',
    zombieAttack = '7pvp:server:zombieAttack',
    hitReport = '7pvp:server:hitReport',
    quit = '7pvp:server:quit',
    heartbeat = '7pvp:server:heartbeat',
    npcHitReport = '7pvp:server:npcHitReport',
    lootPickup = '7pvp:server:lootPickup',
    chatSend = '7pvp:server:chatSend',
    vehicleSpawned = '7pvp:server:vehicleSpawned',
    lootClose = '7pvp:server:lootClose',
    cvcVehicle = '7pvp:server:cvcVehicle',
}

-- Serveur -> client
Events.client = {
    sync = '7pvp:client:sync',
    notify = '7pvp:client:notify',
    spawn = '7pvp:client:spawn',
    openCreator = '7pvp:client:openCreator',
    openLobby = '7pvp:client:openLobby',
    chatMessage = '7pvp:client:chatMessage',
    adminStatus = '7pvp:client:adminStatus',
    adminCommand = '7pvp:client:adminCommand',
    dead = '7pvp:client:dead',
    killfeed = '7pvp:client:killfeed',
    applyItem = '7pvp:client:applyItem',
    lootAdd = '7pvp:client:lootAdd',
    lootRemove = '7pvp:client:lootRemove',
    lootSync = '7pvp:client:lootSync',
    zombieVomit = '7pvp:client:zombieVomit',
    hitConfirm = '7pvp:client:hitConfirm',
    combatTag = '7pvp:client:combatTag',
    groupSync = '7pvp:client:groupSync',
    groupInvite = '7pvp:client:groupInvite',
    groupState = '7pvp:client:groupState',
    airdropSpawn = '7pvp:client:airdropSpawn',
    airdropRemove = '7pvp:client:airdropRemove',
    bountySync = '7pvp:client:bountySync',
    hordeState = '7pvp:client:hordeState',
    controlZones = '7pvp:client:controlZones',
    freeroamCleanup = '7pvp:client:freeroamCleanup',
    teleport = '7pvp:client:teleport',
    teleportCancel = '7pvp:client:teleportCancel',
    vehicleSpawn = '7pvp:client:vehicleSpawn',
    lootContents = '7pvp:client:lootContents',
    chaseQueue = '7pvp:client:chaseQueue',
    chaseVote = '7pvp:client:chaseVote',
    chaseRound = '7pvp:client:chaseRound',
    chaseState = '7pvp:client:chaseState',
    chaseRoundEnd = '7pvp:client:chaseRoundEnd',
    chaseEnd = '7pvp:client:chaseEnd',
    cvcQueue = '7pvp:client:cvcQueue',
    cvcRound = '7pvp:client:cvcRound',
    cvcState = '7pvp:client:cvcState',
    cvcRoundEnd = '7pvp:client:cvcRoundEnd',
    cvcEnd = '7pvp:client:cvcEnd',
    cvcVehicle = '7pvp:client:cvcVehicle',
}

-- Événements internes (même côté, jamais réseau)
Events.internal = {
    -- Profil chargé depuis la base (statut admin, données à envoyer au client...)
    playerLoaded = '7pvp:internal:playerLoaded',
    playerUnloading = '7pvp:internal:playerUnloading',
}

-- Transport des callbacks (voir server/core/callback.lua et client/core/callback.lua)
Events.transport = {
    request = '7pvp:callback:request',
    response = '7pvp:callback:response',
}

-- Noms des callbacks (requête client -> réponse serveur)
Events.callbacks = {
    buy = 'shop:buy',
    useItem = 'inventory:use',
    moveItem = 'inventory:move',
    dropItem = 'inventory:drop',
    setShortcut = 'inventory:setShortcut',
    attachment = 'inventory:attachment',
    craft = 'crafting:craft',
    freeroamPvp = 'freeroam:pvp',
    marketList = 'market:list',
    marketSell = 'market:sell',
    marketBuy = 'market:buy',
    marketCancel = 'market:cancel',
    marketCollect = 'market:collect',
    saveAppearance = 'appearance:save',
    joinMode = 'lobby:join',
    leaveMode = 'lobby:leave',
    adminPlayers = 'admin:players',
    adminAction = 'admin:action',
    leaderboard = 'leaderboard:get',
    groupInvite = 'group:invite',
    groupRespond = 'group:respond',
    groupLeave = 'group:leave',
    groupKick = 'group:kick',
    teleportInfo = 'teleport:info',
    teleport = 'teleport:request',
    vehicleStore = 'vehicle:store',
    lootOpen = 'loot:open',
    lootTake = 'loot:take',
    adminLoot = 'admin:loot',
    adminLootSave = 'admin:lootSave',
    adminLootReset = 'admin:lootReset',
    adminLootZones = 'admin:lootZones',
    activityStart = 'activity:start',
    chaseVote = 'chase:vote',
}
