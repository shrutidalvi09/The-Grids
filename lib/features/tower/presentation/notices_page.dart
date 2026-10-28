import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/session_controller.dart';
import '../../home/presentation/home_providers.dart';
import '../data/tower_repository.dart';
import '../domain/tower_models.dart';
import 'tower_labels.dart';
import 'tower_providers.dart';
import 'widgets/tower_tiles.dart';

class NoticesPage extends ConsumerWidget {
  const NoticesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAdmin = ref.watch(currentSessionProvider)?.role == UserRole.admin;
    return GridsPage(
      title: l10n.noticesTitle,
      showMenu: false,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.noticeForm),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addNotice),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(noticesProvider(null).future),
        child: AsyncValueView(
          value: ref.watch(noticesProvider(null)),
          onRetry: () => ref.invalidate(noticesProvider(null)),
          isEmpty: (n) => n.isEmpty,
          empty: EmptyState(icon: Icons.campaign_rounded, title: l10n.noNotices),
          data: (notices) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
            itemCount: notices.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => Card(
              clipBehavior: Clip.antiAlias,
              child: NoticeTile(notice: notices[i], onTap: () => showNoticeDetails(context, ref, notices[i])),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full notice in a sheet; admins can edit or delete from here.
Future<void> showNoticeDetails(BuildContext context, WidgetRef ref, Notice notice) {
  final l10n = context.l10n;
  final isAdmin = ref.read(currentSessionProvider)?.role == UserRole.admin;
  final repo = ref.read(towerRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);

  return showModalBottomSheet<void>(
    useRootNavigator: true, // above the bottom nav bar
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      final slate = GridsColors.of(sheet).slate;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(categoryIcon(notice.category), color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                if (notice.category != null)
                  Text(categoryLabel(l10n, notice.category!), style: TextStyle(color: slate)),
                if (notice.isAlert) ...[
                  const SizedBox(width: AppSpacing.sm),
                  StatusChip(label: l10n.alertLabel, tone: StatusTone.danger),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(notice.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                if (notice.scheduledAt != null)
                  '${formatDate(sheet, notice.scheduledAt!)} · ${formatTime(sheet, notice.scheduledAt!)}'
                else
                  l10n.postedOn(formatDate(sheet, notice.createdAt)),
                ?notice.towerName,
              ].join(' · '),
              style: TextStyle(color: slate),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(notice.body, style: theme.textTheme.bodyLarge),
            if (isAdmin) ...[
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheet).pop();
                      router.go(AppRoutes.noticeForm, extra: notice);
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: Text(l10n.edit),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: sheet,
                        builder: (d) => AlertDialog(
                          title: Text(l10n.deleteNoticeConfirm),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(l10n.cancel)),
                            TextButton(onPressed: () => Navigator.of(d).pop(true), child: Text(l10n.delete)),
                          ],
                        ),
                      );
                      if (confirmed != true || !sheet.mounted) return;
                      Navigator.of(sheet).pop();
                      try {
                        await repo.deleteNotice(notice.id);
                        ref
                          ..invalidate(noticesProvider)
                          ..invalidate(homeProvider);
                        messenger.showSnackBar(SnackBar(content: Text(l10n.noticeDeleted)));
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(l10n.delete),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}
