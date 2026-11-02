import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../data/gate_repository.dart';
import '../domain/gate_models.dart';

/// Residents: their flat's helpers. The gate and admins: everyone's.
final dailyHelpProvider = FutureProvider.autoDispose<List<DailyHelp>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(gateRepositoryProvider).dailyHelp();
});

/// One helper's visits in a month ("2026-10"; null = this month).
final attendanceProvider = FutureProvider.autoDispose.family<AttendanceMonth, (String, String?)>((ref, key) {
  ref.watch(sessionKeyProvider);
  return ref.watch(gateRepositoryProvider).attendance(key.$1, month: key.$2);
});

/// Residents: their flat's vehicles. Admins: everyone's.
final vehiclesProvider = FutureProvider.autoDispose<List<Vehicle>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(gateRepositoryProvider).vehicles();
});
