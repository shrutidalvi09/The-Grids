import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/l10n/l10n.dart';
import 'core/l10n/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/auth/presentation/session_controller.dart';
import 'features/notifications/data/push_service.dart';
import 'features/notifications/presentation/notification_routes.dart';

class TheGridsApp extends ConsumerStatefulWidget {
  const TheGridsApp({super.key});

  @override
  ConsumerState<TheGridsApp> createState() => _TheGridsAppState();
}

class _TheGridsAppState extends ConsumerState<TheGridsApp> {
  StreamSubscription<Map<String, String>>? _opened;

  @override
  void initState() {
    super.initState();
    // A tapped push opens the related screen (once signed in).
    _opened = ref.read(pushServiceProvider).opened.listen((data) {
      final session = ref.read(currentSessionProvider);
      final route = session == null ? null : routeForNotification(data['type'] ?? '', data, session.role);
      if (route != null) ref.read(routerProvider).go(route);
    });
  }

  @override
  void dispose() {
    _opened?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Register this phone for push whenever someone signs in or switches role.
    ref.listen(sessionKeyProvider, (previous, next) {
      if (next != null && next != previous) unawaited(ref.read(pushServiceProvider).start());
    });

    final config = ref.watch(appConfigProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => config.isDev
          ? Banner(
              message: 'DEV',
              location: BannerLocation.topEnd,
              child: child!,
            )
          : child!,
    );
  }
}
