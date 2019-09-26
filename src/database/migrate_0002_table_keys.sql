ALTER TABLE `ups_punishment`
	DROP INDEX `ups_punishment_fulltext`,
	ADD INDEX `admin_username` (`admin_username`),
	ADD INDEX `player_username` (`player_username`),
	ADD INDEX `reason` (`reason`);

ALTER TABLE `ups_player`
	DROP INDEX `username`,
	ADD INDEX `username` (`username`);

ALTER TABLE `ups_punishment_type`
	ADD UNIQUE INDEX `type_name` (`type_name`);
