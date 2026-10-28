import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../presentation/unread_count_provider.dart';
import 'notifications_repository.dart';

/// Push notifications for the signed-in person.
abstract interface class PushService {
  /// After sign-in: ask permission, register this phone with the server.
  Future<void> start();

  /// Before sign-out: stop pushes for that person on this phone.
  Future<void> stop();

  /// The `data` of pushes the user tapped (to open the related screen).
  Stream<Map<String, String>> get opened;
}

/// No Firebase project configured: notifications stay in-app only.
class NoPushService implements PushService {
  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<Map<String, String>> get opened => const Stream.empty();
}

/// Firebase Cloud Messaging.
class FcmPushService implements PushService {
  FcmPushService(this._ref, this._options);

  final Ref _ref;
  final FirebaseOptions _options;
  final _opened = StreamController<Map<String, String>>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  String? _token;

  @override
  Stream<Map<String, String>> get opened => _opened.stream;

  NotificationsRepository get _repo => _ref.read(notificationsRepositoryProvider);

  @override
  Future<void> start() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: _options);
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;

      // FCM registration tokens are what the server's Admin SDK multicast send
      // targets; the newer FID "direct send" (register/onRegistered) isn't
      // wired up server-side yet.
      // ignore: deprecated_member_use
      _token = await messaging.getToken();
      if (_token != null) await _repo.registerDevice(_token!, Platform.isIOS ? 'ios' : 'android');

      await _cancelSubscriptions();
      _subscriptions
        // ignore: deprecated_member_use
        ..add(messaging.onTokenRefresh.listen((token) {
          _token = token;
          unawaited(_repo.registerDevice(token, Platform.isIOS ? 'ios' : 'android').catchError((_) {}));
        }))
        // In the foreground the OS doesn't show it; just update the bell badge.
        ..add(FirebaseMessaging.onMessage.listen((_) => _ref.read(unreadNotificationCountProvider.notifier).refresh()))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen((m) => _opened.add(_stringData(m))));
      final initial = await messaging.getInitialMessage();
      if (initial != null) _opened.add(_stringData(initial));
    } catch (e) {
      // Push is a nice-to-have; never block sign-in on it.
      debugPrint('Push setup failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    await _cancelSubscriptions();
    final token = _token;
    _token = null;
    if (token == null) return;
    try {
      await _repo.unregisterDevice(token);
    } catch (_) {
      // Offline sign-out: the server drops dead tokens on the next push.
    }
  }

  Future<void> _cancelSubscriptions() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
  }

  static Map<String, String> _stringData(RemoteMessage m) => {for (final e in m.data.entries) e.key: '${e.value}'};
}

final pushServiceProvider = Provider<PushService>((ref) {
  final options = ref.watch(appConfigProvider).firebaseOptions;
  return options == null ? NoPushService() : FcmPushService(ref, options);
});
