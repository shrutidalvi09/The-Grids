import 'package:flutter/foundation.dart';

import '../../tower/domain/tower_models.dart';

/// Kinds of daily help, as the API spells them.
const helpKinds = ['Maid', 'Cook', 'Driver', 'Nanny', 'Cleaner', 'Other'];

/// Maid, cook, driver… who come every day with a permanent gate code.
@immutable
class DailyHelp {
  const DailyHelp({
    required this.id,
    required this.name,
    required this.kind,
    required this.inside,
    required this.daysThisMonth,
    this.phone,
    this.passCode,
    this.flatLabels = const [],
    this.lastIn,
  });

  final String id;
  final String name;

  /// One of [helpKinds].
  final String kind;
  final String? phone;

  /// Shown to the flats they work for and admins; null for guards.
  final String? passCode;

  /// The flats they work for (the gate and admins only).
  final List<String> flatLabels;
  final bool inside;
  final DateTime? lastIn;
  final int daysThisMonth;
}

@immutable
class AttendanceEntry {
  const AttendanceEntry({required this.inTime, this.outTime});

  final DateTime inTime;
  final DateTime? outTime;
}

/// One month of a helper's visits.
@immutable
class AttendanceMonth {
  const AttendanceMonth({required this.month, required this.days, required this.entries});

  /// "2026-10"
  final String month;
  final int days;
  final List<AttendanceEntry> entries;
}

/// What a code typed or scanned at the gate turned out to be.
sealed class PassCheck {
  const PassCheck();
}

final class GuestPass extends PassCheck {
  const GuestPass(this.visitor);
  final Visitor visitor;
}

final class StaffPass extends PassCheck {
  const StaffPass({required this.id, required this.name, required this.kind, required this.inside, this.phone, this.flatLabels = const []});

  final String id;
  final String name;
  final String kind;
  final String? phone;
  final List<String> flatLabels;
  final bool inside;
}

enum SosStatus { active, resolved }

@immutable
class SosAlert {
  const SosAlert({
    required this.id,
    required this.status,
    required this.createdAt,
    this.flatLabel,
    this.raisedByName,
    this.raisedByPhone,
    this.note,
    this.resolvedAt,
    this.resolvedBy,
  });

  final String id;
  final String? flatLabel;
  final String? raisedByName;
  final String? raisedByPhone;
  final String? note;
  final SosStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  bool get isActive => status == SosStatus.active;
}

enum VehicleType {
  car('CAR'),
  bike('BIKE'),
  other('OTHER');

  const VehicleType(this.apiName);
  final String apiName;

  static VehicleType fromApi(String value) => values.firstWhere((t) => t.apiName == value, orElse: () => other);
}

@immutable
class Vehicle {
  const Vehicle({
    required this.id,
    required this.number,
    required this.type,
    this.description,
    this.parkingSlot,
    this.flatLabel,
    this.contacts = const [],
  });

  final String id;

  /// Normalised: "MH04AB1234".
  final String number;
  final VehicleType type;
  final String? description;
  final String? parkingSlot;
  final String? flatLabel;

  /// The flat's residents (gate search only).
  final List<({String name, String phone})> contacts;

  /// "MH 04 AB 1234" for display.
  String get displayNumber {
    final m = RegExp(r'^([A-Z]{2})(\d{1,2})([A-Z]{0,3})(\d{1,4})$').firstMatch(number);
    if (m == null) return number;
    return [for (var i = 1; i <= 4; i++) m.group(i)!].where((p) => p.isNotEmpty).join(' ');
  }
}

@immutable
class VehicleInput {
  const VehicleInput({required this.number, required this.type, this.description, this.flatId});

  final String number;
  final VehicleType type;
  final String? description;

  /// Admins only.
  final String? flatId;

  Map<String, Object?> toJson() => {
        'number': number,
        'type': type.apiName,
        'description': description,
        'flatId': ?flatId,
      };
}
