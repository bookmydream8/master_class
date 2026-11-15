import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'firestore_database.dart';

class WishlistStore extends ChangeNotifier {
  WishlistStore._();
  static final instance = WishlistStore._();

  final ids = <String>{};
  final items = <String, Map<String, dynamic>>{};
  var ready = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    ids
      ..clear()
      ..addAll(prefs.getStringList('saved_listing_ids') ?? const []);
    final raw = prefs.getString('saved_listing_json');
    items.clear();
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (value is Map) {
            items[key.toString()] = Map<String, dynamic>.from(value);
          }
        });
      }
    }
    ready = true;
    notifyListeners();
  }

  bool contains(String id) => ids.contains(id);

  Future<void> toggle(Map<String, dynamic> listing) async {
    final id = (listing['id'] ?? '').toString();
    if (id.isEmpty) return;
    if (!ready) await load();
    if (ids.contains(id)) {
      ids.remove(id);
      items.remove(id);
    } else {
      ids.add(id);
      items[id] = Map<String, dynamic>.from(listing);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_listing_ids', ids.toList());
    await prefs.setString('saved_listing_json', jsonEncode(items));
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    final ref = firestore.collection('profiles').doc(user.uid).collection('saved').doc(id);
    if (ids.contains(id)) {
      await ref.set({
        'listingId': id,
        'title': (listing['title'] ?? '').toString(),
        'savedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
  }
}

class WishlistButton extends StatelessWidget {
  const WishlistButton({super.key, required this.listing});

  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WishlistStore.instance,
      builder: (context, _) {
        final id = (listing['id'] ?? '').toString();
        final saved = WishlistStore.instance.contains(id);
        return Material(
          color: Colors.white.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => WishlistStore.instance.toggle(listing),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                saved ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: saved ? const Color(0xFFE11D48) : AppPalette.of(context).ink,
              ),
            ),
          ),
        );
      },
    );
  }
}

class SavedClassesPage extends StatelessWidget {
  const SavedClassesPage({super.key, required this.onOpen});

  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved classes')),
      body: ListenableBuilder(
        listenable: WishlistStore.instance,
        builder: (context, _) {
          final saved = WishlistStore.instance.items.values.toList();
          if (saved.isEmpty) {
            return const AppEmpty(
              icon: Icons.favorite_border,
              title: 'Nothing saved yet',
              message: 'Tap the heart on a class to keep it here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: saved.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = saved[index];
              return ListTile(
                tileColor: AppPalette.of(context).card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text((data['title'] ?? 'Class').toString()),
                subtitle: Text((data['creatorName'] ?? '').toString()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpen(data),
              );
            },
          );
        },
      ),
    );
  }
}
