-- AlterTable
ALTER TABLE `due` ADD COLUMN `lastRemindedAt` DATETIME(3) NULL;

-- AlterTable
ALTER TABLE `payment` ADD COLUMN `failureReason` VARCHAR(191) NULL,
    ADD COLUMN `gateway` VARCHAR(191) NOT NULL DEFAULT 'razorpay',
    ADD COLUMN `updatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3);

-- CreateTable
CREATE TABLE `ReceiptCounter` (
    `societyId` VARCHAR(191) NOT NULL,
    `key` VARCHAR(191) NOT NULL,
    `value` INTEGER NOT NULL DEFAULT 0,

    PRIMARY KEY (`societyId`, `key`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
