import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'firestore_database.dart';
import 'member_id.dart';

class ClassReview {
  const ClassReview({
    required this.listingId,
    required this.listingTitle,
    required this.masterId,
    required this.masterName,
    required this.authorId,
    required this.authorName,
    required this.mcId,
    required this.classRating,
    required this.masterRating,
    required this.text,
    required this.createdAt,
  });

  final String listingId;
  final String listingTitle;
  final String masterId;
  final String masterName;
  final String authorId;
  final String authorName;
  final String mcId;
  final int classRating;
  final int masterRating;
  final String text;
  final String createdAt;

  static ClassReview fromMap(Map<String, dynamic> data) => ClassReview(
    listingId: (data['listingId'] ?? '').toString(),
    listingTitle: (data['listingTitle'] ?? '').toString(),
    masterId: (data['masterId'] ?? '').toString(),
    masterName: (data['masterName'] ?? '').toString(),
    authorId: (data['authorId'] ?? '').toString(),
    authorName: (data['authorName'] ?? '').toString(),
    mcId: (data['mcId'] ?? '').toString(),
    classRating: (data['classRating'] as num?)?.toInt() ?? 0,
    masterRating: (data['masterRating'] as num?)?.toInt() ?? 0,
    text: (data['text'] ?? '').toString(),
    createdAt: (data['createdAt'] ?? '').toString(),
  );
}

class ReviewStore {
  ReviewStore._();
  static final instance = ReviewStore._();
  final _demo = <String, List<ClassReview>>{};
  var _seeded = false;

  void _seed() {
    if (_seeded) return;
    _seeded = true;
    _demo['demo_online_0'] = [
      _sample(
        'demo_online_0',
        'Hindustani vocals for beginners',
        'demo_meera_rao',
        'Meera Rao',
        'MC100245',
        'Anita Deshpande',
        5,
        5,
        'Asha looks forward to the raag. Meera explains slowly.',
      ),
      _sample(
        'demo_online_0',
        'Hindustani vocals for beginners',
        'demo_meera_rao',
        'Meera Rao',
        'MC100318',
        'Kiran Patel',
        4,
        5,
        'Clear voice lessons from home. I would have liked one more song.',
      ),
    ];
    _demo['demo_physical_25'] = [
      _sample(
        'demo_physical_25',
        'Tabla hands-on',
        'demo_imran_khan',
        'Imran Khan',
        'MC100402',
        'Leela Krishnan',
        5,
        4,
        'The studio in Indiranagar is easy to find. Arun enjoyed the bols.',
      ),
    ];
  }

  ClassReview _sample(
    String listingId,
    String title,
    String masterId,
    String masterName,
    String mcId,
    String author,
    int classRating,
    int masterRating,
    String text,
  ) => ClassReview(
    listingId: listingId,
    listingTitle: title,
    masterId: masterId,
    masterName: masterName,
    authorId: 'demo_$mcId',
    authorName: author,
    mcId: mcId,
    classRating: classRating,
    masterRating: masterRating,
    text: text,
    createdAt: '2026-11-12',
  );

  Future<List<ClassReview>> forListing(String listingId) async {
    if (listingId.startsWith('demo_')) {
      _seed();
      return List<ClassReview>.from(_demo[listingId] ?? const []);
    }
    final snap = await firestore
        .collection('listings')
        .doc(listingId)
        .collection('reviews')
        .get();
    return snap.docs.map((doc) => ClassReview.fromMap(doc.data())).toList();
  }

  Future<List<ClassReview>> forMaster(String masterId) async {
    if (masterId.isEmpty) return const [];
    if (masterId.startsWith('demo_')) {
      _seed();
      return [
        for (final list in _demo.values)
          for (final review in list)
            if (review.masterId == masterId) review,
      ];
    }
    final snap = await firestore
        .collection('profiles')
        .doc(masterId)
        .collection('receivedReviews')
        .get();
    return snap.docs.map((doc) => ClassReview.fromMap(doc.data())).toList();
  }

  Future<bool> canReview(String listingId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return false;
    if (listingId.startsWith('demo_')) {
      _seed();
      return true;
    }
    final interest = await firestore
        .collection('listings')
        .doc(listingId)
        .collection('interests')
        .doc(user.uid)
        .get();
    if (interest.data()?['status'] == 'interested') return true;
    try {
      final mcId = await ensureMemberId(user);
      final enrolment = await firestore
          .collection('listings')
          .doc(listingId)
          .collection('enrollments')
          .doc(mcId)
          .get();
      return enrolment.exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> save({
    required Map<String, dynamic> listing,
    required int classRating,
    required int masterRating,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    var mcId = '';
    try {
      mcId = await ensureMemberId(user);
    } catch (_) {}
    final listingId = (listing['id'] ?? '').toString();
    final review = ClassReview(
      listingId: listingId,
      listingTitle: (listing['title'] ?? '').toString(),
      masterId: (listing['creatorId'] ?? '').toString(),
      masterName: (listing['creatorName'] ?? '').toString(),
      authorId: user.uid,
      authorName: user.displayName ?? 'Learner',
      mcId: mcId,
      classRating: classRating.clamp(1, 5),
      masterRating: masterRating.clamp(1, 5),
      text: text.trim(),
      createdAt: DateTime.now().toIso8601String().substring(0, 10),
    );
    if (listingId.startsWith('demo_')) {
      _seed();
      final list = _demo.putIfAbsent(listingId, () => []);
      list.removeWhere((item) => item.authorId == user.uid);
      list.add(review);
      return;
    }
    final payload = {
      'listingId': review.listingId,
      'listingTitle': review.listingTitle,
      'masterId': review.masterId,
      'masterName': review.masterName,
      'authorId': review.authorId,
      'authorName': review.authorName,
      'mcId': review.mcId,
      'classRating': review.classRating,
      'masterRating': review.masterRating,
      'text': review.text,
      'createdAt': review.createdAt,
    };
    await firestore
        .collection('listings')
        .doc(listingId)
        .collection('reviews')
        .doc(user.uid)
        .set(payload);
    if (review.masterId.isNotEmpty) {
      await firestore
          .collection('profiles')
          .doc(review.masterId)
          .collection('receivedReviews')
          .doc('${listingId}_${user.uid}')
          .set(payload);
    }
  }
}

double averageRating(Iterable<ClassReview> reviews) {
  final scores = reviews.map((item) => item.classRating).where((score) => score > 0).toList();
  if (scores.isEmpty) return 0;
  return scores.reduce((a, b) => a + b) / scores.length;
}

class ClassReviewsSection extends StatefulWidget {
  const ClassReviewsSection({super.key, required this.listing});

  final Map<String, dynamic> listing;

  @override
  State<ClassReviewsSection> createState() => _ClassReviewsSectionState();
}

class _ClassReviewsSectionState extends State<ClassReviewsSection> {
  List<ClassReview> reviews = [];
  var canWrite = false;
  var loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final listingId = (widget.listing['id'] ?? '').toString();
    final loaded = await ReviewStore.instance.forListing(listingId);
    final allowed = await ReviewStore.instance.canReview(listingId);
    if (!mounted) return;
    setState(() {
      reviews = loaded;
      canWrite = allowed;
      loading = false;
    });
  }

  Future<void> _write() async {
    var classRating = 5;
    var masterRating = 5;
    final text = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Rate this class'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(alignment: Alignment.centerLeft, child: Text('Class')),
              Slider(
                value: classRating.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$classRating',
                onChanged: (value) => setLocal(() => classRating = value.round()),
              ),
              const Align(alignment: Alignment.centerLeft, child: Text('Master')),
              Slider(
                value: masterRating.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$masterRating',
                onChanged: (value) => setLocal(() => masterRating = value.round()),
              ),
              TextField(
                controller: text,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'What should the next learner know?'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Publish')),
          ],
        ),
      ),
    );
    final body = text.text;
    text.dispose();
    if (saved != true) return;
    await ReviewStore.instance.save(
      listing: widget.listing,
      classRating: classRating,
      masterRating: masterRating,
      text: body,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final average = averageRating(reviews);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('REVIEWS', style: text.labelSmall?.copyWith(color: colors.muted, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(
          reviews.isEmpty ? 'No reviews yet' : '${average.toStringAsFixed(1)} · ${reviews.length} review${reviews.length == 1 ? '' : 's'}',
          style: text.titleMedium,
        ),
        const SizedBox(height: 8),
        if (loading)
          const LinearProgressIndicator()
        else
          for (final review in reviews)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: appCardDecoration(context, radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.authorName, style: text.titleSmall),
                    Text(
                      'Class ${review.classRating}/5 · Master ${review.masterRating}/5',
                      style: text.bodySmall?.copyWith(color: colors.muted),
                    ),
                    if (review.text.isNotEmpty) Text(review.text),
                  ],
                ),
              ),
            ),
        if (canWrite)
          OutlinedButton.icon(
            onPressed: _write,
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Write a review'),
          )
        else
          Text(
            'Join this class to rate it and the master.',
            style: text.bodySmall?.copyWith(color: colors.muted),
          ),
      ],
    );
  }
}

class MasterReviewsCard extends StatefulWidget {
  const MasterReviewsCard({super.key, required this.masterId});

  final String masterId;

  @override
  State<MasterReviewsCard> createState() => _MasterReviewsCardState();
}

class _MasterReviewsCardState extends State<MasterReviewsCard> {
  List<ClassReview> reviews = [];

  @override
  void initState() {
    super.initState();
    ReviewStore.instance.forMaster(widget.masterId).then((loaded) {
      if (mounted) setState(() => reviews = loaded);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.masterId.isEmpty) return const SizedBox.shrink();
    final colors = AppPalette.of(context);
    final average = reviews.isEmpty
        ? 0
        : reviews.map((item) => item.masterRating).reduce((a, b) => a + b) / reviews.length;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REVIEWS OF YOUR TEACHING', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(
            reviews.isEmpty ? 'No reviews yet' : '${average.toStringAsFixed(1)} from ${reviews.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final review in reviews.take(4))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${review.listingTitle}: ${review.text}'),
            ),
        ],
      ),
    );
  }
}
