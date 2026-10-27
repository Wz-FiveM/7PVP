CREATE TABLE IF NOT EXISTS `pvp_players` (
    `identifier` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) NOT NULL DEFAULT '',
    `xp` INT NOT NULL DEFAULT 0,
    `kills` INT NOT NULL DEFAULT 0,
    `deaths` INT NOT NULL DEFAULT 0,
    `npc_kills` INT NOT NULL DEFAULT 0,
    `inventory` LONGTEXT NULL,
    `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`),
    KEY `idx_kills` (`kills`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
