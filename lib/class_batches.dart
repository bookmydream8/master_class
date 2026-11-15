import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'class_roster.dart';
import 'firestore_database.dart';

class ClassBatch {
  const ClassBatch({
    required this.id,
    required this.name,
    required this.days,
    required this.time,
    required this.capacity,
    required this.startDate,
    required this.endDate,
  });

  final String id;
  final String name;
  final List<String> days;
  final String time;
  final int capacity;
  final String startDate;
  final String endDate;

  static ClassBatch fromMap(String id, Map<String, dynamic> data) => ClassBatch(
    id: id,
    name: (data['name'] ?? '').toString(),
    days: (data['days'] as List? ?? const []).map((item) => item.toString()).toList(),
    time: (data['time'] ?? '').toString(),
    capacity: (data['capacity'] as num?)?.toInt() ?? 0,
    startDate: (data['startDate'] ?? '').toString(),
    endDate: (data['endDate'] ?? '').toString(),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'days': days,
    'time': time,
    'capacity': capacity,
    'startDate': startDate,
    'endDate': endDate,
  };
}

int _feeAmount(Map<String, dynamic> data) {
  final price = data['price'];
  if (price is num) return price.round();
  return int.tryParse('$price') ?? 0;
}

String _feePeriod(Map<String, dynamic> data) =>
    (data['fee_period'] ?? '').toString() == 'course' ? 'course' : 'month';

class BatchStore {
  BatchStore._();
  static final instance = BatchStore._();
  final _demo = <String, List<ClassBatch>>{};
  var _seeded = false;

  void _seed() {
    if (_seeded) return;
    _seeded = true;
    const morning = ClassBatch(
      id: 'morning',
      name: 'Morning batch',
      days: ['Mon', 'Wed'],
      time: '07:00',
      capacity: 8,
      startDate: '2026-11-16',
      endDate: '2026-12-31',
    );
    const evening = ClassBatch(
      id: 'evening',
      name: 'Evening batch',
      days: ['Tue', 'Thu'],
      time: '18:00',
      capacity: 8,
      startDate: '2026-11-16',
      endDate: '2026-12-31',
    );
    _demo['demo_online_0'] = [morning, evening];
    _demo['demo_physical_25'] = [morning, evening];
  }

  Future<List<ClassBatch>> load(String listingId) async {
    if (listingId.startsWith('demo_')) {
      _seed();
      return List<ClassBatch>.from(_demo[listingId] ?? const []);
    }
    final snap = await firestore.collection('listings').doc(listingId).collection('batches').get();
    return snap.docs.map((doc) => ClassBatch.fromMap(doc.id, doc.data())).toList();
  }

  Future<void> save(String listingId, ClassBatch batch) async {
    if (listingId.startsWith('demo_')) {
      _seed();
      final list = _demo.putIfAbsent(listingId, () => []);
      list.removeWhere((item) => item.id == batch.id);
      list.add(batch);
      return;
    }
    await firestore
        .collection('listings')
        .doc(listingId)
        .collection('batches')
        .doc(batch.id)
        .set(batch.toMap());
  }
}

class BatchesPage extends StatefulWidget {
  const BatchesPage({super.key, required this.listing});

  final Map<String, dynamic> listing;

  @override
  State<BatchesPage> createState() => _BatchesPageState();
}

class _BatchesPageState extends State<BatchesPage> {
  List<ClassBatch> batches = [];
  ClassRoster? roster;
  var loading = true;

  String get listingId => (widget.listing['id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loadedBatches = await BatchStore.instance.load(listingId);
    final loadedRoster = await ClassRosterStore.instance.load(
      listingId: listingId,
      feeAmount: _feeAmount(widget.listing),
      feePeriod: _feePeriod(widget.listing),
    );
    if (!mounted) return;
    setState(() {
      batches = loadedBatches;
      roster = loadedRoster;
      loading = false;
    });
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final time = TextEditingController(text: '18:00');
    final capacity = TextEditingController(text: '12');
    final days = <String>{'Sat'};
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('New batch'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                TextField(controller: time, decoration: const InputDecoration(labelText: 'Time')),
                TextField(
                  controller: capacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Capacity'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final day in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                      FilterChip(
                        label: Text(day),
                        selected: days.contains(day),
                        onSelected: (selected) => setLocal(() {
                          if (selected) {
                            days.add(day);
                          } else {
                            days.remove(day);
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final batchName = name.text.trim();
    final batchTime = time.text.trim();
    final seats = int.tryParse(capacity.text.trim()) ?? 12;
    name.dispose();
    time.dispose();
    capacity.dispose();
    if (saved != true || batchName.isEmpty) return;
    await BatchStore.instance.save(
      listingId,
      ClassBatch(
        id: 'b${DateTime.now().millisecondsSinceEpoch}',
        name: batchName,
        days: days.toList(),
        time: batchTime,
        capacity: seats,
        startDate: (widget.listing['start_date'] ?? '').toString(),
        endDate: (widget.listing['expiry_date'] ?? '').toString(),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final current = roster;
    return Scaffold(
      appBar: AppBar(title: const Text('Batches')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Batch'),
      ),
      body: loading || current == null
          ? const AppLoading(message: 'Loading batches')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              children: [
                Text((widget.listing['title'] ?? 'Class').toString(), style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Attendance and fees stay with each attendee. Assign them to a batch to teach them on those days.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppPalette.of(context).muted),
                ),
                const SizedBox(height: 12),
                for (final batch in batches)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: appCardDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(batch.name, style: Theme.of(context).textTheme.titleMedium),
                        Text('${batch.days.join(', ')} · ${batch.time} · ${batch.capacity} seats'),
                        Text('${batch.startDate} – ${batch.endDate}'),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text('Attendees', style: Theme.of(context).textTheme.titleMedium),
                for (final family in current.enrollments)
                  for (final person in family.attendees)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(person.name),
                      subtitle: Text('${family.mcId} · ${person.batchId.isEmpty ? 'No batch' : person.batchId}'),
                      trailing: DropdownButton<String>(
                        value: batches.any((batch) => batch.id == person.batchId) ? person.batchId : '',
                        items: [
                          const DropdownMenuItem(value: '', child: Text('None')),
                          for (final batch in batches)
                            DropdownMenuItem(value: batch.id, child: Text(batch.name)),
                        ],
                        onChanged: (value) async {
                          await ClassRosterStore.instance.assignBatch(
                            listingId: listingId,
                            mcId: family.mcId,
                            attendeeId: person.id,
                            batchId: value ?? '',
                          );
                          await _load();
                        },
                      ),
                    ),
              ],
            ),
    );
  }
}
