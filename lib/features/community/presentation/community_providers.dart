import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';

/// Open polls first, then closed ones.
final pollsProvider = FutureProvider.autoDispose<List<Poll>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(communityRepositoryProvider).polls();
});

final communitiesProvider = FutureProvider.autoDispose<List<Community>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(communityRepositoryProvider).communities();
});

final communityProvider = FutureProvider.autoDispose.family<CommunityDetail, String>((ref, id) {
  ref.watch(sessionKeyProvider);
  return ref.watch(communityRepositoryProvider).community(id);
});

/// Admin: residents to pick from for a club.
final communityCandidatesProvider = FutureProvider.autoDispose<List<CommunityMember>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(communityRepositoryProvider).candidates();
});
