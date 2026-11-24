import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'attendance_place.dart';
import 'category_style.dart';
import 'class_batches.dart';
import 'class_reminders.dart';
import 'class_roster.dart';
import 'firestore_database.dart';
import 'madhura_board.dart' as board;
import 'member_id.dart';
import 'upi_payment.dart';

int classFeeAmount(Map<String, dynamic> data) {
  final price = data['price'];
  if (price is num) return price.round();
  return int.tryParse('$price') ?? 0;
}

String classFeePeriod(Map<String, dynamic> data) {
  final period = (data['fee_period'] ?? data['feePeriod'] ?? '').toString();
  return period == 'course' ? 'course' : 'month';
}

Future<void> openEnrolment(BuildContext context, Map<String, dynamic> listing) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => EnrolmentPage(listing: listing)),
  );
}

Future<void> openAttendance(
  BuildContext context,
  Map<String, dynamic> listing, {
  bool? asMaster,
}) {
  final user = FirebaseAuth.instance.currentUser;
  final master = asMaster ?? user?.uid == listing['creatorId'];
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AttendancePage(listing: listing, asMaster: master),
    ),
  );
}

Future<void> openFees(
  BuildContext context,
  Map<String, dynamic> listing, {
  bool? asMaster,
}) {
  final user = FirebaseAuth.instance.currentUser;
  final master = asMaster ?? user?.uid == listing['creatorId'];
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FeesPage(listing: listing, asMaster: master),
    ),
  );
}

/// Overall Total, Paid, and Pending for every online or physical class
/// this signed-in master has posted.
Future<void> openAllClassFees(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final snap = await firestore
      .collection('listings')
      .where('creatorId', isEqualTo: user.uid)
      .get();
  final classes = snap.docs
      .map((doc) => {...doc.data(), 'id': doc.id})
      .where((data) {
        final type = (data['listing_type'] ?? data['type'] ?? '').toString();
        return type == 'online_class' || type == 'offline_class';
      })
      .toList();
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => FeesOverviewPage(classes: classes)),
  );
}

class EnrolmentPage extends StatefulWidget {
  const EnrolmentPage({super.key, required this.listing, this.viewerMcId});

  final Map<String, dynamic> listing;
  final String? viewerMcId;

  @override
  State<EnrolmentPage> createState() => _EnrolmentPageState();
}

class _EnrolmentPageState extends State<EnrolmentPage> {
  final name = TextEditingController();
  final age = TextEditingController();
  final phone = TextEditingController();
  List<Attendee> attendees = [];
  String mcId = '';
  String userName = '';
  bool loading = true;
  bool saving = false;
  String? error;

  String get listingId => (widget.listing['id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    var id = widget.viewerMcId ?? '';
    var display = user?.displayName ?? 'Member';
    if (id.isEmpty && user != null && !user.isAnonymous) {
      try {
        id = await ensureMemberId(user);
        display = user.displayName ?? display;
      } catch (e) {
        if (mounted) setState(() => error = 'Could not load your MC ID.');
      }
    }
    final roster = await ClassRosterStore.instance.load(
      listingId: listingId,
      feeAmount: classFeeAmount(widget.listing),
      feePeriod: classFeePeriod(widget.listing),
    );
    final mine = roster.enrollments.where((item) => item.mcId == id);
    if (!mounted) return;
    setState(() {
      mcId = id;
      userName = mine.isEmpty ? display : mine.first.userName;
      attendees = mine.isEmpty ? [] : [...mine.first.attendees];
      loading = false;
    });
  }

  void addAttendee() {
    final person = name.text.trim();
    if (person.length < 2) {
      setState(() => error = 'Enter the attendee name.');
      return;
    }
    setState(() {
      attendees = [
        ...attendees,
        Attendee(
          id: newAttendeeId(),
          name: person,
          age: age.text.trim(),
          phone: phone.text.trim(),
        ),
      ];
      name.clear();
      age.clear();
      phone.clear();
      error = null;
    });
  }

  Future<void> save() async {
    if (mcId.isEmpty) {
      setState(() => error = 'Sign in so we can attach these names to your MC ID.');
      return;
    }
    if (attendees.isEmpty) {
      setState(() => error = 'Add at least one attendee.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      await ClassRosterStore.instance.saveEnrollment(
        listingId: listingId,
        enrollment: ClassEnrollment(
          mcId: mcId,
          userId: user?.uid ?? 'demo_$mcId',
          userName: userName.isEmpty ? 'Member' : userName,
          attendees: attendees,
        ),
        feeAmount: classFeeAmount(widget.listing),
        feePeriod: classFeePeriod(widget.listing),
      );
      await scheduleClassReminders(widget.listing);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not save enrolment.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final style = categoryStyleFor(widget.listing);
    final title = (widget.listing['title'] ?? 'Class').toString();
    final fee = classFeeAmount(widget.listing);
    return Scaffold(
      appBar: AppBar(title: const Text('Enrol')),
      body: loading
          ? const AppLoading(message: 'Loading enrolment')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(title, style: text.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  fee == 0
                      ? 'Free · one MC ID can cover several people'
                      : '₹$fee ${feePeriodLabel(classFeePeriod(widget.listing))} · one MC ID covers every name below',
                  style: text.bodyMedium?.copyWith(color: colors.muted),
                ),
                if (mcId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  McIdBanner(mcId: mcId, compact: true),
                ],
                const SizedBox(height: 16),
                for (final person in attendees)
                  Card(
                    color: style.tint,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(person.name, style: text.titleSmall?.copyWith(color: style.ink)),
                      subtitle: Text(
                        [
                          if (person.age.isNotEmpty) 'Age ${person.age}',
                          if (person.phone.isNotEmpty) person.phone,
                        ].join(' · '),
                        style: text.bodySmall?.copyWith(color: style.ink),
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove attendee',
                        onPressed: () => setState(() {
                          attendees = [
                            for (final item in attendees)
                              if (item.id != person.id) item,
                          ];
                        }),
                        icon: Icon(Icons.close, color: style.ink),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text('Add someone', style: text.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: age,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Age (optional)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone (optional)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: addAttendee,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add attendee'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Saving…' : 'Save enrolment'),
                ),
              ],
            ),
    );
  }
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key, required this.listing, required this.asMaster, this.viewerMcId});

  final Map<String, dynamic> listing;
  final bool asMaster;
  final String? viewerMcId;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  ClassRoster? roster;
  List<ClassBatch> batches = [];
  String? date;
  String? batchFilter;
  String viewerMcId = '';
  bool loading = true;

  String get listingId => (widget.listing['id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    var id = widget.viewerMcId ?? '';
    if (id.isEmpty && user != null && !user.isAnonymous) {
      try {
        id = await ensureMemberId(user);
      } catch (_) {}
    }
    final loaded = await ClassRosterStore.instance.load(
      listingId: listingId,
      feeAmount: classFeeAmount(widget.listing),
      feePeriod: classFeePeriod(widget.listing),
    );
    final loadedBatches = await BatchStore.instance.load(listingId);
    if (!mounted) return;
    setState(() {
      roster = loaded;
      batches = loadedBatches;
      viewerMcId = id;
      date = loaded.sessionDates.isEmpty ? null : loaded.sessionDates.last;
      loading = false;
    });
  }

  Future<void> mark(String key, String status) async {
    final selected = date;
    final current = roster;
    if (selected == null || current == null) return;
    await ClassRosterStore.instance.markAttendance(
      listingId: listingId,
      date: selected,
      attendeeKey: key,
      status: status,
      feeAmount: current.feeAmount,
      feePeriod: current.feePeriod,
      recordPlace: board.listingFormat(widget.listing) != 'online',
      placeLat: (widget.listing['lat'] as num?)?.toDouble(),
      placeLng: (widget.listing['lng'] as num?)?.toDouble(),
      placeAddress: [
        widget.listing['area'],
        widget.listing['city'],
      ].whereType<Object>().map((part) => part.toString()).where((part) => part.isNotEmpty).join(', '),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final current = roster;
    final groups = current == null
        ? <ClassEnrollment>[]
        : widget.asMaster
        ? current.enrollments
        : current.enrollments.where((item) => item.mcId == viewerMcId).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: loading || current == null
          ? const AppLoading(message: 'Loading attendance')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Text((widget.listing['title'] ?? 'Class').toString(), style: text.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  widget.asMaster
                      ? 'Mark each person for the selected date.'
                      : 'Attendance for the people on your MC ID.',
                  style: text.bodyMedium?.copyWith(color: colors.muted),
                ),
                if (widget.asMaster && board.listingFormat(widget.listing) != 'online') ...[
                  const SizedBox(height: 8),
                  Text(attendanceLocationNotice, style: text.bodySmall),
                  if (date != null)
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: firestore
                          .collection('listings')
                          .doc(listingId)
                          .collection('attendancePlaces')
                          .doc(date)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final place = snapshot.data?.data();
                        if (place == null) return const SizedBox.shrink();
                        return AttendancePlaceCard(data: place);
                      },
                    ),
                ],
                const SizedBox(height: 12),
                if (batches.isNotEmpty)
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('All batches'),
                            selected: batchFilter == null,
                            onSelected: (_) => setState(() => batchFilter = null),
                          ),
                        ),
                        for (final batch in batches)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(batch.name),
                              selected: batchFilter == batch.id,
                              onSelected: (_) => setState(() => batchFilter = batch.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final session in current.sessionDates)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(session.substring(5)),
                            selected: date == session,
                            onSelected: (_) => setState(() => date = session),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (groups.isEmpty)
                  const AppEmpty(
                    icon: Icons.event_available_outlined,
                    title: 'No one enrolled yet',
                    message: 'Attendees appear here after a member enrols.',
                  )
                else
                  for (final family in groups) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: appCardDecoration(context, radius: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(family.mcId, style: text.titleMedium?.copyWith(color: colors.accent)),
                          Text(family.userName, style: text.bodySmall?.copyWith(color: colors.muted)),
                          const SizedBox(height: 8),
                          for (final person in family.attendees)
                            if (batchFilter == null || person.batchId == batchFilter)
                            _AttendanceRow(
                              name: person.name,
                              summary:
                                  '${current.attended(family.keyFor(person))} / ${current.sessionDates.length} sessions',
                              status: date == null ? null : current.marks[date]?[family.keyFor(person)],
                              enabled: widget.asMaster && date != null,
                              onChanged: (value) => mark(family.keyFor(person), value),
                            ),
                        ],
                      ),
                    ),
                  ],
              ],
            ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.name,
    required this.summary,
    required this.status,
    required this.enabled,
    required this.onChanged,
  });

  final String name;
  final String summary;
  final String? status;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.titleSmall),
                Text(summary, style: text.bodySmall),
              ],
            ),
          ),
          ChoiceChip(
            label: const Text('Present'),
            selected: status == 'present',
            onSelected: enabled ? (_) => onChanged('present') : null,
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('Absent'),
            selected: status == 'absent',
            onSelected: enabled ? (_) => onChanged('absent') : null,
          ),
        ],
      ),
    );
  }
}

class FeesPage extends StatefulWidget {
  const FeesPage({super.key, required this.listing, required this.asMaster, this.viewerMcId});

  final Map<String, dynamic> listing;
  final bool asMaster;
  final String? viewerMcId;

  @override
  State<FeesPage> createState() => _FeesPageState();
}

class _FeesPageState extends State<FeesPage> {
  ClassRoster? roster;
  String viewerMcId = '';
  bool loading = true;

  String get listingId => (widget.listing['id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    var id = widget.viewerMcId ?? '';
    if (id.isEmpty && user != null && !user.isAnonymous) {
      try {
        id = await ensureMemberId(user);
      } catch (_) {}
    }
    final loaded = await ClassRosterStore.instance.load(
      listingId: listingId,
      feeAmount: classFeeAmount(widget.listing),
      feePeriod: classFeePeriod(widget.listing),
    );
    if (!mounted) return;
    setState(() {
      roster = loaded;
      viewerMcId = id;
      loading = false;
    });
  }

  Future<void> record(FeeLine fee) async {
    final controller = TextEditingController(text: '${fee.pending}');
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Payment for ${fee.attendeeName}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Amount received',
            helperText: 'Pending ₹${fee.pending}. A smaller amount is a partial payment.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, int.tryParse(controller.text.trim())),
            child: const Text('Record'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0) return;
    final next = (fee.amountPaid + amount).clamp(0, fee.amountDue);
    await ClassRosterStore.instance.recordPayment(
      listingId: listingId,
      fee: fee,
      amountPaid: next,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final current = roster;
    final lines = current == null
        ? <FeeLine>[]
        : widget.asMaster
        ? current.fees
        : current.fees.where((fee) => fee.mcId == viewerMcId).toList();
    final due = lines.fold(0, (total, fee) => total + fee.amountDue);
    final paid = lines.fold(0, (total, fee) => total + fee.amountPaid);
    final groups = <String, List<FeeLine>>{};
    for (final fee in lines) {
      groups.putIfAbsent(fee.mcId, () => []).add(fee);
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.asMaster ? 'Fees summary' : 'Your fees')),
      body: loading || current == null
          ? const AppLoading(message: 'Loading fees')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Text((widget.listing['title'] ?? 'Class').toString(), style: text.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  current.feePeriod == 'course'
                      ? '₹${current.feeAmount} one-time course fee'
                      : '₹${current.feeAmount} per month · dues add up for each month enrolled',
                  style: text.bodyMedium?.copyWith(color: colors.muted),
                ),
                const SizedBox(height: 14),
                _Totals(due: due, paid: paid),
                if (widget.asMaster)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => openAllClassFees(context),
                      child: const Text('All class fees'),
                    ),
                  ),
                const SizedBox(height: 16),
                if (lines.isEmpty)
                  const AppEmpty(
                    icon: Icons.payments_outlined,
                    title: 'No fees yet',
                    message: 'A fee line is created for each enrolled attendee.',
                  )
                else
                  for (final entry in groups.entries) ...[
                    _McFeeHeader(mcId: entry.key, lines: entry.value),
                    for (final fee in entry.value) _FeeCard(
                      listing: widget.listing,
                      listingId: listingId,
                      fee: fee,
                      asMaster: widget.asMaster,
                      onRecord: () => record(fee),
                      onRefresh: _load,
                    ),
                  ],
              ],
            ),
    );
  }
}

class FeesOverviewPage extends StatefulWidget {
  const FeesOverviewPage({super.key, required this.classes});

  final List<Map<String, dynamic>> classes;

  @override
  State<FeesOverviewPage> createState() => _FeesOverviewPageState();
}

class _FeesOverviewPageState extends State<FeesOverviewPage> {
  var loading = true;
  final rows = <({String title, ClassRoster roster})>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = <({String title, ClassRoster roster})>[];
    for (final listing in widget.classes) {
      final roster = await ClassRosterStore.instance.load(
        listingId: (listing['id'] ?? '').toString(),
        feeAmount: classFeeAmount(listing),
        feePeriod: classFeePeriod(listing),
      );
      loaded.add((title: (listing['title'] ?? 'Class').toString(), roster: roster));
    }
    if (!mounted) return;
    setState(() {
      rows
        ..clear()
        ..addAll(loaded);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final due = rows.fold(0, (total, row) => total + row.roster.totalDue);
    final paid = rows.fold(0, (total, row) => total + row.roster.totalPaid);
    return Scaffold(
      appBar: AppBar(title: const Text('All class fees')),
      body: loading
          ? const AppLoading(message: 'Adding up fees')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Text('Overall', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Total, paid, and pending across these classes.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppPalette.of(context).muted,
                  ),
                ),
                const SizedBox(height: 14),
                _Totals(due: due, paid: paid),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  const AppEmpty(
                    icon: Icons.payments_outlined,
                    title: 'No class fees yet',
                    message: 'Post an online or physical class to collect fees.',
                  )
                else
                  for (final row in rows) ...[
                    Text(row.title, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      row.roster.feePeriod == 'course'
                          ? 'One-time course fee · ₹${row.roster.feeAmount}'
                          : 'Per month · ₹${row.roster.feeAmount}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.of(context).muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Totals(due: row.roster.totalDue, paid: row.roster.totalPaid),
                    const SizedBox(height: 14),
                  ],
              ],
            ),
    );
  }
}

class _McFeeHeader extends StatelessWidget {
  const _McFeeHeader({required this.mcId, required this.lines});
  final String mcId;
  final List<FeeLine> lines;

  @override
  Widget build(BuildContext context) {
    final due = lines.fold(0, (total, fee) => total + fee.amountDue);
    final paid = lines.fold(0, (total, fee) => total + fee.amountPaid);
    final colors = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mcId, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.accent)),
          Text(
            'This MC ID · Total ₹$due · Paid ₹$paid · Pending ₹${due - paid}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}

class _FeeCard extends StatelessWidget {
  const _FeeCard({
    required this.listing,
    required this.listingId,
    required this.fee,
    required this.asMaster,
    required this.onRecord,
    required this.onRefresh,
  });
  final Map<String, dynamic> listing;
  final String listingId;
  final FeeLine fee;
  final bool asMaster;
  final VoidCallback onRecord;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = AppPalette.of(context);
    final detail = fee.feePeriod == 'course'
        ? 'One-time course fee'
        : '₹${fee.unitAmount} × ${fee.monthsBilled} month${fee.monthsBilled == 1 ? '' : 's'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: appCardDecoration(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fee.attendeeName, style: text.titleSmall),
          Text(detail, style: text.bodySmall?.copyWith(color: colors.muted)),
          const SizedBox(height: 8),
          _Totals(due: fee.amountDue, paid: fee.amountPaid, compact: true),
          if (fee.paidAt.isNotEmpty)
            Text('Last payment ${fee.paidAt}', style: text.bodySmall?.copyWith(color: colors.muted)),
          if (asMaster && fee.utrStatus == 'submitted')
            Text('UTR ${fee.utr} · claims ₹${fee.claimedAmount}'),
          if (!asMaster)
            UpiPayPanel(
              listing: listing,
              fee: fee,
              onSubmitted: onRefresh,
            ),
          if (asMaster && fee.pending > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: fee.utrStatus == 'submitted'
                    ? () async {
                        final next = (fee.amountPaid + (fee.claimedAmount == 0 ? fee.pending : fee.claimedAmount))
                            .clamp(0, fee.amountDue);
                        await ClassRosterStore.instance.recordPayment(
                          listingId: listingId,
                          fee: fee,
                          amountPaid: next,
                        );
                        onRefresh();
                      }
                    : onRecord,
                child: Text(fee.utrStatus == 'submitted' ? 'Verify and mark paid' : 'Record payment'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.due, required this.paid, this.compact = false});
  final int due;
  final int paid;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MoneyCard(label: 'Total', amount: due, style: categoryStyleForId('language'), compact: compact)),
        const SizedBox(width: 8),
        Expanded(child: _MoneyCard(label: 'Paid', amount: paid, style: categoryStyleForId('yoga'), compact: compact)),
        const SizedBox(width: 8),
        Expanded(child: _MoneyCard(label: 'Pending', amount: (due - paid).clamp(0, due), style: categoryStyleForId('workshop'), compact: compact)),
      ],
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.label,
    required this.amount,
    required this.style,
    this.compact = false,
  });

  final String label;
  final int amount;
  final CategoryStyle style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: style.tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelSmall?.copyWith(color: style.ink)),
          const SizedBox(height: 2),
          Text(
            '₹$amount',
            style: (compact ? text.titleSmall : text.titleMedium)?.copyWith(color: style.ink),
          ),
        ],
      ),
    );
  }
}
