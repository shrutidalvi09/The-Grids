import 'package:dio/dio.dart';
import 'package:the_grids/core/network/api_exception.dart';
import 'package:the_grids/features/community/data/community_repository.dart';
import 'package:the_grids/features/community/domain/community_models.dart';

final _unused = Dio();
final _now = DateTime.now();

Poll samplePoll({String id = 'poll1', bool voted = false, bool open = true, bool admin = false}) {
  final visible = voted || !open || admin;
  return Poll(
    id: id,
    question: 'Which activity for Sunday?',
    isOpen: open,
    closesAt: _now.add(const Duration(days: 5)),
    createdAt: _now,
    totalVotes: 21 + (voted ? 1 : 0),
    myOptionId: voted ? 'o2' : null,
    resultsVisible: visible,
    options: [
      PollOption(id: 'o1', label: 'Movie Night', votes: visible ? 9 : null),
      PollOption(id: 'o2', label: 'Karaoke', votes: visible ? 7 + (voted ? 1 : 0) : null),
      PollOption(id: 'o3', label: 'Sports Tournament', votes: visible ? 5 : null),
    ],
  );
}

final sampleAnnouncement = Announcement(
  id: 'a1',
  communityId: 'c1',
  title: 'Breathing for Balance',
  body: 'Beginners are welcome — bring your mats and water bottles!',
  eventAt: DateTime(_now.year, _now.month, _now.day, 6, 30).add(const Duration(days: 1)),
  endsAt: DateTime(_now.year, _now.month, _now.day, 7, 15).add(const Duration(days: 1)),
  venue: 'Community Hall Terrace',
  authorName: 'Sanskriti Kadam',
  createdAt: _now,
);

const sampleCandidates = [
  CommunityMember(userId: 'u1', name: 'Shruti Chetan Dalvi', flatLabel: 'Tower-C, 502'),
  CommunityMember(userId: 'u2', name: 'Kiran Rathod', flatLabel: 'Tower-A, 102'),
  CommunityMember(userId: 'u3', name: 'Mehul Shah', flatLabel: 'Tower-A, 202'),
];

/// In-memory polls and clubs.
class FakeCommunityRepository extends CommunityRepository {
  FakeCommunityRepository({bool admin = false}) : super(_unused) {
    pollList = [samplePoll(admin: admin)];
  }

  late List<Poll> pollList;
  Map<String, CommunityDetail> clubs = {
    'c1': CommunityDetail(
      community: Community(
        id: 'c1',
        name: 'Yoga Club',
        description: 'Morning yoga for all levels.',
        memberCount: 1,
        isMember: false,
        latestAnnouncement: sampleAnnouncement,
      ),
      members: const [CommunityMember(userId: 'u2', name: 'Kiran Rathod', flatLabel: 'Tower-A, 102')],
      announcements: [sampleAnnouncement],
    ),
  };

  final votes = <(String, String)>[];
  final createdPolls = <PollInput>[];
  final closedPolls = <String>[];
  final createdClubs = <CommunityInput>[];
  final createdAnnouncements = <(String, AnnouncementInput)>[];
  Object? voteError;

  @override
  Future<List<Poll>> polls({bool openOnly = false}) async => List.of(pollList);

  @override
  Future<Poll> vote(String pollId, String optionId) async {
    if (voteError != null) throw voteError!;
    votes.add((pollId, optionId));
    final voted = samplePoll(id: pollId, voted: true);
    pollList = [for (final p in pollList) p.id == pollId ? voted : p];
    return voted;
  }

  @override
  Future<void> createPoll(PollInput input) async => createdPolls.add(input);

  @override
  Future<Poll> closePoll(String pollId) async {
    closedPolls.add(pollId);
    final closed = samplePoll(id: pollId, open: false);
    pollList = [for (final p in pollList) p.id == pollId ? closed : p];
    return closed;
  }

  @override
  Future<List<Community>> communities() async => [for (final d in clubs.values) d.community];

  @override
  Future<CommunityDetail> community(String id) async =>
      clubs[id] ?? (throw const ApiException(code: 'NOT_FOUND', message: 'Not found', statusCode: 404));

  @override
  Future<List<CommunityMember>> candidates() async => sampleCandidates;

  @override
  Future<CommunityDetail> createCommunity(CommunityInput input) async {
    createdClubs.add(input);
    final id = 'c${clubs.length + 1}';
    final detail = CommunityDetail(
      community: Community(id: id, name: input.name, description: input.description, memberCount: input.memberIds.length, isMember: false),
      members: [for (final c in sampleCandidates) if (input.memberIds.contains(c.userId)) c],
      announcements: const [],
    );
    clubs = {...clubs, id: detail};
    return detail;
  }

  CommunityDetail _setMember(String id, bool member) {
    final d = clubs[id]!;
    final c = d.community;
    final updated = CommunityDetail(
      community: Community(
        id: c.id,
        name: c.name,
        description: c.description,
        memberCount: c.memberCount + (member ? 1 : -1),
        isMember: member,
        latestAnnouncement: c.latestAnnouncement,
      ),
      members: d.members,
      announcements: d.announcements,
    );
    clubs = {...clubs, id: updated};
    return updated;
  }

  @override
  Future<CommunityDetail> join(String id) async => _setMember(id, true);

  @override
  Future<CommunityDetail> leave(String id) async => _setMember(id, false);

  @override
  Future<void> createAnnouncement(String communityId, AnnouncementInput input) async =>
      createdAnnouncements.add((communityId, input));
}
