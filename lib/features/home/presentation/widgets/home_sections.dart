import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../facilities/domain/facility_models.dart';
import '../../../facilities/presentation/facility_labels.dart';
import '../../../tower/domain/tower_models.dart';
import '../../../tower/presentation/widgets/tower_tiles.dart';
import '../../domain/home_models.dart';

/// Admin: orange stat tiles (Towers, Apartments, Owners, Tenants, Dues).
class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key, required this.stats});

  final SocietyStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tiles = [
      (l10n.statTowers, stats.towers, null),
      (l10n.statFlats, stats.flats, null),
      (l10n.statOwners, stats.owners, null),
      (l10n.statTenants, stats.tenants, null),
      (l10n.statDues, stats.pendingDues, () => context.go(AppRoutes.defaulters)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.statsTitle, icon: Icons.insights_rounded),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = AppSpacing.md;
            final width = (constraints.maxWidth - gap * 2) / 3;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              alignment: WrapAlignment.center,
              children: [
                for (final (label, value, onTap) in tiles)
                  SizedBox(width: width, child: StatCard(label: label, value: '$value', onTap: onTap)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class RecentComplaints extends StatelessWidget {
  const RecentComplaints({super.key, required this.complaints});

  final List<Complaint> complaints;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.complaintsTitle,
          icon: Icons.assignment_late_rounded,
          actionLabel: l10n.viewAll,
          onAction: () => context.go(AppRoutes.towerComplaints),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: complaints.isEmpty
              ? Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(l10n.noComplaints))
              : Column(children: [for (final c in complaints) ComplaintTile(complaint: c, showFlat: true)]),
        ),
      ],
    );
  }
}

/// Horizontally scrolling event cards.
class UpcomingEvents extends StatelessWidget {
  const UpcomingEvents({super.key, required this.events});

  final List<SocietyEvent> events;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.upcomingEventsTitle,
          icon: Icons.event_available_rounded,
          actionLabel: events.isEmpty ? null : l10n.viewAll,
          onAction: () => context.push(AppRoutes.events),
        ),
        if (events.isEmpty)
          Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(l10n.noUpcomingEvents)))
        else
          SizedBox(
            height: 172,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, i) => EventCard(event: events[i], width: 240),
            ),
          ),
      ],
    );
  }
}

/// Resident: maid / parcel / bill reminders for today.
class DailyChecklist extends StatelessWidget {
  const DailyChecklist({super.key, required this.items});

  final List<ChecklistItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.dailyChecklistTitle, icon: Icons.checklist_rounded),
        for (final item in items) _ChecklistRow(item: item),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item});

  final ChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final grids = GridsColors.of(context);
    String withPurpose(String name, String? purpose) => purpose == null ? name : '$name ($purpose)';

    final (icon, color, text, onTap) = switch (item) {
      HelpVisit(:final name, :final purpose, checkedIn: true, :final at) => (
          Icons.check_circle_rounded,
          grids.success,
          l10n.checklistHelpIn(withPurpose(name, purpose), at == null ? '' : formatTime(context, at)),
          null,
        ),
      HelpVisit(:final name, :final purpose) => (
          Icons.schedule_rounded,
          grids.warning,
          l10n.checklistHelpExpected(withPurpose(name, purpose)),
          null,
        ),
      ParcelAtGate(:final from) => (Icons.inventory_2_rounded, grids.info, l10n.checklistParcel(from), null),
      BillDue(:final isRent, :final amountPaise, :final dueDate, :final overdue) => (
          overdue ? Icons.error_rounded : Icons.receipt_long_rounded,
          overdue ? grids.danger : grids.warning,
          (overdue ? l10n.checklistBillOverdue : l10n.checklistBillDue)(
            isRent ? l10n.navRent : l10n.navMaintenance,
            formatPaise(amountPaise),
            formatDayMonth(context, dueDate),
          ),
          () => context.go(AppRoutes.maintenance),
        ),
      BillsClear() => (Icons.verified_rounded, grids.success, l10n.checklistBillsClear, null),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: color),
          title: Text(text),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

/// Resident: today's bookings plus facilities free right now.
class FacilitySummary extends StatelessWidget {
  const FacilitySummary({super.key, required this.bookings, required this.facilities});

  final List<Booking> bookings;
  final List<Facility> facilities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bookedIds = {for (final b in bookings) b.facilityId};
    final available =
        facilities.where((f) => f.status is FacilityOpen && !bookedIds.contains(f.id)).take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.facilityBookingSummaryTitle,
          icon: Icons.sports_tennis_rounded,
          actionLabel: l10n.viewAll,
          onAction: () => context.go(AppRoutes.towerFacilities),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: bookings.isEmpty && available.isEmpty
              ? Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(l10n.noFacilities))
              : Column(
                  children: [
                    for (final b in bookings)
                      ListTile(
                        leading: const Icon(Icons.event_available_rounded),
                        title: Text(l10n.facilityBookedToday(b.facilityName, formatTimeRange(context, b.startsAt, b.endsAt))),
                        onTap: () => context.push(AppRoutes.facilityBookings),
                      ),
                    for (final f in available)
                      ListTile(
                        leading: const Icon(Icons.meeting_room_rounded),
                        title: Text(f.name),
                        subtitle: Text(facilityStatusText(context, f.status)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go(AppRoutes.bookFacility(f.id)),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
