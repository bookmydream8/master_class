import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_database.dart';

class Attendee {
  const Attendee({
    required this.id,
    required this.name,
    this.age = '',
    this.phone = '',
  });

  final String id;
  final String name;
  final String age;
  final String phone;

  Attendee copyWith({String? name, String? age, String? phone}) => Attendee(
    id: id,
    name: name ?? this.name,
    age: age ?? this.age,
    phone: phone ?? this.phone,
  );

  Map<String, String> toMap() => {'id': id, 'name': name, 'age': age, 'phone': phone};

  static Attendee fromMap(Map<String, dynamic> data) => Attendee(
    id: (data['id'] ?? '').toString(),
    name: (data['name'] ?? '').toString(),
    age: (data['age'] ?? '').toString(),
    phone: (data['phone'] ?? '').toString(),
  );
}

class ClassEnrollment {
  const ClassEnrollment({
    required this.mcId,
    required this.userId,
    required this.userName,
    required this.attendees,
  });

  final String mcId;
  final String userId;
  final String userName;
  final List<Attendee> attendees;

  String keyFor(Attendee attendee) => '$mcId:${attendee.id}';
}

class FeeLine {
  const FeeLine({
    required this.mcId,
    required this.attendeeId,
    required this.attendeeName,
    required this.amountDue,
    required this.amountPaid,
    required this.unitAmount,
    required this.monthsBilled,
    required this.feePeriod,
    this.paidAt = '',
  });

  final String mcId;
  final String attendeeId;
  final String attendeeName;

  /// Total billed for this attendee. Monthly fees are unit × months.
  final int amountDue;
  final int amountPaid;
  final int unitAmount;
  final int monthsBilled;
  final String feePeriod;
  final String paidAt;

  int get pending => (amountDue - amountPaid).clamp(0, amountDue);
  bool get settled => amountDue == 0 || amountPaid >= amountDue;
  String get key => '$mcId:$attendeeId';

  FeeLine copyWith({int? amountDue, int? amountPaid, String? paidAt}) => FeeLine(
    mcId: mcId,
    attendeeId: attendeeId,
    attendeeName: attendeeName,
    amountDue: amountDue ?? this.amountDue,
    amountPaid: amountPaid ?? this.amountPaid,
    unitAmount: unitAmount,
    monthsBilled: monthsBilled,
    feePeriod: feePeriod,
    paidAt: paidAt ?? this.paidAt,
  );
}

class ClassRoster {
  const ClassRoster({
    required this.enrollments,
    required this.sessionDates,
    required this.marks,
    required this.fees,
    required this.feeAmount,
    required this.feePeriod,
  });

  final List<ClassEnrollment> enrollments;

  /// Session dates, newest last.
  final List<String> sessionDates;

  /// date -> attendee key -> present | absent
  final Map<String, Map<String, String>> marks;
  final List<FeeLine> fees;
  final int feeAmount;
  final String feePeriod;

  int attended(String key) => sessionDates
      .where((date) => marks[date]?[key] == 'present')
      .length;

  int get totalDue => fees.fold(0, (total, fee) => total + fee.amountDue);

  int get totalPaid => fees.fold(0, (total, fee) => total + fee.amountPaid);

  int get totalPending => fees.fold(0, (total, fee) => total + fee.pending);
}

String feePeriodLabel(String period) =>
    period == 'course' ? 'one-time course fee' : 'per month';

int monthsSince(String enrolledAt) {
  final start = DateTime.tryParse(enrolledAt);
  if (start == null) return 1;
  final now = DateTime.now();
  final months = (now.year - start.year) * 12 + now.month - start.month + 1;
  return months < 1 ? 1 : months;
}

bool classSupportsRoster(String format) => format == 'online' || format == 'physical';

class ClassRosterStore {
  ClassRosterStore._();
  static final instance = ClassRosterStore._();

  final _demo = <String, ClassRoster>{};
  bool _seeded = false;

  bool isDemo(String listingId) => listingId.startsWith('demo_');

  Future<ClassRoster> load({
    required String listingId,
    required int feeAmount,
    required String feePeriod,
  }) async {
    if (isDemo(listingId)) {
      _ensureDemo();
      return _demo[listingId] ??
          ClassRoster(
            enrollments: const [],
            sessionDates: _recentDates(),
            marks: const {},
            fees: const [],
            feeAmount: feeAmount,
            feePeriod: feePeriod,
          );
    }
    final root = firestore.collection('listings').doc(listingId);
    final enrollmentDocs = await root.collection('enrollments').get();
    final attendanceDocs = await root.collection('attendance').get();
    final feeDocs = await root.collection('fees').get();
    final enrollments = enrollmentDocs.docs.map(_enrollmentFromDoc).toList();
    final marks = <String, Map<String, String>>{};
    final dates = <String>[];
    for (final doc in attendanceDocs.docs) {
      dates.add(doc.id);
      final raw = doc.data()['marks'];
      marks[doc.id] = raw is Map
          ? raw.map((key, value) => MapEntry(key.toString(), value.toString()))
          : {};
    }
    dates.sort();
    if (dates.isEmpty) dates.addAll(_recentDates());
    final fees = feeDocs.docs.map((doc) {
      final data = doc.data();
      final period = (data['feePeriod'] ?? feePeriod).toString();
      final unit = (data['unitAmount'] as num?)?.toInt() ?? feeAmount;
      final enrolledAt = (data['enrolledAt'] ?? '').toString();
      final months = period == 'course' ? 1 : monthsSince(enrolledAt);
      final due = period == 'course' ? unit : unit * months;
      final storedPaid = (data['amountPaid'] as num?)?.toInt();
      final legacyPaid = (data['status'] ?? '') == 'paid';
      final paid = (storedPaid ?? (legacyPaid ? due : 0)).clamp(0, due);
      return FeeLine(
        mcId: (data['mcId'] ?? '').toString(),
        attendeeId: (data['attendeeId'] ?? '').toString(),
        attendeeName: (data['attendeeName'] ?? '').toString(),
        amountDue: due,
        amountPaid: paid,
        unitAmount: unit,
        monthsBilled: months,
        feePeriod: period == 'course' ? 'course' : 'month',
        paidAt: (data['paidAt'] ?? '').toString(),
      );
    }).toList();
    return ClassRoster(
      enrollments: enrollments,
      sessionDates: dates,
      marks: marks,
      fees: fees,
      feeAmount: feeAmount,
      feePeriod: feePeriod,
    );
  }

  Future<void> saveEnrollment({
    required String listingId,
    required ClassEnrollment enrollment,
    required int feeAmount,
    required String feePeriod,
  }) async {
    if (isDemo(listingId)) {
      _ensureDemo();
      final current = await load(
        listingId: listingId,
        feeAmount: feeAmount,
        feePeriod: feePeriod,
      );
      final enrollments = [
        for (final item in current.enrollments)
          if (item.mcId != enrollment.mcId) item,
        if (enrollment.attendees.isNotEmpty) enrollment,
      ];
      final kept = enrollment.attendees.map((item) => item.id).toSet();
      final fees = [
        for (final fee in current.fees)
          if (fee.mcId != enrollment.mcId || kept.contains(fee.attendeeId)) fee,
        for (final attendee in enrollment.attendees)
          if (!current.fees.any(
            (fee) => fee.mcId == enrollment.mcId && fee.attendeeId == attendee.id,
          ))
            FeeLine(
              mcId: enrollment.mcId,
              attendeeId: attendee.id,
              attendeeName: attendee.name,
              amountDue: feePeriod == 'course' ? feeAmount : feeAmount,
              amountPaid: 0,
              unitAmount: feeAmount,
              monthsBilled: 1,
              feePeriod: feePeriod == 'course' ? 'course' : 'month',
            ),
      ];
      _demo[listingId] = ClassRoster(
        enrollments: enrollments,
        sessionDates: current.sessionDates,
        marks: current.marks,
        fees: fees,
        feeAmount: feeAmount,
        feePeriod: feePeriod,
      );
      return;
    }
    final root = firestore.collection('listings').doc(listingId);
    final ref = root.collection('enrollments').doc(enrollment.mcId);
    if (enrollment.attendees.isEmpty) {
      await ref.delete();
      return;
    }
    await ref.set({
      'mcId': enrollment.mcId,
      'userId': enrollment.userId,
      'userName': enrollment.userName,
      'attendees': enrollment.attendees.map((item) => item.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final attendee in enrollment.attendees) {
      final feeRef = root.collection('fees').doc('${enrollment.mcId}_${attendee.id}');
      final existing = await feeRef.get();
      if (!existing.exists) {
        await feeRef.set({
          'mcId': enrollment.mcId,
          'attendeeId': attendee.id,
          'attendeeName': attendee.name,
          'unitAmount': feeAmount,
          'amountPaid': 0,
          'monthsBilled': 1,
          'enrolledAt': DateTime.now().toIso8601String(),
          'paidAt': '',
          'feePeriod': feePeriod == 'course' ? 'course' : 'month',
        });
      } else {
        await feeRef.set({
          'attendeeName': attendee.name,
          'unitAmount': feeAmount,
          'feePeriod': feePeriod == 'course' ? 'course' : 'month',
        }, SetOptions(merge: true));
      }
    }
  }

  Future<void> markAttendance({
    required String listingId,
    required String date,
    required String attendeeKey,
    required String status,
    required int feeAmount,
    required String feePeriod,
  }) async {
    if (isDemo(listingId)) {
      final current = await load(
        listingId: listingId,
        feeAmount: feeAmount,
        feePeriod: feePeriod,
      );
      final dates = {...current.sessionDates, date}.toList()..sort();
      final marks = {
        for (final entry in current.marks.entries) entry.key: Map<String, String>.from(entry.value),
      };
      marks.putIfAbsent(date, () => {});
      marks[date]![attendeeKey] = status;
      _demo[listingId] = ClassRoster(
        enrollments: current.enrollments,
        sessionDates: dates,
        marks: marks,
        fees: current.fees,
        feeAmount: feeAmount,
        feePeriod: feePeriod,
      );
      return;
    }
    final ref = firestore
        .collection('listings')
        .doc(listingId)
        .collection('attendance')
        .doc(date);
    final existing = await ref.get();
    if (!existing.exists) {
      await ref.set({
        'date': date,
        'marks': {attendeeKey: status},
      });
    } else {
      await ref.update({'marks.$attendeeKey': status});
    }
  }

  Future<void> recordPayment({
    required String listingId,
    required FeeLine fee,
    required int amountPaid,
  }) async {
    final paid = amountPaid.clamp(0, fee.amountDue);
    final paidAt = paid > 0 ? DateTime.now().toIso8601String().substring(0, 10) : '';
    if (isDemo(listingId)) {
      _ensureDemo();
      final current = _demo[listingId];
      if (current == null) return;
      _demo[listingId] = ClassRoster(
        enrollments: current.enrollments,
        sessionDates: current.sessionDates,
        marks: current.marks,
        fees: [
          for (final item in current.fees)
            item.key == fee.key ? item.copyWith(amountPaid: paid, paidAt: paidAt) : item,
        ],
        feeAmount: current.feeAmount,
        feePeriod: current.feePeriod,
      );
      return;
    }
    await firestore
        .collection('listings')
        .doc(listingId)
        .collection('fees')
        .doc('${fee.mcId}_${fee.attendeeId}')
        .set({
          'mcId': fee.mcId,
          'attendeeId': fee.attendeeId,
          'attendeeName': fee.attendeeName,
          'unitAmount': fee.unitAmount,
          'amountPaid': paid,
          'monthsBilled': fee.monthsBilled,
          'paidAt': paidAt,
          'feePeriod': fee.feePeriod,
        }, SetOptions(merge: true));
  }

  void _ensureDemo() {
    if (_seeded) return;
    _seeded = true;
    final dates = _recentDates();
    _demo['demo_online_0'] = _sample(
      feeAmount: 800,
      feePeriod: 'month',
      dates: dates,
      families: const [
        (
          'MC100245',
          'Anita Deshpande',
          [
            ('asha', 'Asha Deshpande', '9', '9845011122'),
            ('ravi', 'Ravi Deshpande', '12', '9845011122'),
          ],
        ),
        (
          'MC100318',
          'Kiran Patel',
          [('kiran', 'Kiran Patel', '34', '9900012345')],
        ),
      ],
      presentPattern: const ['present', 'present', 'absent', 'present'],
    );
    _demo['demo_physical_25'] = _sample(
      feeAmount: 1000,
      feePeriod: 'month',
      dates: dates,
      families: const [
        (
          'MC100402',
          'Leela Krishnan',
          [
            ('leela', 'Leela Krishnan', '38', '9886010101'),
            ('arun', 'Arun Krishnan', '11', '9886010101'),
          ],
        ),
        (
          'MC100511',
          'Farhan Ali',
          [('farhan', 'Farhan Ali', '16', '')],
        ),
      ],
      presentPattern: const ['present', 'absent', 'present', 'present'],
    );
    // One-time course fee (French café A1, ₹1500). First family is settled;
    // the second has paid only part of the course fee.
    _demo['demo_online_6'] = _sample(
      feeAmount: 1500,
      feePeriod: 'course',
      dates: dates,
      families: const [
        (
          'MC100245',
          'Anita Deshpande',
          [('asha', 'Asha Deshpande', '9', '9845011122')],
        ),
        (
          'MC100318',
          'Kiran Patel',
          [('kiran', 'Kiran Patel', '34', '9900012345')],
        ),
      ],
      presentPattern: const ['present', 'present', 'present', 'absent'],
    );
  }

  ClassRoster _sample({
    required int feeAmount,
    required String feePeriod,
    required List<String> dates,
    required List<(String, String, List<(String, String, String, String)>)> families,
    required List<String> presentPattern,
  }) {
    final enrollments = <ClassEnrollment>[];
    final fees = <FeeLine>[];
    final marks = <String, Map<String, String>>{};
    for (final date in dates) {
      marks[date] = {};
    }
    for (var familyIndex = 0; familyIndex < families.length; familyIndex++) {
      final family = families[familyIndex];
      final attendees = [
        for (final person in family.$3)
          Attendee(id: person.$1, name: person.$2, age: person.$3, phone: person.$4),
      ];
      enrollments.add(
        ClassEnrollment(
          mcId: family.$1,
          userId: 'demo_${family.$1}',
          userName: family.$2,
          attendees: attendees,
        ),
      );
      for (var index = 0; index < attendees.length; index++) {
        final attendee = attendees[index];
        final key = '${family.$1}:${attendee.id}';
        final months = feePeriod == 'course' ? 1 : (attendees.length > 1 ? 2 : 1);
        final due = feeAmount * months;
        final paidAmount = feePeriod == 'course'
            ? (familyIndex == 0 ? due : due ~/ 3)
            : index == 0
            ? (attendees.length > 1 ? due : due ~/ 2)
            : due ~/ 3;
        fees.add(
          FeeLine(
            mcId: family.$1,
            attendeeId: attendee.id,
            attendeeName: attendee.name,
            amountDue: due,
            amountPaid: paidAmount,
            unitAmount: feeAmount,
            monthsBilled: months,
            feePeriod: feePeriod == 'course' ? 'course' : 'month',
            paidAt: paidAmount > 0 ? dates.last : '',
          ),
        );
        for (var session = 0; session < dates.length; session++) {
          final pattern = presentPattern[session % presentPattern.length];
          marks[dates[session]]![key] = index == 1 && session == 1 ? 'absent' : pattern;
        }
      }
    }
    return ClassRoster(
      enrollments: enrollments,
      sessionDates: dates,
      marks: marks,
      fees: fees,
      feeAmount: feeAmount,
      feePeriod: feePeriod == 'course' ? 'course' : 'month',
    );
  }

  ClassEnrollment _enrollmentFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final attendees = (data['attendees'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Attendee.fromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
        .toList();
    return ClassEnrollment(
      mcId: (data['mcId'] ?? doc.id).toString(),
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? '').toString(),
      attendees: attendees,
    );
  }
}

List<String> _recentDates() {
  final today = DateTime.now();
  return [
    for (final days in [21, 14, 7, 0])
      _formatDay(today.subtract(Duration(days: days))),
  ];
}

String _formatDay(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String newAttendeeId() => 'a${DateTime.now().microsecondsSinceEpoch}';
