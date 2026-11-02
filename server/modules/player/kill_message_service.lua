---Message de kill en PvP (Config.KillMessage) : texte du tueur sur l'écran de mort de ses victimes.
---Le droit s'achète une fois en points boutique, le texte se change ensuite sans payer.
---Une ligne de la table = droit acheté : un paiement ne dépend pas de la sauvegarde du profil.
---@class KillMessageServiceModule
local KillMessageService = PVP.define('KillMessageService')
local ShopPointsService = PVP.use('ShopPointsService')
local PlayerService = PVP.use('PlayerService')
local ChatService = PVP.use('ChatService')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Logger = PVP.use('Logger')
local Locale = PVP.use('Locale')

KillMessageService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_kill_messages (
    identifier VARCHAR(64) NOT NULL,
    message VARCHAR(80) NOT NULL DEFAULT '',
    price INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

function KillMessageService.init()
    MySQL.ready(function()
        MySQL.query.await(KillMessageService.SCHEMA)
    end)
    Callback.register(Events.callbacks.killMessageBuy, KillMessageService.buy)
    Callback.register(Events.callbacks.killMessageSave, KillMessageService.save)
end

---Droit et texte du joueur, au chargement du profil.
---@param player PvpPlayer
function KillMessageService.load(player)
    local row = MySQL.single.await('SELECT message FROM pvp_kill_messages WHERE identifier = ?', { player.identifier })
    player.killMessageOwned = row and true or false
    player.killMessage = row and KillMessageService.sanitize(row.message) or nil
end

---@param text any
---@return string|nil texte nettoyé et coupé, nil s'il ne reste rien
function KillMessageService.sanitize(text)
    return ChatService.sanitize(text, Config.KillMessage.maxLength)
end

---@param player PvpPlayer
---@return string|nil message montré à ses victimes, seulement en PvP
function KillMessageService.shownBy(player)
    return player.mode == 'pvp' and player.killMessage or nil
end

---Change le texte, sans payer.
---@param source integer
---@param text any chaîne vide pour ne plus afficher de message
---@return { ok: boolean, message?: string }
function KillMessageService.save(source, text)
    local player = PlayerService.get(source)
    if not player or type(text) ~= 'string' or player.killMessageBusy then return { ok = false } end
    if not player.killMessageOwned then return { ok = false, message = Locale.t('Tu ne possèdes pas le message de kill.') } end

    local chosen = KillMessageService.sanitize(text)
    if player.killMessage == chosen then return { ok = true } end

    player.killMessageBusy = true
    local saved = pcall(MySQL.update.await, 'UPDATE pvp_kill_messages SET message = ? WHERE identifier = ?', { chosen or '', player.identifier })
    player.killMessageBusy = false
    if not saved then return { ok = false, message = Locale.t('Enregistrement impossible, réessaie.') } end

    Logger.info('[message de kill] %s : %s', player.name, chosen or '(retiré)')
    if PlayerService.get(source) ~= player then return { ok = false } end
    player.killMessage = chosen
    player:sync()
    return { ok = true, message = chosen and Locale.t('Message de kill enregistré.') or Locale.t('Message de kill retiré.') }
end

---Achat pour toujours, avec le premier texte : il s'affiche aussitôt.
---@param source integer
---@param text any
---@return { ok: boolean, message?: string }
function KillMessageService.buy(source, text)
    local player = PlayerService.get(source)
    if not player or player.killMessageBusy then return { ok = false } end
    if player.killMessageOwned then return { ok = false, message = Locale.t('Tu possèdes déjà le message de kill.') } end

    local chosen = KillMessageService.sanitize(text)
    if not chosen then return { ok = false, message = Locale.t('Écris ton message avant de l\'acheter.') } end

    local price = Config.KillMessage.price
    -- Réservé pendant l'attente de la base : une 2e demande ne peut pas payer en même temps
    player.killMessageBusy = true
    local paid = ShopPointsService.spend(player, price, 'kill_message')
    if not paid then
        player.killMessageBusy = false
        player:sync() -- solde relu en base : l'affichage était peut-être en retard
        return { ok = false, message = Locale.t('Pas assez de %s.', Locale.t(Config.ShopPoints.label:lower())) }
    end

    local saved, changed = pcall(MySQL.update.await,
        'INSERT IGNORE INTO pvp_kill_messages (identifier, message, price) VALUES (?, ?, ?)',
        { player.identifier, chosen, price })
    player.killMessageBusy = false
    if not saved or (changed or 0) == 0 then
        ShopPointsService.credit(player.identifier, price, 'refund:kill_message')
        return { ok = false, message = Locale.t('Achat impossible : tes points ont été rendus.') }
    end

    Logger.info('[points] %s achète le message de kill (%d points) : %s', player.name, price, chosen)
    -- Déconnecté pendant le paiement : l'achat est en base, il le retrouvera
    if PlayerService.get(source) ~= player then return { ok = false } end
    player.killMessageOwned = true
    player.killMessage = chosen
    player:sync()
    return { ok = true, message = Locale.t('Message de kill acheté.') }
end

---Modération : efface le texte, le droit acheté reste.
---@param player PvpPlayer
---@return string|nil texte effacé, nil si le joueur n'en avait pas ou si la base a refusé
function KillMessageService.clear(player)
    local previous = player.killMessage
    if not previous then return nil end

    local saved = pcall(MySQL.update.await, 'UPDATE pvp_kill_messages SET message = ? WHERE identifier = ?', { '', player.identifier })
    if not saved then return nil end
    player.killMessage = nil
    player:sync()
    return previous
end
