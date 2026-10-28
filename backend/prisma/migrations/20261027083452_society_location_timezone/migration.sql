-- AlterTable
ALTER TABLE `society` ADD COLUMN `latitude` DOUBLE NULL,
    ADD COLUMN `longitude` DOUBLE NULL,
    ADD COLUMN `timezone` VARCHAR(191) NOT NULL DEFAULT 'Asia/Kolkata';
