import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../auth/data/auth_providers.dart';
import '../../facilities/data/facilities_repository.dart';
import '../../tower/data/tower_repository.dart';
import '../domain/home_models.dart';

ChecklistItem? checklistItemFromJson(Json json) => switch (json['kind']) {
      'help' => HelpVisit(
          name: json['name'] as String,
          purpose: json['purpose'] as String?,
          checkedIn: json['status'] == 'checked_in',
          at: parseTimeOrNull(json['at']),
        ),
      'parcel' => ParcelAtGate(from: json['from'] as String, at: parseTimeOrNull(json['at'])),
      'bill' => BillDue(
          isRent: json['dueType'] == 'RENT',
          amountPaise: json['amountPaise'] as int,
          dueDate: parseTime(json['dueDate']),
          overdue: json['status'] == 'overdue',
        ),
      'bills_clear' => const BillsClear(),
      _ => null, // newer server, older app: skip what we can't show
    };

HomeData homeFromJson(Json json) {
  final alert = json['alert'] as Json?;
  final weather = json['weather'] as Json?;
  final stats = json['stats'] as Json?;
  return HomeData(
    alert: alert == null
        ? null
        : HomeAlert(id: alert['id'] as String, title: alert['title'] as String, body: alert['body'] as String),
    weather: weather == null
        ? null
        : Weather(temperatureC: weather['temperatureC'] as int, code: weather['code'] as int),
    upcomingEvents: parseList(json['upcomingEvents'], eventFromJson),
    stats: stats == null
        ? null
        : SocietyStats(
            towers: stats['towers'] as int,
            flats: stats['flats'] as int,
            owners: stats['owners'] as int,
            tenants: stats['tenants'] as int,
            pendingDues: stats['pendingDues'] as int,
          ),
    recentComplaints: json['recentComplaints'] == null
        ? const []
        : parseList(json['recentComplaints'], complaintFromJson),
    checklist: json['checklist'] == null
        ? const []
        : parseList(json['checklist'], checklistItemFromJson).nonNulls.toList(),
    myBookingsToday: json['myBookingsToday'] == null
        ? const []
        : parseList(json['myBookingsToday'], bookingFromJson),
    facilities: json['facilities'] == null ? const [] : parseList(json['facilities'], facilityFromJson),
  );
}

class HomeRepository {
  HomeRepository(this._dio);

  final Dio _dio;

  Future<HomeData> fetch() => apiCall(() async => homeFromJson((await _dio.get<Json>('/home')).data!));
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) => HomeRepository(ref.watch(authedDioProvider)));
