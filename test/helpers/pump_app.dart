import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_grids/app.dart';
import 'package:the_grids/core/config/app_config.dart';
import 'package:the_grids/core/storage/preferences.dart';
import 'package:the_grids/features/auth/data/auth_providers.dart';
import 'package:the_grids/features/auth/domain/session.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';
import 'package:the_grids/features/auth/presentation/session_controller.dart';
import 'package:the_grids/features/community/data/community_repository.dart';
import 'package:the_grids/features/facilities/data/facilities_repository.dart';
import 'package:the_grids/features/home/data/home_repository.dart';
import 'package:the_grids/features/maintenance/data/checkout_launcher.dart';
import 'package:the_grids/features/maintenance/data/money_repository.dart';
import 'package:the_grids/features/maintenance/data/receipt_files.dart';
import 'package:the_grids/features/tower/data/tower_repository.dart';

import 'community_fakes.dart';
import 'fakes.dart';
import 'feature_fakes.dart';
import 'money_fakes.dart';

/// Pumps the full app (router, theme, l10n) with a [FakeAuthRepository] and
/// returns its container so tests can drive providers directly.
Future<ProviderContainer> pumpGridsApp(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeHomeRepository? home,
  FakeTowerRepository? tower,
  FakeFacilitiesRepository? facilities,
  FakeMoneyRepository? money,
  FakeCheckoutLauncher? checkout,
  FakeReceiptFiles? receipts,
  FakeCommunityRepository? community,
  Flavor flavor = Flavor.prod,
  List<Override> overrides = const [],
  Map<String, Object> prefs = const {},
}) async {
  // A typical phone (411 × 914 dp) rather than the 800 × 600 test default.
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final sharedPreferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    // Fail fast in tests instead of retrying with backoff timers.
    retry: (_, _) => null,
    overrides: [
      appConfigProvider.overrideWithValue(AppConfig(flavor: flavor)),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      homeRepositoryProvider.overrideWithValue(home ?? FakeHomeRepository()),
      towerRepositoryProvider.overrideWithValue(tower ?? FakeTowerRepository()),
      facilitiesRepositoryProvider.overrideWithValue(facilities ?? FakeFacilitiesRepository()),
      moneyRepositoryProvider.overrideWithValue(money ?? FakeMoneyRepository()),
      checkoutLauncherProvider.overrideWithValue(checkout ?? FakeCheckoutLauncher()),
      receiptFilesProvider.overrideWithValue(receipts ?? FakeReceiptFiles()),
      communityRepositoryProvider.overrideWithValue(community ?? FakeCommunityRepository()),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TheGridsApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Puts a signed-in session in place, as a successful OTP login would.
Future<void> signInAs(WidgetTester tester, ProviderContainer container, UserRole role, {AppSession? session}) async {
  container.read(sessionControllerProvider.notifier).signedIn(session ?? fakeSession(role));
  await tester.pumpAndSettle();
}
