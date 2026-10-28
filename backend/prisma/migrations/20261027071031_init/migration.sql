-- CreateTable
CREATE TABLE `Society` (
    `id` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `address` VARCHAR(191) NULL,
    `city` VARCHAR(191) NULL,
    `logoUrl` VARCHAR(191) NULL,
    `maintenanceDueDay` INTEGER NOT NULL DEFAULT 10,
    `isActive` BOOLEAN NOT NULL DEFAULT true,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    INDEX `Society_name_idx`(`name`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Tower` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `floors` INTEGER NOT NULL,

    UNIQUE INDEX `Tower_societyId_name_key`(`societyId`, `name`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Flat` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `towerId` VARCHAR(191) NOT NULL,
    `number` VARCHAR(191) NOT NULL,
    `floor` INTEGER NOT NULL,

    INDEX `Flat_societyId_idx`(`societyId`),
    UNIQUE INDEX `Flat_towerId_number_key`(`towerId`, `number`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `User` (
    `id` VARCHAR(191) NOT NULL,
    `phone` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `email` VARCHAR(191) NULL,
    `photoUrl` VARCHAR(191) NULL,
    `language` VARCHAR(191) NOT NULL DEFAULT 'en',
    `theme` VARCHAR(191) NOT NULL DEFAULT 'system',
    `notificationPrefs` JSON NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    UNIQUE INDEX `User_phone_key`(`phone`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Membership` (
    `id` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `role` ENUM('ADMIN', 'OWNER', 'TENANT') NOT NULL,
    `flatId` VARCHAR(191) NULL,
    `status` ENUM('INVITED', 'ACTIVE', 'REMOVED') NOT NULL DEFAULT 'INVITED',
    `invitedById` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    INDEX `Membership_societyId_role_idx`(`societyId`, `role`),
    UNIQUE INDEX `Membership_userId_societyId_role_key`(`userId`, `societyId`, `role`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `OtpChallenge` (
    `id` VARCHAR(191) NOT NULL,
    `membershipId` VARCHAR(191) NOT NULL,
    `phone` VARCHAR(191) NOT NULL,
    `codeHash` VARCHAR(191) NOT NULL,
    `expiresAt` DATETIME(3) NOT NULL,
    `attempts` INTEGER NOT NULL DEFAULT 0,
    `consumedAt` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `OtpChallenge_phone_createdAt_idx`(`phone`, `createdAt`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `RefreshToken` (
    `id` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `membershipId` VARCHAR(191) NOT NULL,
    `familyId` VARCHAR(191) NOT NULL,
    `tokenHash` VARCHAR(191) NOT NULL,
    `expiresAt` DATETIME(3) NOT NULL,
    `revokedAt` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    UNIQUE INDEX `RefreshToken_tokenHash_key`(`tokenHash`),
    INDEX `RefreshToken_familyId_idx`(`familyId`),
    INDEX `RefreshToken_userId_idx`(`userId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `HouseholdMember` (
    `id` VARCHAR(191) NOT NULL,
    `flatId` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `relation` VARCHAR(191) NOT NULL,
    `phone` VARCHAR(191) NULL,
    `photoUrl` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `DeviceToken` (
    `id` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `token` VARCHAR(512) NOT NULL,
    `platform` VARCHAR(191) NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    UNIQUE INDEX `DeviceToken_token_key`(`token`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Visitor` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `flatId` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `purpose` VARCHAR(191) NULL,
    `type` ENUM('GUEST', 'DELIVERY', 'SERVICE') NOT NULL,
    `status` ENUM('EXPECTED', 'CHECKED_IN', 'CHECKED_OUT', 'HELD_AT_GATE') NOT NULL DEFAULT 'EXPECTED',
    `inTime` DATETIME(3) NULL,
    `outTime` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `Visitor_societyId_flatId_createdAt_idx`(`societyId`, `flatId`, `createdAt`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Facility` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `towerId` VARCHAR(191) NULL,
    `name` VARCHAR(191) NOT NULL,
    `description` TEXT NULL,
    `photoUrl` VARCHAR(191) NULL,
    `openTime` VARCHAR(191) NOT NULL,
    `closeTime` VARCHAR(191) NOT NULL,
    `maxDurationMins` INTEGER NOT NULL,
    `capacity` INTEGER NULL,
    `isActive` BOOLEAN NOT NULL DEFAULT true,

    INDEX `Facility_societyId_idx`(`societyId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `FacilityBooking` (
    `id` VARCHAR(191) NOT NULL,
    `facilityId` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `startsAt` DATETIME(3) NOT NULL,
    `endsAt` DATETIME(3) NOT NULL,
    `status` ENUM('CONFIRMED', 'CANCELLED') NOT NULL DEFAULT 'CONFIRMED',
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `FacilityBooking_facilityId_startsAt_idx`(`facilityId`, `startsAt`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Notice` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `towerId` VARCHAR(191) NULL,
    `title` VARCHAR(191) NOT NULL,
    `body` TEXT NOT NULL,
    `category` VARCHAR(191) NULL,
    `isAlert` BOOLEAN NOT NULL DEFAULT false,
    `scheduledAt` DATETIME(3) NULL,
    `expiresAt` DATETIME(3) NULL,
    `createdById` VARCHAR(191) NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `Notice_societyId_createdAt_idx`(`societyId`, `createdAt`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Complaint` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `flatId` VARCHAR(191) NULL,
    `raisedById` VARCHAR(191) NOT NULL,
    `title` VARCHAR(191) NOT NULL,
    `category` VARCHAR(191) NULL,
    `description` TEXT NOT NULL,
    `photoUrl` VARCHAR(191) NULL,
    `status` ENUM('OPEN', 'IN_PROGRESS', 'RESOLVED') NOT NULL DEFAULT 'OPEN',
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,
    `resolvedAt` DATETIME(3) NULL,

    INDEX `Complaint_societyId_status_idx`(`societyId`, `status`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `MaintenanceItem` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `label` VARCHAR(191) NOT NULL,
    `amountPaise` INTEGER NOT NULL,
    `sortOrder` INTEGER NOT NULL DEFAULT 0,

    INDEX `MaintenanceItem_societyId_idx`(`societyId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Due` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `flatId` VARCHAR(191) NOT NULL,
    `type` ENUM('MAINTENANCE', 'RENT') NOT NULL,
    `period` VARCHAR(191) NOT NULL,
    `amountPaise` INTEGER NOT NULL,
    `breakdown` JSON NOT NULL,
    `dueDate` DATETIME(3) NOT NULL,
    `status` ENUM('PENDING', 'PAID', 'CANCELLED') NOT NULL DEFAULT 'PENDING',
    `paidAt` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `Due_societyId_status_idx`(`societyId`, `status`),
    UNIQUE INDEX `Due_flatId_type_period_key`(`flatId`, `type`, `period`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Payment` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `dueId` VARCHAR(191) NOT NULL,
    `payerId` VARCHAR(191) NOT NULL,
    `amountPaise` INTEGER NOT NULL,
    `method` VARCHAR(191) NULL,
    `status` ENUM('CREATED', 'PENDING', 'SUCCEEDED', 'FAILED') NOT NULL DEFAULT 'CREATED',
    `razorpayOrderId` VARCHAR(191) NULL,
    `razorpayPaymentId` VARCHAR(191) NULL,
    `receiptNo` VARCHAR(191) NULL,
    `receiptUrl` VARCHAR(191) NULL,
    `paidAt` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    UNIQUE INDEX `Payment_razorpayOrderId_key`(`razorpayOrderId`),
    UNIQUE INDEX `Payment_razorpayPaymentId_key`(`razorpayPaymentId`),
    UNIQUE INDEX `Payment_receiptNo_key`(`receiptNo`),
    INDEX `Payment_societyId_createdAt_idx`(`societyId`, `createdAt`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Tenancy` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `flatId` VARCHAR(191) NOT NULL,
    `ownerId` VARCHAR(191) NOT NULL,
    `tenantId` VARCHAR(191) NOT NULL,
    `monthlyRentPaise` INTEGER NOT NULL,
    `depositPaise` INTEGER NOT NULL,
    `rentDueDay` INTEGER NOT NULL DEFAULT 5,
    `rentBreakdown` JSON NOT NULL,
    `startDate` DATETIME(3) NOT NULL,
    `endDate` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `Tenancy_flatId_idx`(`flatId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `SocietyBill` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `vendor` VARCHAR(191) NOT NULL,
    `category` VARCHAR(191) NULL,
    `amountPaise` INTEGER NOT NULL,
    `dueDate` DATETIME(3) NOT NULL,
    `status` ENUM('PAID', 'DUE') NOT NULL DEFAULT 'DUE',
    `paidAt` DATETIME(3) NULL,

    INDEX `SocietyBill_societyId_status_idx`(`societyId`, `status`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Poll` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `question` VARCHAR(191) NOT NULL,
    `closesAt` DATETIME(3) NULL,
    `createdById` VARCHAR(191) NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `Poll_societyId_createdAt_idx`(`societyId`, `createdAt`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `PollOption` (
    `id` VARCHAR(191) NOT NULL,
    `pollId` VARCHAR(191) NOT NULL,
    `label` VARCHAR(191) NOT NULL,
    `sortOrder` INTEGER NOT NULL DEFAULT 0,

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `PollVote` (
    `id` VARCHAR(191) NOT NULL,
    `pollId` VARCHAR(191) NOT NULL,
    `optionId` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    UNIQUE INDEX `PollVote_pollId_userId_key`(`pollId`, `userId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Community` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `description` TEXT NULL,
    `photoUrl` VARCHAR(191) NULL,
    `createdById` VARCHAR(191) NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    UNIQUE INDEX `Community_societyId_name_key`(`societyId`, `name`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `CommunityMember` (
    `communityId` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `joinedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`communityId`, `userId`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Announcement` (
    `id` VARCHAR(191) NOT NULL,
    `communityId` VARCHAR(191) NOT NULL,
    `authorId` VARCHAR(191) NOT NULL,
    `title` VARCHAR(191) NOT NULL,
    `body` TEXT NOT NULL,
    `eventAt` DATETIME(3) NULL,
    `venue` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    INDEX `Announcement_communityId_createdAt_idx`(`communityId`, `createdAt`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `ServiceProvider` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `category` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `phone` VARCHAR(191) NOT NULL,
    `location` VARCHAR(191) NULL,
    `rating` DOUBLE NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `ServiceProvider_societyId_category_idx`(`societyId`, `category`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Event` (
    `id` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `title` VARCHAR(191) NOT NULL,
    `description` TEXT NULL,
    `location` VARCHAR(191) NOT NULL,
    `imageUrl` VARCHAR(191) NULL,
    `startsAt` DATETIME(3) NOT NULL,
    `endsAt` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `Event_societyId_startsAt_idx`(`societyId`, `startsAt`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Notification` (
    `id` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `societyId` VARCHAR(191) NOT NULL,
    `type` VARCHAR(191) NOT NULL,
    `title` VARCHAR(191) NOT NULL,
    `body` VARCHAR(191) NOT NULL,
    `data` JSON NULL,
    `readAt` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `Notification_userId_readAt_idx`(`userId`, `readAt`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `Tower` ADD CONSTRAINT `Tower_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Flat` ADD CONSTRAINT `Flat_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Flat` ADD CONSTRAINT `Flat_towerId_fkey` FOREIGN KEY (`towerId`) REFERENCES `Tower`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Membership` ADD CONSTRAINT `Membership_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Membership` ADD CONSTRAINT `Membership_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Membership` ADD CONSTRAINT `Membership_flatId_fkey` FOREIGN KEY (`flatId`) REFERENCES `Flat`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Membership` ADD CONSTRAINT `Membership_invitedById_fkey` FOREIGN KEY (`invitedById`) REFERENCES `User`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `OtpChallenge` ADD CONSTRAINT `OtpChallenge_membershipId_fkey` FOREIGN KEY (`membershipId`) REFERENCES `Membership`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `RefreshToken` ADD CONSTRAINT `RefreshToken_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `RefreshToken` ADD CONSTRAINT `RefreshToken_membershipId_fkey` FOREIGN KEY (`membershipId`) REFERENCES `Membership`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `HouseholdMember` ADD CONSTRAINT `HouseholdMember_flatId_fkey` FOREIGN KEY (`flatId`) REFERENCES `Flat`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `DeviceToken` ADD CONSTRAINT `DeviceToken_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Visitor` ADD CONSTRAINT `Visitor_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Visitor` ADD CONSTRAINT `Visitor_flatId_fkey` FOREIGN KEY (`flatId`) REFERENCES `Flat`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Facility` ADD CONSTRAINT `Facility_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Facility` ADD CONSTRAINT `Facility_towerId_fkey` FOREIGN KEY (`towerId`) REFERENCES `Tower`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `FacilityBooking` ADD CONSTRAINT `FacilityBooking_facilityId_fkey` FOREIGN KEY (`facilityId`) REFERENCES `Facility`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `FacilityBooking` ADD CONSTRAINT `FacilityBooking_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Notice` ADD CONSTRAINT `Notice_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Notice` ADD CONSTRAINT `Notice_towerId_fkey` FOREIGN KEY (`towerId`) REFERENCES `Tower`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Notice` ADD CONSTRAINT `Notice_createdById_fkey` FOREIGN KEY (`createdById`) REFERENCES `User`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Complaint` ADD CONSTRAINT `Complaint_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Complaint` ADD CONSTRAINT `Complaint_flatId_fkey` FOREIGN KEY (`flatId`) REFERENCES `Flat`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Complaint` ADD CONSTRAINT `Complaint_raisedById_fkey` FOREIGN KEY (`raisedById`) REFERENCES `User`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `MaintenanceItem` ADD CONSTRAINT `MaintenanceItem_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Due` ADD CONSTRAINT `Due_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Due` ADD CONSTRAINT `Due_flatId_fkey` FOREIGN KEY (`flatId`) REFERENCES `Flat`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Payment` ADD CONSTRAINT `Payment_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Payment` ADD CONSTRAINT `Payment_dueId_fkey` FOREIGN KEY (`dueId`) REFERENCES `Due`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Payment` ADD CONSTRAINT `Payment_payerId_fkey` FOREIGN KEY (`payerId`) REFERENCES `User`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Tenancy` ADD CONSTRAINT `Tenancy_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Tenancy` ADD CONSTRAINT `Tenancy_flatId_fkey` FOREIGN KEY (`flatId`) REFERENCES `Flat`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Tenancy` ADD CONSTRAINT `Tenancy_ownerId_fkey` FOREIGN KEY (`ownerId`) REFERENCES `User`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Tenancy` ADD CONSTRAINT `Tenancy_tenantId_fkey` FOREIGN KEY (`tenantId`) REFERENCES `User`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `SocietyBill` ADD CONSTRAINT `SocietyBill_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Poll` ADD CONSTRAINT `Poll_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Poll` ADD CONSTRAINT `Poll_createdById_fkey` FOREIGN KEY (`createdById`) REFERENCES `User`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `PollOption` ADD CONSTRAINT `PollOption_pollId_fkey` FOREIGN KEY (`pollId`) REFERENCES `Poll`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `PollVote` ADD CONSTRAINT `PollVote_pollId_fkey` FOREIGN KEY (`pollId`) REFERENCES `Poll`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `PollVote` ADD CONSTRAINT `PollVote_optionId_fkey` FOREIGN KEY (`optionId`) REFERENCES `PollOption`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `PollVote` ADD CONSTRAINT `PollVote_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Community` ADD CONSTRAINT `Community_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Community` ADD CONSTRAINT `Community_createdById_fkey` FOREIGN KEY (`createdById`) REFERENCES `User`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `CommunityMember` ADD CONSTRAINT `CommunityMember_communityId_fkey` FOREIGN KEY (`communityId`) REFERENCES `Community`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `CommunityMember` ADD CONSTRAINT `CommunityMember_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Announcement` ADD CONSTRAINT `Announcement_communityId_fkey` FOREIGN KEY (`communityId`) REFERENCES `Community`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Announcement` ADD CONSTRAINT `Announcement_authorId_fkey` FOREIGN KEY (`authorId`) REFERENCES `User`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ServiceProvider` ADD CONSTRAINT `ServiceProvider_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Event` ADD CONSTRAINT `Event_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Notification` ADD CONSTRAINT `Notification_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Notification` ADD CONSTRAINT `Notification_societyId_fkey` FOREIGN KEY (`societyId`) REFERENCES `Society`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
