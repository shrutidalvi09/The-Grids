import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/features/facilities/domain/facility_models.dart';
import 'package:the_grids/features/home/data/home_repository.dart';
import 'package:the_grids/features/home/domain/home_models.dart';

void main() {
  test('parses a resident home payload, skipping unknown checklist kinds', () {
    final home = homeFromJson({
      'alert': null,
      'weather': {'temperatureC': 29, 'code': 61},
      'upcomingEvents': [
        {'id': 'e1', 'title': 'Yoga', 'location': 'Terrace', 'startsAt': '2026-10-29T01:30:00.000Z', 'endsAt': null},
      ],
      'checklist': [
        {'kind': 'help', 'status': 'expected', 'name': 'Rekha', 'purpose': 'Maid', 'at': null},
        {'kind': 'parcel', 'from': 'Amazon', 'at': '2026-10-28T05:00:00.000Z'},
        {'kind': 'something_new', 'foo': 1},
        {'kind': 'bill', 'status': 'overdue', 'dueType': 'RENT', 'amountPaise': 1500000, 'dueDate': '2026-10-05T04:30:00.000Z'},
      ],
      'myBookingsToday': [],
      'facilities': [
        {
          'id': 'f1',
          'name': 'Gym',
          'description': null,
          'photoUrl': null,
          'openTime': '05:00',
          'closeTime': '22:00',
          'maxDurationMins': 90,
          'capacity': null,
          'status': {'status': 'open', 'closesAt': '2026-10-28T16:30:00.000Z', 'remaining': null},
        },
      ],
    });

    expect(home.weather!.code, 61);
    expect(home.stats, isNull);
    expect(home.checklist, hasLength(3));
    expect(home.checklist[0], isA<HelpVisit>().having((h) => h.checkedIn, 'checkedIn', false));
    expect(home.checklist[2], isA<BillDue>().having((b) => b.isRent, 'isRent', true).having((b) => b.overdue, 'overdue', true));
    expect(home.facilities.single.status, isA<FacilityOpen>().having((s) => s.remaining, 'remaining', isNull));
    expect(home.upcomingEvents.single.startsAt.isUtc, isFalse); // shown in local time
  });
}
