import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../data/facilities_repository.dart';
import '../domain/facility_models.dart';

final facilitiesProvider = FutureProvider.autoDispose<List<Facility>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(facilitiesRepositoryProvider).list();
});

/// Slots for one facility on one calendar day (local date, time ignored).
final slotsProvider = FutureProvider.autoDispose.family<List<Slot>, (String, DateTime)>((ref, key) {
  ref.watch(sessionKeyProvider);
  final (facilityId, day) = key;
  return ref.watch(facilitiesRepositoryProvider).slots(facilityId, day);
});

final myBookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(facilitiesRepositoryProvider).myBookings();
});
