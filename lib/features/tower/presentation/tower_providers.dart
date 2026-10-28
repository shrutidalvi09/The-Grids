import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../data/tower_repository.dart';
import '../domain/tower_models.dart';

/// `limit: 3` feeds the Tower tab previews; `null` the full "View all" pages.
final visitorsProvider = FutureProvider.autoDispose.family<List<Visitor>, int?>((ref, limit) {
  ref.watch(sessionKeyProvider);
  return ref.watch(towerRepositoryProvider).visitors(limit: limit);
});

final noticesProvider = FutureProvider.autoDispose.family<List<Notice>, int?>((ref, limit) {
  ref.watch(sessionKeyProvider);
  return ref.watch(towerRepositoryProvider).notices(limit: limit);
});

final neighboursProvider = FutureProvider.autoDispose<List<NeighbourTower>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(towerRepositoryProvider).neighbours();
});

typedef ComplaintsQuery = ({ComplaintStatus? status, int? limit});

final complaintsProvider = FutureProvider.autoDispose.family<List<Complaint>, ComplaintsQuery>((ref, query) {
  ref.watch(sessionKeyProvider);
  return ref.watch(towerRepositoryProvider).complaints(status: query.status, limit: query.limit);
});

final eventsProvider = FutureProvider.autoDispose<List<SocietyEvent>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(towerRepositoryProvider).events();
});
