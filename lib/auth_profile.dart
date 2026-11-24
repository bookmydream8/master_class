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

import 'academy.dart';
import 'app_theme.dart';
import 'class_reminders.dart';
import 'listing_expiry.dart';
import 'spark_logic.dart';
import 'spark_pages.dart';
import 'category_style.dart';
import 'class_reviews.dart';
import 'profile_photo.dart';
import 'class_roster_pages.dart';
import 'learner_badges.dart';
import 'notification_inbox.dart';
import 'upi_payment.dart';
import 'wishlist.dart';
import 'madhura_board.dart' as board;
import 'masters_page.dart';
import 'member_id.dart';
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
      try {
        await ensureMemberId(signedIn.user!);
      } catch (e) {
        debugPrint('MC ID was not assigned: $e');
      }
      try {
        await adoptProviderPhoto(signedIn.user!);
      } catch (e) {
        debugPrint('Provider photo was not saved: $e');
      }
      if (mounted) await offerMissingProfilePhoto(context);
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
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Master Class')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'logo.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Welcome', style: text.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to view class details, publish a class, and manage your profile.',
                    style: text.bodyLarge?.copyWith(color: colors.muted),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        error!,
                        style: text.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: busy ? null : signInWithGoogle,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: CircleAvatar(
                      radius: 12,
                      backgroundColor: colors.card,
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.accent,
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
      final photo = await pickAndCropProfilePhoto(context);
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
      await syncCityTopics(city: city.text.trim(), eventCity: city.text.trim());
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (mounted) setState(() => error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Complete your profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Welcome to Master Class', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text(
              (user.photoURL ?? '').isEmpty
                  ? 'Add a photo so people recognise you, then the details below.'
                  : 'Your Google name and photo are saved. You can change the photo, then add the details below.',
              style: text.bodyMedium?.copyWith(color: colors.muted),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: ProfileAvatar(
                url: user.photoURL ?? '',
                name: user.displayName ?? '',
                radius: 36,
                localPhoto: selectedPhoto == null
                    ? null
                    : File(selectedPhoto!.path),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: choosePhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  selectedPhoto == null
                      ? 'Add or change photo'
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
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving ? null : save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(saving ? 'Saving…' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.previewMcId});

  /// Used by the screenshot preview when nobody is signed in.
  final String? previewMcId;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final expertDetails = TextEditingController();
  final phoneField = TextEditingController();
  final cityField = TextEditingController();
  final upiField = TextEditingController();
  final topicInterests = <String>{};
  String profileCity = '';
  String profilePhone = '';
  String mcId = '';
  String role = 'Learner';
  bool loading = true;
  bool saving = false;
  bool editing = false;
  String? error;
  String storedPhoto = '';
  XFile? selectedPhoto;
  User get user => FirebaseAuth.instance.currentUser!;

  bool get signedIn {
    final current = FirebaseAuth.instance.currentUser;
    return current != null && !current.isAnonymous;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    expertDetails.dispose();
    phoneField.dispose();
    cityField.dispose();
    upiField.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null || current.isAnonymous) {
      mcId = widget.previewMcId ?? '';
      phoneField.text = '9845011122';
      cityField.text = 'Bangalore';
      profilePhone = phoneField.text;
      profileCity = cityField.text;
      expertDetails.text =
          'Hindustani vocals and small-group music classes in Bangalore.';
      topicInterests
        ..clear()
        ..addAll(['Music', 'Yoga']);
      role = 'Learner';
      upiField.text = 'anita.deshpande@oksbi';
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      try {
        mcId = await ensureMemberId(current);
      } catch (_) {}
      final data =
          (await firestore.collection('profiles').doc(current.uid).get())
              .data();
      expertDetails.text = (data?['expertDetails'] ?? '').toString();
      profileCity = (data?['city'] ?? '').toString();
      profilePhone = (data?['phoneNumber'] ?? '').toString();
      phoneField.text = profilePhone;
      cityField.text = profileCity;
      final stored = (data?['mcId'] ?? '').toString();
      if (stored.isNotEmpty) mcId = stored;
      final storedRole = (data?['role'] ?? '').toString();
      role = storedRole == 'Master' ? 'Master' : 'Learner';
      upiField.text = (data?['upiId'] ?? '').toString();
      storedPhoto = (data?['pictureUrl'] ?? current.photoURL ?? '').toString();
      if (storedPhoto.isEmpty) {
        try {
          await adoptProviderPhoto(current);
          storedPhoto = (current.photoURL ?? '').trim();
        } catch (_) {}
      }
      final rawInterests = data?['topicInterests'];
      topicInterests
        ..clear()
        ..addAll(
          rawInterests is List
              ? rawInterests
                    .map((item) => item.toString())
                    .where((item) => item.isNotEmpty)
              : const [],
        );
    } catch (_) {
      // A profile document may not exist yet. The form remains usable.
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> choosePhoto() async {
    if (!signedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to change your photo.')),
      );
      return;
    }
    try {
      final photo = await pickAndCropProfilePhoto(context);
      if (photo == null || !mounted) return;
      setState(() {
        selectedPhoto = photo;
        error = null;
      });
      final url = await uploadProfilePhoto(user, photo);
      if (mounted) {
        setState(() {
          storedPhoto = url;
          selectedPhoto = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Could not update your photo: $e');
      }
    }
  }

  void save() {
    profilePhone = phoneField.text.trim();
    profileCity = cityField.text.trim();
    if (!signedIn) {
      setState(() {
        saving = false;
        editing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save this profile.')),
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final profileRef = firestore.collection('profiles').doc(user.uid);
    final write = profileRef.set({
      'name': user.displayName ?? '',
      'pictureUrl': storedPhoto.isNotEmpty
          ? storedPhoto
          : (user.photoURL ?? ''),
      'expertDetails': expertDetails.text.trim(),
      'email': user.email,
      'phoneNumber': profilePhone,
      'city': profileCity,
      'preferredPhysicalCity': profileCity,
      'topicInterests': topicInterests.toList(),
      'role': role,
      'upiId': upiField.text.trim(),
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
    unawaited(() async {
      try {
        await syncCityTopics(city: profileCity);
        if (role == 'Master') await publishMasterProfile();
      } catch (error) {
        debugPrint('City topic was not updated: $error');
      }
    }());
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

  String get displayName =>
      signedIn ? (user.displayName ?? 'Google account') : 'Demo Member';

  String get displayEmail => signedIn
      ? (user.email ?? 'No email available')
      : 'demo.member@masterclass.app';

  String get photoUrl {
    if (storedPhoto.trim().isNotEmpty) return storedPhoto.trim();
    return signedIn ? (user.photoURL ?? '') : '';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Profile'),
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
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 6),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (mcId.isNotEmpty) ...[
                McIdBanner(mcId: mcId),
                const SizedBox(height: 14),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: appCardDecoration(context, radius: 20),
                child: Column(
                  children: [
                    ProfileAvatar(
                      url: photoUrl,
                      name: displayName,
                      radius: 46,
                      localPhoto: selectedPhoto == null
                          ? null
                          : File(selectedPhoto!.path),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _RoleChip(role: role),
                        if (profileCity.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: AppPalette.of(context).muted,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                profileCity,
                                style: TextStyle(
                                  color: AppPalette.of(context).muted,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: choosePhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Change photo'),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: appCardDecoration(context, radius: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ProfileLabel('CONTACT'),
                    _ProfileInfoRow(
                      icon: Icons.mail_outline,
                      label: 'Email',
                      value: displayEmail,
                    ),
                    const Divider(height: 1),
                    if (editing)
                      TextField(
                        controller: phoneField,
                        keyboardType: TextInputType.phone,
                        decoration: _field(context, 'Phone number'),
                      )
                    else
                      _ProfileInfoRow(
                        icon: Icons.call_outlined,
                        label: 'Phone',
                        value: profilePhone.isEmpty
                            ? 'Not added yet'
                            : profilePhone,
                      ),
                    if (!editing) const Divider(height: 1),
                    if (editing)
                      TextField(
                        controller: cityField,
                        textCapitalization: TextCapitalization.words,
                        decoration: _field(context, 'City'),
                      )
                    else
                      _ProfileInfoRow(
                        icon: Icons.location_city_outlined,
                        label: 'City',
                        value: profileCity.isEmpty
                            ? 'Not added yet'
                            : profileCity,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: appCardDecoration(context, radius: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ProfileLabel('BIO'),
                    if (editing)
                      TextField(
                        controller: expertDetails,
                        minLines: 3,
                        maxLines: 5,
                        decoration: _field(
                          context,
                          'Your skills, experience, and subjects you teach',
                        ),
                      )
                    else
                      Text(
                        expertDetails.text.trim().isEmpty
                            ? 'Add your skills and teaching experience to introduce yourself to learners.'
                            : expertDetails.text.trim(),
                        style: TextStyle(
                          height: 1.45,
                          fontSize: 14,
                          color: expertDetails.text.trim().isEmpty
                              ? AppPalette.of(context).muted
                              : AppPalette.of(context).ink,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: appCardDecoration(context, radius: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ProfileLabel('ROLE'),
                    if (editing)
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final option in const ['Learner', 'Master'])
                            ChoiceChip(
                              label: Text(option),
                              selected: role == option,
                              onSelected: (_) => setState(() => role = option),
                            ),
                        ],
                      )
                    else
                      Text(role, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 16),
                    const _ProfileLabel('UPI ID'),
                    if (editing)
                      TextField(
                        controller: upiField,
                        decoration: _field(context, 'name@okbank'),
                      )
                    else
                      Text(
                        upiField.text.trim().isEmpty
                            ? 'Add a UPI ID so learners can pay you.'
                            : upiField.text.trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 16),
                    const _ProfileLabel('INTERESTS'),
                    if (editing)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final name in board.categories.keys)
                            FilterChip(
                              label: Text(name),
                              selected: topicInterests.contains(name),
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  topicInterests.add(name);
                                } else {
                                  topicInterests.remove(name);
                                }
                              }),
                            ),
                        ],
                      )
                    else if (topicInterests.isEmpty)
                      Text(
                        'No interests yet.',
                        style: TextStyle(color: AppPalette.of(context).muted),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final name in topicInterests)
                            Chip(
                              label: Text(name),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (editing) ...[
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: saving ? null : save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(saving ? 'Saving…' : 'Save changes'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const AcademyInvitesSection(),
              const SizedBox(height: 8),
              const FollowingSection(),
              const VerificationSubmitButton(),
              SharePosterButton(
                title: displayName,
                subtitle: profileCity.isEmpty ? 'Master Class' : profileCity,
                detail: mcId.isEmpty ? 'Learner profile' : mcId,
                link: masterShareLink(signedIn ? user.uid : 'preview'),
                color: const Color(0xFFD3ECF8),
              ),
              const SizedBox(height: 14),
              Builder(
                builder: (context) {
                  final colors = AppPalette.of(context);
                  final text = Theme.of(context).textTheme;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.accentSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          color: colors.onAccentSoft,
                          size: 30,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'YOUR CLASSES',
                                style: text.labelSmall?.copyWith(
                                  color: colors.onAccentSoft,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Manage your posts',
                                style: text.titleMedium?.copyWith(
                                  color: colors.onAccentSoft,
                                ),
                              ),
                              Text(
                                'Open a class to view it, or tap Update',
                                style: text.bodySmall?.copyWith(
                                  color: colors.onAccentSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openAllClassFees(context),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('All class fees'),
                ),
              ),
              if (!signedIn)
                Text(
                  'No classes posted yet.',
                  style: TextStyle(color: AppPalette.of(context).muted),
                )
              else
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: firestore
                      .collection('listings')
                      .where('creatorId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final classes = snapshot.data?.docs ?? [];
                    if (classes.isEmpty) {
                      return Text(
                        'No classes posted yet.',
                        style: TextStyle(color: AppPalette.of(context).muted),
                      );
                    }
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: classes.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: .48,
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
              if (!signedIn)
                Text(
                  'No class interests yet.',
                  style: TextStyle(color: AppPalette.of(context).muted),
                )
              else
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: firestore
                      .collectionGroup('interests')
                      .where('userId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final interests =
                        snapshot.data?.docs
                            .where(
                              (doc) => doc.data()['status'] == 'interested',
                            )
                            .toList() ??
                        [];
                    if (interests.isEmpty) {
                      return Text(
                        'No class interests yet.',
                        style: TextStyle(color: AppPalette.of(context).muted),
                      );
                    }
                    return Column(
                      children: interests
                          .map(
                            (doc) => ListTile(
                              tileColor: board.paper,
                              title: Text(
                                (doc.data()['listingTitle'] ??
                                        'Interested class')
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
              if (!editing && upiField.text.trim().isNotEmpty)
                UpiIdCard(upiId: upiField.text.trim(), name: displayName),
              LearnerBadgesCard(mcId: mcId),
              MasterReviewsCard(masterId: signedIn ? user.uid : ''),
              const _ProfileLabel('SAVED CLASSES'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SavedClassesPage(
                        onOpen: (data) => showMasterClassDetails(context, data),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Open saved classes'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_none),
                title: const Text('Notifications'),
                subtitle: const Text(
                  'Class reminders, fees, and announcements',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationInboxPage(),
                  ),
                ),
              ),
              const _ProfileLabel('ACCOUNT'),
              Card(
                child: ListTile(
                  onTap: () async {
                    if (!signedIn) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sign in to use this account.'),
                        ),
                      );
                      return;
                    }
                    await FirebaseAuth.instance.signOut();
                    await _googleSignIn.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  leading: Icon(
                    Icons.logout,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Sign out',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  subtitle: const Text('Sign out of your account'),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppPalette.of(context).muted,
                  ),
                ),
              ),
            ],
          ),
  );
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final style = categoryStyleForId(role == 'Master' ? 'yoga' : 'language');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: style.ink),
      ),
    );
  }
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

    final colors = AppPalette.of(context);
    return Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.line),
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
                    if (format == 'online') ...[
                      const SizedBox(height: 4),
                      _OnlineExpiryLine(data: data),
                    ],
                    if (data['is_academy'] == true &&
                        (data['academyId'] ?? '').toString().isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => openAcademy(
                            context,
                            (data['academyId'] ?? '').toString(),
                          ),
                          child: const Text('Academy'),
                        ),
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

class _OnlineExpiryLine extends StatelessWidget {
  const _OnlineExpiryLine({required this.data});

  final Map<String, dynamic> data;

  bool get expired {
    final when = readTimestampDate(data['expires_at']);
    if (when == null) return false;
    return !when.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final when = readTimestampDate(data['expires_at']);
    final label = when == null
        ? 'Expiry not set'
        : expired
        ? 'Expired ${formatExpiryDate(when)}'
        : 'Expires ${formatExpiryDate(when)}';
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: expired
                  ? const Color(0xFF9F1239)
                  : const Color(0xFF1A1A1A),
            ),
          ),
        ),
        TextButton(
          onPressed: () => renewOnlineListing(data),
          child: const Text('Renew'),
        ),
      ],
    );
  }
}

Future<void> renewOnlineListing(Map<String, dynamic> data) async {
  final id = (data['id'] ?? '').toString();
  if (id.isEmpty) return;
  final anchor = DateTime.now();
  final expires = capOnlineExpiry(anchor: anchor);
  await firestore.collection('listings').doc(id).update({
    'expires_at': Timestamp.fromDate(expires),
    'expiry_date': expires.toIso8601String().substring(0, 10),
    'renewedAt': Timestamp.fromDate(anchor),
  });
  await scheduleListingExpiryReminder(
    listingId: id,
    title: (data['title'] ?? 'Online class').toString(),
    expiresAt: expires,
  );
}

class _PostedClassImagePlaceholder extends StatelessWidget {
  const _PostedClassImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return ColoredBox(
      color: colors.imageFallback,
      child: Center(
        child: Icon(Icons.auto_stories_outlined, color: colors.accent),
      ),
    );
  }
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

InputDecoration _field(BuildContext context, String hint) {
  final colors = AppPalette.of(context);
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: colors.muted, fontSize: 14),
    filled: true,
    fillColor: colors.canvas,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.line),
    ),
  );
}

class _InterestSessionAccess extends StatelessWidget {
  const _InterestSessionAccess({required this.listingId});
  final String listingId;

  Future<void> _openSession(BuildContext context, String link) async {
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
        future: listingId.isEmpty
            ? null
            : firestore.collection('listings_contact').doc(listingId).get(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          if (data == null) {
            return const Text('Private session details are not available yet.');
          }
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
