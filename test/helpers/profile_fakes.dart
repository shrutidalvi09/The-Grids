import 'package:dio/dio.dart';
import 'package:the_grids/core/network/api_exception.dart';
import 'package:the_grids/features/auth/domain/session.dart';
import 'package:the_grids/features/maintenance/domain/money_models.dart';
import 'package:the_grids/features/notifications/data/notifications_repository.dart';
import 'package:the_grids/features/profile/data/profile_repository.dart';
import 'package:the_grids/features/profile/domain/profile_models.dart';

final _unused = Dio();
final _now = DateTime.now();

Tenancy sampleTenancy({TenantStatus status = TenantStatus.active}) => Tenancy(
      id: 't1',
      flatLabel: 'Tower-C, 502',
      monthlyRentPaise: 1500000,
      depositPaise: 6000000,
      rentDueDay: 5,
      rentBreakdown: const [
        BreakdownItem(label: 'Rent', amountPaise: 1400000),
        BreakdownItem(label: 'Parking', amountPaise: 100000),
      ],
      startDate: DateTime(_now.year, 1, 1),
      endDate: DateTime(_now.year + 1, 1, 1),
      tenant: const Contact(name: 'Shreyas Kulkarni', phone: '+919100000001'),
      tenantStatus: status,
      owner: const Contact(name: 'Shruti Chetan Dalvi', phone: '+919000000001'),
    );

/// In-memory profile data. Edits are recorded for assertions.
class FakeProfileRepository extends ProfileRepository {
  FakeProfileRepository() : super(_unused);

  Preferences prefs = Preferences(notifications: {for (final p in NotificationPref.values) p: true});
  List<HouseholdMember> members = [
    const HouseholdMember(id: 'h1', name: 'Chetan Dalvi', relation: 'Father', phone: '+919811111111'),
  ];
  List<ServiceProvider> serviceList = const [
    ServiceProvider(id: 's1', category: 'Maid', name: 'Akshara More', phone: '+919000010001', location: 'Ambivali', rating: 4.5),
    ServiceProvider(id: 's2', category: 'Maid', name: 'Pooja Sawant', phone: '+919000010002'),
    ServiceProvider(id: 's3', category: 'Plumber', name: 'Raju Plumbing Works', phone: '+919000010015'),
  ];
  Tenancy? currentTenancy;
  Object? deleteError;

  AppSession? session;
  final profileUpdates = <Map<String, Object?>>[];
  final savedPrefs = <Preferences>[];
  final addedTenancies = <TenancyInput>[];
  final endedTenancies = <String>[];
  bool deleted = false;

  @override
  Future<AppSession> updateProfile({
    String? name,
    String? email,
    bool clearEmail = false,
    String? photoPath,
    bool clearPhoto = false,
    String? language,
    String? theme,
  }) async {
    profileUpdates.add({'name': name, 'email': clearEmail ? null : email, 'language': language, 'theme': theme});
    final s = session!;
    return AppSession(
      userId: s.userId,
      displayName: name ?? s.displayName,
      phone: s.phone,
      email: clearEmail ? null : (email ?? s.email),
      photoPath: clearPhoto ? null : (photoPath ?? s.photoPath),
      membership: s.membership,
      memberships: s.memberships,
    );
  }

  @override
  Future<Preferences> preferences() async => prefs;

  @override
  Future<Preferences> savePreferences({
    Map<NotificationPref, bool>? notifications,
    PaymentMethodPref? paymentMethod,
    bool clearPaymentMethod = false,
  }) async {
    prefs = Preferences(
      notifications: notifications ?? prefs.notifications,
      paymentMethod: clearPaymentMethod ? null : (paymentMethod ?? prefs.paymentMethod),
    );
    savedPrefs.add(prefs);
    return prefs;
  }

  @override
  Future<void> deleteAccount() async {
    if (deleteError != null) throw deleteError!;
    deleted = true;
  }

  @override
  Future<List<HouseholdMember>> household() async => List.of(members);

  @override
  Future<void> addHouseholdMember(HouseholdInput input) async {
    members = [...members, HouseholdMember(id: 'h${members.length + 1}', name: input.name, relation: input.relation, phone: input.phone)];
  }

  @override
  Future<void> removeHouseholdMember(String id) async => members = members.where((m) => m.id != id).toList();

  @override
  Future<List<ServiceProvider>> services() async => serviceList;

  @override
  Future<SocietyInfo> society() async => const SocietyInfo(
        id: 'soc1',
        name: 'Sai Icon Co-operative Society',
        city: 'Thane',
        office: [Contact(name: 'Shruti Chetan Dalvi', phone: '+919000000001')],
      );

  @override
  Future<Tenancy?> tenancy() async => currentTenancy;

  @override
  Future<Tenancy> addTenant(TenancyInput input) async {
    addedTenancies.add(input);
    return currentTenancy = sampleTenancy(status: TenantStatus.invited);
  }

  @override
  Future<void> endTenancy(String id) async {
    endedTenancies.add(id);
    currentTenancy = null;
  }
}

/// Notifications in memory; marking read updates the list.
class FakeNotificationsRepository extends NotificationsRepository {
  FakeNotificationsRepository() : super(_unused);

  List<AppNotification> items = [
    AppNotification(
      id: 'n1',
      type: 'poll',
      title: 'New poll',
      body: 'Which activity for Sunday? Cast your vote.',
      read: false,
      createdAt: _now,
    ),
    AppNotification(
      id: 'n2',
      type: 'due',
      title: 'Maintenance due',
      body: 'Your maintenance of ₹2,500 for this month is due.',
      read: true,
      createdAt: _now.subtract(const Duration(days: 2)),
    ),
  ];
  final readIds = <String>[];

  @override
  Future<List<AppNotification>> list({DateTime? before, int limit = 30}) async => List.of(items);

  @override
  Future<int> unreadCount() async => items.where((n) => !n.read).length;

  @override
  Future<void> markRead(String id) async {
    readIds.add(id);
    items = [for (final n in items) n.id == id ? n.markedRead() : n];
  }

  @override
  Future<void> markAllRead() async => items = [for (final n in items) n.markedRead()];

  @override
  Future<void> registerDevice(String token, String platform) async {}

  @override
  Future<void> unregisterDevice(String token) async {}
}

const lastAdminError = ApiException(code: 'LAST_ADMIN', message: 'last admin', statusCode: 409);
