import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_database.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import 'madhura_board.dart' as board;
import 'madhura_detail.dart' show showMasterClassDetails;
import 'madhura_post.dart';

import 'package:url_launcher/url_launcher.dart';

Future<bool> requireLogin(BuildContext context) async {
  var user = FirebaseAuth.instance.currentUser;
  // Wait once for Android to restore a persisted Firebase session on launch.
  user ??= await FirebaseAuth.instance.authStateChanges().first;
  if (user != null && !user.isAnonymous) return true;
  if (!context.mounted) return false;
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
      final signedIn = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final profile = await firestore
          .collection('profiles')
          .doc(signedIn.user!.uid)
          .get();
      if (mounted && profile.data()?['registrationCompleted'] != true) {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const RegistrationPage()));
      }
      if (mounted) Navigator.pop(context, true);
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
    backgroundColor: Colors.white,
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

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final phone = TextEditingController();
  final city = TextEditingController();
  final interests = <String>{};
  bool saving = false;
  String? error;
  XFile? selectedPhoto;
  User get user => FirebaseAuth.instance.currentUser!;

  @override
  void dispose() {
    phone.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> choosePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        imageQuality: 82,
      );
      if (photo != null && mounted) setState(() => selectedPhoto = photo);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not open your photos: $e');
    }
  }

  Future<String> _savePhotoIfSelected() async {
    if (selectedPhoto == null) return user.photoURL ?? '';
    final ref = FirebaseStorage.instance.ref().child(
      'profile_photos/${user.uid}/avatar.jpg',
    );
    await ref.putFile(File(selectedPhoto!.path));
    final url = await ref.getDownloadURL();
    await user.updatePhotoURL(url);
    return url;
  }

  Future<void> save() async {
    if (phone.text.trim().length < 5 || city.text.trim().isEmpty) {
      setState(() => error = 'Enter your phone number and city.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final photoUrl = await _savePhotoIfSelected();
      await firestore.collection('profiles').doc(user.uid).set({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'pictureUrl': photoUrl,
        // Firebase encrypts this private profile data in transit and at rest.
        'phoneNumber': phone.text.trim(),
        'city': city.text.trim(),
        'preferredPhysicalCity': city.text.trim(),
        'topicInterests': interests.toList(),
        'registrationCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (mounted) setState(() => error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: board.paper,
      foregroundColor: board.ink,
      title: const Text(
        'Complete your profile',
        style: TextStyle(fontFamily: 'serif'),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Welcome to Master Class',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 27,
              color: board.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your Google name and photo are used automatically. Add the details below to personalise classes.',
            style: TextStyle(color: board.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          if ((user.photoURL ?? '').isEmpty || selectedPhoto != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: choosePhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  selectedPhoto == null
                      ? 'Add profile photo'
                      : 'Photo selected',
                ),
              ),
            ),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Phone number *',
              helperText: 'Private to your profile.',
            ),
          ),
          TextField(
            controller: city,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'City *'),
          ),
          const SizedBox(height: 12),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(color: board.clay)),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: saving ? null : save,
            style: FilledButton.styleFrom(
              backgroundColor: board.clay,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(saving ? 'Saving…' : 'Continue'),
          ),
        ],
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
  String profileCity = '';
  String profilePhone = '';
  bool loading = true;
  bool saving = false;
  bool editing = false;
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
      final data = (await firestore.collection('profiles').doc(user.uid).get())
          .data();
      expertDetails.text = (data?['expertDetails'] ?? '').toString();
      profileCity = (data?['city'] ?? '').toString();
      profilePhone = (data?['phoneNumber'] ?? '').toString();
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
    final write = profileRef.set({
      'name': user.displayName ?? '',
      'pictureUrl': user.photoURL ?? '',
      'expertDetails': expertDetails.text.trim(),
      'email': user.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    setState(() {
      saving = false;
      editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved. Syncing in the background.'),
      ),
    );
  }

  Future<void> _uploadSelectedPhoto(XFile photo) async {
    try {
      final photoRef = FirebaseStorage.instance.ref().child(
        'profile_photos/${user.uid}/avatar.jpg',
      );
      await photoRef.putFile(File(photo.path));
      final pictureUrl = await photoRef.getDownloadURL();
      await user.updatePhotoURL(pictureUrl);
      await firestore.collection('profiles').doc(user.uid).set({
        'pictureUrl': pictureUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) setState(() => selectedPhoto = null);
    } catch (e) {
      debugPrint('Profile photo upload failed: $e');
      if (mounted) {
        setState(
          () =>
              error = 'Profile details saved, but the photo could not upload.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: board.paper,
      foregroundColor: board.ink,
      title: const Text(
        'Profile',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        TextButton.icon(
          onPressed: saving
              ? null
              : () => setState(() {
                  editing = !editing;
                  error = null;
                  if (!editing) selectedPhoto = null;
                }),
          icon: Icon(editing ? Icons.close : Icons.edit_outlined),
          label: Text(editing ? 'Cancel' : 'Edit'),
          style: TextButton.styleFrom(foregroundColor: board.clay),
        ),
        const SizedBox(width: 6),
      ],
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
                    const SizedBox(height: 12),
                    Text(
                      user.displayName ?? 'Google account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (profileCity.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Color(0xFF8B8B8B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            profileCity,
                            style: const TextStyle(color: Color(0xFF8B8B8B)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (editing)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: choosePhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Update profile photo'),
                  ),
                ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFECECEC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ProfileLabel('CONTACT & EXPERTISE'),
                    _ProfileInfoRow(
                      icon: Icons.mail_outline,
                      label: 'Email',
                      value: user.email ?? 'No email available',
                    ),
                    if (profilePhone.isNotEmpty) ...[
                      const Divider(height: 1, color: Color(0xFFECECEC)),
                      _ProfileInfoRow(
                        icon: Icons.call_outlined,
                        label: 'Phone',
                        value: profilePhone,
                      ),
                    ],
                    const Divider(height: 24, color: Color(0xFFECECEC)),
                    const _ProfileLabel('EXPERT DETAILS'),
                    if (editing)
                      TextField(
                        controller: expertDetails,
                        minLines: 3,
                        maxLines: 5,
                        decoration: _field(
                          'Your skills, experience, and subjects you teach',
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: board.cream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: board.border),
                        ),
                        child: Text(
                          expertDetails.text.trim().isEmpty
                              ? 'Add your skills and teaching experience to introduce yourself to learners.'
                              : expertDetails.text.trim(),
                          style: TextStyle(
                            height: 1.45,
                            color: expertDetails.text.trim().isEmpty
                                ? board.muted
                                : board.ink,
                          ),
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
                    if (editing) ...[
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: saving ? null : save,
                        style: FilledButton.styleFrom(
                          backgroundColor: board.clay,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(saving ? 'Saving…' : 'Save changes'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF8EF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCDE8D1)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.school_outlined,
                      color: Color(0xFF1B6D24),
                      size: 30,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR CLASSES',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1B6D24),
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Manage your posts',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF173A1B),
                            ),
                          ),
                          Text(
                            'Open a class to view it or tap Update',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF55725A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: firestore
                    .collection('listings')
                    .where('creatorId', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final classes = snapshot.data?.docs ?? [];
                  if (classes.isEmpty)
                    return const Text(
                      'No classes posted yet.',
                      style: TextStyle(color: board.muted),
                    );
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: classes.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: .57,
                        ),
                    itemBuilder: (context, index) {
                      final doc = classes[index];
                      return _PostedClassCard(
                        data: doc.data(),
                        onOpen: () => showMasterClassDetails(context, {
                          ...doc.data(),
                          'id': doc.id,
                        }),
                        onUpdate: () => showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => FractionallySizedBox(
                            heightFactor: .94,
                            child: MasterClassPostForm(
                              existing: doc.data(),
                              listingId: doc.id,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 18),
              const _ProfileLabel('MY INTERESTED CLASSES'),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: firestore
                    .collectionGroup('interests')
                    .where('userId', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final interests =
                      snapshot.data?.docs
                          .where((doc) => doc.data()['status'] == 'interested')
                          .toList() ??
                      [];
                  if (interests.isEmpty)
                    return const Text(
                      'No class interests yet.',
                      style: TextStyle(color: board.muted),
                    );
                  return Column(
                    children: interests
                        .map(
                          (doc) => ListTile(
                            tileColor: board.paper,
                            title: Text(
                              (doc.data()['listingTitle'] ?? 'Interested class')
                                  .toString(),
                            ),
                            subtitle: _InterestSessionAccess(
                              listingId: (doc.data()['listingId'] ?? '')
                                  .toString(),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 14),
              const _ProfileLabel('ACCOUNT'),
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE9DED1)),
                ),
                child: ListTile(
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    await _googleSignIn.signOut();
                    if (!mounted) return;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  leading: const Icon(Icons.logout, color: Color(0xFFE11D48)),
                  title: const Text(
                    'Sign out',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                  subtitle: const Text('Sign out of your account'),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF8B8B8B),
                  ),
                ),
              ),
            ],
          ),
  );
}

class _PostedClassCard extends StatelessWidget {
  const _PostedClassCard({
    required this.data,
    required this.onOpen,
    required this.onUpdate,
  });

  final Map<String, dynamic> data;
  final VoidCallback onOpen;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final format = board.listingFormat(data);
    final imageBase64 = (data['image_base64'] ?? '').toString();
    final imageUrl =
        (data['image_url'] ?? data['imageUrl'] ?? data['photoUrl'] ?? '')
            .toString();
    final title = (data['title'] ?? 'Untitled class').toString();
    final categoryId = (data['category'] ?? '').toString();
    var category = categoryId.isEmpty ? 'Class' : categoryId;
    for (final entry in board.categoryIds.entries) {
      if (entry.value == categoryId) {
        category = entry.key;
        break;
      }
    }
    final subcategory = (data['subcategory'] ?? '').toString();
    final place = format == 'online'
        ? 'Online'
        : [
            (data['area'] ?? '').toString(),
            (data['city'] ?? '').toString(),
          ].where((value) => value.trim().isNotEmpty).join(', ');

    Widget imageHeader() {
      if (imageBase64.isNotEmpty) {
        try {
          return Image.memory(base64Decode(imageBase64), fit: BoxFit.cover);
        } on FormatException {
          // Fall through to the remote image or a neutral placeholder.
        }
      }
      if (imageUrl.isNotEmpty) {
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) =>
              const _PostedClassImagePlaceholder(),
        );
      }
      return const _PostedClassImagePlaceholder();
    }

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: const Color(0x16241912),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x66000000), width: 1),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 112,
                child: imageHeader(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 8, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            board.formats[format] ?? 'Class',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          board.listingPrice(data),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      [
                        category,
                        subcategory,
                      ].where((value) => value.trim().isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 13,
                          color: Color(0xFF799487),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            place.isEmpty ? 'Location to be announced' : place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onUpdate,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0C6A5A),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          minimumSize: const Size(0, 28),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 13),
                        label: const Text(
                          'Update',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostedClassImagePlaceholder extends StatelessWidget {
  const _PostedClassImagePlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFEEDFCB),
    child: Center(
      child: Icon(Icons.auto_stories_outlined, color: Color(0xFFD87824)),
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

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E6),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFFD87824)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8B8B8B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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

class _InterestSessionAccess extends StatelessWidget {
  const _InterestSessionAccess({required this.listingId});
  final String listingId;

  Future<void> _openSession(BuildContext context, String link) async {
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
        future: listingId.isEmpty
            ? null
            : firestore.collection('listings_contact').doc(listingId).get(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          if (data == null)
            return const Text('Private session details are not available yet.');
          final contact = (data['contactNumber'] ?? '').toString();
          final session = (data['sessionLink'] ?? '').toString();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contact.isNotEmpty) Text('Owner contact: $contact'),
              if (session.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _openSession(context, session),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open session link'),
                ),
            ],
          );
        },
      );
}
