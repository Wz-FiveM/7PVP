---Accès à la base de la place de marché : annonces (pvp_market_listings) et solde des
---vendeurs (colonne pvp_players.market_balance, modifiée seulement par des requêtes atomiques).
---@class MarketRepositoryModule
local MarketRepository = PVP.define('MarketRepository')

MarketRepository.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_market_listings (
    id INT NOT NULL AUTO_INCREMENT,
    seller VARCHAR(64) NOT NULL,
    seller_name VARCHAR(64) NOT NULL DEFAULT '',
    item VARCHAR(64) NOT NULL,
    count INT NOT NULL,
    price INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_seller (seller)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

---Crée la table au besoin puis renvoie toutes les annonces.
---@return table[]
function MarketRepository.loadAll()
    MySQL.query.await(MarketRepository.SCHEMA)
    return MySQL.query.await('SELECT id, seller, seller_name, item, count, price FROM pvp_market_listings ORDER BY id') or {}
end

---@return integer|nil id de l'annonce
function MarketRepository.insert(seller, sellerName, item, count, price)
    return MySQL.insert.await(
        'INSERT INTO pvp_market_listings (seller, seller_name, item, count, price) VALUES (?, ?, ?, ?, ?)',
        { seller, sellerName, item, count, price }
    )
end

---@param id integer
function MarketRepository.delete(id)
    MySQL.update('DELETE FROM pvp_market_listings WHERE id = ?', { id })
end

---@param identifier string
---@param amount integer
function MarketRepository.credit(identifier, amount)
    MySQL.update('UPDATE pvp_players SET market_balance = market_balance + ? WHERE identifier = ?', { amount, identifier })
end

---@param identifier string
---@return integer
function MarketRepository.getBalance(identifier)
    return MySQL.scalar.await('SELECT market_balance FROM pvp_players WHERE identifier = ?', { identifier }) or 0
end

---Retire du solde le montant récupéré (sans écraser une vente arrivée entre-temps).
---@param identifier string
---@param amount integer
function MarketRepository.debit(identifier, amount)
    MySQL.update.await('UPDATE pvp_players SET market_balance = market_balance - ? WHERE identifier = ?', { amount, identifier })
end
