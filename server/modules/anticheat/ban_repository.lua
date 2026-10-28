---Bannissements (table pvp_bans) : par licence Rockstar, définitifs ou jusqu'à une date.
---@class BanRepositoryModule
local BanRepository = PVP.define('BanRepository')

BanRepository.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_bans (
    identifier VARCHAR(64) NOT NULL,
    name VARCHAR(64) NOT NULL DEFAULT '',
    reason VARCHAR(255) NOT NULL DEFAULT '',
    banned_by VARCHAR(64) NOT NULL DEFAULT '',
    expires_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

function BanRepository.init()
    MySQL.ready(function()
        MySQL.query.await(BanRepository.SCHEMA)
    end)
end

---Ban en cours pour cette licence (les bans expirés sont ignorés).
---@param identifier string
---@return { reason: string, expires_at: string|nil }|nil
function BanRepository.find(identifier)
    return MySQL.single.await(
        [[SELECT reason, DATE_FORMAT(expires_at, '%d/%m/%Y %H:%i') AS expires_at FROM pvp_bans
          WHERE identifier = ? AND (expires_at IS NULL OR expires_at > NOW())]],
        { identifier }
    )
end

---@param identifier string
---@param name string
---@param reason string
---@param bannedBy string
---@param days integer 0 = définitif
function BanRepository.ban(identifier, name, reason, bannedBy, days)
    MySQL.insert.await(
        [[REPLACE INTO pvp_bans (identifier, name, reason, banned_by, expires_at)
          VALUES (?, ?, ?, ?, IF(? > 0, DATE_ADD(NOW(), INTERVAL ? DAY), NULL))]],
        { identifier, name, reason:sub(1, 255), bannedBy, days, days }
    )
end

---@param identifier string
---@return boolean false si aucun ban
function BanRepository.unban(identifier)
    return (MySQL.update.await('DELETE FROM pvp_bans WHERE identifier = ?', { identifier }) or 0) > 0
end

---@return table[] bans en cours
function BanRepository.list()
    return MySQL.query.await(
        [[SELECT identifier, name, reason, banned_by, DATE_FORMAT(expires_at, '%d/%m/%Y') AS expires_at FROM pvp_bans
          WHERE expires_at IS NULL OR expires_at > NOW() ORDER BY created_at DESC LIMIT 50]]
    ) or {}
end
