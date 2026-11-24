import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'app_theme.dart';
import 'category_style.dart';
import 'firestore_database.dart';
import 'home_illustrations.dart';
import 'notification_inbox.dart';
import 'spark_logic.dart';

const followFanOutCap = 30;
const materialByteLimit = 10 * 1024 * 1024;

class SharePosterButton extends StatelessWidget {
  const SharePosterButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.link,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String detail;
  final String link;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showPosterSheet(
        context,
        title: title,
        subtitle: subtitle,
        detail: detail,
        link: link,
        color: color,
      ),
      icon: const Icon(Icons.ios_share),
      label: const Text('Share poster'),
    );
  }
}

Future<void> showPosterSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String detail,
  required String link,
  required Color color,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => _PosterSheet(
      title: title,
      subtitle: subtitle,
      detail: detail,
      link: link,
      color: color,
    ),
  );
}

class _PosterSheet extends StatefulWidget {
  const _PosterSheet({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.link,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String detail;
  final String link;
  final Color color;

  @override
  State<_PosterSheet> createState() => _PosterSheetState();
}

class _PosterSheetState extends State<_PosterSheet> {
  final boundary = GlobalKey();
  bool busy = false;

  Future<Uint8List?> _png() async {
    final render = boundary.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary) return null;
    final image = await render.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  Future<void> share() async {
    setState(() => busy = true);
    try {
      final bytes = await _png();
      if (bytes == null) return;
      final file = File('${Directory.systemTemp.path}/master-class-poster.png');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png', name: 'poster.png')],
          text: widget.link,
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: boundary,
            child: _PosterCard(
              title: widget.title,
              subtitle: widget.subtitle,
              detail: widget.detail,
              link: widget.link,
              color: widget.color,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: widget.link)),
                  icon: const Icon(Icons.link),
                  label: const Text('Copy link'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : share,
                  icon: const Icon(Icons.ios_share),
                  label: Text(busy ? 'Preparing…' : 'Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.link,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String detail;
  final String link;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MASTER CLASS',
            style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(subtitle),
          const SizedBox(height: 4),
          Text(detail),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(6),
              child: QrImageView(data: link, size: 96, backgroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class FollowButton extends StatelessWidget {
  const FollowButton({super.key, required this.masterId, required this.masterName});

  final String masterId;
  final String masterName;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous || user.uid == masterId || masterId.isEmpty) {
      return const SizedBox.shrink();
    }
    final ref = firestore.collection('profiles').doc(user.uid).collection('following').doc(masterId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        final following = snapshot.data?.exists == true;
        return FilledButton.tonalIcon(
          onPressed: () => following
              ? unfollowMaster(masterId)
              : followMaster(masterId, masterName),
          icon: Icon(following ? Icons.check : Icons.person_add_alt),
          label: Text(following ? 'Following' : 'Follow'),
        );
      },
    );
  }
}

Future<void> followMaster(String masterId, String masterName) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final me = firestore.collection('profiles').doc(user.uid);
  final master = firestore.collection('profiles').doc(masterId);
  await me.collection('following').doc(masterId).set({
    'masterId': masterId,
    'name': masterName,
    'followedAt': FieldValue.serverTimestamp(),
  });
  await master.collection('followers').doc(user.uid).set({
    'userId': user.uid,
    'name': user.displayName ?? 'Learner',
    'followedAt': FieldValue.serverTimestamp(),
  });
  await firestore.runTransaction((tx) async {
    final snap = await tx.get(master);
    final count = (snap.data()?['followerCount'] as num?)?.toInt() ?? 0;
    tx.set(master, {'followerCount': count + 1}, SetOptions(merge: true));
  });
}

Future<void> unfollowMaster(String masterId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final master = firestore.collection('profiles').doc(masterId);
  await master.collection('followers').doc(user.uid).delete();
  await firestore.collection('profiles').doc(user.uid).collection('following').doc(masterId).delete();
  await firestore.runTransaction((tx) async {
    final snap = await tx.get(master);
    final count = (snap.data()?['followerCount'] as num?)?.toInt() ?? 0;
    tx.set(master, {'followerCount': count > 0 ? count - 1 : 0}, SetOptions(merge: true));
  });
}

Future<void> notifyFollowersOfPost({
  required String masterId,
  required String title,
  required String kindLabel,
}) async {
  final followers = await firestore
      .collection('profiles')
      .doc(masterId)
      .collection('followers')
      .limit(followFanOutCap)
      .get();
  for (final follower in followers.docs) {
    await postInboxNote(
      userId: follower.id,
      title: 'New $kindLabel',
      body: '$title was just posted by someone you follow.',
      kind: 'new_class',
    );
  }
}

class FollowingSection extends StatelessWidget {
  const FollowingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('profiles')
          .doc(user.uid)
          .collection('following')
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Following', style: Theme.of(context).textTheme.titleMedium),
            for (final doc in docs)
              ListTile(
                title: Text((doc.data()['name'] ?? 'Master').toString()),
                trailing: TextButton(
                  onPressed: () => unfollowMaster(doc.id),
                  child: const Text('Unfollow'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class FollowingRail extends StatelessWidget {
  const FollowingRail({super.key, required this.listings, required this.onOpen});

  final List<Map<String, dynamic>> listings;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('profiles')
          .doc(user.uid)
          .collection('following')
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        final ids = (snapshot.data?.docs ?? []).map((doc) => doc.id).toSet();
        if (ids.isEmpty) return const SizedBox.shrink();
        final mine = listings
            .where((item) => ids.contains((item['creatorId'] ?? '').toString()))
            .take(8)
            .toList();
        if (mine.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const HomeIllustration('music', size: 32),
                const SizedBox(width: 8),
                Text('From masters you follow', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final item in mine)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text((item['title'] ?? 'Class').toString()),
                        onPressed: () => onOpen(item),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class FollowerCount extends StatelessWidget {
  const FollowerCount({super.key, required this.masterId});
  final String masterId;

  @override
  Widget build(BuildContext context) {
    if (masterId.isEmpty || masterId.startsWith('demo_')) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('profiles').doc(masterId).snapshots(),
      builder: (context, snapshot) {
        final count = (snapshot.data?.data()?['followerCount'] as num?)?.toInt() ?? 0;
        return Text('$count followers');
      },
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.verified = false});
  final bool verified;

  @override
  Widget build(BuildContext context) {
    if (!verified) return const SizedBox.shrink();
    return const Icon(Icons.verified, color: Color(0xFF1A6B73), size: 18);
  }
}

class VerificationSubmitButton extends StatelessWidget {
  const VerificationSubmitButton({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return const SizedBox.shrink();
    return OutlinedButton.icon(
      onPressed: () => _submit(context, user),
      icon: const Icon(Icons.badge_outlined),
      label: const Text('Request verified badge'),
    );
  }

  Future<void> _submit(BuildContext context, User user) async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (photo == null) return;
    final file = File(photo.path);
    if (await file.length() > materialByteLimit) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That file is over 10 MB.')),
        );
      }
      return;
    }
    final ref = FirebaseStorage.instance.ref('verification/${user.uid}/id.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await firestore.collection('profiles').doc(user.uid).collection('verification').doc('request').set({
      'status': 'pending',
      'note': 'ID or qualification',
      'url': url,
      'ownerId': user.uid,
      'name': user.displayName ?? '',
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sent for review. An admin can approve it.')),
      );
    }
  }
}

class AdminVerificationPage extends StatelessWidget {
  const AdminVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification requests')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore.collectionGroup('verification').limit(30).snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const AppEmpty(
              icon: Icons.verified_outlined,
              title: 'No requests',
              message: 'Masters submit an ID from Profile.',
            );
          }
          return ListView(
            children: [
              for (final doc in docs)
                ListTile(
                  title: Text((doc.data()['name'] ?? doc.reference.parent.parent?.id ?? 'Master').toString()),
                  subtitle: Text((doc.data()['status'] ?? '').toString()),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => _decide(doc, true),
                        child: const Text('Approve'),
                      ),
                      TextButton(
                        onPressed: () => _decide(doc, false),
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _decide(QueryDocumentSnapshot<Map<String, dynamic>> doc, bool approve) async {
    final uid = doc.reference.parent.parent?.id;
    await doc.reference.update({
      'status': approve ? 'approved' : 'rejected',
      'ownerId': uid,
    });
    if (uid != null && approve) {
      await firestore.collection('profiles').doc(uid).update({'verified': true});
    }
  }
}

class MaterialsButton extends StatelessWidget {
  const MaterialsButton({super.key, required this.listing});
  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MaterialsPage(listing: listing)),
      ),
      icon: const Icon(Icons.folder_outlined),
      label: const Text('Materials'),
    );
  }
}

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({super.key, required this.listing});
  final Map<String, dynamic> listing;

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  final link = TextEditingController();
  final note = TextEditingController();

  @override
  void dispose() {
    link.dispose();
    note.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get folder => firestore
      .collection('listings')
      .doc((widget.listing['id'] ?? '').toString())
      .collection('materials');

  Future<void> addLink(String kind) async {
    final user = FirebaseAuth.instance.currentUser;
    final text = kind == 'note' ? note.text.trim() : link.text.trim();
    if (user == null || text.isEmpty) return;
    await folder.add({
      'title': text,
      'kind': kind,
      'url': kind == 'link' ? text : '',
      'authorId': user.uid,
      'batchId': '',
      'size': text.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
    link.clear();
    note.clear();
  }

  Future<void> addImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (photo == null) return;
    final file = File(photo.path);
    final size = await file.length();
    if (size > materialByteLimit) return;
    final listingId = (widget.listing['id'] ?? '').toString();
    final storage = FirebaseStorage.instance.ref(
      'class_materials/$listingId/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await storage.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await storage.getDownloadURL();
    await folder.add({
      'title': 'Image',
      'kind': 'image',
      'url': url,
      'authorId': user.uid,
      'batchId': '',
      'size': size,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final owner = FirebaseAuth.instance.currentUser?.uid == widget.listing['creatorId'];
    return Scaffold(
      appBar: AppBar(title: const Text('Class materials')),
      body: Column(
        children: [
          if (owner)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(controller: link, decoration: const InputDecoration(labelText: 'Link')),
                  TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(onPressed: () => addLink('link'), child: const Text('Add link')),
                      TextButton(onPressed: () => addLink('note'), child: const Text('Add note')),
                      TextButton(onPressed: addImage, child: const Text('Add image')),
                    ],
                  ),
                  const Text('Images and PDFs stay under 10 MB. Only this class can see the list.'),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: folder.orderBy('createdAt', descending: true).limit(40).snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                return ListView(
                  children: [
                    for (final doc in docs)
                      ListTile(
                        title: Text((doc.data()['title'] ?? '').toString()),
                        subtitle: Text((doc.data()['kind'] ?? '').toString()),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NextUpCard extends StatelessWidget {
  const NextUpCard({super.key, required this.listings, required this.onOpen});

  final List<Map<String, dynamic>> listings;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final data in listings)
        if (listingStart(data) != null)
          ScheduleItem(
            title: (data['title'] ?? 'Class').toString(),
            start: listingStart(data)!,
            kind: (data['listing_type'] ?? 'class').toString(),
            place: (data['city'] ?? '').toString(),
            listingId: (data['id'] ?? '').toString(),
          ),
    ];
    final next = nextUp(items, DateTime.now());
    if (next == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const HomeIllustration('event', size: 40),
        title: Text('Next up · ${next.title}'),
        subtitle: Text('${next.start.day}/${next.start.month} · ${next.place}'),
        onTap: () {
          final match = listings.where((item) => item['id'] == next.listingId);
          if (match.isNotEmpty) onOpen(match.first);
        },
      ),
    );
  }
}

class MySchedulePage extends StatelessWidget {
  const MySchedulePage({super.key, required this.listings});
  final List<Map<String, dynamic>> listings;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final data in listings)
        if (listingStart(data) != null)
          ScheduleItem(
            title: (data['title'] ?? 'Class').toString(),
            start: listingStart(data)!,
            kind: (data['listing_type'] ?? 'class').toString(),
            place: (data['city'] ?? '').toString(),
          ),
    ];
    final now = DateTime.now();
    final week = sortSchedule(
      items.where((item) {
        final end = now.add(const Duration(days: 7));
        return !item.start.isBefore(DateTime(now.year, now.month, now.day)) &&
            item.start.isBefore(end);
      }).toList(),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('My schedule')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('This week', style: Theme.of(context).textTheme.titleLarge),
          if (week.isEmpty) const Text('Nothing on the schedule yet.'),
          for (final item in week)
            ListTile(
              title: Text(item.title),
              subtitle: Text(
                '${item.start.day}/${item.start.month} ${item.start.hour.toString().padLeft(2, '0')}:${item.start.minute.toString().padLeft(2, '0')} · ${item.place}',
              ),
              trailing: IconButton(
                tooltip: 'Add to calendar',
                icon: const Icon(Icons.event),
                onPressed: () async {
                  final ics = buildIcs(
                    title: item.title,
                    start: item.start,
                    end: item.start.add(const Duration(hours: 1)),
                    location: item.place,
                  );
                  final file = File('${Directory.systemTemp.path}/master-class.ics');
                  await file.writeAsString(ics);
                  await SharePlus.instance.share(
                    ShareParams(files: [XFile(file.path, mimeType: 'text/calendar', name: 'class.ics')]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class ChatButton extends StatelessWidget {
  const ChatButton({super.key, required this.listing});
  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatPage(listing: listing)),
      ),
      icon: const Icon(Icons.chat_bubble_outline),
      label: const Text('Message'),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.listing, this.batchId = ''});
  final Map<String, dynamic> listing;
  final String batchId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final text = TextEditingController();

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  String get listingId => (widget.listing['id'] ?? '').toString();
  String get chatId {
    final user = FirebaseAuth.instance.currentUser;
    if (widget.batchId.isNotEmpty) return 'batch_${widget.batchId}';
    final master = (widget.listing['creatorId'] ?? '').toString();
    if (user == null || user.uid == master) return user?.uid ?? 'direct';
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get messages => firestore
      .collection('listings')
      .doc(listingId)
      .collection('chats')
      .doc(chatId)
      .collection('messages');

  Future<void> send({String imageUrl = ''}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final body = text.text.trim();
    if (body.isEmpty && imageUrl.isEmpty) return;
    final chat = firestore.collection('listings').doc(listingId).collection('chats').doc(chatId);
    await chat.set({
      'listingId': listingId,
      'batchId': widget.batchId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await messages.add({
      'authorId': user.uid,
      'text': imageUrl.isEmpty ? body : '$body $imageUrl'.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    text.clear();
  }

  Future<void> block() async {
    final user = FirebaseAuth.instance.currentUser;
    final other = (widget.listing['creatorId'] ?? '').toString();
    if (user == null || other.isEmpty || other == user.uid) return;
    await firestore.collection('profiles').doc(user.uid).collection('blocks').doc(other).set({
      'userId': other,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> report() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await firestore.collection('reports').add({
      'reporterId': user.uid,
      'targetId': chatId,
      'reason': 'Chat report',
      'listingId': listingId,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report sent.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.batchId.isEmpty ? 'Message' : 'Batch chat'),
        actions: [
          IconButton(onPressed: report, icon: const Icon(Icons.flag_outlined)),
          IconButton(onPressed: block, icon: const Icon(Icons.block)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messages.orderBy('createdAt', descending: true).limit(30).snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    return ListTile(
                      title: Text((data['text'] ?? '').toString()),
                      subtitle: Text((data['authorId'] ?? '').toString()),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () async {
                    final photo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 60);
                    if (photo == null) return;
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;
                    final file = File(photo.path);
                    if (await file.length() > 8 * 1024 * 1024) return;
                    final storage = FirebaseStorage.instance.ref(
                      'chat_images/$listingId/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg',
                    );
                    await storage.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
                    final url = await storage.getDownloadURL();
                    await send(imageUrl: url);
                  },
                  icon: const Icon(Icons.image_outlined),
                ),
                Expanded(child: TextField(controller: text, decoration: const InputDecoration(hintText: 'Message'))),
                IconButton(onPressed: send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GalleryButton extends StatelessWidget {
  const GalleryButton({super.key, required this.listing});
  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GalleryPage(listing: listing)),
      ),
      icon: const Icon(Icons.photo_library_outlined),
      label: const Text('Student gallery'),
    );
  }
}

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key, required this.listing});
  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    final listingId = (listing['id'] ?? '').toString();
    final master = FirebaseAuth.instance.currentUser?.uid == listing['creatorId'];
    final folder = firestore.collection('listings').doc(listingId).collection('gallery');
    final query = master ? folder.limit(30) : folder.where('hidden', isEqualTo: false).limit(30);
    return Scaffold(
      appBar: AppBar(title: const Text('Student work')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          final photo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 60);
          if (photo == null) return;
          final file = File(photo.path);
          if (await file.length() > 8 * 1024 * 1024) return;
          final storage = FirebaseStorage.instance.ref(
            'class_gallery/$listingId/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await storage.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
          final url = await storage.getDownloadURL();
          await folder.add({
            'authorId': user.uid,
            'caption': 'Student work',
            'url': url,
            'hidden': false,
            'likes': 0,
            'createdAt': FieldValue.serverTimestamp(),
          });
          final masterId = (listing['creatorId'] ?? '').toString();
          if (masterId.isNotEmpty) {
            await postInboxNote(
              userId: masterId,
              title: 'New student work',
              body: 'A learner posted to ${(listing['title'] ?? 'the class')}.',
              kind: 'gallery',
            );
          }
        },
        child: const Icon(Icons.add_a_photo),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          return ListView(
            children: [
              for (final doc in docs)
                ListTile(
                  title: Text((doc.data()['caption'] ?? '').toString()),
                  subtitle: Text((doc.data()['url'] ?? '').toString(), maxLines: 1),
                  trailing: master
                      ? TextButton(
                          onPressed: () => doc.reference.update({'hidden': true}),
                          child: const Text('Hide'),
                        )
                      : IconButton(
                          icon: const Icon(Icons.favorite_border),
                          onPressed: () => doc.reference.update({
                            'likes': ((doc.data()['likes'] as num?)?.toInt() ?? 0) + 1,
                          }),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PolicyNote extends StatelessWidget {
  const PolicyNote({super.key, required this.listing});
  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    final hours = listing['cancelByHours'];
    final refund = (listing['refundPolicy'] ?? '').toString();
    final makeup = listing['makeupAllowed'] == true;
    if (hours == null && refund.isEmpty) return const SizedBox.shrink();
    final colors = AppPalette.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Cancel at least ${hours ?? 24} hours before. ${refund.isEmpty ? 'Ask the master about refunds.' : refund} Makeup class: ${makeup ? 'yes' : 'no'}.',
      ),
    );
  }
}

class SessionRequestButton extends StatelessWidget {
  const SessionRequestButton({super.key, required this.listing});
  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _ask(context),
      child: const Text('Request cancel or reschedule'),
    );
  }

  Future<void> _ask(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    var kind = 'cancel';
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Change a session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: kind,
              items: const [
                DropdownMenuItem(value: 'cancel', child: Text('Cancel')),
                DropdownMenuItem(value: 'reschedule', child: Text('Reschedule')),
              ],
              onChanged: (value) => kind = value ?? 'cancel',
            ),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Close')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;
    final listingId = (listing['id'] ?? '').toString();
    await firestore.collection('listings').doc(listingId).collection('sessionRequests').add({
      'userId': user.uid,
      'userName': user.displayName ?? 'Learner',
      'status': 'pending',
      'kind': kind,
      'note': note.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    final master = (listing['creatorId'] ?? '').toString();
    if (master.isNotEmpty) {
      await postInboxNote(
        userId: master,
        title: 'Session ${kind == 'cancel' ? 'cancellation' : 'reschedule'}',
        body: '${user.displayName ?? 'A learner'} asked to $kind ${(listing['title'] ?? 'a class')}.',
        kind: 'session_change',
      );
    }
    note.dispose();
  }
}

class SessionRequestList extends StatelessWidget {
  const SessionRequestList({super.key, required this.listingId});
  final String listingId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('listings')
          .doc(listingId)
          .collection('sessionRequests')
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final doc in docs)
              ListTile(
                title: Text('${doc.data()['kind']} · ${doc.data()['status']}'),
                subtitle: Text((doc.data()['note'] ?? '').toString()),
                trailing: doc.data()['status'] == 'pending'
                    ? Wrap(
                        children: [
                          TextButton(
                            onPressed: () => _set(doc, 'approved'),
                            child: const Text('Approve'),
                          ),
                          TextButton(
                            onPressed: () => _set(doc, 'declined'),
                            child: const Text('Decline'),
                          ),
                        ],
                      )
                    : null,
              ),
          ],
        );
      },
    );
  }

  Future<void> _set(QueryDocumentSnapshot<Map<String, dynamic>> doc, String status) async {
    await doc.reference.update({'status': status});
    final uid = (doc.data()['userId'] ?? '').toString();
    if (uid.isEmpty) return;
    await postInboxNote(
      userId: uid,
      title: 'Session request $status',
      body: 'The master $status your ${doc.data()['kind']} request.',
      kind: 'session_change',
    );
  }
}

Future<int?> lookupCouponDiscount({
  required String listingId,
  required String code,
  required int amount,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || code.trim().isEmpty) return null;
  final coupon = await firestore
      .collection('listings')
      .doc(listingId)
      .collection('coupons')
      .doc(code.trim().toUpperCase())
      .get();
  final data = coupon.data();
  if (data == null) return null;
  final starts = (data['starts'] as Timestamp?)?.toDate();
  final ends = (data['ends'] as Timestamp?)?.toDate();
  final usable = couponUsable(
    used: (data['used'] as num?)?.toInt() ?? 0,
    limit: (data['limit'] as num?)?.toInt() ?? 0,
    starts: starts,
    ends: ends,
    now: DateTime.now(),
  );
  if (!usable) return null;
  final prior = await firestore
      .collection('listings')
      .doc(listingId)
      .collection('couponUses')
      .doc(user.uid)
      .get();
  if (prior.exists) return null;
  return discountAmount(
    amount: amount,
    kind: (data['kind'] ?? 'flat').toString(),
    value: (data['value'] as num?)?.toInt() ?? 0,
  );
}

Future<void> redeemCoupon({required String listingId, required String code}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final id = code.trim().toUpperCase();
  final use = firestore.collection('listings').doc(listingId).collection('couponUses').doc(user.uid);
  final coupon = firestore.collection('listings').doc(listingId).collection('coupons').doc(id);
  await use.set({'userId': user.uid, 'code': id, 'counted': false});
  await firestore.runTransaction((tx) async {
    final snap = await tx.get(coupon);
    final used = (snap.data()?['used'] as num?)?.toInt() ?? 0;
    tx.update(coupon, {'used': used + 1});
    tx.update(use, {'counted': true});
  });
}

class CouponBox extends StatefulWidget {
  const CouponBox({super.key, required this.listingId, required this.amount});
  final String listingId;
  final int amount;

  @override
  State<CouponBox> createState() => _CouponBoxState();
}

class _CouponBoxState extends State<CouponBox> {
  final code = TextEditingController();
  String? message;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.listingId.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: code,
            decoration: InputDecoration(
              labelText: 'Coupon',
              helperText: message,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            final discount = await lookupCouponDiscount(
              listingId: widget.listingId,
              code: code.text,
              amount: widget.amount,
            );
            if (!mounted) return;
            if (discount == null) {
              setState(() => message = 'Code is not available.');
              return;
            }
            await redeemCoupon(listingId: widget.listingId, code: code.text);
            setState(() {
              message = '₹$discount off. Pay ₹${widget.amount - discount}.';
            });
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class CouponEditor extends StatelessWidget {
  const CouponEditor({super.key, required this.listingId});
  final String listingId;

  @override
  Widget build(BuildContext context) {
    if (listingId.isEmpty) return const SizedBox.shrink();
    return TextButton(
      onPressed: () => _create(context),
      child: const Text('Add a coupon'),
    );
  }

  Future<void> _create(BuildContext context) async {
    final code = TextEditingController();
    final value = TextEditingController(text: '10');
    var kind = 'percent';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Intro offer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')),
            TextField(
              controller: value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Percent or rupees'),
            ),
            DropdownButtonFormField<String>(
              initialValue: kind,
              items: const [
                DropdownMenuItem(value: 'percent', child: Text('Percent')),
                DropdownMenuItem(value: 'flat', child: Text('Flat ₹')),
              ],
              onChanged: (next) => kind = next ?? 'percent',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || code.text.trim().isEmpty) return;
    final now = DateTime.now();
    await firestore.collection('listings').doc(listingId).collection('coupons').doc(code.text.trim().toUpperCase()).set({
      'kind': kind,
      'value': int.tryParse(value.text.trim()) ?? 10,
      'used': 0,
      'limit': 50,
      'starts': Timestamp.fromDate(now),
      'ends': Timestamp.fromDate(now.add(const Duration(days: 30))),
    });
    code.dispose();
    value.dispose();
  }
}

String categoryColorHex(Map<String, dynamic> data) {
  final color = categoryStyleFor(data).tint;
  return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
}

bool isVerifiedListing(Map<String, dynamic> data) => data['verifiedMaster'] == true;
