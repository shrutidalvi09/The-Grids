import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/facility_models.dart';

/// "Opens at 6:00 AM", "Opens Wed, 28 Oct 6:00 AM" when it's not today.
String _when(BuildContext context, DateTime time) => isSameDay(time, DateTime.now())
    ? formatTime(context, time)
    : '${formatDayShort(context, time)} ${formatTime(context, time)}';

/// One-line live status: "Available now · 12 places left · Open till 10 PM".
String facilityStatusText(BuildContext context, FacilityStatus status) {
  final l10n = context.l10n;
  return switch (status) {
    FacilityOpen(:final remaining, :final closesAt) => [
        l10n.facilityAvailable,
        if (remaining != null) l10n.facilityPlacesLeft(remaining),
        l10n.facilityOpenTill(formatTime(context, closesAt)),
      ].join(' · '),
    FacilityFull(:final nextFreeAt) => [
        l10n.facilityFull,
        if (nextFreeAt != null) l10n.facilityNextFree(formatTime(context, nextFreeAt)),
      ].join(' · '),
    FacilityClosed(:final opensAt) => l10n.facilityClosedOpens(_when(context, opensAt)),
  };
}

StatusChip facilityStatusChip(AppLocalizations l10n, FacilityStatus status) => switch (status) {
      FacilityOpen() => StatusChip(label: l10n.facilityStatusOpen, tone: StatusTone.success),
      FacilityFull() => StatusChip(label: l10n.facilityStatusFull, tone: StatusTone.warning),
      FacilityClosed() => StatusChip(label: l10n.facilityStatusClosed, tone: StatusTone.neutral),
    };

/// "6:00 AM – 10:00 PM" from society-local "HH:mm" strings.
String facilityHours(BuildContext context, Facility f) {
  DateTime at(String hhmm) {
    final [h, m] = hhmm.split(':').map(int.parse).toList();
    return DateTime(2000, 1, 1, h, m);
  }

  return formatTimeRange(context, at(f.openTime), at(f.closeTime));
}
