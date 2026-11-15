import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_moderation.dart';
import 'app_theme.dart';
import 'class_announcements.dart';
import 'class_batches.dart';
import 'class_interest_sheet.dart';
import 'class_reminders.dart';
import 'class_reviews.dart';
import 'class_roster.dart';
import 'class_roster_pages.dart';
import 'firestore_database.dart';
import 'learner_badges.dart';
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
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
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
    final physicalPlace = [
      (data['area'] ?? '').toString(),
      (data['city'] ?? '').toString(),
    ].where((value) => value.isNotEmpty).join(', ');
    final place = format == 'online'
        ? 'Online'
        : physicalPlace.isEmpty
        ? 'Any city'
        : physicalPlace;
    final map = (data['map_location'] ?? '').toString();
    final spokenLanguages = (data['spoken_languages'] as List? ?? const [])
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .join(', ');
    final ageGroup = (data['age_group'] ?? '').toString();
    final expiryDate = (data['expiry_date'] ?? '').toString();
    final listingId = (data['id'] ?? '').toString();
    final isOwner = FirebaseAuth.instance.currentUser?.uid == data['creatorId'];
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium,
            ),
            Text(
              board.formats[format] ?? 'Class',
              style: text.labelSmall?.copyWith(color: colors.muted),
            ),
          ],
        ),
        actions: [
          AdminDeletePostButton(listingId: listingId, title: title),
          IconButton(
            tooltip: 'Copy listing title',
            onPressed: () => copy(context, title, 'Listing title copied'),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 245,
                width: double.infinity,
                child: imageBase64.isNotEmpty
                    ? Image.memory(
                        base64Decode(imageBase64),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: colors.imageFallback,
                          child: Icon(
                            Icons.auto_stories_outlined,
                            size: 64,
                            color: colors.accent,
                          ),
                        ),
                      )
                    : image.isEmpty
                    ? ColoredBox(
                        color: colors.imageFallback,
                        child: Icon(
                          Icons.auto_stories_outlined,
                          size: 64,
                          color: colors.accent,
                        ),
                      )
                    : Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: colors.imageFallback,
                          child: Icon(
                            Icons.auto_stories_outlined,
                            size: 64,
                            color: colors.accent,
                          ),
                        ),
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
                  '${board.formats[format] ?? 'Class'} · $category${data['subcategory'] == null ? '' : ' · ${data['subcategory']}'}',
                  style: text.bodySmall?.copyWith(color: colors.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: text.headlineSmall?.copyWith(color: colors.ink),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _Stat('PRICE', board.listingPrice(data))),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _Stat(
                        format == 'competition' || format == 'event'
                            ? 'WHEN'
                            : 'DATES',
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
                        : format == 'event'
                        ? 'ABOUT THIS EVENT'
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
                if (classSupportsRoster(format)) ...[
                  const SizedBox(height: 4),
                  CertificateButton(listing: data),
                  AnnouncementsSection(listing: data, asMaster: isOwner),
                  if (isOwner)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BatchesPage(listing: data),
                        ),
                      ),
                      icon: const Icon(Icons.groups_outlined),
                      label: const Text('Batches'),
                    ),
                  if (isOwner) const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => openEnrolment(context, data),
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Enrol attendees'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => openAttendance(context, data),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Attendance'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => openFees(context, data),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Fees'),
                  ),
                  const SizedBox(height: 14),
                ],
                if (listingId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  if (isOwner) ...[
                    ClassInterestCount(listingId: listingId),
                    _OwnerInterestList(listingId: listingId),
                  ] else
                    _ClassInterestPanel(
                      listingId: listingId,
                      title: title,
                      listing: data,
                    ),
                  const SizedBox(height: 13),
                ],
                ClassReviewsSection(listing: data),
                const SizedBox(height: 16),
                if (map.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(15),
                    margin: const EdgeInsets.only(bottom: 13),
                    decoration: BoxDecoration(
                      color: colors.card,
                      border: Border.all(color: colors.line),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VENUE',
                          style: text.labelSmall?.copyWith(
                            letterSpacing: 1.1,
                            color: colors.muted,
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
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: colors.muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall?.copyWith(color: colors.ink),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.body);
  final String title, body;
  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: text.bodyMedium?.copyWith(color: colors.ink)),
        ],
      ),
    );
  }
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
          final colors = AppPalette.of(context);
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(Icons.people_outline, color: colors.onAccentSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$count learner${count == 1 ? '' : 's'} interested',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: colors.onAccentSoft),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _ClassInterestPanel extends StatefulWidget {
  const _ClassInterestPanel({
    required this.listingId,
    required this.title,
    this.listing,
  });
  final String listingId;
  final String title;
  final Map<String, dynamic>? listing;

  @override
  State<_ClassInterestPanel> createState() => _ClassInterestPanelState();
}

class _ClassInterestPanelState extends State<_ClassInterestPanel> {
  bool saving = false;
  String? error;

  Future<void> removeInterest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
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
      await ref.delete();
      await cancelClassReminders(widget.listingId);
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
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (interested) {
                        await removeInterest();
                        return;
                      }
                      await showClassInterestSheet(
                        context: context,
                        listingId: widget.listingId,
                        title: widget.title,
                        listing: widget.listing,
                        joining: true,
                      );
                    },
              icon: Icon(
                interested ? Icons.check_circle : Icons.favorite_border,
              ),
              label: Text(
                interested ? 'Interested · Tap to remove' : 'Interested / Join',
              ),
            ),
            if (interested)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showClassInterestSheet(
                    context: context,
                    listingId: widget.listingId,
                    title: widget.title,
                    listing: widget.listing,
                    joining: false,
                  ),
                  icon: const Icon(Icons.contact_phone_outlined),
                  label: const Text('Master contact'),
                ),
              ),
            if (interested) _PrivateClassAccess(listingId: widget.listingId),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the session link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: firestore.collection('listings_contact').doc(listingId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
            );
          }
          final data = snapshot.data!.data();
          if (data == null) {
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'The owner has not added private session details yet.',
                style: TextStyle(color: AppPalette.of(context).muted),
              ),
            );
          }
          final contact = (data['contactNumber'] ?? '').toString();
          final session = (data['sessionLink'] ?? '').toString();
          final colors = AppPalette.of(context);
          return Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRIVATE CLASS ACCESS',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(letterSpacing: 1.1, color: colors.muted),
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
      final colors = AppPalette.of(context);
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INTERESTED LEARNERS',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(letterSpacing: 1.1, color: colors.muted),
            ),
            for (final person in people)
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Text(
                  '${person.data()['userName'] ?? person.data()['userEmail'] ?? 'Learner'}${(person.data()['mcId'] ?? '').toString().isEmpty ? '' : ' · ${person.data()['mcId']}'}${(person.data()['contactNumber'] ?? '').toString().isEmpty ? '' : ' · ${person.data()['contactNumber']}'}',
                ),
              ),
          ],
        ),
      );
    },
  );
}
