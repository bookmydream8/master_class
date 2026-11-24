import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'class_roster.dart';
import 'firestore_database.dart';
import 'member_id.dart';
import 'attendance_place.dart';

int feeTotal({
  required int unitAmount,
  required String feePeriod,
  int months = 1,
}) {
  if (unitAmount <= 0) return 0;
  if (feePeriod == 'course') return unitAmount;
  final count = months < 1 ? 1 : months;
  return unitAmount * count;
}

int feePending({required int total, required int paid}) {
  final pending = total - paid;
  return pending < 0 ? 0 : pending;
}

String monthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

class AcademyPage extends StatelessWidget {
  const AcademyPage({
    super.key,
    required this.academyId,
    this.teacherOnly = false,
  });

  final String academyId;
  final bool teacherOnly;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('academies').doc(academyId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = (data?['name'] ?? 'Academy').toString();
        final user = FirebaseAuth.instance.currentUser;
        final owner = user != null && data?['ownerId'] == user.uid;
        if (owner && !teacherOnly) {
          return AcademyDashboard(academyId: academyId, name: name);
        }
        return TeacherAcademyView(academyId: academyId, name: name);
      },
    );
  }
}

class AcademyDashboard extends StatelessWidget {
  const AcademyDashboard({
    super.key,
    required this.academyId,
    required this.name,
  });

  final String academyId;
  final String name;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Teachers'),
              Tab(text: 'Batches'),
              Tab(text: 'Students'),
              Tab(text: 'Summary'),
              Tab(text: 'Attendance'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TeachersTab(academyId: academyId),
            _BatchesTab(academyId: academyId),
            _StudentsTab(academyId: academyId),
            _SummaryTab(academyId: academyId),
            AcademyAttendancePlaces(academyId: academyId),
          ],
        ),
      ),
    );
  }
}

class _TeachersTab extends StatelessWidget {
  const _TeachersTab({required this.academyId});
  final String academyId;

  @override
  Widget build(BuildContext context) {
    final teachers = firestore
        .collection('academies')
        .doc(academyId)
        .collection('teachers');
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: teachers.snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const AppEmpty(
              icon: Icons.person_outline,
              title: 'No teachers yet',
              message: 'Invite a teacher with their MC ID, phone, or email.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final doc in docs)
                ListTile(
                  title: Text((doc.data()['name'] ?? 'Teacher').toString()),
                  subtitle: Text(
                    'Salary ₹${doc.data()['salaryAmount'] ?? 0} / month',
                  ),
                  trailing: TextButton(
                    onPressed: () => _paySalary(context, doc.id, doc.data()),
                    child: const Text('Pay'),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _invite(context),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Invite'),
      ),
    );
  }

  Future<void> _invite(BuildContext context) async {
    final mcId = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final salary = TextEditingController(text: '15000');
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Invite a teacher'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: mcId,
              decoration: const InputDecoration(labelText: 'MC ID'),
            ),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: salary,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monthly salary (₹)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final owner = FirebaseAuth.instance.currentUser;
    if (owner == null) return;
    final academy = await firestore
        .collection('academies')
        .doc(academyId)
        .get();
    final academyName = (academy.data()?['name'] ?? 'Academy').toString();
    final inviteId = '${DateTime.now().microsecondsSinceEpoch}';
    final payload = {
      'academyId': academyId,
      'academyName': academyName,
      'ownerId': owner.uid,
      'inviteMcId': mcId.text.trim(),
      'invitePhone': phone.text.trim(),
      'inviteEmail': email.text.trim().toLowerCase(),
      'teacherName': name.text.trim(),
      'salaryAmount': int.tryParse(salary.text.trim()) ?? 0,
      'status': 'invited',
      'createdAt': FieldValue.serverTimestamp(),
    };
    final batch = firestore.batch();
    batch.set(
      firestore
          .collection('academies')
          .doc(academyId)
          .collection('invites')
          .doc(inviteId),
      payload,
    );
    final emailKey = payload['inviteEmail'] as String;
    final mcKey = payload['inviteMcId'] as String;
    final phoneKey = payload['invitePhone'] as String;
    if (emailKey.isNotEmpty) {
      batch.set(
        firestore
            .collection('academyInvitesByEmail')
            .doc(emailKey)
            .collection('items')
            .doc(academyId),
        payload,
      );
    }
    if (mcKey.isNotEmpty) {
      batch.set(
        firestore
            .collection('academyInvitesByMc')
            .doc(mcKey)
            .collection('items')
            .doc(academyId),
        payload,
      );
    }
    if (phoneKey.isNotEmpty) {
      batch.set(
        firestore
            .collection('academyInvitesByPhone')
            .doc(phoneKey)
            .collection('items')
            .doc(academyId),
        payload,
      );
    }
    await batch.commit();
    mcId.dispose();
    phone.dispose();
    email.dispose();
    salary.dispose();
    name.dispose();
  }

  Future<void> _paySalary(
    BuildContext context,
    String teacherUid,
    Map<String, dynamic> teacher,
  ) async {
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Record salary payment'),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount paid now (₹)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final paidNow = int.tryParse(amount.text.trim()) ?? 0;
    amount.dispose();
    if (ok != true || paidNow <= 0) return;
    final key = monthKey(DateTime.now());
    final ref = firestore
        .collection('academies')
        .doc(academyId)
        .collection('salaries')
        .doc('${teacherUid}_$key');
    final total = (teacher['salaryAmount'] as num?)?.toInt() ?? 0;
    await firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final already = (snap.data()?['paid'] as num?)?.toInt() ?? 0;
      tx.set(ref, {
        'teacherUid': teacherUid,
        'month': key,
        'total': total,
        'paid': already + paidNow,
        'teacherName': teacher['name'] ?? '',
      });
    });
  }
}

class _BatchesTab extends StatelessWidget {
  const _BatchesTab({required this.academyId});
  final String academyId;

  @override
  Widget build(BuildContext context) {
    final batches = firestore
        .collection('academies')
        .doc(academyId)
        .collection('batches');
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: batches.snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const AppEmpty(
              icon: Icons.groups_outlined,
              title: 'No batches yet',
              message: 'Add a batch and assign a teacher.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final doc in docs)
                ListTile(
                  title: Text((doc.data()['name'] ?? 'Batch').toString()),
                  subtitle: Text(
                    '${doc.data()['schedule'] ?? ''} · ${doc.data()['capacity'] ?? 0} seats',
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Batch'),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final teachers = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('teachers')
        .get();
    if (!context.mounted) return;
    final name = TextEditingController();
    final schedule = TextEditingController(text: 'Mon, Wed · 17:00');
    final capacity = TextEditingController(text: '20');
    String? teacherUid = teachers.docs.isEmpty ? null : teachers.docs.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('New batch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Batch name'),
            ),
            TextField(
              controller: schedule,
              decoration: const InputDecoration(labelText: 'Schedule'),
            ),
            TextField(
              controller: capacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacity'),
            ),
            if (teachers.docs.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: teacherUid,
                items: [
                  for (final doc in teachers.docs)
                    DropdownMenuItem(
                      value: doc.id,
                      child: Text((doc.data()['name'] ?? doc.id).toString()),
                    ),
                ],
                onChanged: (value) => teacherUid = value,
                decoration: const InputDecoration(labelText: 'Teacher'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty && teacherUid != null) {
      await firestore
          .collection('academies')
          .doc(academyId)
          .collection('batches')
          .add({
            'name': name.text.trim(),
            'schedule': schedule.text.trim(),
            'capacity': int.tryParse(capacity.text.trim()) ?? 20,
            'teacherUid': teacherUid,
          });
    }
    name.dispose();
    schedule.dispose();
    capacity.dispose();
  }
}

class _StudentsTab extends StatelessWidget {
  const _StudentsTab({required this.academyId});
  final String academyId;

  @override
  Widget build(BuildContext context) {
    final students = firestore
        .collection('academies')
        .doc(academyId)
        .collection('students');
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: students.snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const AppEmpty(
              icon: Icons.school_outlined,
              title: 'No students yet',
              message: 'Add a student and their fee.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final doc in docs)
                _StudentTile(academyId: academyId, doc: doc),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Student'),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final batches = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('batches')
        .get();
    if (!context.mounted) return;
    final name = TextEditingController();
    final mcId = TextEditingController();
    final fee = TextEditingController(text: '2000');
    var period = 'month';
    String? batchId = batches.docs.isEmpty ? null : batches.docs.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add student'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: mcId,
                decoration: const InputDecoration(labelText: 'MC ID'),
              ),
              TextField(
                controller: fee,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fee amount (₹)'),
              ),
              DropdownButtonFormField<String>(
                initialValue: period,
                items: const [
                  DropdownMenuItem(value: 'month', child: Text('Per month')),
                  DropdownMenuItem(
                    value: 'course',
                    child: Text('One-time course fee'),
                  ),
                ],
                onChanged: (value) => setLocal(() => period = value ?? 'month'),
              ),
              if (batches.docs.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: batchId,
                  items: [
                    for (final doc in batches.docs)
                      DropdownMenuItem(
                        value: doc.id,
                        child: Text((doc.data()['name'] ?? doc.id).toString()),
                      ),
                  ],
                  onChanged: (value) => batchId = value,
                  decoration: const InputDecoration(labelText: 'Batch'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      final id = mcId.text.trim().isEmpty
          ? 'student_${DateTime.now().millisecondsSinceEpoch}'
          : mcId.text.trim();
      String teacherUid = '';
      if (batchId != null) {
        final batch = batches.docs.where((doc) => doc.id == batchId);
        if (batch.isNotEmpty) {
          teacherUid = (batch.first.data()['teacherUid'] ?? '').toString();
        }
      }
      await firestore
          .collection('academies')
          .doc(academyId)
          .collection('students')
          .doc(id)
          .set({
            'name': name.text.trim(),
            'mcId': mcId.text.trim(),
            'userId': '',
            'batchId': batchId ?? '',
            'batchTeacherUid': teacherUid,
            'unitAmount': int.tryParse(fee.text.trim()) ?? 0,
            'feePeriod': period,
            'monthsBilled': 1,
            'amountPaid': 0,
          });
    }
    name.dispose();
    mcId.dispose();
    fee.dispose();
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.academyId, required this.doc});
  final String academyId;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final total = feeTotal(
      unitAmount: (data['unitAmount'] as num?)?.toInt() ?? 0,
      feePeriod: (data['feePeriod'] ?? 'month').toString(),
      months: (data['monthsBilled'] as num?)?.toInt() ?? 1,
    );
    final paid = (data['amountPaid'] as num?)?.toInt() ?? 0;
    final pending = feePending(total: total, paid: paid);
    return ListTile(
      title: Text((data['name'] ?? 'Student').toString()),
      subtitle: Text('Total ₹$total · Paid ₹$paid · Pending ₹$pending'),
      trailing: TextButton(
        onPressed: () async {
          final next = paid + (pending > 0 ? pending : 0);
          await doc.reference.update({
            'amountPaid': next == paid ? paid + 1 : next,
          });
        },
        child: const Text('Mark paid'),
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.academyId});
  final String academyId;

  @override
  Widget build(BuildContext context) {
    final root = firestore.collection('academies').doc(academyId);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: root.collection('students').snapshots(),
      builder: (context, students) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: root.collection('salaries').snapshots(),
            builder: (context, salaries) {
              var feeDue = 0, feePaid = 0;
              for (final doc in students.data?.docs ?? const []) {
                final data = doc.data();
                final total = feeTotal(
                  unitAmount: (data['unitAmount'] as num?)?.toInt() ?? 0,
                  feePeriod: (data['feePeriod'] ?? 'month').toString(),
                  months: (data['monthsBilled'] as num?)?.toInt() ?? 1,
                );
                feeDue += total;
                feePaid += (data['amountPaid'] as num?)?.toInt() ?? 0;
              }
              var salaryDue = 0, salaryPaid = 0;
              for (final doc in salaries.data?.docs ?? const []) {
                salaryDue += (doc.data()['total'] as num?)?.toInt() ?? 0;
                salaryPaid += (doc.data()['paid'] as num?)?.toInt() ?? 0;
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _MoneyCard(
                    title: 'Student fees',
                    total: feeDue,
                    paid: feePaid,
                  ),
                  _MoneyCard(
                    title: 'Teacher salaries',
                    total: salaryDue,
                    paid: salaryPaid,
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.title,
    required this.total,
    required this.paid,
  });
  final String title;
  final int total;
  final int paid;

  @override
  Widget build(BuildContext context) {
    final pending = feePending(total: total, paid: paid);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Total ₹$total'),
          Text('Paid ₹$paid'),
          Text('Pending ₹$pending'),
        ],
      ),
    );
  }
}

class TeacherAcademyView extends StatelessWidget {
  const TeacherAcademyView({
    super.key,
    required this.academyId,
    required this.name,
  });
  final String academyId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final batches = firestore
        .collection('academies')
        .doc(academyId)
        .collection('batches')
        .where('teacherUid', isEqualTo: uid);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Your batches', style: Theme.of(context).textTheme.titleLarge),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: batches.snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Text('No batches assigned yet.');
              return Column(
                children: [
                  for (final doc in docs)
                    ListTile(
                      title: Text((doc.data()['name'] ?? 'Batch').toString()),
                      subtitle: Text((doc.data()['schedule'] ?? '').toString()),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          TextButton(
                            onPressed: () => _attendance(context, doc.id),
                            child: const Text('Attendance'),
                          ),
                          TextButton(
                            onPressed: () => _announce(context, doc.id),
                            child: const Text('Announce'),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Salary', style: Theme.of(context).textTheme.titleLarge),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: firestore
                .collection('academies')
                .doc(academyId)
                .collection('salaries')
                .where('teacherUid', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Text('No salary record yet.');
              return Column(
                children: [
                  for (final doc in docs)
                    _MoneyCard(
                      title: (doc.data()['month'] ?? '').toString(),
                      total: (doc.data()['total'] as num?)?.toInt() ?? 0,
                      paid: (doc.data()['paid'] as num?)?.toInt() ?? 0,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _attendance(BuildContext context, String batchId) async {
    final students = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('students')
        .where('batchId', isEqualTo: batchId)
        .get();
    if (!context.mounted) return;
    final marks = <String, String>{
      for (final doc in students.docs) doc.id: 'present',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Attendance'),
        content: StatefulBuilder(
          builder: (context, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your location is recorded when you mark attendance for this physical batch.',
              ),
              for (final doc in students.docs)
                SwitchListTile(
                  title: Text((doc.data()['name'] ?? doc.id).toString()),
                  value: marks[doc.id] != 'absent',
                  onChanged: (value) => setLocal(
                    () => marks[doc.id] = value ? 'present' : 'absent',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final today = DateTime.now();
    final date =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final academy = await firestore.collection('academies').doc(academyId).get();
    final info = academy.data() ?? const <String, dynamic>{};
    await firestore
        .collection('academies')
        .doc(academyId)
        .collection('attendance')
        .doc('${batchId}_$date')
        .set({
          'batchId': batchId,
          'date': date,
          'marks': marks,
          'authorId': uid,
          'teacherUid': uid,
        });
    await saveAcademyAttendancePlace(
      academyId: academyId,
      batchId: batchId,
      date: date,
      placeLat: (info['lat'] as num?)?.toDouble(),
      placeLng: (info['lng'] as num?)?.toDouble(),
      placeAddress: (info['address'] ?? '').toString(),
    );
  }

  Future<void> _announce(BuildContext context, String batchId) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Announcement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: body,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await firestore
          .collection('academies')
          .doc(academyId)
          .collection('announcements')
          .add({
            'batchId': batchId,
            'title': title.text.trim(),
            'body': body.text.trim(),
            'authorId': uid,
            'teacherUid': uid,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          });
    }
    title.dispose();
    body.dispose();
  }
}

class AcademyInvitesSection extends StatefulWidget {
  const AcademyInvitesSection({super.key});

  @override
  State<AcademyInvitesSection> createState() => _AcademyInvitesSectionState();
}

class _AcademyInvitesSectionState extends State<AcademyInvitesSection> {
  String email = '';
  String mcId = '';
  String phone = '';

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    email = (user.email ?? '').trim().toLowerCase();
    try {
      final data = (await firestore.collection('profiles').doc(user.uid).get())
          .data();
      mcId = (data?['mcId'] ?? '').toString().trim();
      phone = (data?['phoneNumber'] ?? '').toString().trim();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (email.isNotEmpty)
          _InviteInbox(
            stream: firestore
                .collection('academyInvitesByEmail')
                .doc(email)
                .collection('items')
                .snapshots(),
          ),
        if (mcId.isNotEmpty)
          _InviteInbox(
            stream: firestore
                .collection('academyInvitesByMc')
                .doc(mcId)
                .collection('items')
                .snapshots(),
          ),
        if (phone.isNotEmpty)
          _InviteInbox(
            stream: firestore
                .collection('academyInvitesByPhone')
                .doc(phone)
                .collection('items')
                .snapshots(),
          ),
      ],
    );
  }
}

class _InviteInbox extends StatelessWidget {
  const _InviteInbox({required this.stream});

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final invited = (snapshot.data?.docs ?? [])
            .where((doc) => doc.data()['status'] == 'invited')
            .toList();
        final teaching = (snapshot.data?.docs ?? [])
            .where((doc) => doc.data()['status'] == 'accepted')
            .toList();
        if (invited.isEmpty && teaching.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (invited.isNotEmpty)
              Text(
                'Academy invites',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            for (final doc in invited)
              ListTile(
                title: Text(
                  (doc.data()['academyName'] ?? 'Academy').toString(),
                ),
                subtitle: const Text('You are invited to teach'),
                trailing: FilledButton(
                  onPressed: () => acceptAcademyInvite(doc),
                  child: const Text('Accept'),
                ),
              ),
            for (final doc in teaching)
              ListTile(
                title: Text(
                  (doc.data()['academyName'] ?? 'Academy').toString(),
                ),
                subtitle: const Text('Teacher view'),
                trailing: TextButton(
                  onPressed: () => openAcademy(
                    context,
                    (doc.data()['academyId'] ?? doc.id).toString(),
                    teacher: true,
                  ),
                  child: const Text('Open'),
                ),
              ),
          ],
        );
      },
    );
  }
}

Future<void> acceptAcademyInvite(
  DocumentSnapshot<Map<String, dynamic>> invite,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final data = invite.data() ?? {};
  final academyId = (data['academyId'] ?? invite.id).toString();
  var mcId = '';
  try {
    mcId = await ensureMemberId(user);
  } catch (_) {}
  await invite.reference.update({'status': 'accepted', 'teacherUid': user.uid});
  await firestore
      .collection('academies')
      .doc(academyId)
      .collection('teachers')
      .doc(user.uid)
      .set({
        'userId': user.uid,
        'name': (data['teacherName'] ?? user.displayName ?? 'Teacher')
            .toString(),
        'salaryAmount': (data['salaryAmount'] as num?)?.toInt() ?? 0,
        'status': 'active',
        'mcId': mcId,
        'email': user.email ?? '',
      });
}

Future<String> createAcademyForListing({
  required String listingId,
  required String name,
  required String address,
  required String ownerId,
  String? imageBase64,
}) async {
  final ref = firestore.collection('academies').doc();
  await ref.set({
    'name': name,
    'address': address,
    'ownerId': ownerId,
    'listingId': listingId,
    'image_base64': ?imageBase64,
    'createdAt': FieldValue.serverTimestamp(),
  });
  await firestore.collection('listings').doc(listingId).set({
    'is_academy': true,
    'academyId': ref.id,
  }, SetOptions(merge: true));
  return ref.id;
}

/// Opens the right academy screen for the signed-in person.
void openAcademy(
  BuildContext context,
  String academyId, {
  bool teacher = false,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AcademyPage(academyId: academyId, teacherOnly: teacher),
    ),
  );
}

/// Keeps the fee helpers referenced the same way as class fees.
int studentFeePending(Map<String, dynamic> data) {
  final total = feeTotal(
    unitAmount: (data['unitAmount'] as num?)?.toInt() ?? 0,
    feePeriod: (data['feePeriod'] ?? 'month').toString(),
    months: (data['monthsBilled'] as num?)?.toInt() ?? 1,
  );
  return feePending(
    total: total,
    paid: (data['amountPaid'] as num?)?.toInt() ?? 0,
  );
}

// FeeLine is the class-roster model these academy totals mirror.
typedef AcademyFee = FeeLine;
