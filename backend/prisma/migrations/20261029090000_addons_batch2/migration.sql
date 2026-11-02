-- AlterTable
ALTER TABLE `Membership` MODIFY `role` ENUM('ADMIN', 'OWNER', 'TENANT', 'GUARD') NOT NULL;

-- AlterTable
ALTER TABLE `Visitor` ADD COLUMN `decidedById` VARCHAR(191) NULL,
    ADD COLUMN `passCode` VARCHAR(191) NULL,
    ADD COLUMN `photoUrl` VARCHAR(191) NULL,
    ADD COLUMN `vehicleNumber` VARCHAR(191) NULL,
    MODIFY `status` ENUM('EXPECTED', 'CHECKED_IN', 'CHECKED_OUT', 'HELD_AT_GATE', 'PENDING_APPROVAL', 'DENIED') NOT NULL DEFAULT 'EXPECTED';

-- CreateTable
CREATE TABLE `DailyHelp` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `kind` VARCHAR(191) NOT NULL,
    `phone` VARCHAR(191) NULL,
    `passCode` VARCHAR(191) NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `DailyHelp_societyId_phone_idx`(`societyId`, `phone`),
    UNIQUE INDEX `DailyHelp_societyId_passCode_key`(`societyId`, `passCode`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `DailyHelpFlat` (
    `dailyHelpId` VARCHAR(191) NOT NULL,
    `flatId` VARCHAR(191) NOT NULL,
    `addedById` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `DailyHelpFlat_flatId_idx`(`flatId`),
    PRIMARY KEY (`dailyHelpId`, `flatId`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `DailyHelpEntry` (
    `id` VARCHAR(191) NOT NULL,
    `dailyHelpId` VARCHAR(191) NOT NULL,
    `inTime` DATETIME(3) NOT NULL,
    `outTime` DATETIME(3) NULL,

    INDEX `DailyHelpEntry_dailyHelpId_inTime_idx`(`dailyHelpId`, `inTime`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `SosAlert` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `flatId` VARCHAR(191) NULL,
    `raisedById` VARCHAR(191) NULL,
    `note` VARCHAR(191) NULL,
    `status` ENUM('ACTIVE', 'RESOLVED') NOT NULL DEFAULT 'ACTIVE',
    `resolvedById` VARCHAR(191) NULL,
    `resolvedAt` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `SosAlert_societyId_status_idx`(`societyId`, `status`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Vehicle` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `flatId` VARCHAR(191) NOT NULL,
    `number` VARCHAR(191) NOT NULL,
    `type` ENUM('CAR', 'BIKE', 'OTHER') NOT NULL,
    `description` VARCHAR(191) NULL,
    `parkingSlot` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `Vehicle_flatId_idx`(`flatId`),
    UNIQUE INDEX `Vehicle_societyId_number_key`(`societyId`, `number`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE INDEX `Visitor_societyId_status_idx` ON `Visitor`(`societyId`, `status`);

-- CreateIndex
CREATE UNIQUE INDEX `Visitor_societyId_passCode_key` ON `Visitor`(`societyId`, `passCode`);

-- AddForeignKey
ALTER TABLE `Visitor` ADD CONSTRAINT `Visitor_decidedById_fkey` FOREIGN KEY (`decidedById`) REFERENCES `User`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `DailyHelp` ADD CONSTRAINT `DailyHelp_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `DailyHelpFlat` ADD CONSTRAINT `DailyHelpFlat_dailyHelpId_fkey` FOREIGN KEY (`dailyHelpId`) REFERENCES `DailyHelp`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `DailyHelpFlat` ADD CONSTRAINT `DailyHelpFlat_flatId_fkey` FOREIGN KEY (`flatId`) REFERENCES `Flat`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `DailyHelpFlat` ADD CONSTRAINT `DailyHelpFlat_addedById_fkey` FOREIGN KEY (`addedById`) REFERENCES `User`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `DailyHelpEntry` ADD CONSTRAINT `DailyHelpEntry_dailyHelpId_fkey` FOREIGN KEY (`dailyHelpId`) REFERENCES `DailyHelp`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `SosAlert` ADD CONSTRAINT `SosAlert_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `SosAlert` ADD CONSTRAINT `SosAlert_flatId_fkey` FOREIGN KEY (`flatId`) REFERENCES `Flat`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `SosAlert` ADD CONSTRAINT `SosAlert_raisedById_fkey` FOREIGN KEY (`raisedById`) REFERENCES `User`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `SosAlert` ADD CONSTRAINT `SosAlert_resolvedById_fkey` FOREIGN KEY (`resolvedById`) REFERENCES `User`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Vehicle` ADD CONSTRAINT `Vehicle_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Vehicle` ADD CONSTRAINT `Vehicle_flatId_fkey` FOREIGN KEY (`flatId`) REFERENCES `Flat`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
