import 'package:dio/dio.dart';
import 'package:the_grids/core/network/api_exception.dart';
import 'package:the_grids/features/gate/data/gate_repository.dart';
import 'package:the_grids/features/gate/domain/gate_models.dart';
import 'package:the_grids/features/tower/domain/tower_models.dart';

final _unused = Dio();

const passNotFound = ApiException(code: 'PASS_NOT_FOUND', message: 'no pass', statusCode: 404);

/// Gate passes, daily help, SOS and vehicles in memory. Calls are recorded.
class FakeGateRepository extends GateRepository {
  FakeGateRepository() : super(_unused);

  List<DailyHelp> helpers = [
    const DailyHelp(
      id: 'dh1',
      name: 'Rekha Jadhav',
      kind: 'Maid',
      phone: '+919300000001',
      passCode: '24680',
      flatLabels: ['Tower-C, 502'],
      inside: true,
      daysThisMonth: 21,
    ),
  ];
  List<Vehicle> vehicleList = const [
    Vehicle(id: 've1', number: 'MH04AB1234', type: VehicleType.car, description: 'White Swift', parkingSlot: 'C-12', flatLabel: 'Tower-C, 502'),
  ];

  /// What [verifyPass] answers, by code.
  Map<String, PassCheck> passes = {
    '482913': const GuestPass(
      Visitor(id: 'v9', name: 'Kavya', type: VisitorType.guest, status: VisitorStatus.expected, flatLabel: 'Tower-C, 502'),
    ),
    '24680': const StaffPass(id: 'dh1', name: 'Rekha Jadhav', kind: 'Maid', inside: false, flatLabels: ['Tower-C, 502']),
  };

  final checkedCodes = <String>[];
  final attendanceMarks = <String>[];
  final addedHelpers = <(String, String, String?)>[];
  final removedHelpers = <String>[];
  final sosRaised = <String?>[];
  final sosResolved = <String>[];
  final addedVehicles = <VehicleInput>[];
  final slots = <(String, String?)>[];
  final searches = <String>[];

  @override
  Future<PassCheck> verifyPass(String code) async {
    checkedCodes.add(code);
    return passes[code.replaceFirst(RegExp('^grids:(pass|staff):'), '')] ?? (throw passNotFound);
  }

  @override
  Future<List<DailyHelp>> dailyHelp() async => List.of(helpers);

  @override
  Future<DailyHelp> addDailyHelp({required String name, required String kind, String? phone}) async {
    addedHelpers.add((name, kind, phone));
    final h = DailyHelp(id: 'dh${helpers.length + 1}', name: name, kind: kind, phone: phone, passCode: '13579', inside: false, daysThisMonth: 0);
    helpers = [...helpers, h];
    return h;
  }

  @override
  Future<void> removeDailyHelp(String id) async {
    removedHelpers.add(id);
    helpers = helpers.where((h) => h.id != id).toList();
  }

  @override
  Future<DailyHelp> markAttendance(String id) async {
    attendanceMarks.add(id);
    return helpers.firstWhere((h) => h.id == id, orElse: () => helpers.first);
  }

  @override
  Future<AttendanceMonth> attendance(String id, {String? month}) async => AttendanceMonth(
        month: '2026-10',
        days: 1,
        entries: [AttendanceEntry(inTime: DateTime(2026, 10, 28, 9), outTime: DateTime(2026, 10, 28, 11))],
      );

  @override
  Future<SosAlert> raiseSos({String? note}) async {
    sosRaised.add(note);
    return SosAlert(id: 'sos1', status: SosStatus.active, createdAt: DateTime.now(), note: note);
  }

  @override
  Future<SosAlert> resolveSos(String id) async {
    sosResolved.add(id);
    return SosAlert(id: id, status: SosStatus.resolved, createdAt: DateTime.now());
  }

  @override
  Future<List<Vehicle>> vehicles() async => vehicleList;

  @override
  Future<Vehicle> addVehicle(VehicleInput input) async {
    addedVehicles.add(input);
    final v = Vehicle(id: 've${vehicleList.length + 1}', number: input.number.toUpperCase().replaceAll(' ', ''), type: input.type);
    vehicleList = [...vehicleList, v];
    return v;
  }

  @override
  Future<Vehicle> setParkingSlot(String id, String? slot) async {
    slots.add((id, slot));
    return vehicleList.first;
  }

  @override
  Future<List<Vehicle>> searchVehicles(String query) async {
    searches.add(query);
    return [
      for (final v in vehicleList)
        if (v.number.contains(query.toUpperCase()))
          Vehicle(
            id: v.id,
            number: v.number,
            type: v.type,
            description: v.description,
            parkingSlot: v.parkingSlot,
            flatLabel: v.flatLabel,
            contacts: const [(name: 'Shruti Chetan Dalvi', phone: '+919000000001')],
          ),
    ];
  }
}
