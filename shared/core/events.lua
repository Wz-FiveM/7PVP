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
    lootPickup = '7pvp:server:lootPickup',
    chatSend = '7pvp:server:chatSend',
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
}

-- Événements internes (même côté, jamais réseau)
Events.internal = {
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
    saveAppearance = 'appearance:save',
    joinMode = 'lobby:join',
    leaveMode = 'lobby:leave',
    adminPlayers = 'admin:players',
    adminAction = 'admin:action',
    leaderboard = 'leaderboard:get',
}
