-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Server version:               5.7.26-29 - Percona Server (GPL), Release '29', Revision '11ad961'
-- Server OS:                    debian-linux-gnu
-- HeidiSQL Version:             10.2.0.5599
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

-- Dumping structure for table ups.ups_player
CREATE TABLE IF NOT EXISTS `ups_player` (
  `account_id` int(10) unsigned NOT NULL COMMENT 'Unique client identifier',
  `username` varchar(64) NOT NULL DEFAULT 'unnamed' COMMENT 'Client username',
  `last_activity` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'Last user activity',
  PRIMARY KEY (`account_id`),
  FULLTEXT KEY `username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='All players who received or added a punishment';

-- Dumping data for table ups.ups_player: ~1 rows (approximately)
/*!40000 ALTER TABLE `ups_player` DISABLE KEYS */;
INSERT INTO `ups_player` (`account_id`, `username`, `last_activity`) VALUES
	(0, 'CONSOLE', 0);
/*!40000 ALTER TABLE `ups_player` ENABLE KEYS */;

-- Dumping structure for table ups.ups_punishment
CREATE TABLE IF NOT EXISTS `ups_punishment` (
  `punishment_id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique punishment identifier',
  `punishment_type_id` int(10) unsigned NOT NULL COMMENT 'Punishment type',
  `server_id` int(10) unsigned NOT NULL COMMENT 'Server identifier, where ban added',
  `admin_id` int(10) unsigned NOT NULL COMMENT 'Unique administrator identifier',
  `admin_username` varchar(64) NOT NULL DEFAULT 'unnamed' COMMENT 'Admin username (at moment when punishment added)',
  `admin_ip` int(10) unsigned NOT NULL COMMENT 'Admin Internet Address (at moment when punishment added)',
  `player_id` int(10) unsigned NOT NULL COMMENT 'Unique punishment target identifier',
  `player_username` varchar(64) NOT NULL DEFAULT 'unnamed' COMMENT 'Ban target username (at moment when punishment added)',
  `player_ip` int(10) unsigned NOT NULL COMMENT 'Admin Internet Address (at moment when punishment added)',
  `reason` varchar(256) NOT NULL COMMENT 'Punishment reason (filled by admin)',
  `created` int(10) unsigned NOT NULL COMMENT 'Unix timestamp when punishment added',
  `ends` int(10) unsigned NOT NULL COMMENT 'Unix timestamp when punishment expires',
  `length` int(10) unsigned DEFAULT NULL COMMENT 'Punishment length (null - permanent)',
  `deleted_by` int(10) unsigned DEFAULT NULL COMMENT 'Admin identifier who removed ban (null - ban will not removed)',
  `deleted_at` int(10) unsigned DEFAULT NULL COMMENT 'Unix timestamp when ban removed',
  `delete_reason` varchar(256) DEFAULT NULL COMMENT 'Remove reason (filled by admin)',
  PRIMARY KEY (`punishment_id`),
  KEY `FK_ups_punishment_ups_server` (`server_id`),
  KEY `FK_ups_punishment_ups_punishment_type` (`punishment_type_id`),
  KEY `FK_ups_punishment_ups_player_admin` (`admin_id`),
  KEY `FK_ups_punishment_ups_player` (`player_id`),
  KEY `FK_ups_punishment_ups_player_admin_delete` (`deleted_by`),
  FULLTEXT KEY `ups_punishment_fulltext` (`admin_username`,`player_username`,`reason`),
  CONSTRAINT `FK_ups_punishment_ups_player` FOREIGN KEY (`player_id`) REFERENCES `ups_player` (`account_id`),
  CONSTRAINT `FK_ups_punishment_ups_player_admin` FOREIGN KEY (`admin_id`) REFERENCES `ups_player` (`account_id`),
  CONSTRAINT `FK_ups_punishment_ups_player_admin_delete` FOREIGN KEY (`deleted_by`) REFERENCES `ups_player` (`account_id`),
  CONSTRAINT `FK_ups_punishment_ups_punishment_type` FOREIGN KEY (`punishment_type_id`) REFERENCES `ups_punishment_type` (`punishment_type_id`),
  CONSTRAINT `FK_ups_punishment_ups_server` FOREIGN KEY (`server_id`) REFERENCES `ups_server` (`server_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='All created punishments';

-- Dumping data for table ups.ups_punishment: ~0 rows (approximately)
/*!40000 ALTER TABLE `ups_punishment` DISABLE KEYS */;
/*!40000 ALTER TABLE `ups_punishment` ENABLE KEYS */;

-- Dumping structure for table ups.ups_punishment_type
CREATE TABLE IF NOT EXISTS `ups_punishment_type` (
  `punishment_type_id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique punishment type id (used in ups_punishment)',
  `type_name` varchar(64) NOT NULL COMMENT 'Unique punishment type name (received from plugin-modules)',
  `registered_at` int(10) unsigned NOT NULL COMMENT 'Datetime when type is registered',
  PRIMARY KEY (`punishment_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='All registered punishment types';

-- Dumping data for table ups.ups_punishment_type: ~0 rows (approximately)
/*!40000 ALTER TABLE `ups_punishment_type` DISABLE KEYS */;
/*!40000 ALTER TABLE `ups_punishment_type` ENABLE KEYS */;

-- Dumping structure for table ups.ups_server
CREATE TABLE IF NOT EXISTS `ups_server` (
  `server_id` int(10) unsigned NOT NULL COMMENT 'Unique server identifier',
  `address` int(10) unsigned NOT NULL COMMENT 'Server address',
  `port` smallint(5) unsigned NOT NULL COMMENT 'Server port',
  `hostname` varchar(256) NOT NULL COMMENT 'Server hostname',
  PRIMARY KEY (`server_id`),
  UNIQUE KEY `address_port` (`address`,`port`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='All servers where plugin started';

-- Dumping data for table ups.ups_server: ~0 rows (approximately)
/*!40000 ALTER TABLE `ups_server` DISABLE KEYS */;
/*!40000 ALTER TABLE `ups_server` ENABLE KEYS */;

/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
