import 'package:flutter/foundation.dart';

import '../../auth/domain/user_role.dart';

enum VisitorType { guest, delivery, service }

enum VisitorStatus { expected, checkedIn, checkedOut, heldAtGate }

@immutable
class Visitor {
  const Visitor({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.purpose,
    this.inTime,
    this.outTime,
    this.flatLabel,
  });

  final String id;
  final String name;
  final String? purpose;
  final VisitorType type;
  final VisitorStatus status;
  final DateTime? inTime;
  final DateTime? outTime;

  /// Shown to admins, who see every flat.
  final String? flatLabel;
}

@immutable
class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.isAlert,
    required this.createdAt,
    this.category,
    this.scheduledAt,
    this.expiresAt,
    this.towerName,
  });

  final String id;
  final String title;
  final String body;
  final String? category;
  final bool isAlert;
  final DateTime? scheduledAt;
  final DateTime? expiresAt;
  final String? towerName;
  final DateTime createdAt;

  /// When to show next to the title: the event date, else the posting date.
  DateTime get displayDate => scheduledAt ?? createdAt;
}

@immutable
class NoticeInput {
  const NoticeInput({
    required this.title,
    required this.body,
    this.category,
    this.scheduledAt,
    this.isAlert = false,
  });

  final String title;
  final String body;
  final String? category;
  final DateTime? scheduledAt;
  final bool isAlert;

  Map<String, Object?> toJson() => {
        'title': title,
        'body': body,
        'category': category,
        'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
        'isAlert': isAlert,
      };
}

@immutable
class Resident {
  const Resident({required this.name, required this.role, this.photoPath});

  final String name;
  final UserRole role;
  final String? photoPath;
}

@immutable
class NeighbourFlat {
  const NeighbourFlat({required this.flatId, required this.number, required this.residents});

  final String flatId;
  final String number;
  final List<Resident> residents;
}

@immutable
class NeighbourTower {
  const NeighbourTower({required this.towerName, required this.flats});

  final String towerName;
  final List<NeighbourFlat> flats;
}

enum ComplaintStatus {
  open('OPEN'),
  inProgress('IN_PROGRESS'),
  resolved('RESOLVED');

  const ComplaintStatus(this.apiName);
  final String apiName;

  static ComplaintStatus fromApi(String value) => values.firstWhere((s) => s.apiName == value);
}

@immutable
class Complaint {
  const Complaint({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.raisedBy,
    required this.createdAt,
    this.category,
    this.photoPath,
    this.flatLabel,
    this.resolvedAt,
  });

  final String id;
  final String title;
  final String? category;
  final String description;
  final String? photoPath;
  final ComplaintStatus status;
  final String? flatLabel;
  final String raisedBy;
  final DateTime createdAt;
  final DateTime? resolvedAt;
}

@immutable
class ComplaintInput {
  const ComplaintInput({required this.title, required this.description, this.category, this.photoPath});

  final String title;
  final String description;
  final String? category;
  final String? photoPath;

  Map<String, Object?> toJson() => {
        'title': title,
        'description': description,
        'category': ?category,
        'photoUrl': ?photoPath,
      };
}

@immutable
class SocietyEvent {
  const SocietyEvent({
    required this.id,
    required this.title,
    required this.location,
    required this.startsAt,
    this.description,
    this.imagePath,
    this.endsAt,
  });

  final String id;
  final String title;
  final String? description;
  final String location;
  final String? imagePath;
  final DateTime startsAt;
  final DateTime? endsAt;
}
