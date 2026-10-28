import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../data/money_repository.dart';
import '../domain/money_models.dart';

final myDuesProvider = FutureProvider.autoDispose<List<Due>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(moneyRepositoryProvider).myDues();
});

/// `limit: 3` for the tab preview; `null` for the full history.
final myPaymentsProvider = FutureProvider.autoDispose.family<List<Payment>, int?>((ref, limit) {
  ref.watch(sessionKeyProvider);
  return ref.watch(moneyRepositoryProvider).myPayments(limit: limit);
});

final paymentProvider = FutureProvider.autoDispose.family<Payment, String>((ref, id) {
  ref.watch(sessionKeyProvider);
  return ref.watch(moneyRepositoryProvider).payment(id);
});

final maintenanceConfigProvider = FutureProvider.autoDispose<MaintenanceConfig>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(moneyRepositoryProvider).config();
});

final maintenanceSummaryProvider = FutureProvider.autoDispose<MaintenanceSummary>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(moneyRepositoryProvider).summary();
});

final defaultersProvider = FutureProvider.autoDispose<List<Defaulter>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(moneyRepositoryProvider).defaulters();
});

final societyBillsProvider = FutureProvider.autoDispose.family<List<SocietyBill>, bool>((ref, paid) {
  ref.watch(sessionKeyProvider);
  return ref.watch(moneyRepositoryProvider).bills(paid: paid);
});

/// Everything that changes when a payment settles.
void invalidateAfterPayment(WidgetRef ref) {
  ref
    ..invalidate(myDuesProvider)
    ..invalidate(myPaymentsProvider)
    ..invalidate(paymentProvider);
}
