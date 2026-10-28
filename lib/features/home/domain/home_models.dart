import 'package:flutter/foundation.dart';

import '../../facilities/domain/facility_models.dart';
import '../../tower/domain/tower_models.dart';

@immutable
class Weather {
  const Weather({required this.temperatureC, required this.code});

  final int temperatureC;

  /// WMO weather code: 0 clear, 1–3 cloudy, 45/48 fog, 51–67/80–82 rain,
  /// 71–77/85–86 snow, 95–99 thunderstorm.
  final int code;
}

@immutable
class HomeAlert {
  const HomeAlert({required this.id, required this.title, required this.body});

  final String id;
  final String title;
  final String body;
}

@immutable
class SocietyStats {
  const SocietyStats({
    required this.towers,
    required this.flats,
    required this.owners,
    required this.tenants,
    required this.pendingDues,
  });

  final int towers;
  final int flats;
  final int owners;
  final int tenants;
  final int pendingDues;
}

/// One line of a resident's daily checklist.
sealed class ChecklistItem {
  const ChecklistItem();
}

/// Maid, cook, cleaner… expected today or already in.
final class HelpVisit extends ChecklistItem {
  const HelpVisit({required this.name, required this.checkedIn, this.purpose, this.at});
  final String name;
  final String? purpose;
  final bool checkedIn;
  final DateTime? at;
}

final class ParcelAtGate extends ChecklistItem {
  const ParcelAtGate({required this.from, this.at});
  final String from;
  final DateTime? at;
}

final class BillDue extends ChecklistItem {
  const BillDue({required this.isRent, required this.amountPaise, required this.dueDate, required this.overdue});
  final bool isRent;
  final int amountPaise;
  final DateTime dueDate;
  final bool overdue;
}

final class BillsClear extends ChecklistItem {
  const BillsClear();
}

@immutable
class HomeData {
  const HomeData({
    required this.upcomingEvents,
    this.alert,
    this.weather,
    this.stats,
    this.recentComplaints = const [],
    this.checklist = const [],
    this.myBookingsToday = const [],
    this.facilities = const [],
  });

  final HomeAlert? alert;
  final Weather? weather;
  final List<SocietyEvent> upcomingEvents;

  /// Admin dashboard.
  final SocietyStats? stats;
  final List<Complaint> recentComplaints;

  /// Owner and tenant dashboard.
  final List<ChecklistItem> checklist;
  final List<Booking> myBookingsToday;
  final List<Facility> facilities;
}
