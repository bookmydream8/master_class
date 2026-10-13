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

import 'madhura_board.dart' as board;

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
    if (ageGroups.isEmpty && (data['age_group'] ?? '').toString().isNotEmpty)
      ageGroups.add(data['age_group'].toString());
    spokenLanguages.addAll(
      (data['spoken_languages'] as List? ?? const []).map(
        (value) => value.toString(),
      ),
    );
    final time = (data['start_time'] ?? '').toString().split(':');
    if (time.length == 2)
      startTime = TimeOfDay(
        hour: int.tryParse(time[0]) ?? 0,
        minute: int.tryParse(time[1]) ?? 0,
      );
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

  Future<void> choosePhoto() async {
    if (choosingPhoto) return;
    setState(() {
      choosingPhoto = true;
      error = null;
    });
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 75,
      );
      if (photo == null) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: photo.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 55,
        maxWidth: 800,
        maxHeight: 800,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop class photo',
            toolbarColor: board.ink,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false,
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
            if (encodedPhoto != null) 'image_base64': encodedPhoto,
            if (encodedPhoto == null &&
                widget.existing?['image_base64'] is String)
              'image_base64': widget.existing!['image_base64'],
            if (encodedPhoto == null && widget.existing?['image_url'] is String)
              'image_url': widget.existing!['image_url'],
            'priceType': isFree ? 'free' : 'paid',
            'is_free': isFree,
            'price': isFree ? 0 : amount,
            'start_date': startDate?.toIso8601String().substring(0, 10),
            'start_time': startTime == null
                ? null
                : '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}',
            'duration_days': int.tryParse(durationDays.text.trim()),
            'spoken_languages': spokenLanguages.toList()..sort(),
            'age_groups': ageGroups.toList()..sort(),
            'age_group': ageGroups.join(', '),
            'expiry_date': (expiryDate ?? startDate)!
                .toIso8601String()
                .substring(0, 10),
            'expires_at': Timestamp.fromDate(
              DateTime(
                (expiryDate ?? startDate)!.year,
                (expiryDate ?? startDate)!.month,
                (expiryDate ?? startDate)!.day,
                23,
                59,
                59,
              ),
            ),
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
            'creatorEmail': user.email ?? '',
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          })
          .timeout(const Duration(seconds: 20));
      if (contact.isNotEmpty) {
        await firestore.collection('listings_contact').doc(ref.id).set({
          'id': ref.id,
          'creatorId': user.uid,
          'contactNumber': contact,
          if (session.isNotEmpty) 'sessionLink': session,
          'updatedAt': now.toIso8601String(),
        }, SetOptions(merge: true));
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
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      decoration: const BoxDecoration(
        color: board.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          22 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: board.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SHARE WHAT YOU KNOW',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: board.muted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      format == 'event' ? 'Post an event' : 'Post a class',
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: board.ink,
                      ),
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
                          selectedColor: board.gold,
                          backgroundColor: board.cream,
                          onSelected: (_) => setState(() => format = entry.key),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          _FormCard(
            'FOCUS',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [...board.categories.keys, 'Custom']
                        .map(
                          (name) => Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              label: Text(name),
                              selected: category == name,
                              selectedColor: board.ink,
                              backgroundColor: board.cream,
                              labelStyle: TextStyle(
                                color: category == name
                                    ? board.paper
                                    : board.ink,
                              ),
                              onSelected: (_) => setState(() {
                                category = name;
                                focus = null;
                              }),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                if (category == 'Custom') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: customCategory,
                    decoration: _decoration('Custom category'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: customSubcategory,
                    decoration: _decoration('Custom sub-category · optional'),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: focus,
                    hint: Text('Any ${category.toLowerCase()}'),
                    decoration: _decoration('Specific focus'),
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
                const Text(
                  'Spoken language(s) used for the class',
                  style: TextStyle(fontSize: 12, color: board.muted),
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
                          selectedColor: board.gold,
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customSpokenLanguage,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration('Other language'),
                        onSubmitted: (_) => _addCustomSpokenLanguage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Add language',
                      onPressed: _addCustomSpokenLanguage,
                      icon: const Icon(Icons.add),
                    ),
                  ],
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
                const Text(
                  'Suitable age groups · optional',
                  style: TextStyle(fontSize: 12, color: board.muted),
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
                          selectedColor: board.gold,
                          onSelected: (selected) => setState(() {
                            if (selected)
                              ageGroups.add(value);
                            else
                              ageGroups.remove(value);
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
                    'Class name — e.g. Tabla foundations',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: _decoration(
                    'What learners cover, weekly schedule, level…',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: aboutMaster,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _decoration('About the master / teacher'),
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
              decoration: _decoration('YouTube or website links, one per line'),
            ),
          ),
          _FormCard(
            'CONTACT & SESSION ACCESS',
            Column(
              children: [
                TextField(
                  controller: contactNumber,
                  keyboardType: TextInputType.phone,
                  decoration: _decoration('Contact / WhatsApp number *'),
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
                  decoration: _decoration('Session link (Zoom, Meet, etc.)'),
                ),
                const SizedBox(height: 7),
                const Text(
                  'These details are hidden from the class listing and shared after a learner expresses interest.',
                  style: TextStyle(fontSize: 12, color: board.muted),
                ),
              ],
            ),
          ),
          _FormCard(
            'PRICING',
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Free')),
                        selected: isFree,
                        selectedColor: board.gold,
                        onSelected: (_) => setState(() => isFree = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Paid')),
                        selected: !isFree,
                        selectedColor: board.gold,
                        onSelected: (_) => setState(() => isFree = false),
                      ),
                    ),
                  ],
                ),
                if (!isFree) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: _decoration('Price in ₹'),
                  ),
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
                    expiryDate == null
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
                  decoration: _decoration('Duration in number of days'),
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
                    key: ValueKey(city),
                    initialValue: city.isEmpty ? null : city,
                    decoration: _decoration(
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
                      decoration: _decoration('Enter city name'),
                    ),
                  ],
                  if (format == 'physical' || format == 'competition') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: area,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 100,
                      decoration: _decoration(
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
                    decoration: _decoration('Google Maps link to the venue'),
                  ),
                ],
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(error!, style: const TextStyle(color: board.clay)),
            ),
          FilledButton(
            onPressed: saving ? null : publish,
            style: FilledButton.styleFrom(
              backgroundColor: board.clay,
              minimumSize: const Size.fromHeight(49),
            ),
            child: Text(saving ? 'Publishing…' : 'Publish listing'),
          ),
        ],
      ),
    ),
  );
}

class _FormCard extends StatelessWidget {
  const _FormCard(this.title, this.child);
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: board.paper,
        border: Border.all(color: board.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: board.muted,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

InputDecoration _decoration(String hint) => InputDecoration(
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
