---Points boutique (config/shop_points.lua) : crédités par Tebex ou un admin, dépensés en jeu.
---La base fait foi : `player.shopPoints` n'est qu'une copie pour l'affichage, relue après
---chaque opération. Un retrait passe par une requête conditionnelle (jamais de solde négatif).
---@class ShopPointsServiceModule
local ShopPointsService = PVP.define('ShopPointsService')
local ShopPointsRepository = PVP.use('ShopPointsRepository')
local PlayerService = PVP.use('PlayerService')
local AdminService = PVP.use('AdminService')
local DiscordService = PVP.use('DiscordService')
local Logger = PVP.use('Logger')

function ShopPointsService.init()
    -- Commandes console (Tebex) et admins en jeu, via la permission command.<nom>
    RegisterCommand('addpoints', function(source, args)
        ShopPointsService.commandChange(source, args, 1)
    end, true)
    RegisterCommand('removepoints', function(source, args)
        ShopPointsService.commandChange(source, args, -1)
    end, true)
    RegisterCommand('points', function(source, args)
        ShopPointsService.commandShow(source, args[1])
    end, true)
end

---@param identifier string
---@return integer
function ShopPointsService.load(identifier)
    return ShopPointsRepository.getBalance(identifier)
end

---@param identifier string
---@return PvpPlayer|nil
function ShopPointsService.findOnline(identifier)
    for _, player in pairs(PlayerService.all()) do
        if player.identifier == identifier then return player end
    end
    return nil
end

---Relit le solde d'un joueur en ligne et l'envoie à son interface.
---@param identifier string
---@return PvpPlayer|nil
function ShopPointsService.refresh(identifier)
    local player = ShopPointsService.findOnline(identifier)
    if not player then return nil end
    player.shopPoints = ShopPointsRepository.getBalance(identifier)
    player:sync()
    return player
end

---@param player PvpPlayer
---@return integer
function ShopPointsService.get(player)
    return player.shopPoints or 0
end

---@param amount any
---@return integer|nil montant entier strictement positif
function ShopPointsService.parseAmount(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > Config.ShopPoints.maxPerCommand then return nil end
    return amount
end

---Ajoute des points, même à une licence hors ligne.
---@param identifier string
---@param amount integer
---@param reason string ex : 'tebex', 'admin'
---@param reference? string référence unique (transaction Tebex) : un doublon n'est pas crédité
---@return 'ok'|'duplicate'|'invalid'|'error'
function ShopPointsService.credit(identifier, amount, reason, reference)
    amount = ShopPointsService.parseAmount(amount)
    if not amount then return 'invalid' end
    if reference and ShopPointsRepository.hasReference(reference) then return 'duplicate' end
    if not ShopPointsRepository.credit(identifier, amount, reason, reference) then
        return (reference and ShopPointsRepository.hasReference(reference)) and 'duplicate' or 'error'
    end

    Logger.info('[points] %s : +%d (%s%s)', identifier, amount, reason, reference and (', réf. ' .. reference) or '')
    local player = ShopPointsService.refresh(identifier)
    if player then
        player:notify(('+%d %s'):format(amount, Config.ShopPoints.label:lower()), 'success')
    end
    return 'ok'
end

---Dépense des points pour un achat en jeu. N'envoie pas la synchro : à l'appelant de le faire.
---@param player PvpPlayer
---@param amount integer
---@param reason string ex : 'case:case_elite'
---@return boolean false si le solde est insuffisant
function ShopPointsService.spend(player, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local ok = ShopPointsRepository.debit(player.identifier, amount, reason)
    player.shopPoints = ShopPointsRepository.getBalance(player.identifier)
    if ok then
        Logger.info('[points] %s : -%d (%s)', player.name, amount, reason)
    end
    return ok
end

---Retire jusqu'à `amount` points (remboursement, sanction), sans descendre sous 0.
---@param identifier string
---@param amount integer
---@param reason string
---@return integer|nil points réellement retirés (nil = montant invalide)
function ShopPointsService.deduct(identifier, amount, reason)
    amount = ShopPointsService.parseAmount(amount)
    if not amount then return nil end
    local removed = ShopPointsRepository.deduct(identifier, amount, reason)
    if removed > 0 then
        Logger.info('[points] %s : -%d (%s)', identifier, removed, reason)
        ShopPointsService.refresh(identifier)
    end
    return removed
end

-- ---------------------------------------------------------------------------
-- Commandes
-- ---------------------------------------------------------------------------

---addpoints <id | license:xxxx> <montant> [référence]
---removepoints <id | license:xxxx> <montant>
---@param source integer 0 = console
---@param args string[]
---@param sign 1|-1
function ShopPointsService.commandChange(source, args, sign)
    local command = sign > 0 and 'addpoints' or 'removepoints'
    local identifier, name = AdminService.resolveTarget(args[1])
    local amount = ShopPointsService.parseAmount(args[2])
    if not identifier or not amount then
        local usage = sign > 0 and '<montant> [référence]' or '<montant>'
        return AdminService.reply(source, ('Usage : %s <id du joueur | license:xxxx> %s'):format(command, usage))
    end

    local label = name or identifier
    local reason = source == 0 and 'console' or ('admin:' .. (GetPlayerName(source) or source))
    if sign > 0 then
        local reference = args[3]
        local status = ShopPointsService.credit(identifier, amount, reason, reference)
        if status == 'duplicate' then
            return AdminService.reply(source, ('Référence %s déjà créditée : ignorée.'):format(reference))
        elseif status ~= 'ok' then
            Logger.error('[points] %s %s %d a échoué (%s)', command, label, amount, status)
            return AdminService.reply(source, 'Échec du crédit des points (voir la console).')
        end
        DiscordService.shopPoints(source, label, amount, reference)
        AdminService.reply(source, ('%s : +%d points boutique.'):format(label, amount))
    else
        local removed = ShopPointsService.deduct(identifier, amount, reason)
        if removed > 0 then DiscordService.shopPoints(source, label, -removed) end
        AdminService.reply(source, ('%s : -%d points boutique.'):format(label, removed))
    end
end

---points <id | license:xxxx>
---@param source integer
---@param arg string|nil
function ShopPointsService.commandShow(source, arg)
    local identifier, name = AdminService.resolveTarget(arg)
    if not identifier then
        return AdminService.reply(source, 'Usage : points <id du joueur | license:xxxx>')
    end
    AdminService.reply(source, ('%s : %d points boutique.'):format(name or identifier, ShopPointsRepository.getBalance(identifier)))
end
