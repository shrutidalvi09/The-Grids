import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/tower_models.dart';

/// Categories offered on the notice form (stored in English, shown localised).
const noticeCategories = ['Maintenance', 'Utilities', 'Safety', 'Meeting', 'Event', 'General'];

/// Categories offered on the complaint form.
const complaintCategories = [
  'Lift',
  'Plumbing',
  'Electrical',
  'Water',
  'Cleaning',
  'Security',
  'Parking',
  'Facilities',
  'Other',
];

/// Localised name for a stored category; unknown ones are shown as stored.
String categoryLabel(AppLocalizations l10n, String category) => switch (category) {
      'Maintenance' => l10n.categoryMaintenance,
      'Utilities' => l10n.categoryUtilities,
      'Safety' => l10n.categorySafety,
      'Meeting' => l10n.categoryMeeting,
      'Event' => l10n.categoryEvent,
      'General' => l10n.categoryGeneral,
      'Lift' => l10n.categoryLift,
      'Plumbing' => l10n.categoryPlumbing,
      'Electrical' => l10n.categoryElectrical,
      'Water' => l10n.categoryWater,
      'Cleaning' => l10n.categoryCleaning,
      'Security' => l10n.categorySecurity,
      'Parking' => l10n.categoryParking,
      'Facilities' => l10n.categoryFacilities,
      'Other' => l10n.categoryOther,
      _ => category,
    };

IconData categoryIcon(String? category) => switch (category) {
      'Maintenance' => Icons.build_rounded,
      'Utilities' || 'Water' => Icons.water_drop_rounded,
      'Safety' => Icons.local_fire_department_rounded,
      'Meeting' => Icons.groups_rounded,
      'Event' => Icons.celebration_rounded,
      'Lift' => Icons.elevator_rounded,
      'Plumbing' => Icons.plumbing_rounded,
      'Electrical' => Icons.electrical_services_rounded,
      'Cleaning' => Icons.cleaning_services_rounded,
      'Security' => Icons.security_rounded,
      'Parking' => Icons.local_parking_rounded,
      'Facilities' => Icons.fitness_center_rounded,
      _ => Icons.campaign_rounded,
    };

String complaintStatusLabel(AppLocalizations l10n, ComplaintStatus status) => switch (status) {
      ComplaintStatus.open => l10n.complaintStatusOpen,
      ComplaintStatus.inProgress => l10n.complaintStatusInProgress,
      ComplaintStatus.resolved => l10n.complaintStatusResolved,
    };

StatusChip complaintStatusChip(AppLocalizations l10n, ComplaintStatus status) => StatusChip(
      label: complaintStatusLabel(l10n, status),
      tone: switch (status) {
        ComplaintStatus.open => StatusTone.danger,
        ComplaintStatus.inProgress => StatusTone.warning,
        ComplaintStatus.resolved => StatusTone.success,
      },
    );

StatusChip visitorStatusChip(AppLocalizations l10n, VisitorStatus status) => switch (status) {
      VisitorStatus.expected => StatusChip(label: l10n.visitorExpected, tone: StatusTone.neutral),
      VisitorStatus.checkedIn => StatusChip(label: l10n.visitorCheckedIn, tone: StatusTone.success),
      VisitorStatus.checkedOut => StatusChip(label: l10n.visitorCheckedOut, tone: StatusTone.info),
      VisitorStatus.heldAtGate => StatusChip(label: l10n.visitorAtGate, tone: StatusTone.warning),
    };

IconData visitorIcon(VisitorType type) => switch (type) {
      VisitorType.guest => Icons.person_rounded,
      VisitorType.delivery => Icons.local_shipping_rounded,
      VisitorType.service => Icons.cleaning_services_rounded,
    };
