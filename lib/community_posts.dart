import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_profile.dart' show requireLogin;
import 'firestore_database.dart';
import 'madhura_board.dart' as board;

Future<void> openCommunityPost(
  BuildContext context,
  String kind, {
  String? listingId,
  Map<String, dynamic>? existing,
}) async {
  if (!await requireLogin(context) || !context.mounted) return;
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (_) => FractionallySizedBox(
      heightFactor: .94,
      child: CommunityPostForm(
        kind: kind,
        listingId: listingId,
        existing: existing,
      ),
    ),
  );
}

String communityPublicName(Object? value) {
  final name = (value ?? '').toString().trim();
  if (name.isEmpty || name.contains('@')) return 'Member';
  return name.length > 100 ? name.substring(0, 100) : name;
}

class CommunityPostForm extends StatefulWidget {
  const CommunityPostForm({
    super.key,
    required this.kind,
    this.listingId,
    this.existing,
  });
  final String kind;
  final String? listingId;
  final Map<String, dynamic>? existing;

  @override
  State<CommunityPostForm> createState() => _CommunityPostFormState();
}

class _CommunityPostFormState extends State<CommunityPostForm> {
  final title = TextEditingController();
  final description = TextEditingController();
  final city = TextEditingController();
  final area = TextEditingController();
  String requestMode = 'online';
  bool saving = false;
  String? error;

  bool get isPoll => widget.kind == 'demo_poll';

  @override
  void initState() {
    super.initState();
    final data = widget.existing;
    if (data == null) return;
    title.text = (data['title'] ?? '').toString();
    description.text = (data['description'] ?? '').toString();
    city.text = (data['city'] ?? '').toString();
    area.text = (data['area'] ?? '').toString();
    requestMode = (data['request_mode'] ?? 'online').toString();
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    city.dispose();
    area.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final name = title.text.trim();
    final details = description.text.trim();
    if (name.length < 3 ||
        name.length > 150 ||
        details.isEmpty ||
        details.length > 2000) {
      setState(
        () => error = 'Add a title (3–150 characters) and details (up to 2,000 characters).',
      );
      return;
    }

    if (city.text.trim().length > 100) {
      setState(() => error = 'City must be 100 characters or less.');
      return;
    }
    if (!isPoll &&
        requestMode == 'physical' &&
        (city.text.trim().isEmpty || area.text.trim().isEmpty)) {
      setState(
        () =>
            error = 'City and area are required for a physical class request.',
      );
      return;
    }
    if (area.text.trim().length > 100) {
      setState(() => error = 'Area must be 100 characters or less.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      setState(() => error = 'Sign in before posting.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final ref = firestore
          .collection('listings')
          .doc(
            widget.listingId ??
                '${widget.kind}_${DateTime.now().microsecondsSinceEpoch}',
          );
      if (widget.existing == null) {
        final profile =
            (await firestore.collection('profiles').doc(user.uid).get()).data();
        final batch = firestore.batch();
        batch.set(ref, {
          'id': ref.id,
          'type': isPoll || requestMode == 'online'
              ? 'online_class'
              : 'offline_class',
          if (!isPoll) 'request_mode': requestMode,
          'listing_type': widget.kind,
          'listing_kind': widget.kind,
          'title': name,
          'description': details,
          'priceType': 'free',
          'is_free': true,
          'price': 0,
          'creatorId': user.uid,
          'creatorEmail': '',
          'creatorName': communityPublicName(user.displayName),
          if (city.text.trim().isNotEmpty) 'city': city.text.trim(),
          if (!isPoll && requestMode == 'physical') 'area': area.text.trim(),
          if (isPoll) 'poll_options': const ['Vote +'],
          'createdAt': now,
          'updatedAt': now,
          'expires_at': Timestamp.fromDate(DateTime.utc(2100, 1, 1)),
        });
        final creatorResponse = firestore
            .collection('registrations')
            .doc('response_${ref.id}_${user.uid}');
        batch.set(creatorResponse, {
          'id': creatorResponse.id,
          'listingId': ref.id,
          'userId': user.uid,
          'userEmail': user.email ?? '',
          'userName': communityPublicName(
            (profile?['name'] ?? '').toString().trim().isNotEmpty
                ? profile!['name']
                : user.displayName,
          ),
          if ((profile?['phoneNumber'] ?? '').toString().isNotEmpty)
            'contactNumber': profile!['phoneNumber'],
          'status': 'creator',
          'updatedAt': now,
        });
        await batch.commit();
      } else {
        // Vote choices stay fixed so votes remain attached to the same option.
        await ref.update({
          'title': name,
          'description': details,
          'creatorEmail': '',
          'creatorName': communityPublicName(user.displayName),
          'city': city.text.trim(),
          if (!isPoll) 'request_mode': requestMode,
          if (!isPoll && requestMode == 'physical') 'area': area.text.trim(),
          'updatedAt': now,
          'expires_at': Timestamp.fromDate(DateTime.utc(2100, 1, 1)),
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseException catch (e) {
      if (mounted) setState(() => error = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: EdgeInsets.fromLTRB(
        18,
        20,
        18,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        Text(
          isPoll ? 'Demo class vote' : 'Request a class',
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 27,
            color: board.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isPoll
              ? 'Propose a demo class and ask learners to vote. Each person can change their vote.'
              : 'Tell masters what you want to learn. Other learners can show interest.',
          style: const TextStyle(color: board.muted),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: title,
          maxLength: 150,
          decoration: InputDecoration(
            labelText: isPoll ? 'Demo class title' : 'Class requested',
          ),
        ),
        TextField(
          controller: description,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(labelText: 'Details'),
        ),
        if (!isPoll) ...[
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'online',
                label: Text('Online'),
                icon: Icon(Icons.language_outlined),
              ),
              ButtonSegment(
                value: 'physical',
                label: Text('Physical'),
                icon: Icon(Icons.location_city_outlined),
              ),
            ],
            selected: {requestMode},
            onSelectionChanged: (value) =>
                setState(() => requestMode = value.first),
          ),
        ],
        TextField(
          controller: city,
          maxLength: 100,
          decoration: InputDecoration(
            labelText: !isPoll && requestMode == 'physical'
                ? 'City *'
                : 'City (optional)',
          ),
        ),
        if (!isPoll && requestMode == 'physical')
          TextField(
            controller: area,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Area / nearby locality *',
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(error!, style: const TextStyle(color: board.clay)),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(
            saving
                ? 'Saving…'
                : widget.existing == null
                ? 'Post'
                : 'Update',
          ),
        ),
      ],
    ),
  );
}

class CommunityDetailPage extends StatefulWidget {
  const CommunityDetailPage({
    super.key,
    required this.listingId,
    required this.data,
  });
  final String listingId;
  final Map<String, dynamic> data;

  @override
  State<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends State<CommunityDetailPage> {
  bool working = false;
  String? error;
  bool get isPoll => widget.data['listing_kind'] == 'demo_poll';
  User? get user => FirebaseAuth.instance.currentUser;
  String get registrationId => 'response_${widget.listingId}_${user!.uid}';

  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser?.uid == widget.data['creatorId']) {
      unawaited(_backfillPublicResponses());
    }
  }

  Future<void> _backfillPublicResponses() async {
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) return;
      final profile =
          (await firestore.collection('profiles').doc(current.uid).get())
              .data();
      final creatorResponse = firestore
          .collection('registrations')
          .doc('response_${widget.listingId}_${current.uid}');
      await creatorResponse.set({
        'id': creatorResponse.id,
        'listingId': widget.listingId,
        'userId': current.uid,
        'userEmail': current.email ?? '',
        'userName': communityPublicName(
          profile?['name'] ?? current.displayName,
        ),
        if ((profile?['phoneNumber'] ?? '').toString().isNotEmpty)
          'contactNumber': profile!['phoneNumber'],
        'status': 'creator',
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      final existing = await firestore
          .collection('registrations')
          .where('listingId', isEqualTo: widget.listingId)
          .get();
      for (var start = 0; start < existing.docs.length; start += 8) {
        final batch = firestore.batch();
        for (final doc in existing.docs.skip(start).take(8)) {
          final data = doc.data();
          final userId = (data['userId'] ?? '').toString();
          final status = (data['status'] ?? '').toString();
          if (userId.isEmpty ||
              !['interested', 'master_ready', 'vote_0'].contains(status)) {
            continue;
          }
          final publicRef = firestore
              .collection('community_responses')
              .doc(widget.listingId)
              .collection('members')
              .doc(userId);
          batch.set(publicRef, {
            'listingId': widget.listingId,
            'responseId': doc.id,
            'userId': userId,
            'userName': communityPublicName(data['userName']),
            'status': status,
          });
        }
        await batch.commit();
      }
      try {
        await firestore.collection('listings').doc(widget.listingId).update({
          'creatorEmail': '',
          'creatorName': communityPublicName(current.displayName),
        });
      } on FirebaseException {
        // Existing responses are still visible if listing cleanup fails.
      }
    } on FirebaseException {
      // Existing responses remain private until the community rules are published.
    }
  }

  Future<void> respond(String status, {bool remove = false}) async {
    final current = user;
    if (current == null || current.isAnonymous) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      if (!isPoll && status == 'master_ready' && !remove) {
        final accepted = await firestore
            .collection('community_responses')
            .doc(widget.listingId)
            .collection('members')
            .where('status', isEqualTo: 'master_ready')
            .get();
        if (accepted.docs.length >= 2) {
          if (mounted)
            setState(
              () => error = 'This request already has two accepted masters.',
            );
          return;
        }
      }
      final profile =
          (await firestore.collection('profiles').doc(current.uid).get())
              .data();
      final ref = firestore.collection('registrations').doc(registrationId);
      final publicRef = firestore
          .collection('community_responses')
          .doc(widget.listingId)
          .collection('members')
          .doc(current.uid);
      final batch = firestore.batch();
      if (remove) {
        batch.delete(ref);
        batch.delete(publicRef);
      } else {
        final displayName = communityPublicName(
          (profile?['name'] ?? '').toString().trim().isNotEmpty
              ? profile!['name']
              : current.displayName,
        );
        batch.set(ref, {
          'id': ref.id,
          'listingId': widget.listingId,
          'userId': current.uid,
          'userEmail': current.email ?? '',
          'userName': displayName,
          if ((profile?['phoneNumber'] ?? '').toString().isNotEmpty)
            'contactNumber': profile!['phoneNumber'],
          'status': status,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
        batch.set(publicRef, {
          'listingId': widget.listingId,
          'responseId': ref.id,
          'userId': current.uid,
          'userName': displayName,
          'status': status,
        });
      }
      await batch.commit();
      if (!remove) {
        if (!isPoll && status == 'master_ready') {
          final accepted = await firestore
              .collection('community_responses')
              .doc(widget.listingId)
              .collection('members')
              .where('status', isEqualTo: 'master_ready')
              .get();
          if (accepted.docs.length >= 2) {
            try {
              await firestore
                  .collection('listings')
                  .doc(widget.listingId)
                  .update({
                    'requestClosed': true,
                    'expires_at': Timestamp.now(),
                    'updatedAt': DateTime.now().toUtc().toIso8601String(),
                  });
            } on FirebaseException {
              // The response is saved even when only the creator can close a request.
            }
          }
        }
      }
    } on FirebaseException catch (e) {
      if (mounted) setState(() => error = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not save response: $e');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = user?.uid == widget.data['creatorId'];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(isPoll ? 'Demo class vote' : 'Class request')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            (widget.data['title'] ?? '').toString(),
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 26,
              color: board.ink,
            ),
          ),
          const SizedBox(height: 8),
          if (!isPoll)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: board.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: board.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, color: board.clay),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Requested by ${widget.data['creatorName'] ?? widget.data['creatorEmail'] ?? 'Member'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: board.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text((widget.data['description'] ?? '').toString()),
          if ((widget.data['city'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('City: ${widget.data['city']}'),
          ],
          if ((widget.data['area'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Area: ${widget.data['area']}'),
          ],
          const SizedBox(height: 18),
          CommunityActivity(
            listingId: widget.listingId,
            isPoll: isPoll,
            creatorId: (widget.data['creatorId'] ?? '').toString(),
            creatorName: (widget.data['creatorName'] ?? 'Member').toString(),
          ),
          const SizedBox(height: 24),
          if (user == null) const Text('Sign in to show interest or vote.'),
          if (user != null && !owner)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('registrations')
                  .where('userId', isEqualTo: user!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    'Could not load your response: ${snapshot.error}',
                  );
                }
                final matches = snapshot.data?.docs.where(
                  (doc) => doc.data()['listingId'] == widget.listingId,
                );
                final status = matches == null || matches.isEmpty
                    ? null
                    : matches.first.data()['status']?.toString();
                if (isPoll) {
                  return FilledButton.icon(
                    onPressed: working
                        ? null
                        : () => respond('vote_0', remove: status == 'vote_0'),
                    icon: Icon(
                      status == 'vote_0'
                          ? Icons.check_circle
                          : Icons.add_circle_outline,
                    ),
                    label: Text(
                      status == 'vote_0'
                          ? 'Vote + added · Tap to remove'
                          : 'Vote +',
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: working
                          ? null
                          : () => respond(
                              'interested',
                              remove: status == 'interested',
                            ),
                      icon: Icon(
                        status == 'interested'
                            ? Icons.check
                            : Icons.favorite_border,
                      ),
                      label: Text(
                        status == 'interested'
                            ? 'Interested · Tap to remove'
                            : 'I am interested',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: working
                          ? null
                          : () => respond(
                              'master_ready',
                              remove: status == 'master_ready',
                            ),
                      icon: Icon(
                        status == 'master_ready'
                            ? Icons.check_circle
                            : Icons.school_outlined,
                      ),
                      label: Text(
                        status == 'master_ready'
                            ? 'Ready to take this class · Tap to remove'
                            : 'I am a master ready to take this class',
                      ),
                    ),
                  ],
                );
              },
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(color: board.clay)),
            ),
        ],
      ),
    );
  }
}

class CommunityActivity extends StatelessWidget {
  const CommunityActivity({
    super.key,
    required this.listingId,
    required this.isPoll,
    required this.creatorId,
    required this.creatorName,
  });

  final String listingId;
  final bool isPoll;
  final String creatorId;
  final String creatorName;

  @override
  Widget build(BuildContext context) {
    if (listingId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('community_responses')
          .doc(listingId)
          .collection('members')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Participation details are unavailable right now.',
              style: TextStyle(color: board.clay, fontSize: 12),
            ),
          );
        }
        final responses = snapshot.data?.docs ?? [];
        final voters = responses
            .where((doc) => doc.data()['status'] == 'vote_0')
            .toList();
        final interested = responses
            .where((doc) => doc.data()['status'] == 'interested')
            .toList();
        final masters = responses
            .where((doc) => doc.data()['status'] == 'master_ready')
            .toList();
        final people = isPoll ? voters : interested;
        final viewer = FirebaseAuth.instance.currentUser;
        final canSeeContacts =
            viewer != null &&
            !viewer.isAnonymous &&
            (viewer.uid == creatorId ||
                responses.any((doc) => doc.id == viewer.uid));
        return Container(
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FAFE),
            border: Border.all(color: const Color(0xFFB7DFEE)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            key: PageStorageKey('community_activity_$listingId'),
            dense: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            leading: Icon(
              isPoll ? Icons.how_to_vote_outlined : Icons.people_outline,
              color: const Color(0xFF008ECC),
              size: 20,
            ),
            title: Text(
              isPoll
                  ? '${people.length} vote${people.length == 1 ? '' : 's'}'
                  : '${people.length} interested learner${people.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            subtitle: isPoll
                ? null
                : Text(
                    '${masters.length} master${masters.length == 1 ? '' : 's'} accepted',
                    style: const TextStyle(fontSize: 11, color: board.muted),
                  ),
            children: [
              _CommunityPeople(
                label: isPoll ? 'VOTERS' : 'INTERESTED LEARNERS',
                people: people,
                canSeeContacts: canSeeContacts,
                emptyText: isPoll
                    ? 'No votes yet.'
                    : 'No learner interest yet.',
              ),
              if (!isPoll) ...[
                const SizedBox(height: 12),
                _CommunityPeople(
                  label: 'MASTERS ACCEPTED',
                  people: masters,
                  canSeeContacts: canSeeContacts,
                  emptyText: 'No master has accepted yet.',
                ),
              ],
              const SizedBox(height: 12),
              _CommunityCreator(
                listingId: listingId,
                creatorId: creatorId,
                creatorName: creatorName,
                isPoll: isPoll,
                canSeeContacts: canSeeContacts,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommunityCreator extends StatelessWidget {
  const _CommunityCreator({
    required this.listingId,
    required this.creatorId,
    required this.creatorName,
    required this.isPoll,
    required this.canSeeContacts,
  });

  final String listingId;
  final String creatorId;
  final String creatorName;
  final bool isPoll;
  final bool canSeeContacts;

  @override
  Widget build(BuildContext context) {
    final name = communityPublicName(creatorName);
    final label = isPoll ? 'DEMO MASTER' : 'REQUESTED BY';
    if (!canSeeContacts || creatorId.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text('$label · $name', style: const TextStyle(fontSize: 11)),
      );
    }
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: firestore
          .collection('registrations')
          .doc('response_${listingId}_$creatorId')
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final email = (data?['userEmail'] ?? '').toString();
        final phone = (data?['contactNumber'] ?? '').toString();
        return Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label · $name',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: board.ink,
                ),
              ),
              if (email.isNotEmpty || phone.isNotEmpty)
                Text(
                  [email, phone].where((part) => part.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 11, color: board.muted),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CommunityPeople extends StatelessWidget {
  const _CommunityPeople({
    required this.label,
    required this.people,
    required this.canSeeContacts,
    required this.emptyText,
  });

  final String label;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> people;
  final bool canSeeContacts;
  final String emptyText;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label · ${people.length}',
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 1,
          fontWeight: FontWeight.w800,
          color: board.muted,
        ),
      ),
      const SizedBox(height: 4),
      if (people.isEmpty)
        Text(
          emptyText,
          style: const TextStyle(fontSize: 12, color: board.muted),
        )
      else
        for (final person in people)
          _CommunityPerson(data: person.data(), canSeeContacts: canSeeContacts),
    ],
  );
}

class _CommunityPerson extends StatelessWidget {
  const _CommunityPerson({required this.data, required this.canSeeContacts});

  final Map<String, dynamic> data;
  final bool canSeeContacts;

  @override
  Widget build(BuildContext context) {
    final name = communityPublicName(data['userName']);
    final responseId = (data['responseId'] ?? '').toString();
    if (!canSeeContacts || responseId.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          name,
          style: const TextStyle(fontSize: 12, color: board.ink),
        ),
      );
    }
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: firestore.collection('registrations').doc(responseId).get(),
      builder: (context, snapshot) {
        final privateData = snapshot.data?.data();
        final email = (privateData?['userEmail'] ?? '').toString();
        final phone = (privateData?['contactNumber'] ?? '').toString();
        return Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontSize: 12, color: board.ink),
              ),
              if (email.isNotEmpty || phone.isNotEmpty)
                Text(
                  [email, phone].where((part) => part.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 11, color: board.muted),
                ),
            ],
          ),
        );
      },
    );
  }
}
