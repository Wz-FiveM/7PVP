---Échanges entre joueurs (/trade) : demande, offre de chaque côté, « Prêt » puis confirmation des deux.
---Les objets proposés restent dans l'inventaire de leur propriétaire jusqu'au bout : tout est
---revérifié au moment de l'échange, appliqué d'un coup, et défait si quelque chose ne tient pas.
---Un échange n'existe qu'en mémoire : il est annulé dès que l'un des deux s'éloigne, meurt,
---entre en combat, quitte le PvP ou se déconnecte.
---@class PvpTrade
---@field id integer
---@field players integer[] les deux server ids (celui qui a fait la demande en premier)
---@field offers table<integer, table<string, integer>> objets proposés par chaque joueur
---@field ready table<integer, boolean> offre validée (« Prêt »)
---@field confirmed table<integer, boolean> échange confirmé (possible une fois les deux prêts)

---@class TradeServiceModule
local TradeService = PVP.define('TradeService')
local PlayerService = PVP.use('PlayerService')
local PlayerRepository = PVP.use('PlayerRepository')
local CombatTagService = PVP.use('CombatTagService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Utils = PVP.use('Utils')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

---@type table<integer, PvpTrade>
TradeService.trades = {}
---@type table<integer, integer> server id -> id de l'échange en cours
TradeService.tradeOf = {}
---@type table<integer, { from: integer, expires: integer }> demande reçue par joueur
TradeService.requests = {}
TradeService.nextId = 0
TradeService.CHECK_INTERVAL = 1000

function TradeService.init()
    Callback.register(Events.callbacks.tradeRequest, TradeService.request)
    Callback.register(Events.callbacks.tradeRespond, TradeService.respond)
    Callback.register(Events.callbacks.tradeOffer, TradeService.offer)
    Callback.register(Events.callbacks.tradeReady, TradeService.setReady)
    Callback.register(Events.callbacks.tradeConfirm, TradeService.confirm)
    Callback.register(Events.callbacks.tradeCancel, TradeService.cancelCallback)

    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        local trade = TradeService.getTradeOf(playerSource)
        if trade then TradeService.close(trade, Locale.t('Ton partenaire s\'est déconnecté : échange annulé.')) end
        TradeService.requests[playerSource] = nil
    end)

    CreateThread(TradeService.checkLoop)
end

---Distance, mort, combat, mode : vérifiés chaque seconde pendant un échange.
function TradeService.checkLoop()
    while true do
        Wait(TradeService.CHECK_INTERVAL)
        for _, trade in pairs(TradeService.trades) do
            TradeService.validate(trade)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Lecture
-- ---------------------------------------------------------------------------

---@param source integer
---@return PvpTrade|nil
function TradeService.getTradeOf(source)
    local id = TradeService.tradeOf[source]
    return id and TradeService.trades[id] or nil
end

---@param trade PvpTrade
---@param source integer
---@return integer server id de l'autre joueur
function TradeService.partnerOf(trade, source)
    return trade.players[1] == source and trade.players[2] or trade.players[1]
end

---@param player PvpPlayer
---@param you boolean message adressé à ce joueur (sinon à son partenaire)
---@return table|nil raison pour laquelle ce joueur ne peut pas échanger (Locale.t)
function TradeService.unavailable(player, you)
    if player.mode ~= 'pvp' then
        return you and Locale.t('Échanges disponibles seulement en PvP.') or Locale.t('%s n\'est pas en PvP.', player.name)
    end
    if player.dead then
        return you and Locale.t('Impossible en étant mort.') or Locale.t('%s est mort.', player.name)
    end
    if CombatTagService.isTagged(player) then
        return you and Locale.t('Impossible en combat (%d s).', CombatTagService.remaining(player))
            or Locale.t('%s est en combat.', player.name)
    end
    return nil
end

---@param player PvpPlayer
---@param partner PvpPlayer
---@return table|nil raison (vue par `player`) pour laquelle ils ne peuvent pas échanger
function TradeService.denied(player, partner)
    local reason = TradeService.unavailable(player, true) or TradeService.unavailable(partner, false)
    if reason then return reason end
    if #(player:getCoords() - partner:getCoords()) > Config.Trade.maxDistance then
        return Locale.t('Rapproche-toi de %s.', partner.name)
    end
    return nil
end

---Les deux joueurs peuvent-ils encore échanger ? Sinon l'échange est annulé (chacun reçoit la raison).
---@param trade PvpTrade
---@return PvpPlayer|nil, PvpPlayer|nil
function TradeService.validate(trade)
    local a, b = PlayerService.get(trade.players[1]), PlayerService.get(trade.players[2])
    if not a or not b then
        TradeService.close(trade, Locale.t('Ton partenaire est parti : échange annulé.'))
        return nil, nil
    end
    local reasonA = TradeService.denied(a, b)
    if not reasonA then return a, b end

    TradeService.close(trade)
    a:notify(Locale.t('Échange annulé. %s', reasonA), 'error')
    b:notify(Locale.t('Échange annulé. %s', TradeService.denied(b, a) or ''), 'error')
    return nil, nil
end

---@param trade PvpTrade
---@param source integer
---@return table données envoyées à ce joueur
function TradeService.serialize(trade, source)
    local partnerSource = TradeService.partnerOf(trade, source)
    local partner = PlayerService.get(partnerSource)
    return {
        id = trade.id,
        partner = {
            id = partnerSource,
            name = partner and partner.name or GetPlayerName(partnerSource),
            avatar = partner and partner.avatar,
        },
        mine = TradeService.serializeOffer(trade, source),
        theirs = TradeService.serializeOffer(trade, partnerSource),
    }
end

---@param trade PvpTrade
---@param source integer
---@return table
function TradeService.serializeOffer(trade, source)
    return {
        items = trade.offers[source],
        ready = trade.ready[source] == true,
        confirmed = trade.confirmed[source] == true,
    }
end

---@param trade PvpTrade
function TradeService.sync(trade)
    for _, source in ipairs(trade.players) do
        TriggerClientEvent(Events.client.tradeState, source, TradeService.serialize(trade, source))
    end
end

---@param offer table<string, integer>
---@return integer objets différents proposés
function TradeService.countKinds(offer)
    local count = 0
    for _ in pairs(offer) do count = count + 1 end
    return count
end

-- ---------------------------------------------------------------------------
-- Actions (callbacks de la commande /trade, du menu d'interaction et de l'inventaire)
-- ---------------------------------------------------------------------------

---Demande d'échange. Si l'autre joueur nous en avait déjà fait une, l'échange commence.
---@param source integer
---@param targetId any server id du joueur
---@return { ok: boolean, message?: string }
function TradeService.request(source, targetId)
    local player = PlayerService.get(source)
    local target = PlayerService.get(tonumber(targetId))
    if not player then return { ok = false } end
    if not target or target == player then return { ok = false, message = Locale.t('Joueur introuvable.') } end

    local denied = TradeService.checkStart(player, target)
    if denied then return { ok = false, message = denied } end

    local received = TradeService.requests[source]
    if received and received.from == target.source and received.expires >= os.time() then
        TradeService.requests[source] = nil
        TradeService.start(target, player)
        return { ok = true }
    end

    local sent = TradeService.requests[target.source]
    if sent and sent.from == source and sent.expires >= os.time() then
        return { ok = false, message = Locale.t('Demande déjà envoyée à %s.', target.name) }
    end

    TradeService.requests[target.source] = { from = source, expires = os.time() + Config.Trade.requestTimeout }
    TriggerClientEvent(Events.client.tradeRequest, target.source, { from = source, fromName = player.name })
    return { ok = true, message = Locale.t('Demande d\'échange envoyée à %s.', target.name) }
end

---@param source integer
---@param accept any
---@return { ok: boolean, message?: string }
function TradeService.respond(source, accept)
    local request = TradeService.requests[source]
    TradeService.requests[source] = nil
    local player = PlayerService.get(source)
    if not player or not request or request.expires < os.time() then
        return { ok = false, message = Locale.t('Aucune demande d\'échange en attente.') }
    end

    local from = PlayerService.get(request.from)
    if accept ~= true then
        if from then from:notify(Locale.t('%s a refusé l\'échange.', player.name), 'info') end
        return { ok = true, message = Locale.t('Demande d\'échange refusée.') }
    end
    if not from then return { ok = false, message = Locale.t('Ce joueur n\'est plus là.') } end

    local denied = TradeService.checkStart(player, from)
    if denied then return { ok = false, message = denied } end
    TradeService.start(from, player)
    return { ok = true }
end

---@param player PvpPlayer
---@param partner PvpPlayer
---@return table|nil raison pour laquelle l'échange ne peut pas commencer (Locale.t)
function TradeService.checkStart(player, partner)
    if TradeService.tradeOf[player.source] then return Locale.t('Tu es déjà en train d\'échanger.') end
    if TradeService.tradeOf[partner.source] then
        return Locale.t('%s est déjà en train d\'échanger.', partner.name)
    end
    return TradeService.denied(player, partner)
end

---Change la quantité proposée d'un objet (0 = le retirer de l'offre).
---@param source integer
---@param data { item: string, count: integer }
---@return { ok: boolean, message?: string }
function TradeService.offer(source, data)
    local trade = TradeService.getTradeOf(source)
    local player = PlayerService.get(source)
    if not trade or not player then return { ok = false, message = Locale.t('Aucun échange en cours.') } end
    if type(data) ~= 'table' then return { ok = false } end

    local item = data.item
    local count = math.floor(tonumber(data.count) or -1)
    if not Items.exists(item) or Config.Trade.blocked[item] then
        return { ok = false, message = Locale.t('Cet objet ne peut pas être échangé.') }
    end
    if count < 0 then return { ok = false } end
    if count > player:getItemCount(item) then return { ok = false, message = Locale.t('Tu n\'as pas cette quantité sur toi.') } end

    local offer = trade.offers[source]
    if count > 0 and not offer[item] and TradeService.countKinds(offer) >= Config.Trade.maxItems then
        return { ok = false, message = Locale.t('%d objets différents maximum.', Config.Trade.maxItems) }
    end
    if (offer[item] or 0) == count then return { ok = true } end

    offer[item] = count > 0 and count or nil
    -- L'offre a changé : chacun doit revoir l'échange avant de valider
    trade.ready = {}
    trade.confirmed = {}
    TradeService.sync(trade)
    return { ok = true }
end

---@param source integer
---@param ready any
---@return { ok: boolean, message?: string }
function TradeService.setReady(source, ready)
    local trade = TradeService.getTradeOf(source)
    if not trade then return { ok = false, message = Locale.t('Aucun échange en cours.') } end

    ready = ready == true
    if ready and next(trade.offers[trade.players[1]]) == nil and next(trade.offers[trade.players[2]]) == nil then
        return { ok = false, message = Locale.t('Propose au moins un objet.') }
    end
    trade.ready[source] = ready or nil
    trade.confirmed = {}
    TradeService.sync(trade)
    return { ok = true }
end

---@param source integer
---@return { ok: boolean, message?: string }
function TradeService.confirm(source)
    local trade = TradeService.getTradeOf(source)
    if not trade then return { ok = false, message = Locale.t('Aucun échange en cours.') } end
    if not trade.ready[trade.players[1]] or not trade.ready[trade.players[2]] then
        return { ok = false, message = Locale.t('Les deux joueurs doivent être prêts.') }
    end

    trade.confirmed[source] = true
    if trade.confirmed[trade.players[1]] and trade.confirmed[trade.players[2]] then
        return TradeService.complete(trade)
    end
    TradeService.sync(trade)
    return { ok = true }
end

---@param source integer
---@return { ok: boolean, message?: string }
function TradeService.cancelCallback(source)
    local trade = TradeService.getTradeOf(source)
    local player = PlayerService.get(source)
    if not trade or not player then return { ok = false, message = Locale.t('Aucun échange en cours.') } end
    TradeService.close(trade, Locale.t('%s a annulé l\'échange.', player.name), source)
    return { ok = true, message = Locale.t('Échange annulé.') }
end

-- ---------------------------------------------------------------------------
-- Cycle de vie
-- ---------------------------------------------------------------------------

---@param a PvpPlayer celui qui a fait la demande
---@param b PvpPlayer
function TradeService.start(a, b)
    TradeService.nextId = TradeService.nextId + 1
    local trade = {
        id = TradeService.nextId,
        players = { a.source, b.source },
        offers = { [a.source] = {}, [b.source] = {} },
        ready = {},
        confirmed = {},
    }
    TradeService.trades[trade.id] = trade
    TradeService.tradeOf[a.source] = trade.id
    TradeService.tradeOf[b.source] = trade.id
    TradeService.sync(trade)
end

---Termine l'échange (réussi ou annulé) et ferme la fenêtre des deux joueurs.
---@param trade PvpTrade
---@param reason? table notification (Locale.t) envoyée (en erreur) aux joueurs
---@param except? integer joueur qui ne reçoit pas la notification
function TradeService.close(trade, reason, except)
    TradeService.trades[trade.id] = nil
    for _, source in ipairs(trade.players) do
        TradeService.tradeOf[source] = nil
        TriggerClientEvent(Events.client.tradeState, source, false)
        local player = reason and source ~= except and PlayerService.get(source)
        if player then player:notify(reason, 'error') end
    end
end

---Les deux ont confirmé : on vérifie tout une dernière fois, puis on échange.
---@param trade PvpTrade
---@return { ok: boolean, message?: string }
function TradeService.complete(trade)
    local a, b = TradeService.validate(trade)
    if not a or not b then return { ok = false } end

    local offerA, offerB = trade.offers[a.source], trade.offers[b.source]
    local ok, failure = TradeService.transfer(a, b, offerA, offerB)
    if not ok then
        -- Rien n'a bougé : les joueurs corrigent leur offre et valident à nouveau
        trade.ready = {}
        trade.confirmed = {}
        TradeService.sync(trade)
        a:notify(failure, 'error')
        b:notify(failure, 'error')
        return { ok = false }
    end

    TradeService.close(trade)
    a:sync()
    b:sync()
    -- Sauvegardés tout de suite : un arrêt du serveur ne peut pas faire perdre l'échange à un seul des deux
    PlayerRepository.save(a)
    PlayerRepository.save(b)
    a:notify(Locale.t('Échange terminé avec %s.', b.name), 'success')
    b:notify(Locale.t('Échange terminé avec %s.', a.name), 'success')
    Logger.info('[échange] %s donne [%s] à %s contre [%s]', a.name, Items.describe(offerA), b.name, Items.describe(offerB))
    return { ok = true }
end

---Retire les offres des deux inventaires puis les donne à l'autre (dans son sac).
---Si quelque chose ne tient pas, les deux inventaires sont remis exactement comme avant.
---@param a PvpPlayer
---@param b PvpPlayer
---@param offerA table<string, integer>
---@param offerB table<string, integer>
---@return boolean ok, table|nil raison de l'échec (Locale.t)
function TradeService.transfer(a, b, offerA, offerB)
    for _, side in ipairs({ { a, offerA }, { b, offerB } }) do
        for name, count in pairs(side[2]) do
            if side[1]:getItemCount(name) < count then
                return false, Locale.t('%s n\'a plus tout ce qu\'il propose.', side[1].name)
            end
        end
    end

    local backupA, backupB = TradeService.snapshot(a.inventory), TradeService.snapshot(b.inventory)
    local full
    if not TradeService.take(a, offerA) then full = a
    elseif not TradeService.take(b, offerB) then full = b
    elseif not TradeService.give(a, offerB) then full = a
    elseif not TradeService.give(b, offerA) then full = b
    end
    if not full then return true end

    TradeService.restore(a.inventory, backupA)
    TradeService.restore(b.inventory, backupB)
    return false, Locale.t('Pas assez de place dans le sac de %s.', full.name)
end

---Retire l'offre de l'inventaire. Les accessoires d'une arme donnée restent à son ancien
---propriétaire (rendus dans son sac), comme à la place de marché.
---@param player PvpPlayer
---@param offer table<string, integer>
---@return boolean false si un accessoire ne tient pas dans le sac
function TradeService.take(player, offer)
    for name, count in pairs(offer) do
        player.inventory:remove(name, count)
    end
    for name in pairs(offer) do
        for attachment, released in pairs(player.inventory:releaseAttachments(name)) do
            if player:giveItem(attachment, released) < released then return false end
        end
    end
    return true
end

---@param player PvpPlayer
---@param offer table<string, integer>
---@return boolean false si tout ne tient pas dans le sac
function TradeService.give(player, offer)
    for name, count in pairs(offer) do
        if player:giveItem(name, count) < count then return false end
    end
    return true
end

---@param inventory PvpInventory
---@return table copie de ce qu'un échange peut modifier
function TradeService.snapshot(inventory)
    local attachments = {}
    for weapon, list in pairs(inventory.attachments) do
        attachments[weapon] = Utils.shallowCopy(list)
    end
    return {
        bag = Utils.shallowCopy(inventory.bag),
        protected = Utils.shallowCopy(inventory.protected),
        attachments = attachments,
    }
end

---@param inventory PvpInventory
---@param backup table résultat de TradeService.snapshot
function TradeService.restore(inventory, backup)
    inventory.bag = backup.bag
    inventory.protected = backup.protected
    inventory.attachments = backup.attachments
end
