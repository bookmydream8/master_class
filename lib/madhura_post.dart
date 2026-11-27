import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_database.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import 'academy.dart';
import 'app_theme.dart';
import 'class_reminders.dart';
import 'listing_expiry.dart';
import 'madhura_board.dart' as board;
import 'profile_photo.dart';
import 'spark_pages.dart';

const spokenLanguageOptions = <String>[
  'English',
  'Hindi',
  'Kannada',
  'Tamil',
  'Telugu',
  'Malayalam',
  'Marathi',
  'Bengali',
  'Gujarati',
  'Punjabi',
  'Odia',
  'Assamese',
  'Konkani',
  'Kashmiri',
  'Sindhi',
  'Nepali',
  'Manipuri',
  'Bodo',
  'Dogri',
  'Maithili',
  'Santali',
  'Urdu',
  'Sanskrit',
  'French',
  'German',
  'Spanish',
  'Japanese',
];
const ageGroupOptions = <String>[
  'Preschooler · 3–5 years',
  'Child / Kids · 5–12 years',
  'Teenager / Preteen · 13–19 years',
  'Young Adult · 18–30 years',
  'Adult · 30–45 years / 13+ general',
  'Middle-aged · 45–65 years',
];

class MasterClassPostForm extends StatefulWidget {
  const MasterClassPostForm({super.key, this.existing, this.listingId});
  final Map<String, dynamic>? existing;
  final String? listingId;
  @override
  State<MasterClassPostForm> createState() => _MasterClassPostFormState();
}

class _MasterClassPostFormState extends State<MasterClassPostForm> {
  String format = 'physical';
  String category = 'Music';
  String? focus;
  String city = '';
  final customCity = TextEditingController();
  final area = TextEditingController();
  bool isFree = true;
  bool asAcademy = false;
  bool makeupAllowed = false;
  String feePeriod = 'month';
  bool saving = false;
  bool locating = false;
  String? error;
  DateTime? startDate;
  DateTime? expiryDate;
  TimeOfDay? startTime;
  final ageGroups = <String>{};
  final spokenLanguages = <String>{};
  final customSpokenLanguage = TextEditingController();
  XFile? selectedPhoto;
  bool choosingPhoto = false;
  String profilePhone = '';
  final title = TextEditingController();
  final description = TextEditingController();
  final aboutMaster = TextEditingController();
  final durationDays = TextEditingController();
  final previousLinks = TextEditingController();
  final price = TextEditingController();
  final mapLink = TextEditingController();
  final landmark = TextEditingController();
  final sessionLink = TextEditingController();
  final contactNumber = TextEditingController();
  final cancelHours = TextEditingController(text: '24');
  final refundPolicy = TextEditingController();
  final customCategory = TextEditingController();
  final customSubcategory = TextEditingController();

  @override
  void initState() {
    super.initState();
    final data = widget.existing;
    if (data == null) {
      _loadProfileDefaults();
      return;
    }
    format = (data['listing_type'] ?? 'physical').toString();
    category = board.categories.keys.firstWhere(
      (key) => board.categoryIds[key] == data['category'],
      orElse: () => 'Music',
    );
    focus = data['subcategory']?.toString();
    city = data['city']?.toString() ?? '';
    if (city.isNotEmpty && !board.cities.contains(city)) {
      customCity.text = city;
      city = '_custom';
    }
    isFree = data['is_free'] == true || data['priceType'] == 'free';
    feePeriod = data['fee_period'] == 'course' ? 'course' : 'month';
    title.text = (data['title'] ?? '').toString();
    description.text = (data['description'] ?? '').toString();
    aboutMaster.text = (data['about_master'] ?? '').toString();
    price.text = (data['price'] ?? '').toString();
    durationDays.text = (data['duration_days'] ?? '').toString();
    previousLinks.text = (data['previous_class_links'] ?? '').toString();
    mapLink.text = (data['map_location'] ?? '').toString();
    landmark.text = (data['landmark'] ?? '').toString();
    area.text = (data['area'] ?? '').toString();
    _loadPrivateContact();
    _loadProfilePhone();
    startDate = DateTime.tryParse((data['start_date'] ?? '').toString());
    expiryDate =
        DateTime.tryParse((data['expiry_date'] ?? '').toString()) ?? startDate;
    ageGroups.addAll(
      (data['age_groups'] as List? ?? const []).map(
        (value) => value.toString(),
      ),
    );
    if (ageGroups.isEmpty && (data['age_group'] ?? '').toString().isNotEmpty) {
      ageGroups.add(data['age_group'].toString());
    }
    spokenLanguages.addAll(
      (data['spoken_languages'] as List? ?? const []).map(
        (value) => value.toString(),
      ),
    );
    final time = (data['start_time'] ?? '').toString().split(':');
    if (time.length == 2) {
      startTime = TimeOfDay(
        hour: int.tryParse(time[0]) ?? 0,
        minute: int.tryParse(time[1]) ?? 0,
      );
    }
  }

  Future<void> _loadProfileDefaults() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final profile =
          (await firestore.collection('profiles').doc(user.uid).get()).data();
      if (!mounted || profile == null) return;
      setState(() {
        aboutMaster.text = (profile['expertDetails'] ?? '').toString();
        profilePhone = (profile['phoneNumber'] ?? '').toString().trim();
        contactNumber.text = profilePhone;
        final profileCity =
            (profile['city'] ?? profile['preferredPhysicalCity'] ?? '')
                .toString();
        if (profileCity.isNotEmpty) {
          if (board.cities.contains(profileCity)) {
            city = profileCity;
          } else {
            city = '_custom';
            customCity.text = profileCity;
          }
        }
      });
    } catch (_) {}
  }

  String _expiryDateString(DateTime value) =>
      value.toIso8601String().substring(0, 10);

  Future<void> choosePhoto() async {
    if (choosingPhoto) return;
    setState(() {
      choosingPhoto = true;
      error = null;
    });
    try {
      final source = await askImageSource(context);
      if (source == null || !mounted) return;
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (photo == null) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: photo.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 55,
        maxWidth: 1200,
        maxHeight: 800,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop class photo',
            toolbarColor: const Color(0xFF1A6B73),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false,
            aspectRatioPresets: const [
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.original,
            ],
          ),
          IOSUiSettings(
            title: 'Crop class photo',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
            aspectRatioPickerButtonHidden: false,
            aspectRatioPresets: const [
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.original,
            ],
          ),
        ],
      );
      if (cropped == null || !mounted) return;
      final prepared = XFile(cropped.path);
      if (await prepared.length() > 600 * 1024) {
        if (mounted) {
          setState(
            () => error = 'This photo is too large. Crop a smaller area or choose another photo.',
          );
        }
        return;
      }
      if (mounted) setState(() => selectedPhoto = prepared);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not prepare the photo: $e');
    } finally {
      if (mounted) setState(() => choosingPhoto = false);
    }
  }

  void _addCustomSpokenLanguage() {
    final value = customSpokenLanguage.text.trim();
    if (value.isEmpty) return;
    setState(() {
      spokenLanguages.add(value);
      customSpokenLanguage.clear();
    });
  }

  @override
  void dispose() {
    for (final controller in [
      title,
      description,
      aboutMaster,
      durationDays,
      previousLinks,
      price,
      mapLink,
      customCity,
      area,
      customCategory,
      customSubcategory,
      customSpokenLanguage,
      cancelHours,
      refundPolicy,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfilePhone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final profile =
          (await firestore.collection('profiles').doc(user.uid).get()).data();
      final value = (profile?['phoneNumber'] ?? '').toString().trim();
      if (mounted && value.isNotEmpty) setState(() => profilePhone = value);
    } catch (_) {}
  }

  Future<void> _loadPrivateContact() async {
    final id = widget.listingId;
    if (id == null) return;
    try {
      final data =
          (await firestore.collection('listings_contact').doc(id).get()).data();
      if (!mounted || data == null) return;
      sessionLink.text = (data['sessionLink'] ?? '').toString();
      contactNumber.text = (data['contactNumber'] ?? '').toString();
    } catch (_) {
      // Private details may not exist for older listings.
    }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        final previousStart = startDate;
        startDate = picked;
        if (expiryDate == null || expiryDate == previousStart) {
          expiryDate = picked;
        }
      });
    }
  }

  Future<void> pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: expiryDate ?? startDate ?? DateTime.now(),
      firstDate: startDate ?? DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => expiryDate = picked);
  }

  Future<void> useCurrentLocation() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(
          'Turn on Location in your phone settings, then try again.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw StateError('Location permission was not granted.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission is blocked. Enable it in the app settings.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 20));
      mapLink.text =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current location added to the venue link.'),
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        setState(
          () => error = 'Location took too long. Check GPS and try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => locating = false);
      }
    }
  }

  Future<void> publish() async {
    if (title.text.trim().isEmpty || description.text.trim().isEmpty) {
      setState(() => error = 'Add a class name and description.');
      return;
    }
    if (startDate == null) {
      setState(() => error = 'Select a start date.');
      return;
    }
    if (expiryDate != null && expiryDate!.isBefore(startDate!)) {
      setState(() => error = 'Expiry date cannot be before the start date.');
      return;
    }
    final amount = double.tryParse(price.text.trim());
    if (!isFree && (amount == null || amount < 0)) {
      setState(() => error = 'Enter a valid price in rupees.');
      return;
    }
    final contact = contactNumber.text.trim();
    final session = sessionLink.text.trim();
    if (contact.length < 5) {
      setState(() => error = 'A valid contact / WhatsApp number is required.');
      return;
    }
    final selectedCity = city == '_custom' ? customCity.text.trim() : city;
    if (format != 'online' && city == '_custom' && selectedCity.isEmpty) {
      setState(() => error = 'Enter a city name.');
      return;
    }
    final requiresPhysicalArea =
        format == 'physical' || format == 'competition';
    if (requiresPhysicalArea && selectedCity.isEmpty) {
      setState(() => error = 'Select the city for this physical listing.');
      return;
    }
    if (requiresPhysicalArea && area.text.trim().isEmpty) {
      setState(
        () => error = 'Enter the area / locality for this physical listing.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        throw StateError('Please sign in before publishing.');
      }
      final photoBytes = selectedPhoto == null
          ? null
          : await selectedPhoto!.readAsBytes();
      if (photoBytes != null && photoBytes.lengthInBytes > 600 * 1024) {
        throw StateError('The photo is too large. Choose a smaller crop.');
      }
      final encodedPhoto = photoBytes == null
          ? null
          : await compute(base64Encode, photoBytes);
      final legacyType = switch (format) {
        'physical' => 'offline_class',
        'online' => 'online_class',
        // Keep the legacy type accepted by existing Firestore rules.
        'event' => 'competition',
        _ => 'competition',
      };
      final now = DateTime.now();
      final existingPosted = readTimestampDate(widget.existing?['postedAt']);
      final anchor = existingPosted ?? now;
      final resolvedExpiry = format == 'online'
          ? capOnlineExpiry(anchor: anchor, requested: expiryDate)
          : DateTime(
              (expiryDate ?? startDate ?? now).year,
              (expiryDate ?? startDate ?? now).month,
              (expiryDate ?? startDate ?? now).day,
              23,
              59,
              59,
            );
      final postedAt = Timestamp.fromDate(anchor);
      final ref = firestore
          .collection('listings')
          .doc(
            widget.listingId ??
                '${format}_${user.uid}_${now.microsecondsSinceEpoch}',
          );
      await ref
          .set({
            'id': ref.id,
            'type': legacyType,
            'listing_type': format,
            'category': category == 'Custom'
                ? customCategory.text.trim()
                : board.categoryIds[category],
            'subcategory': category == 'Custom'
                ? customSubcategory.text.trim()
                : focus,
            'title': title.text.trim(),
            'description': description.text.trim(),
            'about_master': aboutMaster.text.trim(),
            'image_base64': ?encodedPhoto,
            if (encodedPhoto == null &&
                widget.existing?['image_base64'] is String)
              'image_base64': widget.existing!['image_base64'],
            if (encodedPhoto == null && widget.existing?['image_url'] is String)
              'image_url': widget.existing!['image_url'],
            'priceType': isFree ? 'free' : 'paid',
            'is_free': isFree,
            'price': isFree ? 0 : amount,
            if (format == 'online' || format == 'physical')
              'fee_period': isFree ? 'month' : feePeriod,
            'start_date': startDate?.toIso8601String().substring(0, 10),
            'start_time': startTime == null
                ? null
                : '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}',
            'duration_days': int.tryParse(durationDays.text.trim()),
            'spoken_languages': spokenLanguages.toList()..sort(),
            'age_groups': ageGroups.toList()..sort(),
            'age_group': ageGroups.join(', '),
            'expiry_date': _expiryDateString(resolvedExpiry),
            'expires_at': Timestamp.fromDate(resolvedExpiry),
            if (format == 'online') 'postedAt': postedAt,
            if (previousLinks.text.trim().isNotEmpty)
              'previous_class_links': previousLinks.text.trim(),
            if (format != 'online' && selectedCity.isNotEmpty)
              'city': selectedCity,
            if ((format == 'physical' || format == 'competition') &&
                area.text.trim().isNotEmpty)
              'area': area.text.trim(),
            if (format != 'online' && landmark.text.trim().isNotEmpty)
              'landmark': landmark.text.trim(),
            if (format != 'online' && mapLink.text.trim().isNotEmpty)
              'map_location': mapLink.text.trim(),
            if (format == 'online') 'topic': focus ?? category,
            'creatorId': user.uid,
            'creatorName': user.displayName ?? 'Class master',
            'cancelByHours': int.tryParse(cancelHours.text.trim()) ?? 24,
            'refundPolicy': refundPolicy.text.trim().isEmpty
                ? 'Ask the master before paying.'
                : refundPolicy.text.trim(),
            'makeupAllowed': makeupAllowed,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          })
          .timeout(const Duration(seconds: 20));
      if (contact.isNotEmpty) {
        var upiId = '';
        var masterName = user.displayName ?? 'Class master';
        try {
          final profile =
              (await firestore.collection('profiles').doc(user.uid).get())
                  .data();
          upiId = (profile?['upiId'] ?? '').toString().trim();
          final storedName = (profile?['name'] ?? '').toString().trim();
          if (storedName.isNotEmpty) masterName = storedName;
        } catch (_) {}
        await firestore.collection('listings_contact').doc(ref.id).set({
          'id': ref.id,
          'creatorId': user.uid,
          'contactNumber': contact,
          'masterName': masterName,
          'masterEmail': user.email ?? '',
          'masterPhone': contact,
          if (upiId.isNotEmpty) 'upiId': upiId,
          if (session.isNotEmpty) 'sessionLink': session,
          'updatedAt': now.toIso8601String(),
        }, SetOptions(merge: true));
      }
      if (format == 'online') {
        await scheduleListingExpiryReminder(
          listingId: ref.id,
          title: title.text.trim(),
          expiresAt: resolvedExpiry,
        );
      }
      await notifyFollowersOfPost(
        masterId: user.uid,
        title: title.text.trim(),
        kindLabel: format,
      );
      if (format == 'physical' && asAcademy) {
        final address = [
          area.text.trim(),
          selectedCity,
          landmark.text.trim(),
        ].where((value) => value.isNotEmpty).join(', ');
        await createAcademyForListing(
          listingId: ref.id,
          name: title.text.trim(),
          address: address,
          ownerId: user.uid,
          imageBase64: encodedPhoto,
        );
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop(true);
    } on TimeoutException {
      if (mounted) {
        setState(
          () => error =
              'Publishing took too long. Check your connection and try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Could not publish: $e');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          22 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHARE WHAT YOU KNOW',
                      style: text.labelSmall?.copyWith(
                        letterSpacing: 1.1,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      format == 'event' ? 'Post an event' : 'Post a class',
                      style: text.headlineSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FormCard(
            'WHAT ARE YOU POSTING?',
            Column(
              children: [
                Wrap(
                  spacing: 7,
                  children: board.formats.entries
                      .where(
                        (entry) => const {
                          'online',
                          'physical',
                          'competition',
                          'event',
                        }.contains(entry.key),
                      )
                      .map(
                        (entry) => ChoiceChip(
                          label: Text(entry.value),
                          selected: format == entry.key,
                          onSelected: (_) => setState(() => format = entry.key),
                        ),
                      )
                      .toList(),
                ),
                if (format == 'physical')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('This is an Academy'),
                    subtitle: const Text(
                      'Several teachers, batches, students, fees, and salaries.',
                    ),
                    value: asAcademy,
                    onChanged: (value) => setState(() => asAcademy = value),
                  ),
                TextField(
                  controller: cancelHours,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cancel at least this many hours before',
                  ),
                ),
                TextField(
                  controller: refundPolicy,
                  decoration: const InputDecoration(
                    labelText: 'Refund note',
                    hintText: 'Full refund if cancelled in time, or no refund',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Makeup class allowed'),
                  value: makeupAllowed,
                  onChanged: (value) => setState(() => makeupAllowed = value),
                ),
              ],
            ),
          ),
          _FormCard(
            'FOCUS',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [...board.categories.keys, 'Custom']
                      .map(
                        (name) => ChoiceChip(
                          label: Text(name),
                          selected: category == name,
                          onSelected: (_) => setState(() {
                            category = name;
                            focus = null;
                          }),
                        ),
                      )
                      .toList(),
                ),
                if (category == 'Custom') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: customCategory,
                    decoration: _decoration(context, 'Custom category'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: customSubcategory,
                    decoration: _decoration(
                      context,
                      'Custom sub-category · optional',
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: focus,
                    hint: Text('Any ${category.toLowerCase()}'),
                    decoration: _decoration(context, 'Specific focus'),
                    items: board.categories[category]!
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => focus = value),
                  ),
                ],
              ],
            ),
          ),
          _FormCard(
            'LEARNING AUDIENCE',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spoken language(s) used for the class',
                  style: text.bodySmall?.copyWith(color: colors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: spokenLanguageOptions
                      .map(
                        (language) => FilterChip(
                          label: Text(language),
                          selected: spokenLanguages.contains(language),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              spokenLanguages.add(language);
                            } else {
                              spokenLanguages.remove(language);
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: customSpokenLanguage,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(context, 'Other language'),
                  onSubmitted: (_) => _addCustomSpokenLanguage(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addCustomSpokenLanguage,
                    icon: const Icon(Icons.add),
                    label: const Text('Add language'),
                  ),
                ),
                for (final language in spokenLanguages.where(
                  (value) => !spokenLanguageOptions.contains(value),
                ))
                  InputChip(
                    label: Text(language),
                    onDeleted: () =>
                        setState(() => spokenLanguages.remove(language)),
                  ),
                const SizedBox(height: 14),
                Text(
                  'Suitable age groups · optional',
                  style: text.bodySmall?.copyWith(color: colors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ageGroupOptions
                      .map(
                        (value) => FilterChip(
                          label: Text(value),
                          selected: ageGroups.contains(value),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              ageGroups.add(value);
                            } else {
                              ageGroups.remove(value);
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          _FormCard(
            'CLASS DETAILS',
            Column(
              children: [
                TextField(
                  controller: title,
                  decoration: _decoration(
                    context,
                    'Class name — e.g. Tabla foundations',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: _decoration(
                    context,
                    'What learners cover, weekly schedule, level…',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: aboutMaster,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _decoration(
                    context,
                    'About the master / teacher',
                  ),
                ),
              ],
            ),
          ),
          _FormCard(
            'COVER PHOTO · OPTIONAL',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: choosingPhoto || saving ? null : choosePhoto,
                  icon: choosingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(
                    choosingPhoto
                        ? 'Preparing photo…'
                        : selectedPhoto == null
                        ? 'Choose and crop photo'
                        : 'Change photo',
                  ),
                ),
                if (selectedPhoto != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(selectedPhoto!.path),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Photo ready to publish',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          _FormCard(
            'PREVIOUS CLASSES · OPTIONAL',
            TextField(
              controller: previousLinks,
              keyboardType: TextInputType.url,
              maxLines: 3,
              decoration: _decoration(
                context,
                'YouTube or website links, one per line',
              ),
            ),
          ),
          _FormCard(
            'CONTACT & SESSION ACCESS',
            Column(
              children: [
                TextField(
                  controller: contactNumber,
                  keyboardType: TextInputType.phone,
                  decoration: _decoration(
                    context,
                    'Contact / WhatsApp number *',
                  ),
                ),
                if (profilePhone.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => contactNumber.text = profilePhone),
                      icon: const Icon(Icons.content_copy_outlined, size: 16),
                      label: const Text('Use phone from profile'),
                    ),
                  ),

                const SizedBox(height: 10),
                TextField(
                  controller: sessionLink,
                  keyboardType: TextInputType.url,
                  decoration: _decoration(
                    context,
                    'Session link (Zoom, Meet, etc.)',
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'These details are hidden from the class listing and shared after a learner expresses interest.',
                  style: text.bodySmall?.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
          _FormCard(
            'PRICING',
            Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Free'),
                      selected: isFree,
                      onSelected: (_) => setState(() => isFree = true),
                    ),
                    ChoiceChip(
                      label: const Text('Paid'),
                      selected: !isFree,
                      onSelected: (_) => setState(() => isFree = false),
                    ),
                  ],
                ),
                if (!isFree) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: _decoration(
                      context,
                      format == 'online' || format == 'physical'
                          ? 'Fee amount in ₹'
                          : 'Price in ₹',
                    ),
                  ),
                  if (format == 'online' || format == 'physical') ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Fee type',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Per month'),
                          selected: feePeriod == 'month',
                          onSelected: (_) =>
                              setState(() => feePeriod = 'month'),
                        ),
                        ChoiceChip(
                          label: const Text('One-time course fee'),
                          selected: feePeriod == 'course',
                          onSelected: (_) =>
                              setState(() => feePeriod = 'course'),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
          _FormCard(
            'SCHEDULE',
            Column(
              children: [
                OutlinedButton(
                  onPressed: pickDate,
                  child: Text(
                    startDate == null
                        ? 'Select start date'
                        : 'Start: ${startDate!.day}/${startDate!.month}/${startDate!.year}',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: pickExpiryDate,
                  child: Text(
                    format == 'online'
                        ? 'Online expiry: ${formatExpiryDate(capOnlineExpiry(anchor: DateTime.now(), requested: expiryDate))} (max 1 month)'
                        : expiryDate == null
                        ? 'Expiry date (defaults to start date)'
                        : 'Expires: ${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: startTime ?? TimeOfDay.now(),
                    );
                    if (time != null) setState(() => startTime = time);
                  },
                  child: Text(
                    startTime == null
                        ? 'Select start time'
                        : startTime!.format(context),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: durationDays,
                  keyboardType: TextInputType.number,
                  decoration: _decoration(
                    context,
                    'Duration in number of days',
                  ),
                ),
              ],
            ),
          ),
          if (format != 'online')
            _FormCard(
              format == 'physical' || format == 'competition'
                  ? 'LOCATION · REQUIRED FOR PHYSICAL LISTINGS'
                  : 'LOCATION · OPTIONAL',
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey(city),
                    initialValue: city.isEmpty ? null : city,
                    decoration: _decoration(
                      context,
                      format == 'physical' || format == 'competition'
                          ? 'City *'
                          : 'City (optional)',
                    ),
                    items: [
                      ...board.cities.map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      ),
                      const DropdownMenuItem(
                        value: '_custom',
                        child: Text('Other city…'),
                      ),
                    ],
                    onChanged: (value) => setState(() => city = value ?? ''),
                  ),
                  if (city == '_custom') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: customCity,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 100,
                      decoration: _decoration(context, 'Enter city name'),
                    ),
                  ],
                  if (format == 'physical' || format == 'competition') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: area,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 100,
                      decoration: _decoration(
                        context,
                        'Area / locality * — e.g. Indiranagar',
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: locating ? null : useCurrentLocation,
                    icon: locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_outlined),
                    label: Text(
                      locating
                          ? 'Getting current location…'
                          : 'Use current location',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: mapLink,
                    keyboardType: TextInputType.url,
                    decoration: _decoration(
                      context,
                      'Google Maps link to the venue',
                    ),
                  ),
                ],
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: saving ? null : publish,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(saving ? 'Publishing…' : 'Publish listing'),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard(this.title, this.child);
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(letterSpacing: 1.1, color: colors.muted),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

InputDecoration _decoration(BuildContext context, String hint) {
  final colors = AppPalette.of(context);
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: colors.muted, fontSize: 13),
    filled: true,
    fillColor: colors.canvas,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.line),
    ),
  );
}
