import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/facility_models.dart';

FacilityStatus facilityStatusFromJson(Json json) => switch (json['status']) {
      'open' => FacilityOpen(closesAt: parseTime(json['closesAt']), remaining: json['remaining'] as int?),
      'full' => FacilityFull(closesAt: parseTime(json['closesAt']), nextFreeAt: parseTimeOrNull(json['nextFreeAt'])),
      _ => FacilityClosed(opensAt: parseTime(json['opensAt'])),
    };

Facility facilityFromJson(Json json) => Facility(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      photoPath: json['photoUrl'] as String?,
      openTime: json['openTime'] as String,
      closeTime: json['closeTime'] as String,
      maxDurationMins: json['maxDurationMins'] as int,
      capacity: json['capacity'] as int?,
      status: facilityStatusFromJson(json['status'] as Json),
    );

Booking bookingFromJson(Json json) => Booking(
      id: json['id'] as String,
      facilityId: json['facilityId'] as String,
      facilityName: json['facilityName'] as String,
      startsAt: parseTime(json['startsAt']),
      endsAt: parseTime(json['endsAt']),
    );

Slot slotFromJson(Json json) => Slot(
      startsAt: parseTime(json['startsAt']),
      endsAt: parseTime(json['endsAt']),
      available: json['available'] as bool,
      mine: json['mine'] as bool,
      remaining: json['remaining'] as int?,
    );

String _isoDate(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

class FacilitiesRepository {
  FacilitiesRepository(this._dio);

  final Dio _dio;

  Future<List<Facility>> list() =>
      apiCall(() async => parseList((await _dio.get<List<dynamic>>('/facilities')).data, facilityFromJson));

  Future<List<Slot>> slots(String facilityId, DateTime day) => apiCall(() async {
        final response = await _dio.get<List<dynamic>>(
          '/facilities/$facilityId/slots',
          queryParameters: {'date': _isoDate(day)},
        );
        return parseList(response.data, slotFromJson);
      });

  Future<Booking> book(String facilityId, DateTime startsAt) => apiCall(() async {
        final response = await _dio.post<Json>(
          '/facilities/$facilityId/bookings',
          data: {'startsAt': startsAt.toUtc().toIso8601String()},
        );
        return bookingFromJson(response.data!);
      });

  Future<List<Booking>> myBookings() =>
      apiCall(() async => parseList((await _dio.get<List<dynamic>>('/bookings/mine')).data, bookingFromJson));

  Future<void> cancel(String bookingId) => apiCall(() => _dio.delete<void>('/bookings/$bookingId'));

  Future<void> create(FacilityInput input) => apiCall(() => _dio.post<void>('/facilities', data: input.toJson()));

  Future<void> update(String id, FacilityInput input) =>
      apiCall(() => _dio.patch<void>('/facilities/$id', data: input.toJson()));
}

final facilitiesRepositoryProvider = Provider<FacilitiesRepository>(
  (ref) => FacilitiesRepository(ref.watch(authedDioProvider)),
);
