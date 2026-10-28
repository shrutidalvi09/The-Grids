import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/otp_page.dart';
import '../../features/auth/presentation/phone_page.dart';
import '../../features/auth/presentation/select_role_page.dart';
import '../../features/auth/presentation/select_society_page.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/auth/presentation/sign_in_flow.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/community/domain/community_models.dart';
import '../../features/community/presentation/announcement_form_page.dart';
import '../../features/community/presentation/community_detail_page.dart';
import '../../features/community/presentation/community_form_page.dart';
import '../../features/community/presentation/community_page.dart';
import '../../features/community/presentation/poll_form_page.dart';
import '../../features/community/presentation/polls_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/maintenance/domain/money_models.dart';
import '../../features/maintenance/presentation/defaulters_page.dart';
import '../../features/maintenance/presentation/maintenance_page.dart';
import '../../features/maintenance/presentation/pay_page.dart';
import '../../features/maintenance/presentation/payment_history_page.dart';
import '../../features/maintenance/presentation/receipt_page.dart';
import '../../features/maintenance/presentation/society_bills_page.dart';
import '../../features/maintenance/presentation/update_maintenance_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/profile/domain/profile_models.dart';
import '../../features/profile/presentation/account_pages.dart';
import '../../features/profile/presentation/help_about_pages.dart';
import '../../features/profile/presentation/household_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/profile/presentation/services_pages.dart';
import '../../features/profile/presentation/settings_pages.dart';
import '../../features/profile/presentation/tenancy_pages.dart';
import '../../features/facilities/domain/facility_models.dart';
import '../../features/facilities/presentation/facilities_page.dart';
import '../../features/facilities/presentation/facility_booking_page.dart';
import '../../features/facilities/presentation/facility_form_page.dart';
import '../../features/facilities/presentation/my_bookings_page.dart';
import '../../features/tower/domain/tower_models.dart';
import '../../features/tower/presentation/complaints_page.dart';
import '../../features/tower/presentation/events_page.dart';
import '../../features/tower/presentation/neighbours_page.dart';
import '../../features/tower/presentation/notice_form_page.dart';
import '../../features/tower/presentation/notices_page.dart';
import '../../features/tower/presentation/post_complaint_page.dart';
import '../../features/tower/presentation/tower_page.dart';
import '../../features/tower/presentation/visitors_page.dart';
import '../shell/animated_branch_container.dart';
import '../shell/app_shell.dart';
import '../shell/not_found_page.dart';
import 'route_guard.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the session changes (sign in / out / switch).
  final sessionChanges = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (_, _) => sessionChanges.value++);

  // Later sign-in steps need the earlier choices; restart if they're missing
  // (e.g. after the app was killed mid-flow).
  String? requireFlow(bool Function(SignInFlow flow) ready) =>
      ready(ref.read(signInFlowProvider)) ? null : AppRoutes.signIn;

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: sessionChanges,
    redirect: (context, state) => resolveRedirect(
      location: state.matchedLocation,
      session: ref.read(sessionControllerProvider),
    ),
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, _) => const SelectSocietyPage(),
        routes: [
          GoRoute(
            path: 'role',
            redirect: (_, _) => requireFlow((f) => f.society != null),
            builder: (_, _) => const SelectRolePage(),
          ),
          GoRoute(
            path: 'phone',
            redirect: (_, _) => requireFlow((f) => f.society != null && f.role != null),
            builder: (_, _) => const PhonePage(),
          ),
          GoRoute(
            path: 'otp',
            redirect: (_, _) => requireFlow((f) => f.challenge != null),
            builder: (_, _) => const OtpPage(),
          ),
        ],
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        // Keeps every tab's state like indexedStack, but cross-fades between them.
        navigatorContainerBuilder: (context, shell, children) =>
            AnimatedBranchContainer(currentIndex: shell.currentIndex, children: children),
        branches: [
          _tab(AppRoutes.home, const HomePage()),
          _tab(AppRoutes.tower, const TowerPage(), routes: _towerRoutes),
          _tab(AppRoutes.maintenance, const MaintenancePage(), routes: _maintenanceRoutes),
          _tab(AppRoutes.community, const CommunityPage(), routes: _communityRoutes),
          _tab(AppRoutes.profile, const ProfilePage(), routes: _profileRoutes),
        ],
      ),
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const NotificationsPage(),
      ),
      GoRoute(
        path: AppRoutes.events,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const EventsPage(),
      ),
      GoRoute(
        path: AppRoutes.facilityBookings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const MyBookingsPage(),
      ),
      GoRoute(
        path: AppRoutes.help,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const HelpPage(),
      ),
      GoRoute(
        path: AppRoutes.about,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const AboutPage(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    sessionChanges.dispose();
  });
  return router;
});

StatefulShellBranch _tab(String path, Widget page, {List<RouteBase> routes = const []}) => StatefulShellBranch(
      routes: [GoRoute(path: path, pageBuilder: (_, _) => NoTransitionPage(child: page), routes: routes)],
    );

/// Pages pushed inside the Tower tab (paths relative to /tower).
final _towerRoutes = <RouteBase>[
  GoRoute(path: 'visitors', builder: (_, _) => const VisitorsPage()),
  GoRoute(path: 'notices', builder: (_, _) => const NoticesPage()),
  GoRoute(path: 'neighbours', builder: (_, _) => const NeighboursPage()),
  GoRoute(
    path: 'facilities',
    builder: (_, _) => const FacilitiesPage(),
    routes: [
      GoRoute(
        path: ':id/book',
        builder: (_, state) => FacilityBookingPage(facilityId: state.pathParameters['id']!),
      ),
    ],
  ),
  GoRoute(
    path: 'complaints',
    builder: (_, _) => const ComplaintsPage(),
    routes: [GoRoute(path: 'new', builder: (_, _) => const PostComplaintPage())],
  ),
  // Admin only (see restrictedRoutes). Editing passes the item as `extra`.
  GoRoute(path: 'manage/notice', builder: (_, state) => NoticeFormPage(notice: state.extra as Notice?)),
  GoRoute(path: 'manage/facility', builder: (_, state) => FacilityFormPage(facility: state.extra as Facility?)),
];

/// Pages pushed inside the Maintenance / Rent tab (paths relative to /maintenance).
final _maintenanceRoutes = <RouteBase>[
  GoRoute(
    path: 'pay/:dueId',
    builder: (_, state) => PayPage(dueId: state.pathParameters['dueId']!, due: state.extra as Due?),
  ),
  GoRoute(
    path: 'receipts/:paymentId',
    builder: (_, state) => ReceiptPage(paymentId: state.pathParameters['paymentId']!),
  ),
  GoRoute(path: 'history', builder: (_, _) => const PaymentHistoryPage()),
  // Admin only (see restrictedRoutes).
  GoRoute(path: 'configure', builder: (_, _) => const UpdateMaintenancePage()),
  GoRoute(path: 'defaulters', builder: (_, _) => const DefaultersPage()),
  GoRoute(path: 'bills', builder: (_, _) => const SocietyBillsPage()),
];

/// Pages pushed inside the Community tab (paths relative to /community).
final _communityRoutes = <RouteBase>[
  GoRoute(path: 'polls', builder: (_, _) => const PollsPage()),
  GoRoute(
    path: 'clubs/:id',
    builder: (_, state) => CommunityDetailPage(communityId: state.pathParameters['id']!),
  ),
  // Admin only (see restrictedRoutes).
  GoRoute(path: 'manage/poll', builder: (_, _) => const PollFormPage()),
  GoRoute(
    path: 'manage/club',
    builder: (_, state) => CommunityFormPage(communityId: state.uri.queryParameters['id']),
  ),
  GoRoute(
    path: 'manage/announcement',
    redirect: (_, state) => state.uri.queryParameters['club'] == null ? AppRoutes.community : null,
    builder: (_, state) => AnnouncementFormPage(
      communityId: state.uri.queryParameters['club']!,
      announcement: state.extra as Announcement?,
    ),
  ),
];

/// Pages pushed inside the Profile tab (paths relative to /profile).
final _profileRoutes = <RouteBase>[
  GoRoute(path: 'household', builder: (_, _) => const HouseholdPage()),
  GoRoute(
    path: 'services',
    builder: (_, _) => const ServicesPage(),
    routes: [
      GoRoute(
        path: ':category',
        builder: (_, state) => ServiceCategoryPage(category: state.pathParameters['category']!),
      ),
    ],
  ),
  GoRoute(path: 'payment-settings', builder: (_, _) => const PaymentSettingsPage()),
  GoRoute(path: 'language', builder: (_, _) => const LanguageSettingsPage()),
  GoRoute(path: 'notifications', builder: (_, _) => const NotificationSettingsPage()),
  GoRoute(path: 'theme', builder: (_, _) => const ThemeSettingsPage()),
  GoRoute(path: 'account', builder: (_, _) => const AccountPage()),
  GoRoute(path: 'edit', builder: (_, _) => const EditProfilePage()),
  GoRoute(path: 'lease', builder: (_, _) => const LeaseInfoPage()),
  // Owners only (see restrictedRoutes). Editing passes the tenancy as `extra`.
  GoRoute(
    path: 'tenant-info',
    builder: (_, _) => const TenantInfoPage(),
    routes: [GoRoute(path: 'edit', builder: (_, state) => TenantFormPage(tenancy: state.extra as Tenancy?))],
  ),
];
