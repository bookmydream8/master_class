import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'firestore_database.dart';

final _mcIdPattern = RegExp(r'^MC\d{6,}$');

/// Assigns a permanent MC ID the first time a signed-in user needs one.
///
/// A transaction on `counters/memberId` hands out the next number, starting
/// at MC100001. An ID already stored on `profiles/{uid}` is never replaced.
Future<String> ensureMemberId(User user) async {
  final profileRef = firestore.collection('profiles').doc(user.uid);
  final counterRef = firestore.collection('counters').doc('memberId');
  return firestore.runTransaction((transaction) async {
    final profile = await transaction.get(profileRef);
    final existing = (profile.data()?['mcId'] ?? '').toString().trim();
    if (_mcIdPattern.hasMatch(existing)) return existing;
    final counter = await transaction.get(counterRef);
    final next = ((counter.data()?['next'] as num?)?.toInt() ?? 100000) + 1;
    final mcId = 'MC$next';
    transaction.set(counterRef, {'next': next}, SetOptions(merge: true));
    transaction.set(profileRef, {
      'mcId': mcId,
      'uid': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return mcId;
  });
}

class McIdBanner extends StatelessWidget {
  const McIdBanner({super.key, required this.mcId, this.compact = false});

  final String mcId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: colors.accentSoft,
      borderRadius: BorderRadius.circular(compact ? 12 : 18),
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: mcId));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('MC ID copied')),
            );
          }
        },
        borderRadius: BorderRadius.circular(compact ? 12 : 18),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16,
            vertical: compact ? 6 : 14,
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(Icons.badge_outlined, color: colors.onAccentSoft, size: compact ? 16 : 22),
              const SizedBox(width: 8),
              if (!compact)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR MC ID',
                        style: text.labelSmall?.copyWith(
                          color: colors.onAccentSoft,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        mcId,
                        style: text.headlineSmall?.copyWith(color: colors.onAccentSoft),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  mcId,
                  style: text.labelLarge?.copyWith(color: colors.onAccentSoft),
                ),
              Icon(Icons.copy_rounded, color: colors.onAccentSoft, size: compact ? 16 : 20),
            ],
          ),
        ),
      ),
    );
  }
}
