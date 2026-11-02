---Séries de kills et primes : un joueur qui enchaîne Config.Bounty.threshold kills sans mourir
---est signalé à tous sur la carte. Celui qui l'abat touche la prime, qui grossit à chaque kill.
---Les joueurs peuvent aussi mettre une tête à prix (Config.Bounty.player) : ces primes-là sont payées
---d'avance, gardées en base et restent sur la cible jusqu'à ce que quelqu'un l'abatte.
---@class BountyServiceModule
local BountyService = PVP.define('BountyService')
local PlayerService = PVP.use('PlayerService')
local PlayerRepository = PVP.use('PlayerRepository')
local ModeRegistry = PVP.use('ModeRegistry')
local ChatService = PVP.use('ChatService')
local CrewService = PVP.use('CrewService')
local GroupService = PVP.use('GroupService')
local Callback = PVP.use('Callback')
local Utils = PVP.use('Utils')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

BountyService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_player_bounties (
    target VARCHAR(64) NOT NULL,
    placer VARCHAR(64) NOT NULL,
    amount INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (target, placer)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

---@type table<string, table<string, integer>> licence de la cible -> licence de celui qui paie -> montant
BountyService.placed = {}

function BountyService.init()
    -- Les joueurs qui arrivent voient les primes en cours
    RegisterNetEvent(Events.server.ready, function()
        TriggerClientEvent(Events.client.bountySync, source, BountyService.list())
    end)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        local player = PlayerService.get(playerSource)
        if not player then return end
        local listed = player.bounty > 0 or BountyService.placedOn(player) > 0
        player.bounty = 0
        BountyService.setListed(player, false, listed)
    end)
    MySQL.ready(function()
        MySQL.query.await(BountyService.SCHEMA)
        local rows = MySQL.query.await('SELECT target, placer, amount FROM pvp_player_bounties') or {}
        for _, row in ipairs(rows) do
            BountyService.placed[row.target] = BountyService.placed[row.target] or {}
            BountyService.placed[row.target][row.placer] = row.amount
        end
    end)
    Callback.register(Events.callbacks.bountyPlace, BountyService.place)
    Callback.register(Events.callbacks.bountyTargets, BountyService.targets)
end

---@param streak integer
---@return integer prime correspondant à une série
function BountyService.amountFor(streak)
    if streak < Config.Bounty.threshold then return 0 end
    return Config.Bounty.base + (streak - Config.Bounty.threshold) * Config.Bounty.perKill
end

---@param player PvpPlayer
---@return integer total des primes posées par des joueurs sur sa tête
function BountyService.placedOn(player)
    local total = 0
    for _, amount in pairs(BountyService.placed[player.identifier] or {}) do total = total + amount end
    return total
end

---@return table[] { id, name, amount, streak }
function BountyService.list()
    local list = {}
    for _, player in pairs(PlayerService.all()) do
        local amount = player.bounty + (player.bountyListed and BountyService.placedOn(player) or 0)
        if amount > 0 then
            list[#list + 1] = { id = player.source, name = player:displayName(), amount = amount, streak = player.streak }
        end
    end
    return list
end

function BountyService.broadcast()
    TriggerClientEvent(Events.client.bountySync, -1, BountyService.list())
end

---Les primes posées ne s'affichent que tant que la cible est en PvP (voir PvpMode).
---@param player PvpPlayer
---@param listed boolean
---@param force? boolean renvoyer la liste même sans prime posée
function BountyService.setListed(player, listed, force)
    player.bountyListed = listed
    if force or BountyService.placedOn(player) > 0 then BountyService.broadcast() end
end

---Kill d'un joueur : le tueur touche la prime de sa victime, puis sa propre série avance.
---@param killer PvpPlayer
---@param victim PvpPlayer
function BountyService.onPlayerKill(killer, victim)
    local reward = victim.bounty + BountyService.claim(killer, victim)
    if reward > 0 then
        killer:addMoney(reward)
        killer:notify(Locale.t('Prime encaissée : $%d pour %s', reward, victim:displayName()), 'success')
        ChatService.announce('pvp', Locale.t('%s a abattu %s et encaisse sa prime de $%d !', killer:displayName(), victim:displayName(), reward))
        -- La prime posée sur la victime peut disparaître sans que sa série n'ait existé
        BountyService.broadcast()
    end

    killer.streak = killer.streak + 1
    local bounty = BountyService.amountFor(killer.streak)
    if bounty > 0 then
        killer.bounty = bounty
        if killer.streak == Config.Bounty.threshold then
            ChatService.announce('pvp', Locale.t('%s enchaîne %d kills : sa tête est mise à prix ($%d) !', killer:displayName(), killer.streak, bounty))
            ModeRegistry.broadcast('pvp', Events.client.notify, Locale.t('Prime sur %s : $%d (repère rouge)', killer:displayName(), bounty), 'info')
        elseif killer.streak % Config.Bounty.announceEvery == 0 then
            ChatService.announce('pvp', Locale.t('%s : série de %d kills, prime de $%d.', killer:displayName(), killer.streak, bounty))
        end
        BountyService.broadcast()
    end
end

---Primes posées que ce tueur peut encaisser : ni les siennes, ni aucune s'il est du côté de la victime.
---Celles qu'il a posées lui-même restent sur la tête de la victime.
---@param killer PvpPlayer
---@param victim PvpPlayer
---@return integer montant retiré de la base, à lui verser
function BountyService.claim(killer, victim)
    local placed = BountyService.placed[victim.identifier]
    if not placed or GroupService.areAllies(killer.source, victim.source) then return 0 end
    local tag = CrewService.tagOf(killer.identifier)
    if tag and tag == CrewService.tagOf(victim.identifier) then return 0 end

    local total = 0
    for placer, amount in pairs(placed) do
        if placer ~= killer.identifier then
            total = total + amount
            placed[placer] = nil
        end
    end
    if next(placed) == nil then BountyService.placed[victim.identifier] = nil end
    if total > 0 then
        MySQL.update('DELETE FROM pvp_player_bounties WHERE target = ? AND placer <> ?', { victim.identifier, killer.identifier })
    end
    return total
end

---Mort (ou déconnexion en combat) : la série et la prime repartent à zéro.
---@param player PvpPlayer
function BountyService.reset(player)
    local hadBounty = player.bounty > 0
    player.streak = 0
    player.bounty = 0
    if hadBounty then BountyService.broadcast() end
end

---Joueurs à qui l'on peut mettre une prime.
---@param source integer
---@return { list: { id: integer, name: string }[] }
function BountyService.targets(source)
    local list = {}
    for _, player in pairs(PlayerService.all()) do
        if player.mode == 'pvp' and player.source ~= source then
            list[#list + 1] = { id = player.source, name = player:displayName() }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return { list = list }
end

---Met une tête à prix : le montant et les frais sont payés tout de suite avec l'argent porté.
---@param source integer
---@param data any { target, amount }
---@return { ok: boolean, message?: string }
function BountyService.place(source, data)
    local player = PlayerService.get(source)
    if not player or player.dead or player.mode ~= 'pvp' or type(data) ~= 'table' then return { ok = false } end

    local settings = Config.Bounty.player
    local target = PlayerService.get(tonumber(data.target))
    if not target or target.mode ~= 'pvp' or target == player then
        return { ok = false, message = Locale.t('Ce joueur n\'est pas en PvP.') }
    end
    local amount = Utils.toCount(data.amount)
    if amount < settings.min or amount > settings.max then
        return { ok = false, message = Locale.t('Une prime va de $%d à $%d.', settings.min, settings.max) }
    end
    local now = GetGameTimer()
    if player.bountyPlacedAt and now - player.bountyPlacedAt < settings.delay * 1000 then
        return { ok = false, message = Locale.t('Attends un peu avant de poser une autre prime.') }
    end
    if BountyService.placedOn(target) + amount > settings.maxOnHead then
        return { ok = false, message = Locale.t('La tête de ce joueur ne peut pas valoir plus de $%d.', settings.maxOnHead) }
    end
    local cost = amount + math.ceil(amount * settings.fee)
    if not player:removeMoney(cost) then
        return { ok = false, message = Locale.t('Il te faut $%d sur toi (prime et frais).', cost) }
    end

    player.bountyPlacedAt = now
    local placed = BountyService.placed[target.identifier] or {}
    BountyService.placed[target.identifier] = placed
    placed[player.identifier] = (placed[player.identifier] or 0) + amount
    MySQL.insert('INSERT INTO pvp_player_bounties (target, placer, amount) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)', {
        target.identifier, player.identifier, amount,
    })
    PlayerRepository.save(player)
    player:sync()
    target:sync()

    target:notify(Locale.t('Quelqu\'un a mis ta tête à prix : $%d.', amount), 'error')
    ChatService.announce('pvp', Locale.t('%s met $%d sur la tête de %s !', player:displayName(), amount, target:displayName()))
    Logger.info('[prime] %s pose $%d sur %s', player.name, amount, target.name)
    BountyService.broadcast()
    return { ok = true, message = Locale.t('Prime posée sur %s : $%d (frais : $%d).', target:displayName(), amount, cost - amount) }
end
