import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'app_theme.dart';
import 'firestore_database.dart';

bool _offeredProfilePhoto = false;
bool _offeringProfilePhoto = false;

/// Saves the sign-in provider photo onto the profile when the member has not
/// uploaded their own picture yet.
Future<void> adoptProviderPhoto(User user) async {
  final provider = (user.photoURL ?? '').trim();
  if (provider.isEmpty) return;
  final ref = firestore.collection('profiles').doc(user.uid);
  final data = (await ref.get()).data();
  final stored = (data?['pictureUrl'] ?? '').toString().trim();
  if (_isUploadedPhoto(stored) || stored == provider) return;
  await ref.set({
    'pictureUrl': provider,
    'name': user.displayName ?? data?['name'] ?? '',
    'email': user.email ?? data?['email'] ?? '',
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

bool _isUploadedPhoto(String url) =>
    url.contains('firebasestorage.googleapis.com') ||
    url.contains('/profile_photos/');

Future<ImageSource?> askImageSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

Future<XFile?> pickAndCropProfilePhoto(BuildContext context) async {
  final source = await askImageSource(context);
  if (source == null) return null;
  final photo = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 90,
  );
  if (photo == null) return null;
  final cropped = await ImageCropper().cropImage(
    sourcePath: photo.path,
    maxWidth: 800,
    maxHeight: 800,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 82,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop profile photo',
        toolbarColor: const Color(0xFF1A6B73),
        toolbarWidgetColor: Colors.white,
        cropStyle: CropStyle.circle,
        lockAspectRatio: true,
        initAspectRatio: CropAspectRatioPreset.square,
        aspectRatioPresets: const [CropAspectRatioPreset.square],
      ),
      IOSUiSettings(
        title: 'Crop profile photo',
        cropStyle: CropStyle.circle,
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
        aspectRatioPresets: const [CropAspectRatioPreset.square],
      ),
    ],
  );
  if (cropped == null) return null;
  return XFile(cropped.path);
}

Future<String> uploadProfilePhoto(User user, XFile file) async {
  final ref = FirebaseStorage.instance.ref().child(
    'profile_photos/${user.uid}/avatar.jpg',
  );
  await ref.putFile(
    File(file.path),
    SettableMetadata(contentType: 'image/jpeg'),
  );
  final url = await ref.getDownloadURL();
  await user.updatePhotoURL(url);
  await firestore.collection('profiles').doc(user.uid).set({
    'pictureUrl': url,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  return url;
}

/// Offers a camera or gallery photo when the signed-in member has none.
Future<void> offerMissingProfilePhoto(BuildContext context) async {
  if (_offeredProfilePhoto || _offeringProfilePhoto) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.isAnonymous) return;
  _offeringProfilePhoto = true;
  try {
    try {
      await adoptProviderPhoto(user);
    } catch (_) {}
    final data = (await firestore.collection('profiles').doc(user.uid).get())
        .data();
    final stored = (data?['pictureUrl'] ?? '').toString().trim();
    final provider = (user.photoURL ?? '').trim();
    if (stored.isNotEmpty || provider.isNotEmpty) return;
    _offeredProfilePhoto = true;
    if (!context.mounted) return;
    final add = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a profile photo'),
        content: const Text(
          'Google did not share a photo. Take one or choose from your gallery. You can change it later from Profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Add photo'),
          ),
        ],
      ),
    );
    if (add != true || !context.mounted) return;
    final file = await pickAndCropProfilePhoto(context);
    if (file == null) return;
    await uploadProfilePhoto(user, file);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile photo saved.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the photo: $error')),
      );
    }
  } finally {
    _offeringProfilePhoto = false;
  }
}

/// Small round photo used on Home and Profile.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.url,
    required this.name,
    this.radius = 22,
    this.localPhoto,
  });

  final String url;
  final String name;
  final double radius;
  final File? localPhoto;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    final network = url.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.accentSoft,
      foregroundImage: localPhoto != null
          ? FileImage(localPhoto!)
          : (network.isEmpty ? null : NetworkImage(network)),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w700,
          color: colors.onAccentSoft,
        ),
      ),
    );
  }
}
