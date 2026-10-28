import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../data/home_repository.dart';
import '../domain/home_models.dart';

final homeProvider = FutureProvider.autoDispose<HomeData>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(homeRepositoryProvider).fetch();
});
