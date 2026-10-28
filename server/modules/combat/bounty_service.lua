---Séries de kills et primes : un joueur qui enchaîne Config.Bounty.threshold kills sans mourir
---est signalé à tous sur la carte. Celui qui l'abat touche la prime, qui grossit à chaque kill.
---@class BountyServiceModule
local BountyService = PVP.define('BountyService')
local PlayerService = PVP.use('PlayerService')
local ModeRegistry = PVP.use('ModeRegistry')
local ChatService = PVP.use('ChatService')
local Events = PVP.use('Events')

function BountyService.init()
    -- Les joueurs qui arrivent voient les primes en cours
    RegisterNetEvent(Events.server.ready, function()
        TriggerClientEvent(Events.client.bountySync, source, BountyService.list())
    end)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        local player = PlayerService.get(playerSource)
        if player and player.bounty > 0 then
            player.bounty = 0
            BountyService.broadcast()
        end
    end)
end

---@param streak integer
---@return integer prime correspondant à une série
function BountyService.amountFor(streak)
    if streak < Config.Bounty.threshold then return 0 end
    return Config.Bounty.base + (streak - Config.Bounty.threshold) * Config.Bounty.perKill
end

---@return table[] { id, name, amount, streak }
function BountyService.list()
    local list = {}
    for _, player in pairs(PlayerService.all()) do
        if player.bounty > 0 then
            list[#list + 1] = { id = player.source, name = player.name, amount = player.bounty, streak = player.streak }
        end
    end
    return list
end

function BountyService.broadcast()
    TriggerClientEvent(Events.client.bountySync, -1, BountyService.list())
end

---Kill d'un joueur : le tueur touche la prime de sa victime, puis sa propre série avance.
---@param killer PvpPlayer
---@param victim PvpPlayer
function BountyService.onPlayerKill(killer, victim)
    if victim.bounty > 0 then
        killer:addMoney(victim.bounty)
        killer:notify(('Prime encaissée : $%d pour %s'):format(victim.bounty, victim.name), 'success')
        ChatService.announce('pvp', ('%s a abattu %s et encaisse sa prime de $%d !'):format(killer.name, victim.name, victim.bounty))
    end

    killer.streak = killer.streak + 1
    local bounty = BountyService.amountFor(killer.streak)
    if bounty > 0 then
        killer.bounty = bounty
        if killer.streak == Config.Bounty.threshold then
            ChatService.announce('pvp', ('%s enchaîne %d kills : sa tête est mise à prix ($%d) !'):format(killer.name, killer.streak, bounty))
            ModeRegistry.broadcast('pvp', Events.client.notify, ('Prime sur %s : $%d (repère rouge)'):format(killer.name, bounty), 'info')
        elseif killer.streak % Config.Bounty.announceEvery == 0 then
            ChatService.announce('pvp', ('%s : série de %d kills, prime de $%d.'):format(killer.name, killer.streak, bounty))
        end
        BountyService.broadcast()
    end
end

---Mort (ou déconnexion en combat) : la série et la prime repartent à zéro.
---@param player PvpPlayer
function BountyService.reset(player)
    local hadBounty = player.bounty > 0
    player.streak = 0
    player.bounty = 0
    if hadBounty then BountyService.broadcast() end
end
