import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/uploads_api.dart';
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

/// Admins: every complaint with a status filter and status changes.
/// Residents: their flat's complaints and "Post Complaint".
class ComplaintsPage extends ConsumerStatefulWidget {
  const ComplaintsPage({super.key});

  @override
  ConsumerState<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends ConsumerState<ComplaintsPage> {
  ComplaintStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAdmin = ref.watch(currentSessionProvider)?.role == UserRole.admin;
    final query = (status: _filter, limit: null);

    return GridsPage(
      title: isAdmin ? l10n.complaintsTitle : l10n.myComplaintsTitle,
      showMenu: false,
      floatingActionButton: isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.postComplaint),
              icon: const Icon(Icons.add_comment_rounded),
              label: Text(l10n.postComplaint),
            ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Row(
              children: [
                for (final status in [null, ...ComplaintStatus.values])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(status == null ? l10n.filterAll : complaintStatusLabel(l10n, status)),
                      selected: _filter == status,
                      onSelected: (_) => setState(() => _filter = status),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(complaintsProvider(query).future),
              child: AsyncValueView(
                value: ref.watch(complaintsProvider(query)),
                onRetry: () => ref.invalidate(complaintsProvider(query)),
                isEmpty: (c) => c.isEmpty,
                empty: EmptyState(icon: Icons.task_alt_rounded, title: l10n.noComplaints),
                data: (complaints) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
                  itemCount: complaints.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => Card(
                    clipBehavior: Clip.antiAlias,
                    child: ComplaintTile(
                      complaint: complaints[i],
                      showFlat: isAdmin,
                      onTap: () => _showDetails(complaints[i], isAdmin),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetails(Complaint complaint, bool isAdmin) {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(towerRepositoryProvider);

    return showModalBottomSheet<void>(
      useRootNavigator: true, // above the bottom nav bar
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) {
        final theme = Theme.of(sheet);
        final slate = GridsColors.of(sheet).slate;
        final photoUrl = ref.read(photoUrlProvider(complaint.photoPath));
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(categoryIcon(complaint.category), color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  if (complaint.category != null)
                    Expanded(child: Text(categoryLabel(l10n, complaint.category!), style: TextStyle(color: slate))),
                  complaintStatusChip(l10n, complaint.status),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(complaint.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  l10n.raisedByOn(complaint.raisedBy, formatDate(sheet, complaint.createdAt)),
                  ?complaint.flatLabel,
                ].join(' · '),
                style: TextStyle(color: slate),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(complaint.description, style: theme.textTheme.bodyLarge),
              if (photoUrl != null) ...[
                const SizedBox(height: AppSpacing.lg),
                ClipRRect(
                  borderRadius: const BorderRadius.all(AppRadii.md),
                  child: Image.network(photoUrl, height: 200, width: double.infinity, fit: BoxFit.cover),
                ),
              ],
              if (isAdmin) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(l10n.changeStatus, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<ComplaintStatus>(
                  showSelectedIcon: false,
                  segments: [
                    for (final s in ComplaintStatus.values)
                      ButtonSegment(value: s, label: Text(complaintStatusLabel(l10n, s))),
                  ],
                  selected: {complaint.status},
                  onSelectionChanged: (selection) async {
                    Navigator.of(sheet).pop();
                    try {
                      await repo.updateComplaintStatus(complaint.id, selection.single);
                      ref
                        ..invalidate(complaintsProvider)
                        ..invalidate(homeProvider);
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.complaintStatusChanged(complaintStatusLabel(l10n, selection.single)))),
                      );
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
