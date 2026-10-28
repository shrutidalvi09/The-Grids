import 'package:flutter/foundation.dart';

/// Live state of a facility right now.
sealed class FacilityStatus {
  const FacilityStatus();
}

final class FacilityOpen extends FacilityStatus {
  const FacilityOpen({required this.closesAt, this.remaining});
  final DateTime closesAt;

  /// Places left right now; null when there is no capacity limit.
  final int? remaining;
}

final class FacilityFull extends FacilityStatus {
  const FacilityFull({required this.closesAt, this.nextFreeAt});
  final DateTime closesAt;
  final DateTime? nextFreeAt;
}

final class FacilityClosed extends FacilityStatus {
  const FacilityClosed({required this.opensAt});
  final DateTime opensAt;
}

@immutable
class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.openTime,
    required this.closeTime,
    required this.maxDurationMins,
    required this.status,
    this.description,
    this.photoPath,
    this.capacity,
  });

  final String id;
  final String name;
  final String? description;
  final String? photoPath;

  /// Society-local "HH:mm".
  final String openTime;
  final String closeTime;
  final int maxDurationMins;
  final int? capacity;
  final FacilityStatus status;
}

@immutable
class Slot {
  const Slot({
    required this.startsAt,
    required this.endsAt,
    required this.available,
    required this.mine,
    this.remaining,
  });

  final DateTime startsAt;
  final DateTime endsAt;
  final bool available;
  final bool mine;
  final int? remaining;
}

@immutable
class Booking {
  const Booking({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.startsAt,
    required this.endsAt,
  });

  final String id;
  final String facilityId;
  final String facilityName;
  final DateTime startsAt;
  final DateTime endsAt;
}

/// What an admin edits on the facility form.
@immutable
class FacilityInput {
  const FacilityInput({
    required this.name,
    required this.openTime,
    required this.closeTime,
    required this.maxDurationMins,
    this.description,
    this.photoPath,
    this.capacity,
  });

  final String name;
  final String? description;
  final String? photoPath;
  final String openTime;
  final String closeTime;
  final int maxDurationMins;
  final int? capacity;

  Map<String, Object?> toJson() => {
        'name': name,
        'description': description,
        'photoUrl': photoPath,
        'openTime': openTime,
        'closeTime': closeTime,
        'maxDurationMins': maxDurationMins,
        'capacity': capacity,
      };
}
