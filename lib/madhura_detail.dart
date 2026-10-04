import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firestore_database.dart';
import 'madhura_board.dart' as board;

void showMasterClassDetails(BuildContext context, Map<String, dynamic> data) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => MasterClassDetailPage(data: data)));
}

class MasterClassDetailPage extends StatelessWidget {
  const MasterClassDetailPage({super.key, required this.data});
  final Map<String, dynamic> data;

  Future<void> copy(BuildContext context, String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> openInMaps(BuildContext context, String link) async {
    final location = Uri.tryParse(link);
    if (location == null || !location.hasScheme) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This class has an invalid Maps link.')),
        );
      }
      return;
    }
    final opened = await launchUrl(
      location,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Maps location.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = board.listingFormat(data);
    final image = (data['image_url'] ?? '').toString();
    final imageBase64 = (data['image_base64'] ?? '').toString();
    final title = (data['title'] ?? 'Class details').toString();
    final category =
        board.categories.keys
            .where((key) => board.categoryIds[key] == data['category'])
            .firstOrNull ??
        'Class';
    final start = (data['start_date'] ?? '').toString();
    final end = (data['end_date'] ?? '').toString();
    final dates = start.isEmpty
        ? 'Dates to be announced'
        : end.isNotEmpty && end != start
        ? '$start – $end'
        : start;
    final place = format == 'online'
        ? 'Online'
        : (data['city'] ?? 'Bangalore').toString();
    final map = (data['map_location'] ?? '').toString();
    final spokenLanguages = (data['spoken_languages'] as List? ?? const [])
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .join(', ');
    final ageGroup = (data['age_group'] ?? '').toString();
    final expiryDate = (data['expiry_date'] ?? '').toString();
    final listingId = (data['id'] ?? '').toString();
    final isOwner = FirebaseAuth.instance.currentUser?.uid == data['creatorId'];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: board.paper,
        foregroundColor: board.ink,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'serif', fontSize: 17),
            ),
            Text(
              board.formats[format] ?? 'Class',
              style: const TextStyle(fontSize: 10, color: board.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Copy listing title',
            onPressed: () => copy(context, title, 'Listing title copied'),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 245,
            width: double.infinity,
            child: imageBase64.isNotEmpty
                ? Image.memory(base64Decode(imageBase64), fit: BoxFit.cover)
                : image.isEmpty
                ? Container(
                    color: const Color(0xFFEEDFCB),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: board.clay,
                      size: 74,
                    ),
                  )
                : Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: const Color(0xFFEEDFCB),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: board.clay,
                        size: 74,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 17, 16, 35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${board.formats[format] ?? 'Class'} · $category${data['subcategory'] == null ? '' : ' · ${data['subcategory']}'}'
                      .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: board.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 27,
                    height: 1.13,
                    fontWeight: FontWeight.w700,
                    color: board.ink,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _Stat('PRICE', board.listingPrice(data))),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _Stat(
                        format == 'competition' ? 'WINDOW' : 'DATES',
                        dates,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: _Stat('WHERE', place)),
                  ],
                ),
                const SizedBox(height: 15),
                if ((data['description'] ?? '').toString().isNotEmpty)
                  _Section(
                    format == 'competition'
                        ? 'ABOUT THIS COMPETITION'
                        : 'ABOUT THIS CLASS',
                    data['description'].toString(),
                  ),
                if ((data['about_master'] ?? '').toString().isNotEmpty)
                  _Section('ABOUT THE MASTER', data['about_master'].toString()),
                if (spokenLanguages.isNotEmpty)
                  _Section('CLASS LANGUAGE', spokenLanguages),
                if (ageGroup.isNotEmpty)
                  _Section('SUITABLE AGE GROUP', ageGroup),
                if (expiryDate.isNotEmpty)
                  _Section('LISTING EXPIRES', expiryDate),
                if (listingId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  if (isOwner) ...[
                    ClassInterestCount(listingId: listingId),
                    _OwnerInterestList(listingId: listingId),
                  ] else
                    _ClassInterestPanel(listingId: listingId, title: title),
                  const SizedBox(height: 13),
                ],
                if (map.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(15),
                    margin: const EdgeInsets.only(bottom: 13),
                    decoration: BoxDecoration(
                      color: board.paper,
                      border: Border.all(color: board.border),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VENUE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: board.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 9),
                        OutlinedButton.icon(
                          onPressed: () => openInMaps(context, map),
                          icon: const Icon(Icons.location_on_outlined),
                          label: const Text('Open in Maps'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    height: 66,
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: board.paper,
      border: Border.all(color: board.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: board.muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: board.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.body);
  final String title, body;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    margin: const EdgeInsets.only(bottom: 13),
    decoration: BoxDecoration(
      color: board.paper,
      border: Border.all(color: board.border),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            color: board.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          body,
          style: const TextStyle(fontSize: 14, height: 1.5, color: board.ink),
        ),
      ],
    ),
  );
}

class ClassInterestCount extends StatelessWidget {
  const ClassInterestCount({super.key, required this.listingId});
  final String listingId;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('listings')
            .doc(listingId)
            .collection('interests')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const SizedBox.shrink();
          final count =
              (snapshot.data?.docs ??
                      const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                  .where((doc) => doc.data()['status'] == 'interested')
                  .length;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            margin: const EdgeInsets.only(bottom: 13),
            decoration: BoxDecoration(
              color: board.paper,
              border: Border.all(color: board.border),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_outline, color: board.clay),
                const SizedBox(width: 9),
                Text(
                  '$count learner${count == 1 ? '' : 's'} interested',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: board.ink,
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _ClassInterestPanel extends StatefulWidget {
  const _ClassInterestPanel({required this.listingId, required this.title});
  final String listingId;
  final String title;

  @override
  State<_ClassInterestPanel> createState() => _ClassInterestPanelState();
}

class _ClassInterestPanelState extends State<_ClassInterestPanel> {
  bool saving = false;
  String? error;
  final contact = TextEditingController();

  @override
  void dispose() {
    contact.dispose();
    super.dispose();
  }

  Future<void> updateInterest(String? currentStatus) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    final contactValue = contact.text.trim();
    if (currentStatus != 'interested' &&
        contactValue.isNotEmpty &&
        contactValue.length < 5) {
      setState(
        () => error = 'Enter a valid contact number, or leave it empty.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final ref = firestore
        .collection('listings')
        .doc(widget.listingId)
        .collection('interests')
        .doc(user.uid);
    try {
      if (currentStatus == 'interested') {
        await ref.delete();
      } else {
        await ref.set({
          'listingId': widget.listingId,
          'listingTitle': widget.title,
          'userId': user.uid,
          'userName': user.displayName ?? '',
          'userEmail': user.email ?? '',
          if (contactValue.isNotEmpty) 'contactNumber': contactValue,
          'status': 'interested',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } on FirebaseException catch (e) {
      if (mounted) setState(() => error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    final ref = firestore
        .collection('listings')
        .doc(widget.listingId)
        .collection('interests')
        .doc(user.uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        final status = snapshot.data?.data()?['status']?.toString();
        final interested = status == 'interested';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!interested) ...[
              TextField(
                controller: contact,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Your WhatsApp / contact number (optional)',
                  helperText: 'Shared only with the class owner.',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              onPressed: saving ? null : () => updateInterest(status),
              icon: Icon(
                interested ? Icons.check_circle : Icons.favorite_border,
              ),
              label: Text(
                interested ? 'Interested · Tap to remove' : 'Express interest',
              ),
            ),
            if (interested) _PrivateClassAccess(listingId: widget.listingId),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: const TextStyle(color: board.clay)),
              ),
          ],
        );
      },
    );
  }
}

class _PrivateClassAccess extends StatelessWidget {
  const _PrivateClassAccess({required this.listingId});
  final String listingId;

  Future<void> _open(BuildContext context, String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the session link.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: firestore.collection('listings_contact').doc(listingId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
            );
          final data = snapshot.data!.data();
          if (data == null)
            return const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'The owner has not added private session details yet.',
                style: TextStyle(color: board.muted),
              ),
            );
          final contact = (data['contactNumber'] ?? '').toString();
          final session = (data['sessionLink'] ?? '').toString();
          return Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: board.paper,
              border: Border.all(color: board.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRIVATE CLASS ACCESS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    color: board.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (contact.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SelectableText('Owner contact: $contact'),
                ],
                if (session.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _open(context, session),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open session link'),
                  ),
                ],
              ],
            ),
          );
        },
      );
}

class _OwnerInterestList extends StatelessWidget {
  const _OwnerInterestList({required this.listingId});
  final String listingId;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: firestore
        .collection('listings')
        .doc(listingId)
        .collection('interests')
        .snapshots(),
    builder: (context, snapshot) {
      final people =
          snapshot.data?.docs
              .where((doc) => doc.data()['status'] == 'interested')
              .toList() ??
          [];
      if (people.isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: board.paper,
          border: Border.all(color: board.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'INTERESTED LEARNERS',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.1,
                color: board.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final person in people)
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Text(
                  '${person.data()['userName'] ?? person.data()['userEmail'] ?? 'Learner'}${(person.data()['contactNumber'] ?? '').toString().isEmpty ? '' : ' · ${person.data()['contactNumber']}'}',
                ),
              ),
          ],
        ),
      );
    },
  );
}
