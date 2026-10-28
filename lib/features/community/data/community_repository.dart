import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/community_models.dart';

Poll pollFromJson(Json json) => Poll(
      id: json['id'] as String,
      question: json['question'] as String,
      closesAt: parseTimeOrNull(json['closesAt']),
      isOpen: json['isOpen'] as bool,
      createdAt: parseTime(json['createdAt']),
      totalVotes: json['totalVotes'] as int,
      myOptionId: json['myOptionId'] as String?,
      resultsVisible: json['resultsVisible'] as bool,
      options: parseList(
        json['options'],
        (o) => PollOption(id: o['id'] as String, label: o['label'] as String, votes: o['votes'] as int?),
      ),
    );

Announcement announcementFromJson(Json json) => Announcement(
      id: json['id'] as String,
      communityId: json['communityId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      eventAt: parseTimeOrNull(json['eventAt']),
      endsAt: parseTimeOrNull(json['endsAt']),
      venue: json['venue'] as String?,
      authorName: json['authorName'] as String,
      createdAt: parseTime(json['createdAt']),
    );

Community communityFromJson(Json json) {
  final latest = json['latestAnnouncement'] as Json?;
  return Community(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    photoPath: json['photoUrl'] as String?,
    memberCount: json['memberCount'] as int,
    isMember: json['isMember'] as bool,
    latestAnnouncement: latest == null ? null : announcementFromJson(latest),
  );
}

CommunityMember memberFromJson(Json json) => CommunityMember(
      userId: json['userId'] as String,
      name: json['name'] as String,
      flatLabel: json['flatLabel'] as String?,
    );

CommunityDetail communityDetailFromJson(Json json) => CommunityDetail(
      community: communityFromJson(json),
      members: parseList(json['members'], memberFromJson),
      announcements: parseList(json['announcements'], announcementFromJson),
    );

/// Polls, clubs and club announcements.
class CommunityRepository {
  CommunityRepository(this._dio);

  final Dio _dio;

  Future<List<Poll>> polls({bool openOnly = false}) => apiCall(() async => parseList(
        (await _dio.get<List<dynamic>>('/polls', queryParameters: {if (openOnly) 'status': 'open'})).data,
        pollFromJson,
      ));

  Future<Poll> vote(String pollId, String optionId) => apiCall(() async =>
      pollFromJson((await _dio.post<Json>('/polls/$pollId/votes', data: {'optionId': optionId})).data!));

  Future<void> createPoll(PollInput input) => apiCall(() => _dio.post<void>('/polls', data: input.toJson()));

  Future<Poll> closePoll(String pollId) =>
      apiCall(() async => pollFromJson((await _dio.post<Json>('/polls/$pollId/close')).data!));

  Future<void> deletePoll(String pollId) => apiCall(() => _dio.delete<void>('/polls/$pollId'));

  Future<List<Community>> communities() =>
      apiCall(() async => parseList((await _dio.get<List<dynamic>>('/communities')).data, communityFromJson));

  Future<CommunityDetail> community(String id) =>
      apiCall(() async => communityDetailFromJson((await _dio.get<Json>('/communities/$id')).data!));

  Future<List<CommunityMember>> candidates() => apiCall(
        () async => parseList((await _dio.get<List<dynamic>>('/communities/candidates')).data, memberFromJson),
      );

  Future<CommunityDetail> createCommunity(CommunityInput input) => apiCall(
        () async => communityDetailFromJson((await _dio.post<Json>('/communities', data: input.toJson())).data!),
      );

  Future<CommunityDetail> updateCommunity(String id, CommunityInput input) => apiCall(
        () async => communityDetailFromJson((await _dio.patch<Json>('/communities/$id', data: input.toJson())).data!),
      );

  Future<void> deleteCommunity(String id) => apiCall(() => _dio.delete<void>('/communities/$id'));

  Future<CommunityDetail> join(String id) =>
      apiCall(() async => communityDetailFromJson((await _dio.post<Json>('/communities/$id/join')).data!));

  Future<CommunityDetail> leave(String id) =>
      apiCall(() async => communityDetailFromJson((await _dio.post<Json>('/communities/$id/leave')).data!));

  Future<void> createAnnouncement(String communityId, AnnouncementInput input) =>
      apiCall(() => _dio.post<void>('/communities/$communityId/announcements', data: input.toJson()));

  Future<void> updateAnnouncement(String id, AnnouncementInput input) =>
      apiCall(() => _dio.patch<void>('/announcements/$id', data: input.toJson()));

  Future<void> deleteAnnouncement(String id) => apiCall(() => _dio.delete<void>('/announcements/$id'));
}

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(ref.watch(authedDioProvider)),
);
