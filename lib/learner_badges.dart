import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'member_id.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'app_theme.dart';
import 'class_roster.dart';
import 'firestore_database.dart';
import 'seed/bangalore_demo.dart';

class LearnerBadge {
  const LearnerBadge({required this.title, required this.detail, required this.earned});

  final String title;
  final String detail;
  final bool earned;
}

class _Progress {
  const _Progress({required this.classesJoined, required this.bestStreak, required this.completed});

  final int classesJoined;
  final int bestStreak;
  final List<({String title, String master, String date})> completed;
}

Future<_Progress> _loadLearnerProgress(String mcId) async {
  var joined = 0;
  var best = 0;
  final completed = <({String title, String master, String date})>[];
  if (mcId.isNotEmpty) {
    final catalogue = bangaloreDemoListings();
    final demo = ClassRosterStore.instance;
    for (final entry in demo.demoRosters.entries) {
      final matches = entry.value.enrollments.where((item) => item.mcId == mcId).toList();
      if (matches.isEmpty) continue;
      joined += 1;
      final roster = entry.value;
      final family = matches.first;
      final listing = catalogue.where((item) => item['id'] == entry.key);
      final title = listing.isEmpty ? 'Class' : (listing.first['title'] ?? 'Class').toString();
      final master = listing.isEmpty ? 'Master' : (listing.first['creatorName'] ?? 'Master').toString();
      for (final person in family.attendees) {
        final key = family.keyFor(person);
        var streak = 0;
        var allPresent = roster.sessionDates.isNotEmpty;
        for (final date in roster.sessionDates) {
          if (roster.marks[date]?[key] == 'present') {
            streak += 1;
            if (streak > best) best = streak;
          } else {
            streak = 0;
            allPresent = false;
          }
        }
        if (allPresent) {
          completed.add((title: title, master: master, date: roster.sessionDates.last));
        }
      }
    }
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && !user.isAnonymous && mcId.isNotEmpty) {
    try {
      final snap = await firestore.collectionGroup('enrollments').where('mcId', isEqualTo: mcId).get();
      joined += snap.docs.length;
    } catch (_) {}
  }
  return _Progress(classesJoined: joined, bestStreak: best, completed: completed);
}

List<LearnerBadge> _badgesFor(_Progress progress) => [
  LearnerBadge(
    title: 'First class',
    detail: progress.classesJoined > 0 ? 'You joined a class' : 'Join your first class',
    earned: progress.classesJoined >= 1,
  ),
  LearnerBadge(
    title: 'Five classes',
    detail: '${progress.classesJoined} of 5 classes joined',
    earned: progress.classesJoined >= 5,
  ),
  LearnerBadge(
    title: 'Attendance streak',
    detail: progress.bestStreak >= 3
        ? 'Present for ${progress.bestStreak} sessions in a row'
        : 'Be present for 3 sessions in a row',
    earned: progress.bestStreak >= 3,
  ),
  LearnerBadge(
    title: 'Course completed',
    detail: progress.completed.isEmpty
        ? 'Attend every session of a class'
        : '${progress.completed.length} class${progress.completed.length == 1 ? '' : 'es'} finished',
    earned: progress.completed.isNotEmpty,
  ),
];

class LearnerBadgesCard extends StatefulWidget {
  const LearnerBadgesCard({super.key, required this.mcId});

  final String mcId;

  @override
  State<LearnerBadgesCard> createState() => _LearnerBadgesCardState();
}

class _LearnerBadgesCardState extends State<LearnerBadgesCard> {
  _Progress? progress;

  @override
  void initState() {
    super.initState();
    _loadLearnerProgress(widget.mcId).then((value) {
      if (mounted) setState(() => progress = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = progress;
    final colors = AppPalette.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BADGES', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted, letterSpacing: 1)),
          const SizedBox(height: 8),
          if (current == null)
            const LinearProgressIndicator()
          else
            for (final badge in _badgesFor(current))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  badge.earned ? Icons.verified : Icons.radio_button_unchecked,
                  color: badge.earned ? colors.accent : colors.muted,
                ),
                title: Text(badge.title),
                subtitle: Text(badge.detail),
              ),
        ],
      ),
    );
  }
}

Future<void> shareCertificate({
  required String learnerName,
  required String mcId,
  required String classTitle,
  required String masterName,
  required String date,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('Master Class', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text('Certificate of completion'),
            pw.SizedBox(height: 28),
            pw.Text(learnerName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.Text(mcId),
            pw.SizedBox(height: 16),
            pw.Text('finished'),
            pw.Text(classTitle, style: pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 8),
            pw.Text('with $masterName'),
            pw.SizedBox(height: 20),
            pw.Text(date),
          ],
        ),
      ),
    ),
  );
  final bytes = await doc.save();
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          bytes,
          mimeType: 'application/pdf',
          name: 'master-class-certificate.pdf',
        ),
      ],
      fileNameOverrides: const ['master-class-certificate.pdf'],
      text: 'Master Class certificate for $classTitle',
    ),
  );
}

class CertificateButton extends StatefulWidget {
  const CertificateButton({super.key, required this.listing});

  final Map<String, dynamic> listing;

  @override
  State<CertificateButton> createState() => _CertificateButtonState();
}

class _CertificateButtonState extends State<CertificateButton> {
  String mcId = '';
  String learnerName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        setState(() {
          mcId = 'MC100245';
          learnerName = 'Anita Deshpande';
        });
      }
      return;
    }
    try {
      final id = await ensureMemberId(user);
      if (mounted) {
        setState(() {
          mcId = id;
          learnerName = user.displayName ?? 'Learner';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final listingId = (widget.listing['id'] ?? '').toString();
    if (!listingId.startsWith('demo_') || mcId.isEmpty) return const SizedBox.shrink();
    final roster = ClassRosterStore.instance.demoRosters[listingId];
    if (roster == null) return const SizedBox.shrink();
    final family = roster.enrollments.where((item) => item.mcId == mcId);
    if (family.isEmpty || roster.sessionDates.isEmpty) return const SizedBox.shrink();
    final finished = family.first.attendees.any((person) {
      final key = family.first.keyFor(person);
      return roster.sessionDates.every((date) => roster.marks[date]?[key] == 'present');
    });
    if (!finished) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton.icon(
        onPressed: () => shareCertificate(
          learnerName: learnerName,
          mcId: mcId,
          classTitle: (widget.listing['title'] ?? 'Class').toString(),
          masterName: (widget.listing['creatorName'] ?? 'Master').toString(),
          date: roster.sessionDates.last,
        ),
        icon: const Icon(Icons.workspace_premium_outlined),
        label: const Text('Certificate'),
      ),
    );
  }
}
