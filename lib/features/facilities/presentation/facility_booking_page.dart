import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/uploads_api.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/presentation/home_providers.dart';
import '../data/facilities_repository.dart';
import '../domain/facility_models.dart';
import 'facility_labels.dart';
import 'facility_providers.dart';

/// Pick a day (next 7) and a free slot, then confirm.
class FacilityBookingPage extends ConsumerStatefulWidget {
  const FacilityBookingPage({super.key, required this.facilityId});

  final String facilityId;

  static const bookingWindowDays = 7;

  @override
  ConsumerState<FacilityBookingPage> createState() => _FacilityBookingPageState();
}

class _FacilityBookingPageState extends ConsumerState<FacilityBookingPage> {
  late DateTime _day = DateUtils.dateOnly(DateTime.now());
  Slot? _selected;
  bool _booking = false;

  Future<void> _book(Facility facility) async {
    final slot = _selected!;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _booking = true);
    try {
      await ref.read(facilitiesRepositoryProvider).book(facility.id, slot.startsAt);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.bookingConfirmed(
              facility.name,
              '${formatDayShort(context, slot.startsAt)}, ${formatTimeRange(context, slot.startsAt, slot.endsAt)}',
            ),
          ),
        ),
      );
      setState(() => _selected = null);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      ref
        ..invalidate(slotsProvider((facility.id, _day)))
        ..invalidate(myBookingsProvider)
        ..invalidate(facilitiesProvider)
        ..invalidate(homeProvider);
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final facilities = ref.watch(facilitiesProvider);
    final facility = facilities.value?.where((f) => f.id == widget.facilityId).firstOrNull;

    return GridsPage(
      title: facility?.name ?? l10n.facilitiesTitle,
      showMenu: false,
      body: facility == null
          ? AsyncValueView(
              value: facilities,
              onRetry: () => ref.invalidate(facilitiesProvider),
              data: (_) => EmptyState(icon: Icons.search_off_rounded, title: l10n.pageNotFoundTitle),
            )
          : Column(
              children: [
                Expanded(child: _content(facility)),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: PrimaryButton(
                      label: _selected == null ? l10n.book : l10n.bookSlot(formatTime(context, _selected!.startsAt)),
                      isLoading: _booking,
                      onPressed: _selected == null ? null : () => _book(facility),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _content(Facility facility) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final slate = GridsColors.of(context).slate;
    final photoUrl = ref.watch(photoUrlProvider(facility.photoPath));
    final today = DateUtils.dateOnly(DateTime.now());
    final days = [for (var i = 0; i < FacilityBookingPage.bookingWindowDays; i++) today.add(Duration(days: i))];
    final slots = ref.watch(slotsProvider((facility.id, _day)));

    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        if (photoUrl != null) ...[
          ClipRRect(
            borderRadius: const BorderRadius.all(AppRadii.md),
            child: Image.network(photoUrl, height: 160, fit: BoxFit.cover),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            Expanded(child: Text(facilityStatusText(context, facility.status), style: TextStyle(color: slate))),
            facilityStatusChip(l10n, facility.status),
          ],
        ),
        if (facility.description != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(facility.description!, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          [
            facilityHours(context, facility),
            l10n.slotLength(facility.maxDurationMins),
            if (facility.capacity != null) l10n.capacityUpTo(facility.capacity!),
          ].join(' · '),
          style: TextStyle(color: slate),
        ),
        SectionHeader(title: l10n.chooseDay, icon: Icons.calendar_month_rounded),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) {
              final day = days[i];
              final label = switch (i) {
                0 => l10n.today,
                1 => l10n.tomorrow,
                _ => formatDayShort(context, day),
              };
              return ChoiceChip(
                label: Text(label),
                selected: day == _day,
                onSelected: (_) => setState(() {
                  _day = day;
                  _selected = null;
                }),
              );
            },
          ),
        ),
        SectionHeader(title: l10n.chooseSlot, icon: Icons.schedule_rounded),
        slots.when(
          skipLoadingOnRefresh: false,
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(describeError(l10n, error)),
          data: (list) {
            if (list.isEmpty) return Text(l10n.noSlots);
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final slot in list)
                  ChoiceChip(
                    avatar: slot.mine ? const Icon(Icons.check_circle_rounded, size: 18) : null,
                    label: Text(slot.mine ? '${formatTime(context, slot.startsAt)} · ${l10n.slotYours}' : formatTime(context, slot.startsAt)),
                    tooltip: slot.remaining == null ? null : l10n.facilityPlacesLeft(slot.remaining!),
                    selected: _selected?.startsAt == slot.startsAt,
                    onSelected: slot.available && !slot.mine ? (_) => setState(() => _selected = slot) : null,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
