import '../../../core/router/routes.dart';
import '../../auth/domain/user_role.dart';

/// The screen a notification (in the list or a tapped push) should open.
String? routeForNotification(String type, Map<String, String> data, UserRole role) => switch (type) {
      'due' || 'due_reminder' => AppRoutes.maintenance,
      'payment' => data['paymentId'] == null ? AppRoutes.paymentHistory : AppRoutes.receipt(data['paymentId']!),
      'notice' || 'alert' => AppRoutes.towerNotices,
      'poll' => AppRoutes.communityPolls,
      'announcement' => data['communityId'] == null ? AppRoutes.community : AppRoutes.communityClub(data['communityId']!),
      'complaint' => AppRoutes.towerComplaints,
      'visitor' || 'parcel' || 'visitor_approval' || 'visitor_decision' => AppRoutes.towerVisitors,
      'staff' => role.isGate ? AppRoutes.gateStaff : AppRoutes.dailyHelp,
      'sos' => AppRoutes.home,
      'tenancy' => role == UserRole.owner ? AppRoutes.tenantInfo : AppRoutes.leaseInfo,
      _ => null,
    };
