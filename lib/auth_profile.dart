import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import 'madhura_board.dart' as board;
import 'madhura_post.dart';

Future<bool> requireLogin(BuildContext context) async {
  if (FirebaseAuth.instance.currentUser != null &&
      !FirebaseAuth.instance.currentUser!.isAnonymous)
    return true;
  final result = await Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (_) => const LoginPage()));
  return result == true;
}

Future<void> openProfile(BuildContext context) async {
  if (!await requireLogin(context) || !context.mounted) return;
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const ProfilePage()));
}

final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: <String>['email']);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool busy = false;
  String? error;

  Future<void> signInWithGoogle() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => error = e.code == 'operation-not-allowed'
              ? 'Google Sign-In is not enabled in Firebase yet.'
              : e.message ??
                    'Google Sign-In did not complete. Please try again.',
        );
      }
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      if (mounted) {
        setState(() => error = 'Google Sign-In error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: board.cream,
    appBar: AppBar(
      backgroundColor: board.paper,
      foregroundColor: board.ink,
      title: const Text('Master Class', style: TextStyle(fontFamily: 'serif')),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 430),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: board.paper,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: board.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: board.gold,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: board.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Sign in with Google',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 28,
                    color: board.ink,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Use your Google account to view class details, publish a class, and manage your profile.',
                  style: TextStyle(color: board.muted, height: 1.4),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      error!,
                      style: const TextStyle(color: board.clay, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: busy ? null : signInWithGoogle,
                  style: FilledButton.styleFrom(
                    backgroundColor: board.ink,
                    foregroundColor: board.paper,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.white,
                    child: Text(
                      'G',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: board.ink,
                      ),
                    ),
                  ),
                  label: Text(
                    busy ? 'Opening Google…' : 'Continue with Google',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final expertDetails = TextEditingController();
  bool loading = true;
  bool saving = false;
  String? error;
  XFile? selectedPhoto;
  User get user => FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    expertDetails.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final data =
          (await firestore
                  .collection('profiles')
                  .doc(user.uid)
                  .get())
              .data();
      expertDetails.text = (data?['expertDetails'] ?? '').toString();
    } catch (_) {
      // A profile document may not exist yet. The form remains usable.
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> choosePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        imageQuality: 82,
      );
      if (photo != null && mounted) {
        setState(() => selectedPhoto = photo);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Could not open your photos: $e');
      }
    }
  }
  void save() {
    setState(() {
      saving = true;
      error = null;
    });
    final profileRef = firestore.collection('profiles').doc(user.uid);
    final write = profileRef.set(
      {
        'name': user.displayName ?? '',
        'pictureUrl': user.photoURL ?? '',
        'expertDetails': expertDetails.text.trim(),
        'email': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    unawaited(
      write.catchError((Object e, StackTrace stackTrace) {
        debugPrint('Profile sync failed: $e\n$stackTrace');
        if (mounted) {
          setState(() => error = 'Could not sync profile: $e');
        }
      }),
    );
    if (selectedPhoto != null) {
      unawaited(_uploadSelectedPhoto(selectedPhoto!));
    }
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved. Syncing in the background.')),
    );
  }

  Future<void> _uploadSelectedPhoto(XFile photo) async {
    try {
      final photoRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos/${user.uid}/avatar.jpg');
      await photoRef.putFile(File(photo.path));
      final pictureUrl = await photoRef.getDownloadURL();
      await user.updatePhotoURL(pictureUrl);
      await firestore.collection('profiles').doc(user.uid).set(
        {
          'pictureUrl': pictureUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (mounted) setState(() => selectedPhoto = null);
    } catch (e) {
      debugPrint('Profile photo upload failed: $e');
      if (mounted) {
        setState(
          () => error = 'Profile details saved, but the photo could not upload.',
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: board.cream,
    appBar: AppBar(
      backgroundColor: board.paper,
      foregroundColor: board.ink,
      title: const Text('Your profile', style: TextStyle(fontFamily: 'serif')),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    _Avatar(
                      url: user.photoURL ?? '',
                      name: user.displayName ?? user.email ?? '',
                      localPhoto: selectedPhoto == null
                          ? null
                          : File(selectedPhoto!.path),
                    ),
                    if ((user.photoURL ?? '').trim().isEmpty && selectedPhoto == null)
                      TextButton.icon(
                        onPressed: choosePhoto,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Add profile photo'),
                      )
                    else
                      TextButton.icon(
                        onPressed: choosePhoto,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Change profile photo'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: board.paper,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: board.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ProfileLabel('GOOGLE ACCOUNT'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: board.cream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: board.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName ?? 'Google account',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: board.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user.email ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: board.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _ProfileLabel('EXPERT DETAILS · OPTIONAL'),
                    TextField(
                      controller: expertDetails,
                      minLines: 3,
                      maxLines: 5,
                      decoration: _field(
                        'Your skills, experience, and subjects you teach',
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          error!,
                          style: const TextStyle(color: board.clay),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: saving ? null : save,
                      style: FilledButton.styleFrom(
                        backgroundColor: board.clay,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(saving ? 'Saving…' : 'Save profile'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _ProfileLabel('MY POSTED CLASSES'),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: firestore.collection('listings').where('creatorId', isEqualTo: user.uid).snapshots(),
                builder: (context, snapshot) {
                  final classes = snapshot.data?.docs ?? [];
                  if (classes.isEmpty) return const Text('No classes posted yet.', style: TextStyle(color: board.muted));
                  return Column(children: classes.map((doc) => ListTile(
                    tileColor: board.paper,
                    title: Text((doc.data()['title'] ?? 'Untitled class').toString()),
                    trailing: TextButton(
                      child: const Text('Update'),
                      onPressed: () => showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => FractionallySizedBox(heightFactor: .94, child: MadhuraPostForm(existing: doc.data(), listingId: doc.id))),
                    ),
                  )).toList());
                },
              ),
              const SizedBox(height: 14),              OutlinedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted)
                    Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name, this.localPhoto});
  final String url, name;
  final File? localPhoto;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 46,
    backgroundColor: board.gold,
    foregroundImage: localPhoto != null
        ? FileImage(localPhoto!)
        : (url.trim().isEmpty ? null : NetworkImage(url.trim())),
    child: Text(
      name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase(),
      style: const TextStyle(
        fontFamily: 'serif',
        fontSize: 34,
        color: board.ink,
      ),
    ),
  );
}

class _ProfileLabel extends StatelessWidget {
  const _ProfileLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        color: board.muted,
      ),
    ),
  );
}

InputDecoration _field(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: board.muted, fontSize: 13),
  filled: true,
  fillColor: board.cream,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: board.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: board.border),
  ),
);
