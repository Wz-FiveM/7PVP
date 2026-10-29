---Accès aux points boutique : solde (pvp_shop_points) et historique (pvp_shop_points_log).
---Le solde n'est modifié que par des requêtes atomiques, jamais réécrit depuis le cache du joueur.
---Tables créées par PlayerRepository.MIGRATIONS.
---@class ShopPointsRepositoryModule
local ShopPointsRepository = PVP.define('ShopPointsRepository')

---@param identifier string
---@return integer
function ShopPointsRepository.getBalance(identifier)
    return MySQL.scalar.await('SELECT balance FROM pvp_shop_points WHERE identifier = ?', { identifier }) or 0
end

---@param reference string
---@return boolean
function ShopPointsRepository.hasReference(reference)
    return MySQL.scalar.await('SELECT 1 FROM pvp_shop_points_log WHERE reference = ?', { reference }) ~= nil
end

---Ajoute des points (crée le solde au besoin). Avec une référence déjà utilisée, rien n'est
---ajouté : la clé unique fait échouer la transaction entière.
---@param identifier string
---@param amount integer > 0
---@param reason string
---@param reference string|nil
---@return boolean
function ShopPointsRepository.credit(identifier, amount, reason, reference)
    return MySQL.transaction.await({
        {
            query = 'INSERT INTO pvp_shop_points_log (identifier, amount, reason, reference) VALUES (?, ?, ?, ?)',
            values = { identifier, amount, reason, reference },
        },
        {
            query = 'INSERT INTO pvp_shop_points (identifier, balance) VALUES (?, ?) ON DUPLICATE KEY UPDATE balance = balance + ?',
            values = { identifier, amount, amount },
        },
    }) == true
end

---Retire des points seulement si le solde suffit.
---@param identifier string
---@param amount integer > 0
---@param reason string
---@return boolean false si le solde est insuffisant
function ShopPointsRepository.debit(identifier, amount, reason)
    local changed = MySQL.update.await(
        'UPDATE pvp_shop_points SET balance = balance - ? WHERE identifier = ? AND balance >= ?',
        { amount, identifier, amount }
    )
    if (changed or 0) == 0 then return false end
    MySQL.insert('INSERT INTO pvp_shop_points_log (identifier, amount, reason) VALUES (?, ?, ?)', {
        identifier, -amount, reason,
    })
    return true
end

---Retire jusqu'à `amount` points, sans descendre sous 0 (remboursement, sanction).
---@param identifier string
---@param amount integer > 0
---@param reason string
---@return integer points réellement retirés
function ShopPointsRepository.deduct(identifier, amount, reason)
    local balance = ShopPointsRepository.getBalance(identifier)
    local removed = math.min(amount, balance)
    if removed <= 0 then return 0 end
    -- Le solde a pu baisser entre-temps : la condition garde le retrait atomique
    if not ShopPointsRepository.debit(identifier, removed, reason) then
        return ShopPointsRepository.deduct(identifier, amount, reason)
    end
    return removed
end
