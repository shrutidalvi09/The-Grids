import 'package:flutter/foundation.dart';

@immutable
class PollOption {
  const PollOption({required this.id, required this.label, this.votes});

  final String id;
  final String label;

  /// Null until the results are visible to the caller.
  final int? votes;
}

@immutable
class Poll {
  const Poll({
    required this.id,
    required this.question,
    required this.isOpen,
    required this.createdAt,
    required this.totalVotes,
    required this.resultsVisible,
    required this.options,
    this.closesAt,
    this.myOptionId,
  });

  final String id;
  final String question;
  final DateTime? closesAt;
  final bool isOpen;
  final DateTime createdAt;
  final int totalVotes;
  final String? myOptionId;

  /// Counts show once you've voted, when the poll closes, or for admins.
  final bool resultsVisible;
  final List<PollOption> options;

  bool get hasVoted => myOptionId != null;

  PollOption? get myOption => options.where((o) => o.id == myOptionId).firstOrNull;
}

@immutable
class PollInput {
  const PollInput({required this.question, required this.options, this.closesAt});

  final String question;
  final List<String> options;
  final DateTime? closesAt;

  Map<String, Object> toJson() => {
        'question': question,
        'options': options,
        'closesAt': ?closesAt?.toUtc().toIso8601String(),
      };
}

@immutable
class Announcement {
  const Announcement({
    required this.id,
    required this.communityId,
    required this.title,
    required this.body,
    required this.authorName,
    required this.createdAt,
    this.eventAt,
    this.endsAt,
    this.venue,
  });

  final String id;
  final String communityId;
  final String title;
  final String body;
  final DateTime? eventAt;
  final DateTime? endsAt;
  final String? venue;
  final String authorName;
  final DateTime createdAt;
}

@immutable
class AnnouncementInput {
  const AnnouncementInput({required this.title, required this.body, this.eventAt, this.endsAt, this.venue});

  final String title;
  final String body;
  final DateTime? eventAt;
  final DateTime? endsAt;
  final String? venue;

  Map<String, Object?> toJson() => {
        'title': title,
        'body': body,
        'eventAt': eventAt?.toUtc().toIso8601String(),
        'endsAt': endsAt?.toUtc().toIso8601String(),
        'venue': venue,
      };
}

@immutable
class CommunityMember {
  const CommunityMember({required this.userId, required this.name, this.flatLabel});

  final String userId;
  final String name;
  final String? flatLabel;
}

/// A club (Yoga Club, Book Readers…) as listed on the Community tab.
@immutable
class Community {
  const Community({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.isMember,
    this.description,
    this.photoPath,
    this.latestAnnouncement,
  });

  final String id;
  final String name;
  final String? description;
  final String? photoPath;
  final int memberCount;
  final bool isMember;
  final Announcement? latestAnnouncement;
}

@immutable
class CommunityDetail {
  const CommunityDetail({required this.community, required this.members, required this.announcements});

  final Community community;
  final List<CommunityMember> members;
  final List<Announcement> announcements;
}

@immutable
class CommunityInput {
  const CommunityInput({required this.name, required this.memberIds, this.description, this.photoPath});

  final String name;
  final String? description;
  final String? photoPath;
  final List<String> memberIds;

  Map<String, Object?> toJson() => {
        'name': name,
        'description': description,
        'photoUrl': photoPath,
        'memberIds': memberIds,
      };
}
