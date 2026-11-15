import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'class_batches.dart';
import 'class_roster.dart';
import 'firestore_database.dart';
import 'notification_inbox.dart';

class ClassAnnouncement {
  const ClassAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.batchId,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String batchId;
  final String createdAt;

  static ClassAnnouncement fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ClassAnnouncement(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      batchId: (data['batchId'] ?? '').toString(),
      createdAt: (data['createdAt'] ?? '').toString(),
    );
  }
}

class AnnouncementStore {
  AnnouncementStore._();
  static final instance = AnnouncementStore._();
  final _demo = <String, List<ClassAnnouncement>>{};

  Future<List<ClassAnnouncement>> load(String listingId) async {
    if (listingId.startsWith('demo_')) {
      return List<ClassAnnouncement>.from(_demo[listingId] ?? const []);
    }
    final snap = await firestore
        .collection('listings')
        .doc(listingId)
        .collection('announcements')
        .get();
    final items = snap.docs.map(ClassAnnouncement.fromDoc).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> post({
    required Map<String, dynamic> listing,
    required String title,
    required String body,
    required String batchId,
  }) async {
    final listingId = (listing['id'] ?? '').toString();
    final createdAt = DateTime.now().toIso8601String();
    final announcement = ClassAnnouncement(
      id: 'a${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      batchId: batchId,
      createdAt: createdAt,
    );
    final price = listing['price'];
    final roster = await ClassRosterStore.instance.load(
      listingId: listingId,
      feeAmount: price is num ? price.round() : int.tryParse('$price') ?? 0,
      feePeriod: (listing['fee_period'] ?? '').toString() == 'course' ? 'course' : 'month',
    );
    final families = roster.enrollments.where((family) {
      if (batchId.isEmpty) return true;
      return family.attendees.any((person) => person.batchId == batchId);
    });
    if (listingId.startsWith('demo_')) {
      _demo.putIfAbsent(listingId, () => []).insert(0, announcement);
    } else {
      await firestore.collection('listings').doc(listingId).collection('announcements').add({
        'title': title,
        'body': body,
        'batchId': batchId,
        'createdAt': createdAt,
        'authorId': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
    }
    for (final family in families) {
      if (family.userId.startsWith('demo_')) continue;
      await postInboxNote(
        userId: family.userId,
        title: title,
        body: body,
        kind: 'announcement',
      );
    }
  }
}

class AnnouncementsSection extends StatefulWidget {
  const AnnouncementsSection({super.key, required this.listing, required this.asMaster});

  final Map<String, dynamic> listing;
  final bool asMaster;

  @override
  State<AnnouncementsSection> createState() => _AnnouncementsSectionState();
}

class _AnnouncementsSectionState extends State<AnnouncementsSection> {
  List<ClassAnnouncement> items = [];
  List<ClassBatch> batches = [];

  String get listingId => (widget.listing['id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await AnnouncementStore.instance.load(listingId);
    final loadedBatches = await BatchStore.instance.load(listingId);
    if (!mounted) return;
    setState(() {
      items = loaded;
      batches = loadedBatches;
    });
  }

  Future<void> _compose() async {
    final title = TextEditingController();
    final body = TextEditingController();
    var batchId = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Announcement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
              TextField(
                controller: body,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
              DropdownButtonFormField<String>(
                initialValue: batchId,
                decoration: const InputDecoration(labelText: 'Who hears this'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Everyone enrolled')),
                  for (final batch in batches)
                    DropdownMenuItem(value: batch.id, child: Text(batch.name)),
                ],
                onChanged: (value) => setLocal(() => batchId = value ?? ''),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Send')),
          ],
        ),
      ),
    );
    final heading = title.text.trim();
    final message = body.text.trim();
    title.dispose();
    body.dispose();
    if (saved != true || heading.isEmpty || message.isEmpty) return;
    await AnnouncementStore.instance.post(
      listing: widget.listing,
      title: heading,
      body: message,
      batchId: batchId,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ANNOUNCEMENTS', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted, letterSpacing: 1)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text('No announcements yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.muted)),
        for (final item in items)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: appCardDecoration(context, radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleSmall),
                Text(item.body),
                if (item.batchId.isNotEmpty)
                  Text('Batch ${item.batchId}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.muted)),
              ],
            ),
          ),
        if (widget.asMaster)
          OutlinedButton.icon(
            onPressed: _compose,
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('Post announcement'),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
