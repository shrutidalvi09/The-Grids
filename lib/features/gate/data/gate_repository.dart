import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../auth/data/auth_providers.dart';
import '../../tower/data/tower_repository.dart';
import '../domain/gate_models.dart';

DailyHelp dailyHelpFromJson(Json json) => DailyHelp(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: json['kind'] as String,
      phone: json['phone'] as String?,
      passCode: json['passCode'] as String?,
      flatLabels: [for (final f in (json['flatLabels'] as List<dynamic>?) ?? const []) f as String],
      inside: json['inside'] as bool,
      lastIn: parseTimeOrNull(json['lastIn']),
      daysThisMonth: json['daysThisMonth'] as int,
    );

AttendanceMonth attendanceFromJson(Json json) => AttendanceMonth(
      month: json['month'] as String,
      days: json['days'] as int,
      entries: parseList(
        json['entries'],
        (e) => AttendanceEntry(inTime: parseTime(e['inTime']), outTime: parseTimeOrNull(e['outTime'])),
      ),
    );

PassCheck passCheckFromJson(Json json) {
  if (json['kind'] == 'visitor') return GuestPass(visitorFromJson(json['visitor'] as Json));
  final s = json['staff'] as Json;
  return StaffPass(
    id: s['id'] as String,
    name: s['name'] as String,
    kind: s['kind'] as String,
    phone: s['phone'] as String?,
    flatLabels: [for (final f in s['flatLabels'] as List<dynamic>) f as String],
    inside: s['inside'] as bool,
  );
}

SosAlert sosFromJson(Json json) {
  final raisedBy = json['raisedBy'] as Json?;
  return SosAlert(
    id: json['id'] as String,
    flatLabel: json['flatLabel'] as String?,
    raisedByName: raisedBy?['name'] as String?,
    raisedByPhone: raisedBy?['phone'] as String?,
    note: json['note'] as String?,
    status: json['status'] == 'ACTIVE' ? SosStatus.active : SosStatus.resolved,
    createdAt: parseTime(json['createdAt']),
    resolvedAt: parseTimeOrNull(json['resolvedAt']),
    resolvedBy: json['resolvedBy'] as String?,
  );
}

Vehicle vehicleFromJson(Json json) => Vehicle(
      id: json['id'] as String,
      number: json['number'] as String,
      type: VehicleType.fromApi(json['type'] as String),
      description: json['description'] as String?,
      parkingSlot: json['parkingSlot'] as String?,
      flatLabel: json['flatLabel'] as String?,
      contacts: [
        for (final c in (json['contacts'] as List<dynamic>?) ?? const [])
          (name: (c as Json)['name'] as String, phone: c['phone'] as String),
      ],
    );

/// Gate passes, daily help, SOS alerts and vehicles.
class GateRepository {
  GateRepository(this._dio);

  final Dio _dio;

  /// The gate: look up a guest pass or a daily-help code (typed or scanned).
  Future<PassCheck> verifyPass(String code) => apiCall(() async =>
      passCheckFromJson((await _dio.post<Json>('/visitors/verify-pass', data: {'code': code})).data!));

  Future<List<DailyHelp>> dailyHelp() =>
      apiCall(() async => parseList((await _dio.get<List<dynamic>>('/daily-help')).data, dailyHelpFromJson));

  Future<DailyHelp> addDailyHelp({required String name, required String kind, String? phone}) => apiCall(() async =>
      dailyHelpFromJson((await _dio.post<Json>('/daily-help', data: {'name': name, 'kind': kind, 'phone': phone})).data!));

  Future<void> removeDailyHelp(String id) => apiCall(() => _dio.delete<void>('/daily-help/$id'));

  /// The gate marks them in, or out if they're inside.
  Future<DailyHelp> markAttendance(String id) =>
      apiCall(() async => dailyHelpFromJson((await _dio.post<Json>('/daily-help/$id/attendance')).data!));

  Future<AttendanceMonth> attendance(String id, {String? month}) => apiCall(() async => attendanceFromJson(
        (await _dio.get<Json>('/daily-help/$id/attendance', queryParameters: {'month': ?month})).data!,
      ));

  Future<List<SosAlert>> sosAlerts() =>
      apiCall(() async => parseList((await _dio.get<List<dynamic>>('/sos')).data, sosFromJson));

  Future<SosAlert> raiseSos({String? note}) =>
      apiCall(() async => sosFromJson((await _dio.post<Json>('/sos', data: {'note': note})).data!));

  Future<SosAlert> resolveSos(String id) =>
      apiCall(() async => sosFromJson((await _dio.post<Json>('/sos/$id/resolve')).data!));

  Future<List<Vehicle>> vehicles() =>
      apiCall(() async => parseList((await _dio.get<List<dynamic>>('/vehicles')).data, vehicleFromJson));

  Future<Vehicle> addVehicle(VehicleInput input) =>
      apiCall(() async => vehicleFromJson((await _dio.post<Json>('/vehicles', data: input.toJson())).data!));

  Future<void> removeVehicle(String id) => apiCall(() => _dio.delete<void>('/vehicles/$id'));

  /// Admin: assign (or free, with null) a parking slot.
  Future<Vehicle> setParkingSlot(String id, String? slot) => apiCall(() async =>
      vehicleFromJson((await _dio.patch<Json>('/vehicles/$id', data: {'parkingSlot': slot})).data!));

  /// The gate: "whose car is this?"
  Future<List<Vehicle>> searchVehicles(String query) => apiCall(() async => parseList(
        (await _dio.get<List<dynamic>>('/vehicles/search', queryParameters: {'q': query})).data,
        vehicleFromJson,
      ));
}

final gateRepositoryProvider = Provider<GateRepository>((ref) => GateRepository(ref.watch(authedDioProvider)));
