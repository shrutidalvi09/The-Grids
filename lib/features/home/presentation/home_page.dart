import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/session_controller.dart';
import '../../gate/presentation/gate_dashboard.dart';
import '../../gate/presentation/sos_widgets.dart';
import 'home_providers.dart';
import 'widgets/home_header.dart';
import 'widgets/home_sections.dart';

/// Admins see society statistics and complaints; owners and tenants see their
/// daily checklist and facility bookings.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(currentSessionProvider);
    final home = ref.watch(homeProvider);
    if (session == null) return const SizedBox.shrink();

    final isGuard = session.role == UserRole.guard;
    return GridsPage(
      title: isGuard ? l10n.navGate : l10n.navHome,
      // Guards respond to alerts; everyone else can raise one.
      actions: [if (!isGuard) const SosButton()],
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(homeProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
          children: [
            GreetingHeader(session: session, weather: home.value?.weather),
            const SizedBox(height: AppSpacing.lg),
            ...home.when(
              skipLoadingOnRefresh: true,
              loading: () => const [
                Padding(padding: EdgeInsets.all(AppSpacing.xxl), child: Center(child: CircularProgressIndicator())),
              ],
              error: (error, _) => [
                EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: describeError(l10n, error),
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(homeProvider),
                ),
              ],
              data: (data) => [
                if (data.activeSos.isNotEmpty) SosBanners(alerts: data.activeSos),
                if (data.alert != null) AlertBanner(alert: data.alert!),
                if (isGuard) ...[
                  if (data.alert != null) const SizedBox(height: AppSpacing.md),
                  GateDashboard(summary: data.gate),
                ] else if (session.role == UserRole.admin) ...[
                  if (data.stats != null) StatsGrid(stats: data.stats!),
                  RecentComplaints(complaints: data.recentComplaints),
                  UpcomingEvents(events: data.upcomingEvents),
                ] else ...[
                  UpcomingEvents(events: data.upcomingEvents),
                  DailyChecklist(items: data.checklist),
                  FacilitySummary(bookings: data.myBookingsToday, facilities: data.facilities),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
