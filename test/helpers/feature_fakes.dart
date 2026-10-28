import 'package:dio/dio.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';
import 'package:the_grids/features/facilities/data/facilities_repository.dart';
import 'package:the_grids/features/facilities/domain/facility_models.dart';
import 'package:the_grids/features/home/data/home_repository.dart';
import 'package:the_grids/features/home/domain/home_models.dart';
import 'package:the_grids/features/tower/data/tower_repository.dart';
import 'package:the_grids/features/tower/domain/tower_models.dart';

final _unused = Dio();
final _now = DateTime.now();
DateTime _today(int hour, [int minute = 0]) => DateTime(_now.year, _now.month, _now.day, hour, minute);

final sampleEvents = [
  SocietyEvent(id: 'e1', title: 'Yoga Session', location: 'Terrace', startsAt: _today(7).add(const Duration(days: 1))),
  SocietyEvent(id: 'e2', title: 'Kids Painting', location: 'Clubhouse Court', startsAt: _today(17).add(const Duration(days: 3))),
];

final sampleFacilities = [
  Facility(
    id: 'f1',
    name: 'Badminton Court',
    openTime: '06:00',
    closeTime: '22:00',
    maxDurationMins: 60,
    capacity: 1,
    status: FacilityOpen(closesAt: _today(22), remaining: 1),
  ),
  Facility(
    id: 'f2',
    name: 'Swimming Pool',
    openTime: '06:00',
    closeTime: '20:00',
    maxDurationMins: 60,
    capacity: 25,
    status: FacilityClosed(opensAt: _today(6).add(const Duration(days: 1))),
  ),
];

final sampleComplaints = [
  Complaint(
    id: 'c1',
    title: 'Lift stuck between floors',
    category: 'Lift',
    description: 'Twice this week',
    status: ComplaintStatus.open,
    flatLabel: 'Tower-C, 502',
    raisedBy: 'Shruti Chetan Dalvi',
    createdAt: _now,
  ),
];

/// Home payloads per role, without a server.
class FakeHomeRepository extends HomeRepository {
  FakeHomeRepository() : super(_unused);

  HomeData data = HomeData(
    alert: const HomeAlert(id: 'a1', title: 'Water supply interruption', body: 'Off from 2 PM to 4 PM today.'),
    weather: const Weather(temperatureC: 30, code: 2),
    upcomingEvents: sampleEvents,
    stats: const SocietyStats(towers: 3, flats: 30, owners: 20, tenants: 4, pendingDues: 10),
    recentComplaints: sampleComplaints,
    checklist: [
      HelpVisit(name: 'Rekha', purpose: 'Maid', checkedIn: true, at: _today(9)),
      const ParcelAtGate(from: 'Amazon'),
      BillDue(isRent: false, amountPaise: 250000, dueDate: _today(10), overdue: true),
    ],
    myBookingsToday: [
      Booking(id: 'b1', facilityId: 'f1', facilityName: 'Badminton Court', startsAt: _today(17), endsAt: _today(18)),
    ],
    facilities: sampleFacilities,
  );

  @override
  Future<HomeData> fetch() async => data;
}

class FakeTowerRepository extends TowerRepository {
  FakeTowerRepository() : super(_unused);

  final postedComplaints = <ComplaintInput>[];
  final createdNotices = <NoticeInput>[];
  final statusChanges = <(String, ComplaintStatus)>[];

  List<Notice> noticeList = [
    Notice(id: 'n1', title: 'Lift maintenance', body: 'Use the service lift.', category: 'Maintenance', isAlert: false, createdAt: _now),
    Notice(id: 'n2', title: 'Fire drill', body: 'Assemble at the main gate.', category: 'Safety', isAlert: false, createdAt: _now),
  ];

  @override
  Future<List<Visitor>> visitors({int? limit}) async => [
        Visitor(id: 'v1', name: 'Rekha', purpose: 'Maid', type: VisitorType.service, status: VisitorStatus.checkedIn, inTime: _today(9)),
        const Visitor(id: 'v2', name: 'Amazon', purpose: 'Parcel', type: VisitorType.delivery, status: VisitorStatus.heldAtGate),
      ];

  @override
  Future<List<Notice>> notices({int? limit}) async => noticeList;

  @override
  Future<void> createNotice(NoticeInput input) async => createdNotices.add(input);

  @override
  Future<List<NeighbourTower>> neighbours() async => const [
        NeighbourTower(
          towerName: 'Tower-A',
          flats: [
            NeighbourFlat(flatId: 'fa1', number: '101', residents: [Resident(name: 'Riya Mehta', role: UserRole.owner)]),
            NeighbourFlat(flatId: 'fa2', number: '102', residents: [Resident(name: 'Kiran Rathod', role: UserRole.owner)]),
          ],
        ),
      ];

  @override
  Future<List<Complaint>> complaints({ComplaintStatus? status, int? limit}) async =>
      sampleComplaints.where((c) => status == null || c.status == status).toList();

  @override
  Future<void> postComplaint(ComplaintInput input) async => postedComplaints.add(input);

  @override
  Future<void> updateComplaintStatus(String id, ComplaintStatus status) async => statusChanges.add((id, status));

  @override
  Future<List<SocietyEvent>> events({int? limit}) async => sampleEvents;
}

class FakeFacilitiesRepository extends FacilitiesRepository {
  FakeFacilitiesRepository() : super(_unused);

  final booked = <(String, DateTime)>[];

  @override
  Future<List<Facility>> list() async => sampleFacilities;

  @override
  Future<List<Slot>> slots(String facilityId, DateTime day) async => [
        for (var h = 6; h < 10; h++)
          Slot(
            startsAt: DateTime(day.year, day.month, day.day, h),
            endsAt: DateTime(day.year, day.month, day.day, h + 1),
            // Tomorrow 07:00 is taken; everything else is free.
            available: !(h == 7 && day.day != _now.day),
            mine: false,
            remaining: 1,
          ),
      ];

  @override
  Future<Booking> book(String facilityId, DateTime startsAt) async {
    booked.add((facilityId, startsAt));
    return Booking(
      id: 'b${booked.length}',
      facilityId: facilityId,
      facilityName: 'Badminton Court',
      startsAt: startsAt,
      endsAt: startsAt.add(const Duration(hours: 1)),
    );
  }

  @override
  Future<List<Booking>> myBookings() async => [];
}
