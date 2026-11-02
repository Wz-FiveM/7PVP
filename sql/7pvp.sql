CREATE TABLE IF NOT EXISTS `pvp_players` (
    `identifier` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) NOT NULL DEFAULT '',
    `xp` INT NOT NULL DEFAULT 0,
    `kills` INT NOT NULL DEFAULT 0,
    `deaths` INT NOT NULL DEFAULT 0,
    `npc_kills` INT NOT NULL DEFAULT 0,
    `inventory` LONGTEXT NULL,
    `appearance` LONGTEXT NULL,
    `is_admin` TINYINT(1) NOT NULL DEFAULT 0,
    `contracts` LONGTEXT NULL,
    `market_balance` INT NOT NULL DEFAULT 0,
    `class_id` VARCHAR(16) NULL,
    `name_color` VARCHAR(16) NULL,
    `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`),
    KEY `idx_kills` (`kills`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
