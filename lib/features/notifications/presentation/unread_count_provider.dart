import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../data/notifications_repository.dart';

/// Unread notifications for the bell badge. Refreshes every minute while the
/// app is open, when it comes back to the foreground, and when a push arrives
/// (see `PushService`). Errors show as 0 rather than breaking the app bar.
class UnreadCount extends Notifier<int> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  int build() {
    final signedIn = ref.watch(sessionKeyProvider) != null;
    // Runs before every rebuild (sign-in/out, role switch) and on disposal.
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
      _timer = null;
      _lifecycle = null;
    });
    if (!signedIn) return 0;
    final every = ref.watch(unreadPollIntervalProvider);
    if (every != null) _timer = Timer.periodic(every, (_) => refresh());
    _lifecycle = AppLifecycleListener(onResume: refresh);
    unawaited(Future.microtask(refresh));
    return 0;
  }

  Future<void> refresh() async {
    try {
      final count = await ref.read(notificationsRepositoryProvider).unreadCount();
      if (ref.mounted) state = count;
    } catch (_) {
      // Keep the last known count; the list screen shows real errors.
    }
  }

  /// Optimistic updates from the list screen.
  void set(int count) => state = count < 0 ? 0 : count;
}

/// How often the badge refreshes; tests turn polling off with `null`.
final unreadPollIntervalProvider = Provider<Duration?>((ref) => const Duration(minutes: 1));

final unreadNotificationCountProvider = NotifierProvider<UnreadCount, int>(UnreadCount.new);
