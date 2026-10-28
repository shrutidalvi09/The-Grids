import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/uploads_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/community_models.dart';

/// The club's photo, or its initial on a tinted square.
class CommunityPhoto extends ConsumerWidget {
  const CommunityPhoto({super.key, required this.community, this.size = 56});

  final Community community;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(photoUrlProvider(community.photoPath));
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: const BorderRadius.all(AppRadii.md),
      child: SizedBox.square(
        dimension: size,
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                semanticLabel: community.name,
                errorBuilder: (_, _, _) => _initial(scheme),
              )
            : _initial(scheme),
      ),
    );
  }

  Widget _initial(ColorScheme scheme) => ColoredBox(
        color: scheme.primaryContainer,
        child: Center(
          child: Text(
            initialsOf(community.name),
            style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: size * 0.36),
          ),
        ),
      );
}

/// A club on the Community tab with its latest announcement.
class CommunityCard extends StatelessWidget {
  const CommunityCard({super.key, required this.community, required this.onTap});

  final Community community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final grids = GridsColors.of(context);
    final latest = community.latestAnnouncement;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  CommunityPhoto(community: community),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          community.name,
                          style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
                        ),
                        Text(l10n.membersCount(community.memberCount), style: TextStyle(color: grids.slate)),
                      ],
                    ),
                  ),
                  if (community.isMember) StatusChip(label: l10n.joined, tone: StatusTone.success),
                  // The whole card opens the club; the chevron says so.
                  Icon(Icons.chevron_right_rounded, color: grids.slate),
                ],
              ),
            ),
            if (latest != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.campaign_rounded, size: 32),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(l10n.announcementsTitle, style: theme.textTheme.titleMedium)),
                              Text(formatDayMonth(context, latest.createdAt), style: TextStyle(color: grids.slate)),
                            ],
                          ),
                          Text(
                            '${latest.authorName}: ${latest.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: grids.slate),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Date, time and venue lines for an announcement that is an event.
class AnnouncementEventInfo extends StatelessWidget {
  const AnnouncementEventInfo({super.key, required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    if (a.eventAt == null && a.venue == null) return const SizedBox.shrink();
    final grids = GridsColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget line(IconData icon, String text, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Row(
            children: [
              Icon(icon, size: 18, color: grids.slate),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text, style: TextStyle(color: color))),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (a.eventAt != null) ...[
          line(Icons.event_rounded, formatDate(context, a.eventAt!), color: scheme.secondary),
          line(
            Icons.schedule_rounded,
            a.endsAt == null ? formatTime(context, a.eventAt!) : formatTimeRange(context, a.eventAt!, a.endsAt!),
          ),
        ],
        if (a.venue != null) line(Icons.place_rounded, a.venue!),
      ],
    );
  }
}
