import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../auth/data/auth_dto.dart' show sessionFromMeJson;
import '../../auth/data/auth_providers.dart';
import '../../auth/domain/session.dart';
import '../../auth/domain/user_role.dart';
import '../../maintenance/domain/money_models.dart';
import '../domain/profile_models.dart';

Preferences preferencesFromJson(Json json) {
  final stored = json['notifications'] as Json;
  return Preferences(
    notifications: {for (final p in NotificationPref.values) p: (stored[p.name] as bool?) ?? true},
    paymentMethod: PaymentMethodPref.fromApi(json['paymentMethod'] as String?),
  );
}

HouseholdMember householdFromJson(Json json) => HouseholdMember(
      id: json['id'] as String,
      name: json['name'] as String,
      relation: json['relation'] as String,
      phone: json['phone'] as String?,
      photoPath: json['photoUrl'] as String?,
    );

ServiceProvider serviceFromJson(Json json) => ServiceProvider(
      id: json['id'] as String,
      category: json['category'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      location: json['location'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: (json['ratingCount'] as int?) ?? 0,
      myRating: json['myRating'] as int?,
    );

Member memberFromJson(Json json) => Member(
      membershipId: json['membershipId'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      role: UserRole.fromApi(json['role'] as String),
      invited: json['status'] == 'INVITED',
      flatId: json['flatId'] as String?,
      flatLabel: json['flatLabel'] as String?,
    );

FlatOption flatOptionFromJson(Json json) => FlatOption(
      id: json['id'] as String,
      label: json['label'] as String,
      occupants: [
        for (final o in json['occupants'] as List<dynamic>) (o as Json)['name'] as String,
      ],
      contacts: [
        for (final o in json['occupants'] as List<dynamic>)
          if ((o as Json)['phone'] != null) Contact(name: o['name'] as String, phone: o['phone'] as String),
      ],
    );

Contact _contact(Object? json) => Contact(name: (json as Json)['name'] as String, phone: json['phone'] as String);

SocietyInfo societyFromJson(Json json) => SocietyInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      city: json['city'] as String?,
      office: [for (final c in json['office'] as List<dynamic>) _contact(c)],
    );

Tenancy? tenancyFromJson(Object? data) {
  final json = (data as Json)['tenancy'] as Json?;
  if (json == null) return null;
  final tenant = json['tenant'] as Json;
  return Tenancy(
    id: json['id'] as String,
    flatLabel: json['flatLabel'] as String?,
    monthlyRentPaise: json['monthlyRentPaise'] as int,
    depositPaise: json['depositPaise'] as int,
    rentDueDay: json['rentDueDay'] as int,
    rentBreakdown: parseList(
      json['rentBreakdown'],
      (i) => BreakdownItem(label: i['label'] as String, amountPaise: i['amountPaise'] as int),
    ),
    startDate: parseTime(json['startDate']),
    endDate: parseTimeOrNull(json['endDate']),
    tenant: _contact(tenant),
    tenantStatus: TenantStatus.values.byName((tenant['status'] as String).toLowerCase()),
    owner: _contact(json['owner']),
  );
}

/// Profile tab: account, preferences, household, services, society, tenancy.
class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  /// Only the fields given are changed. Pass `clearEmail`/`clearPhoto` to remove them.
  Future<AppSession> updateProfile({
    String? name,
    String? email,
    bool clearEmail = false,
    String? photoPath,
    bool clearPhoto = false,
    String? language,
    String? theme,
  }) =>
      apiCall(() async {
        final response = await _dio.patch<Json>('/me', data: {
          'name': ?name,
          if (clearEmail) 'email': null else 'email': ?email,
          if (clearPhoto) 'photoUrl': null else 'photoUrl': ?photoPath,
          'language': ?language,
          'theme': ?theme,
        });
        return sessionFromMeJson(response.data!);
      });

  Future<Preferences> preferences() =>
      apiCall(() async => preferencesFromJson((await _dio.get<Json>('/me/preferences')).data!));

  Future<Preferences> savePreferences({Map<NotificationPref, bool>? notifications, PaymentMethodPref? paymentMethod, bool clearPaymentMethod = false}) =>
      apiCall(() async {
        final response = await _dio.put<Json>('/me/preferences', data: {
          if (notifications != null) 'notifications': {for (final e in notifications.entries) e.key.name: e.value},
          if (clearPaymentMethod) 'paymentMethod': null else 'paymentMethod': ?paymentMethod?.name,
        });
        return preferencesFromJson(response.data!);
      });

  Future<void> deleteAccount() => apiCall(() => _dio.delete<void>('/me'));

  Future<List<HouseholdMember>> household() =>
      apiCall(() async => parseList((await _dio.get<List<dynamic>>('/household')).data, householdFromJson));

  Future<void> addHouseholdMember(HouseholdInput input) =>
      apiCall(() => _dio.post<void>('/household', data: input.toJson()));

  Future<void> updateHouseholdMember(String id, HouseholdInput input) =>
      apiCall(() => _dio.patch<void>('/household/$id', data: input.toJson()));

  Future<void> removeHouseholdMember(String id) => apiCall(() => _dio.delete<void>('/household/$id'));

  Future<List<ServiceProvider>> services() =>
      apiCall(() async => parseList((await _dio.get<List<dynamic>>('/services')).data, serviceFromJson));

  Future<void> addService({required String category, required String name, required String phone, String? location}) =>
      apiCall(() => _dio.post<void>('/services', data: {
            'category': category,
            'name': name,
            'phone': phone,
            'location': ?location,
          }));

  Future<void> removeService(String id) => apiCall(() => _dio.delete<void>('/services/$id'));

  Future<ServiceProvider> rateService(String id, int stars) => apiCall(() async =>
      serviceFromJson((await _dio.put<Json>('/services/$id/rating', data: {'stars': stars})).data!));

  // Admin: managing residents.
  Future<List<Member>> members() =>
      apiCall(() async => parseList((await _dio.get<List<dynamic>>('/memberships')).data, memberFromJson));

  Future<List<FlatOption>> flats() =>
      apiCall(() async => parseList((await _dio.get<List<dynamic>>('/flats')).data, flatOptionFromJson));

  Future<void> invite({required String name, required String phone, required UserRole role, String? flatId}) =>
      apiCall(() => _dio.post<void>('/memberships/invites', data: {
            'name': name,
            'phone': phone,
            'role': role.apiName,
            'flatId': ?flatId,
          }));

  Future<void> removeMember(String membershipId) => apiCall(() => _dio.delete<void>('/memberships/$membershipId'));

  Future<SocietyInfo> society() => apiCall(() async => societyFromJson((await _dio.get<Json>('/society')).data!));

  Future<Tenancy?> tenancy() => apiCall(() async => tenancyFromJson((await _dio.get<Json>('/tenancy')).data));

  Future<Tenancy> addTenant(TenancyInput input) =>
      apiCall(() async => tenancyFromJson((await _dio.post<Json>('/tenancy', data: input.toJson())).data)!);

  Future<Tenancy> updateTenancy(String id, TenancyInput input) =>
      apiCall(() async => tenancyFromJson((await _dio.patch<Json>('/tenancy/$id', data: input.toJson())).data)!);

  Future<void> endTenancy(String id) => apiCall(() => _dio.post<void>('/tenancy/$id/end'));
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(authedDioProvider)),
);
