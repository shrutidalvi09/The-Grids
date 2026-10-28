import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/presentation/home_providers.dart';
import '../data/facilities_repository.dart';
import '../domain/facility_models.dart';
import 'facility_providers.dart';

/// Drawer → Facility Bookings: the user's upcoming bookings.
class MyBookingsPage extends ConsumerWidget {
  const MyBookingsPage({super.key});

  Future<void> _cancel(BuildContext context, WidgetRef ref, Booking booking) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final when = '${formatDayShort(context, booking.startsAt)}, ${formatTimeRange(context, booking.startsAt, booking.endsAt)}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.cancelBookingConfirm(booking.facilityName, when)),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(l10n.keepBooking)),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: Text(l10n.cancelBooking)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(facilitiesRepositoryProvider).cancel(booking.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.bookingCancelled)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      ref
        ..invalidate(myBookingsProvider)
        ..invalidate(slotsProvider)
        ..invalidate(facilitiesProvider)
        ..invalidate(homeProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return GridsPage(
      title: l10n.drawerFacilityBookings,
      showMenu: false,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myBookingsProvider.future),
        child: AsyncValueView(
          value: ref.watch(myBookingsProvider),
          onRetry: () => ref.invalidate(myBookingsProvider),
          isEmpty: (b) => b.isEmpty,
          empty: EmptyState(
            icon: Icons.event_busy_rounded,
            title: l10n.noBookings,
            actionLabel: l10n.bookAFacility,
            onAction: () => context.go(AppRoutes.towerFacilities),
          ),
          data: (bookings) => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: bookings.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) {
              final b = bookings[i];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.event_available_rounded),
                  title: Text(b.facilityName),
                  subtitle: Text('${formatDayShort(context, b.startsAt)} · ${formatTimeRange(context, b.startsAt, b.endsAt)}'),
                  trailing: TextButton(
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                    onPressed: () => _cancel(context, ref, b),
                    child: Text(l10n.cancel),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
