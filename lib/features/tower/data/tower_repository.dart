import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/domain/user_role.dart';
import '../domain/tower_models.dart';

const _visitorTypes = {'GUEST': VisitorType.guest, 'DELIVERY': VisitorType.delivery, 'SERVICE': VisitorType.service};
const _visitorStatuses = {
  'EXPECTED': VisitorStatus.expected,
  'CHECKED_IN': VisitorStatus.checkedIn,
  'CHECKED_OUT': VisitorStatus.checkedOut,
  'HELD_AT_GATE': VisitorStatus.heldAtGate,
  'PENDING_APPROVAL': VisitorStatus.pendingApproval,
  'DENIED': VisitorStatus.denied,
};

Visitor visitorFromJson(Json json) => Visitor(
      id: json['id'] as String,
      name: json['name'] as String,
      purpose: json['purpose'] as String?,
      type: _visitorTypes[json['type']]!,
      status: _visitorStatuses[json['status']]!,
      phone: json['phone'] as String?,
      expectedAt: parseTimeOrNull(json['expectedAt']),
      preApproved: (json['preApproved'] as bool?) ?? false,
      inTime: parseTimeOrNull(json['inTime']),
      outTime: parseTimeOrNull(json['outTime']),
      flatLabel: json['flatLabel'] as String?,
      flatId: json['flatId'] as String?,
      passCode: json['passCode'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );

Notice noticeFromJson(Json json) => Notice(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      category: json['category'] as String?,
      isAlert: json['isAlert'] as bool,
      scheduledAt: parseTimeOrNull(json['scheduledAt']),
      expiresAt: parseTimeOrNull(json['expiresAt']),
      towerName: json['towerName'] as String?,
      createdAt: parseTime(json['createdAt']),
    );

NeighbourTower neighbourTowerFromJson(Json json) => NeighbourTower(
      towerName: json['towerName'] as String,
      flats: parseList(
        json['flats'],
        (f) => NeighbourFlat(
          flatId: f['flatId'] as String,
          number: f['number'] as String,
          residents: parseList(
            f['residents'],
            (r) => Resident(
              name: r['name'] as String,
              role: UserRole.fromApi(r['role'] as String),
              photoPath: r['photoUrl'] as String?,
            ),
          ),
        ),
      ),
    );

Complaint complaintFromJson(Json json) => Complaint(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String?,
      description: (json['description'] as String?) ?? '',
      photoPath: json['photoUrl'] as String?,
      status: ComplaintStatus.fromApi(json['status'] as String),
      flatLabel: json['flatLabel'] as String?,
      raisedBy: (json['raisedBy'] as String?) ?? '',
      createdAt: parseTime(json['createdAt']),
      resolvedAt: parseTimeOrNull(json['resolvedAt']),
    );

SocietyEvent eventFromJson(Json json) => SocietyEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String,
      imagePath: json['imageUrl'] as String?,
      startsAt: parseTime(json['startsAt']),
      endsAt: parseTimeOrNull(json['endsAt']),
    );

/// Visitors, notices, neighbours, complaints and events.
class TowerRepository {
  TowerRepository(this._dio);

  final Dio _dio;

  Map<String, Object> _limit(int? limit) => {'limit': ?limit};

  Future<List<Visitor>> visitors({int? limit}) => apiCall(() async =>
      parseList((await _dio.get<List<dynamic>>('/visitors', queryParameters: _limit(limit))).data, visitorFromJson));

  Future<Visitor> addVisitor(VisitorInput input) =>
      apiCall(() async => visitorFromJson((await _dio.post<Json>('/visitors', data: input.toJson())).data!));

  /// The gate (admins) marks arrival, parcel held or exit.
  Future<Visitor> setVisitorStatus(String id, GateStatus status) => apiCall(() async =>
      visitorFromJson((await _dio.patch<Json>('/visitors/$id/status', data: {'status': status.apiName})).data!));

  Future<void> cancelVisitor(String id) => apiCall(() => _dio.delete<void>('/visitors/$id'));

  /// The flat allows or denies a walk-in waiting at the gate.
  Future<Visitor> decideVisitor(String id, {required bool allow}) => apiCall(() async =>
      visitorFromJson((await _dio.patch<Json>('/visitors/$id/decision', data: {'allow': allow})).data!));

  Future<List<Notice>> notices({int? limit}) => apiCall(() async =>
      parseList((await _dio.get<List<dynamic>>('/notices', queryParameters: _limit(limit))).data, noticeFromJson));

  Future<void> createNotice(NoticeInput input) => apiCall(() => _dio.post<void>('/notices', data: input.toJson()));

  Future<void> updateNotice(String id, NoticeInput input) =>
      apiCall(() => _dio.patch<void>('/notices/$id', data: input.toJson()));

  Future<void> deleteNotice(String id) => apiCall(() => _dio.delete<void>('/notices/$id'));

  Future<List<NeighbourTower>> neighbours() => apiCall(
        () async => parseList((await _dio.get<List<dynamic>>('/neighbours')).data, neighbourTowerFromJson),
      );

  Future<List<Complaint>> complaints({ComplaintStatus? status, int? limit}) => apiCall(() async {
        final response = await _dio.get<List<dynamic>>(
          '/complaints',
          queryParameters: {..._limit(limit), 'status': ?status?.apiName},
        );
        return parseList(response.data, complaintFromJson);
      });

  Future<void> postComplaint(ComplaintInput input) =>
      apiCall(() => _dio.post<void>('/complaints', data: input.toJson()));

  Future<void> updateComplaintStatus(String id, ComplaintStatus status) =>
      apiCall(() => _dio.patch<void>('/complaints/$id/status', data: {'status': status.apiName}));

  Future<void> createEvent(EventInput input) => apiCall(() => _dio.post<void>('/events', data: input.toJson()));

  Future<void> updateEvent(String id, EventInput input) =>
      apiCall(() => _dio.patch<void>('/events/$id', data: input.toJson()));

  Future<void> deleteEvent(String id) => apiCall(() => _dio.delete<void>('/events/$id'));

  Future<List<SocietyEvent>> events({int? limit}) => apiCall(() async =>
      parseList((await _dio.get<List<dynamic>>('/events', queryParameters: _limit(limit))).data, eventFromJson));
}

final towerRepositoryProvider = Provider<TowerRepository>(
  (ref) => TowerRepository(ref.watch(authedDioProvider)),
);
