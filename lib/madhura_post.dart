import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'madhura_board.dart' as board;

class MadhuraPostForm extends StatefulWidget {
  const MadhuraPostForm({super.key, this.existing, this.listingId});
  final Map<String, dynamic>? existing;
  final String? listingId;
  @override
  State<MadhuraPostForm> createState() => _MadhuraPostFormState();
}

class _MadhuraPostFormState extends State<MadhuraPostForm> {
  String format = 'physical';
  String category = 'Music';
  String? focus;
  String city = '';
  bool isFree = true;
  bool saving = false;
  bool locating = false;
  String? error;
  DateTime? startDate;
  TimeOfDay? startTime;
  XFile? selectedPhoto;
  final title = TextEditingController();
  final description = TextEditingController();
  final aboutMaster = TextEditingController();
  final durationDays = TextEditingController();
  final previousLinks = TextEditingController();
  final price = TextEditingController();
  final mapLink = TextEditingController();
  final customCategory = TextEditingController();
  final customSubcategory = TextEditingController();

  @override
  void initState() {
    super.initState();
    final data = widget.existing;
    if (data == null) return;
    format = (data['listing_type'] ?? 'physical').toString();
    category = board.categories.keys.firstWhere(
      (key) => board.categoryIds[key] == data['category'],
      orElse: () => 'Music',
    );
    focus = data['subcategory']?.toString();
    city = data['city']?.toString() ?? ''; 
    isFree = data['is_free'] == true || data['priceType'] == 'free';
    title.text = (data['title'] ?? '').toString();
    description.text = (data['description'] ?? '').toString();
    aboutMaster.text = (data['about_master'] ?? '').toString();
    price.text = (data['price'] ?? '').toString();
    durationDays.text = (data['duration_days'] ?? '').toString();
    previousLinks.text = (data['previous_class_links'] ?? '').toString();
    mapLink.text = (data['map_location'] ?? '').toString();
    startDate = DateTime.tryParse((data['start_date'] ?? '').toString());
    final time = (data['start_time'] ?? '').toString().split(':');
    if (time.length == 2) startTime = TimeOfDay(hour: int.tryParse(time[0]) ?? 0, minute: int.tryParse(time[1]) ?? 0);
  }

  Future<void> choosePhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 900, imageQuality: 65);
    if (photo != null && mounted) setState(() => selectedPhoto = photo);
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
      customCategory,
      customSubcategory,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => startDate = picked);
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
    final amount = double.tryParse(price.text.trim());
    if (!isFree && (amount == null || amount < 0)) {
      setState(() => error = 'Enter a valid price in rupees.');
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
      final legacyType = switch (format) {
        'physical' => 'offline_class',
        'online' => 'online_class',
        _ => 'competition',
      };
      final now = DateTime.now();
      final ref = firestore
          .collection('listings')
          .doc('${legacyType}_${now.millisecondsSinceEpoch}');
      await ref.set({
        'id': ref.id,
        'type': legacyType,
        'listing_type': format,
        'category': category == 'Custom' ? customCategory.text.trim() : board.categoryIds[category],
        'subcategory': category == 'Custom' ? customSubcategory.text.trim() : focus,
        'title': title.text.trim(),
        'description': description.text.trim(),
        'about_master': aboutMaster.text.trim(),
        if (selectedPhoto != null) 'image_base64': base64Encode(await selectedPhoto!.readAsBytes()),
        'priceType': isFree ? 'free' : 'paid',
        'is_free': isFree,
        'price': isFree ? 0 : amount,
        'start_date': startDate?.toIso8601String().substring(0, 10),
        'start_time': startTime == null ? null : ':',
        'duration_days': int.tryParse(durationDays.text.trim()),
        if (previousLinks.text.trim().isNotEmpty) 'previous_class_links': previousLinks.text.trim(),
        if (format != 'online' && city.isNotEmpty) 'city': city,
        if (format != 'online' && mapLink.text.trim().isNotEmpty)
          'map_location': mapLink.text.trim(),
        if (format == 'online') 'topic': focus ?? category,
        'creatorId': user.uid,
        'creatorEmail': user.email ?? '',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      }).timeout(const Duration(seconds: 20));
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHARE WHAT YOU KNOW',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: board.muted,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Post a class',
                      style: TextStyle(
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
                    children: board.categories.keys
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
                  TextField(controller: customCategory, decoration: _decoration('Custom category')),
                  const SizedBox(height: 10),
                  TextField(controller: customSubcategory, decoration: _decoration('Custom sub-category · optional')),
                ] else ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                  initialValue: focus,
                  hint: Text('Any ${category.toLowerCase()}'),
                  decoration: _decoration('Specific focus'),
                  items: board.categories[category]!
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => focus = value),
                  ),
                ],
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
          _FormCard('COVER PHOTO · OPTIONAL', OutlinedButton.icon(onPressed: choosePhoto, icon: const Icon(Icons.photo_library_outlined), label: Text(selectedPhoto == null ? 'Upload photo' : 'Photo selected'))),
          _FormCard('PREVIOUS CLASSES · OPTIONAL', TextField(controller: previousLinks, keyboardType: TextInputType.url, maxLines: 3, decoration: _decoration('YouTube or website links, one per line'))),
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
            Column(children: [
              OutlinedButton(onPressed: pickDate, child: Text(startDate == null ? 'Select start date' : '${startDate!.day}/${startDate!.month}/${startDate!.year}')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () async { final time = await showTimePicker(context: context, initialTime: startTime ?? TimeOfDay.now()); if (time != null) setState(() => startTime = time); }, child: Text(startTime == null ? 'Select start time' : startTime!.format(context))),
              const SizedBox(height: 8),
              TextField(controller: durationDays, keyboardType: TextInputType.number, decoration: _decoration('Duration in number of days')),
            ]),
          ),          if (format != 'online')
            _FormCard(
              'LOCATION · OPTIONAL',
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: city.isEmpty ? null : city,
                    decoration: _decoration('City'),
                    items: board.cities
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => city = value ?? city),
                  ),
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
