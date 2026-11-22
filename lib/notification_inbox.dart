import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'firestore_database.dart';

/// How long after a due date a still-pending fee is reminded again.
const feeReminderAfterDue = Duration(days: 3);

Future<void> postInboxNote({
  required String title,
  required String body,
  required String kind,
  String? userId,
  String? noteId,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  final uid = userId ?? user?.uid;
  if (uid == null || uid.isEmpty) return;
  final notes = firestore
      .collection('profiles')
      .doc(uid)
      .collection('notifications');
  final payload = {
    'title': title,
    'body': body,
    'kind': kind,
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
  };
  if (noteId == null) {
    await notes.add(payload);
  } else {
    await notes.doc(noteId).set(payload);
  }
}

class NotificationInboxPage extends StatelessWidget {
  const NotificationInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: user == null || user.isAnonymous
          ? const AppEmpty(
              icon: Icons.notifications_none,
              title: 'Sign in for notifications',
              message: 'Class reminders, fee reminders, and announcements land here.',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('profiles')
                  .doc(user.uid)
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const AppEmpty(
                    icon: Icons.notifications_none,
                    title: 'No notifications yet',
                    message: 'Reminders and announcements from your classes show up here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: appCardDecoration(context, radius: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (data['title'] ?? 'Notice').toString(),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text((data['body'] ?? '').toString()),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
