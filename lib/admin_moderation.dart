import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firestore_database.dart';

/// The button is only visible to administrators. Firestore rules also enforce it.
class AdminDeletePostButton extends StatefulWidget {
  const AdminDeletePostButton({
    super.key,
    required this.listingId,
    required this.title,
  });

  final String listingId;
  final String title;

  @override
  State<AdminDeletePostButton> createState() => _AdminDeletePostButtonState();
}

class _AdminDeletePostButtonState extends State<AdminDeletePostButton> {
  bool deleting = false;

  Future<void> deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post?'),
        content: Text(
          '“${widget.title}” will be removed for everyone. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => deleting = true);
    try {
      final listing = firestore.collection('listings').doc(widget.listingId);
      final contact = firestore
          .collection('listings_contact')
          .doc(widget.listingId);
      final contactSnapshot = await contact.get();
      final batch = firestore.batch();
      batch.delete(listing);
      if (contactSnapshot.exists) batch.delete(contact);
      await batch.commit();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not delete post: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous || widget.listingId.isEmpty) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: firestore.collection('admins').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.data?.exists != true) return const SizedBox.shrink();
        return IconButton(
          tooltip: 'Delete post as admin',
          onPressed: deleting ? null : deletePost,
          icon: deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
        );
      },
    );
  }
}
