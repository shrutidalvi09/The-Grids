import 'package:flutter/foundation.dart';

import '../../maintenance/domain/money_models.dart';

/// One switch on the Notification Preferences screen (API names match).
enum NotificationPref {
  paymentReminder,
  paymentSuccess,
  maintenanceDue,
  announcements,
  eventsNotices,
  emergencyAlerts,
  complaintUpdates,
  visitorArrival,
  packageDelivery,
  staffAttendance,
  push,
}

/// Pre-selected in Razorpay Checkout. Card/UPI details are stored only by Razorpay.
enum PaymentMethodPref {
  upi,
  card,
  netbanking;

  static PaymentMethodPref? fromApi(String? value) => values.where((m) => m.name == value).firstOrNull;
}

@immutable
class Preferences {
  const Preferences({required this.notifications, this.paymentMethod});

  final Map<NotificationPref, bool> notifications;
  final PaymentMethodPref? paymentMethod;

  bool wants(NotificationPref pref) => notifications[pref] ?? true;
}

@immutable
class HouseholdMember {
  const HouseholdMember({required this.id, required this.name, required this.relation, this.phone, this.photoPath});

  final String id;
  final String name;
  final String relation;
  final String? phone;
  final String? photoPath;
}

@immutable
class HouseholdInput {
  const HouseholdInput({required this.name, required this.relation, this.phone, this.photoPath});

  final String name;
  final String relation;
  final String? phone;
  final String? photoPath;

  Map<String, Object?> toJson() => {'name': name, 'relation': relation, 'phone': phone, 'photoUrl': photoPath};
}

@immutable
class ServiceProvider {
  const ServiceProvider({
    required this.id,
    required this.category,
    required this.name,
    required this.phone,
    this.location,
    this.rating,
  });

  final String id;

  /// "Maid", "Cook", "Plumber"… as entered by the society.
  final String category;
  final String name;
  final String phone;
  final String? location;
  final double? rating;
}

@immutable
class Contact {
  const Contact({required this.name, required this.phone});

  final String name;
  final String phone;
}

@immutable
class SocietyInfo {
  const SocietyInfo({required this.id, required this.name, required this.office, this.address, this.city});

  final String id;
  final String name;
  final String? address;
  final String? city;

  /// The society office (admins), for Help.
  final List<Contact> office;
}

enum TenantStatus { invited, active, removed }

@immutable
class Tenancy {
  const Tenancy({
    required this.id,
    required this.monthlyRentPaise,
    required this.depositPaise,
    required this.rentDueDay,
    required this.rentBreakdown,
    required this.startDate,
    required this.tenant,
    required this.tenantStatus,
    required this.owner,
    this.flatLabel,
    this.endDate,
  });

  final String id;
  final String? flatLabel;
  final int monthlyRentPaise;
  final int depositPaise;
  final int rentDueDay;

  /// Rent items only (not maintenance services).
  final List<BreakdownItem> rentBreakdown;
  final DateTime startDate;
  final DateTime? endDate;
  final Contact tenant;
  final TenantStatus tenantStatus;
  final Contact owner;
}

@immutable
class TenancyInput {
  const TenancyInput({
    required this.rentBreakdown,
    required this.depositPaise,
    required this.rentDueDay,
    required this.startDate,
    this.endDate,
    this.tenantName,
    this.tenantPhone,
  });

  final List<BreakdownItem> rentBreakdown;
  final int depositPaise;
  final int rentDueDay;
  final DateTime startDate;
  final DateTime? endDate;

  /// Only when adding a tenant.
  final String? tenantName;
  final String? tenantPhone;

  int get monthlyRentPaise => rentBreakdown.fold(0, (sum, i) => sum + i.amountPaise);

  Map<String, Object?> toJson() => {
        'rentBreakdown': [for (final i in rentBreakdown) i.toJson()],
        'depositPaise': depositPaise,
        'rentDueDay': rentDueDay,
        'startDate': _day(startDate),
        'endDate': endDate == null ? null : _day(endDate!),
        'tenantName': ?tenantName,
        'tenantPhone': ?tenantPhone,
      };

  /// Lease dates are calendar days; send local midnight as an instant.
  static String _day(DateTime d) => DateTime(d.year, d.month, d.day).toUtc().toIso8601String();
}
