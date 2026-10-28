import '../../features/auth/domain/session.dart';
import '../../features/auth/domain/user_role.dart';
import 'routes.dart';

/// Paths (and everything under them) that only some roles may open.
/// Anything not listed is open to every signed-in role.
const Map<String, Set<UserRole>> restrictedRoutes = {
  AppRoutes.towerManage: {UserRole.admin},
  AppRoutes.maintenanceConfig: {UserRole.admin},
  AppRoutes.defaulters: {UserRole.admin},
  AppRoutes.societyBills: {UserRole.admin},
  AppRoutes.payDues: {UserRole.owner, UserRole.tenant},
  AppRoutes.communityManage: {UserRole.admin},
  AppRoutes.tenantInfo: {UserRole.owner},
  AppRoutes.leaseInfo: {UserRole.tenant},
  AppRoutes.household: {UserRole.owner, UserRole.tenant},
  AppRoutes.paymentSettings: {UserRole.owner, UserRole.tenant},
};

bool canAccess(String location, UserRole role) {
  for (final MapEntry(key: prefix, value: roles) in restrictedRoutes.entries) {
    if (_isWithin(location, prefix) && !roles.contains(role)) return false;
  }
  return true;
}

/// go_router `redirect` logic, kept pure so it can be unit tested.
/// Returns the path to redirect to, or `null` to stay on [location].
String? resolveRedirect({
  required String location,
  required SessionState session,
}) {
  final onSplash = location == AppRoutes.splash;
  final onSignIn = _isWithin(location, AppRoutes.signIn);

  return switch (session) {
    SessionUnknown() || SessionRestoreFailed() => onSplash ? null : AppRoutes.splash,
    SignedOut() => onSignIn ? null : AppRoutes.signIn,
    SignedIn() when onSplash || onSignIn => AppRoutes.home,
    SignedIn(:final session) when !canAccess(location, session.role) => AppRoutes.home,
    SignedIn() => null,
  };
}

bool _isWithin(String location, String prefix) =>
    location == prefix || location.startsWith('$prefix/');
