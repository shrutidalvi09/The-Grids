import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../auth/data/auth_providers.dart';

/// An alert in the bell list: dues, notices, polls, visitors…
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.data = const {},
  });

  final String id;

  /// due | due_reminder | payment | notice | alert | poll | announcement | complaint | visitor | parcel | tenancy…
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  /// Ids for opening the related screen (pollId, communityId, paymentId…).
  final Map<String, String> data;

  AppNotification markedRead() =>
      AppNotification(id: id, type: type, title: title, body: body, read: true, createdAt: createdAt, data: data);
}

AppNotification notificationFromJson(Json json) => AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      read: json['read'] as bool,
      createdAt: parseTime(json['createdAt']),
      data: {for (final e in ((json['data'] as Json?) ?? const {}).entries) e.key: '${e.value}'},
    );

class NotificationsRepository {
  NotificationsRepository(this._dio);

  final Dio _dio;

  Future<List<AppNotification>> list({DateTime? before, int limit = 30}) => apiCall(() async => parseList(
        (await _dio.get<List<dynamic>>('/notifications', queryParameters: {
          'limit': limit,
          'before': ?before?.toUtc().toIso8601String(),
        })).data,
        notificationFromJson,
      ));

  Future<int> unreadCount() =>
      apiCall(() async => (await _dio.get<Json>('/notifications/unread-count')).data!['count'] as int);

  Future<void> markRead(String id) => apiCall(() => _dio.post<void>('/notifications/$id/read'));

  Future<void> markAllRead() => apiCall(() => _dio.post<void>('/notifications/read-all'));

  Future<void> registerDevice(String token, String platform) =>
      apiCall(() => _dio.put<void>('/devices', data: {'token': token, 'platform': platform}));

  Future<void> unregisterDevice(String token) => apiCall(() => _dio.delete<void>('/devices/${Uri.encodeComponent(token)}'));
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(authedDioProvider)),
);
