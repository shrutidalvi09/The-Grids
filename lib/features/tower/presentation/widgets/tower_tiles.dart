import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/domain/user_role.dart';
import '../../domain/tower_models.dart';
import '../tower_labels.dart';

class VisitorTile extends StatelessWidget {
  const VisitorTile({super.key, required this.visitor, this.showFlat = false});

  final Visitor visitor;
  final bool showFlat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final v = visitor;
    final title = v.purpose == null || v.purpose == v.name ? v.name : '${v.name} (${v.purpose})';
    final time = v.inTime == null ? null : formatTime(context, v.inTime!);
    return ListTile(
      leading: Icon(visitorIcon(v.type)),
      title: Text(title),
      // No empty second line when there's no time yet (keeps the name centred).
      subtitle: switch ([?time, if (showFlat) ?v.flatLabel]) {
        [] => null,
        final parts => Text(parts.join(' · ')),
      },
      trailing: visitorStatusChip(l10n, v.status),
    );
  }
}

class NoticeTile extends StatelessWidget {
  const NoticeTile({super.key, required this.notice, this.onTap});

  final Notice notice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final n = notice;
    return ListTile(
      onTap: onTap,
      leading: Icon(categoryIcon(n.category)),
      title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: n.towerName == null ? null : Text(n.towerName!),
      trailing: Text(formatDayMonth(context, n.displayDate)),
    );
  }
}

class ComplaintTile extends StatelessWidget {
  const ComplaintTile({super.key, required this.complaint, this.showFlat = false, this.onTap});

  final Complaint complaint;
  final bool showFlat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = complaint;
    return ListTile(
      onTap: onTap,
      leading: Icon(categoryIcon(c.category)),
      title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text([if (showFlat) ?c.flatLabel, formatDayMonth(context, c.createdAt)].join(' · ')),
      trailing: complaintStatusChip(l10n, c.status),
    );
  }
}

/// One flat in the neighbours directory: avatars, names and the flat number.
class NeighbourTile extends StatelessWidget {
  const NeighbourTile({super.key, required this.towerName, required this.flat});

  final String towerName;
  final NeighbourFlat flat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final first = flat.residents.first;
    return ListTile(
      leading: PersonAvatar(name: first.name, photoPath: first.photoPath),
      title: Text(flat.residents.map((r) => r.name).join(', ')),
      subtitle: flat.residents.any((r) => r.role == UserRole.tenant)
          ? Text(flat.residents.map((r) => r.role.label(l10n)).join(' · '))
          : null,
      trailing: Text(
        '$towerName\n${l10n.flatNumber(flat.number)}',
        textAlign: TextAlign.end,
        style: TextStyle(color: GridsColors.of(context).slate),
      ),
    );
  }
}

/// Horizontal event card (Home) or full-width card (Events page).
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.width});

  final SocietyEvent event;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = event;
    final when = '${formatDayShort(context, e.startsAt)} · ${formatTime(context, e.startsAt)}';
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showDetails(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 96,
                width: double.infinity,
                decoration: BoxDecoration(
                  // Fixed deep brand colours in both themes so the white title
                  // stays readable (the dark theme's primary/secondary are pale).
                  gradient: const LinearGradient(
                    colors: [AppColors.greenDark, AppColors.orangeText],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                alignment: Alignment.bottomLeft,
                child: Text(
                  e.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IconLine(icon: Icons.event_rounded, text: when),
                    const SizedBox(height: 4),
                    _IconLine(icon: Icons.place_rounded, text: e.location),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      useRootNavigator: true, // above the bottom nav bar
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _IconLine(
              icon: Icons.event_rounded,
              text: event.endsAt == null
                  ? '${formatDate(context, event.startsAt)} · ${formatTime(context, event.startsAt)}'
                  : '${formatDate(context, event.startsAt)} · ${formatTimeRange(context, event.startsAt, event.endsAt!)}',
            ),
            const SizedBox(height: 6),
            _IconLine(icon: Icons.place_rounded, text: event.location),
            if (event.description != null) ...[
              const SizedBox(height: 16),
              Text(event.description!, style: theme.textTheme.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final slate = GridsColors.of(context).slate;
    return Row(
      children: [
        Icon(icon, size: 16, color: slate),
        const SizedBox(width: 6),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
