CREATE TABLE IF NOT EXISTS `shocks_vehicle_keys` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(64) NOT NULL,
  `plate` VARCHAR(16) NOT NULL,
  `key_type` VARCHAR(16) NOT NULL DEFAULT 'permanent',
  `issued_by` VARCHAR(64) NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_shocks_vehicle_key` (`citizenid`, `plate`, `key_type`),
  KEY `idx_shocks_vehicle_key_plate` (`plate`),
  KEY `idx_shocks_vehicle_key_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
