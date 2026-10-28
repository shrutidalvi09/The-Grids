import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../data/profile_repository.dart';
import '../domain/profile_models.dart';

final preferencesProvider = FutureProvider.autoDispose<Preferences>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(profileRepositoryProvider).preferences();
});

final householdProvider = FutureProvider.autoDispose<List<HouseholdMember>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(profileRepositoryProvider).household();
});

final servicesProvider = FutureProvider.autoDispose<List<ServiceProvider>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(profileRepositoryProvider).services();
});

final societyInfoProvider = FutureProvider.autoDispose<SocietyInfo>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(profileRepositoryProvider).society();
});

/// Owners: their tenant. Tenants: their lease and owner. Null when there's none.
final tenancyProvider = FutureProvider.autoDispose<Tenancy?>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(profileRepositoryProvider).tenancy();
});
