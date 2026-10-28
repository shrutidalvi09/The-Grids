import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/router/route_guard.dart';
import 'package:the_grids/core/router/routes.dart';
import 'package:the_grids/features/auth/domain/session.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';

import '../../helpers/fakes.dart';

SignedIn _as(UserRole role) => SignedIn(fakeSession(role));

void main() {
  group('resolveRedirect', () {
    test('while restoring (or after a failed restore), everything goes to splash', () {
      for (final session in const [SessionUnknown(), SessionRestoreFailed()]) {
        expect(resolveRedirect(location: AppRoutes.home, session: session), AppRoutes.splash);
        expect(resolveRedirect(location: AppRoutes.signIn, session: session), AppRoutes.splash);
        expect(resolveRedirect(location: AppRoutes.splash, session: session), isNull);
      }
    });

    test('signed-out users are sent to sign-in and may move through its steps', () {
      const session = SignedOut();
      expect(resolveRedirect(location: AppRoutes.home, session: session), AppRoutes.signIn);
      expect(resolveRedirect(location: AppRoutes.splash, session: session), AppRoutes.signIn);
      for (final step in [AppRoutes.signIn, AppRoutes.signInRole, AppRoutes.signInPhone, AppRoutes.signInOtp]) {
        expect(resolveRedirect(location: step, session: session), isNull, reason: step);
      }
    });

    test('signed-in users leave splash and sign-in for home', () {
      final session = _as(UserRole.owner);
      expect(resolveRedirect(location: AppRoutes.splash, session: session), AppRoutes.home);
      expect(resolveRedirect(location: AppRoutes.signInOtp, session: session), AppRoutes.home);
    });

    test('every role can open the five tabs', () {
      for (final role in UserRole.values) {
        for (final tab in [
          AppRoutes.home,
          AppRoutes.tower,
          AppRoutes.maintenance,
          AppRoutes.community,
          AppRoutes.profile,
        ]) {
          expect(resolveRedirect(location: tab, session: _as(role)), isNull, reason: '$role → $tab');
        }
      }
    });

    test('maintenance configuration is admin-only, including sub-pages', () {
      const path = AppRoutes.maintenanceConfig;
      expect(resolveRedirect(location: path, session: _as(UserRole.admin)), isNull);
      expect(resolveRedirect(location: '$path/items', session: _as(UserRole.admin)), isNull);
      expect(resolveRedirect(location: path, session: _as(UserRole.owner)), AppRoutes.home);
      expect(resolveRedirect(location: '$path/items', session: _as(UserRole.tenant)), AppRoutes.home);
    });

    test('defaulters and society bills are admin-only; paying is for residents', () {
      for (final path in [AppRoutes.defaulters, AppRoutes.societyBills]) {
        expect(resolveRedirect(location: path, session: _as(UserRole.admin)), isNull, reason: path);
        expect(resolveRedirect(location: path, session: _as(UserRole.owner)), AppRoutes.home, reason: path);
        expect(resolveRedirect(location: path, session: _as(UserRole.tenant)), AppRoutes.home, reason: path);
      }
      final pay = AppRoutes.payDue('d1');
      expect(resolveRedirect(location: pay, session: _as(UserRole.owner)), isNull);
      expect(resolveRedirect(location: pay, session: _as(UserRole.tenant)), isNull);
      expect(resolveRedirect(location: pay, session: _as(UserRole.admin)), AppRoutes.home);
      // Receipts and history are scoped server-side, so every role may open them.
      for (final role in UserRole.values) {
        expect(resolveRedirect(location: AppRoutes.receipt('p1'), session: _as(role)), isNull);
        expect(resolveRedirect(location: AppRoutes.paymentHistory, session: _as(role)), isNull);
      }
    });

    test('community forms are admin-only; clubs and polls are open to all', () {
      for (final path in [AppRoutes.pollForm, AppRoutes.communityForm, '/community/manage/announcement']) {
        expect(resolveRedirect(location: path, session: _as(UserRole.admin)), isNull, reason: path);
        expect(resolveRedirect(location: path, session: _as(UserRole.owner)), AppRoutes.home, reason: path);
        expect(resolveRedirect(location: path, session: _as(UserRole.tenant)), AppRoutes.home, reason: path);
      }
      for (final role in UserRole.values) {
        expect(resolveRedirect(location: AppRoutes.communityPolls, session: _as(role)), isNull);
        expect(resolveRedirect(location: AppRoutes.communityClub('c1'), session: _as(role)), isNull);
      }
    });

    test('tenant info is owner-only', () {
      const path = AppRoutes.tenantInfo;
      expect(resolveRedirect(location: path, session: _as(UserRole.owner)), isNull);
      expect(resolveRedirect(location: path, session: _as(UserRole.tenant)), AppRoutes.home);
      expect(resolveRedirect(location: path, session: _as(UserRole.admin)), AppRoutes.home);
    });

    test('prefix matching respects path segments', () {
      // "/profile/tenant-information" is not under "/profile/tenant-info".
      expect(canAccess('/profile/tenant-information', UserRole.tenant), isTrue);
    });
  });
}
