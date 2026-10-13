import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_database.dart';

import 'package:flutter/material.dart';

import 'master_class_app.dart' show showPostSheet;
import 'madhura_detail.dart' show MasterClassDetailPage, showMasterClassDetails;
import 'auth_profile.dart' show requireLogin, openProfile;
import 'community_posts.dart'
    show CommunityActivity, CommunityDetailPage, openCommunityPost;

const cream = Color(0xFFF7F1E6),
    paper = Color(0xFFFFFCF6),
    ink = Color(0xFF42352B),
    muted = Color(0xFF806F61),
    border = Color(0xFFE6D8C8),
    clay = Color(0xFFB9654A),
    gold = Color(0xFFE8AD42),
    mildBlue = Color(0xFFDDF3F2),
    mildBlueInk = Color(0xFF0B6B73);
const categories = <String, List<String>>{
  'Music': [
    'Flute',
    'Guitar',
    'Tabla',
    'Dance',
    'Sitar',
    'Violin',
    'Veena',
    'Keyboard',
    'Vocal — Carnatic',
    'Vocal — Hindustani',
    'Drums',
    'Mridangam',
  ],
  'Language': [
    'Kannada',
    'Hindi',
    'Tamil',
    'Telugu',
    'Malayalam',
    'Marathi',
    'Bengali',
    'Gujarati',
    'Punjabi',
    'Odia',
    'Assamese',
    'Urdu',
    'Sanskrit',
    'Konkani',
    'English',
  ],
  'Yoga': [
    'Hatha Yoga',
    'Vinyasa Yoga',
    'Pranayama',
    'Yoga for beginners',
    'Yoga therapy',
  ],
  'Meditation': [
    'Mindfulness meditation',
    'Guided meditation',
    'Breath meditation',
    'Stress relief',
    'Sound meditation',
  ],
  'Bhagavat Geeta': [
    'Introduction',
    'Chapter-wise study',
    'Bhakti Yoga',
    'Karma Yoga',
    'Jnana Yoga',
  ],
  'Workshop': [
    'Creative workshop',
    'Career workshop',
    'Skill-building workshop',
    'Weekend workshop',
  ],
  'Arts': [
    'Drawing',
    'Painting',
    'Crafts',
    'Photography',
    'Theatre',
    'Calligraphy',
  ],
  'Adult': [
    'Career development',
    'Financial literacy',
    'Parenting',
    'Wellness',
    'Life skills',
  ],
  'Sports': [
    'Cricket',
    'Football',
    'Badminton',
    'Swimming',
    'Tennis',
    'Basketball',
    'Martial arts',
    'Fitness',
  ],
  'Foreign Languages': [
    'French',
    'German',
    'Spanish',
    'Japanese',
    'Korean',
    'Mandarin Chinese',
    'Italian',
    'Arabic',
    'Russian',
    'Portuguese',
  ],
  'Curriculum': [
    'CBSE',
    'ICSE',
    'State Board',
    'IB',
    'Maths',
    'Science',
    'Olympiad',
    'Competitive Exams',
  ],
  'Trading / Stock': [
    'Equities',
    'Options',
    'Futures',
    'Technical Analysis',
    'Mutual Funds',
    'Crypto',
  ],
  'AI Tools': [
    'Prompting',
    'ChatGPT',
    'Image Generation',
    'Automation',
    'Data & Analytics',
    'AI for Business',
  ],
};
const categoryIds = <String, String>{
  'Music': 'music',
  'Language': 'language',
  'Foreign Languages': 'foreign_languages',
  'Yoga': 'yoga',
  'Meditation': 'meditation',
  'Bhagavat Geeta': 'bhagavat_geeta',
  'Workshop': 'workshop',
  'Arts': 'arts',
  'Adult': 'adult',
  'Sports': 'sports',
  'Curriculum': 'curriculum',
  'Trading / Stock': 'trading',
  'Custom': 'custom',
  'AI Tools': 'ai_tools',
};
const cities = <String>[
  'Bangalore',
  'Mysore',
  'Hubli',
  'Mangalore',
  'Chennai',
  'Hyderabad',
  'Mumbai',
  'Pune',
  'Delhi',
  'Kolkata',
  'Ahmedabad',
  'Kochi',
  'Jaipur',
];
const formats = <String, String>{
  'physical': 'Physical class',
  'online': 'Online class',
  'competition': 'Competition',
  'event': 'Event',
  'class_request': 'Class request',
  'demo_poll': 'Demo vote',
};

String listingFormat(Map<String, dynamic> data) =>
    data['listing_kind'] == 'class_request'
    ? 'class_request'
    : data['listing_kind'] == 'demo_poll'
    ? 'demo_poll'
    : switch ((data['listing_type'] ?? data['type'] ?? '').toString()) {
        'offline_class' => 'physical',
        'online_class' => 'online',
        final value => value,
      };
String listingPrice(Map<String, dynamic> data) =>
    data['listing_kind'] == 'class_request'
    ? 'Interest'
    : data['listing_kind'] == 'demo_poll'
    ? 'Vote'
    : data['is_free'] == true ||
          data['priceType'] == 'free' ||
          data['price'] == null
    ? 'Free'
    : '₹${data['price']}';

bool isActiveCommunityListing(Map<String, dynamic> data) {
  if (data['requestClosed'] == true) return false;
  final expiry = data['expires_at'];
  return expiry is! Timestamp || expiry.toDate().isAfter(DateTime.now());
}

class MasterClassBoard extends StatefulWidget {
  const MasterClassBoard({super.key});
  @override
  State<MasterClassBoard> createState() => _MasterClassBoardState();
}

class _MasterClassBoardState extends State<MasterClassBoard> {
  final search = TextEditingController();
  String? category, focus;
  bool freeOnly = false;
  String? _browseFormat;
  String city = '';
  String area = '';
  String savedPhysicalCity = 'Bangalore';
  String savedPhysicalArea = '';
  String savedEventCity = 'Bangalore';
  final selectedFormats = <String>{'online'};
  static const _pageSize = 30;
  final _listingDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastListing;
  DocumentSnapshot<Map<String, dynamic>>? _lastLegacyListing;
  bool _loadingListings = false;
  bool _loadingMore = false;
  bool _pendingListingReset = false;
  bool _hasMoreListings = true;
  String? _listingError;
  @override
  void initState() {
    super.initState();
    _loadPreferredCity();
  }

  Future<void> _loadPreferredCity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final data = (await firestore.collection('profiles').doc(user.uid).get())
          .data();
      final value = (data?['preferredPhysicalCity'] ?? data?['city'] ?? '')
          .toString()
          .trim();
      final eventValue = (data?['preferredEventCity'] ?? '').toString().trim();
      final areaValue = (data?['preferredPhysicalArea'] ?? '')
          .toString()
          .trim();
      if (mounted) {
        setState(() {
          if (value.isNotEmpty) savedPhysicalCity = value;
          savedPhysicalArea = areaValue;
          if (data?.containsKey('preferredEventCity') == true) {
            savedEventCity = eventValue;
          }
          if (selectedFormats.contains('event')) {
            city = savedEventCity;
          } else if (selectedFormats.contains('physical') ||
              selectedFormats.contains('competition')) {
            city = savedPhysicalCity;
            area = savedPhysicalArea;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _rememberPhysicalCity(String value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || value.isEmpty) return;
    setState(() => savedPhysicalCity = value);
    try {
      await firestore.collection('profiles').doc(user.uid).set({
        'preferredPhysicalCity': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _rememberPhysicalArea(String value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => savedPhysicalArea = value);
    try {
      await firestore.collection('profiles').doc(user.uid).set({
        'preferredPhysicalArea': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  List<String> _availableAreas() {
    final values =
        _listingDocs
            .where((doc) {
              final data = doc.data();
              return (listingFormat(data) == 'physical' ||
                      listingFormat(data) == 'competition') &&
                  (city.isEmpty ||
                      (data['city'] ?? '').toString().toLowerCase() ==
                          city.toLowerCase());
            })
            .map((doc) => (doc.data()['area'] ?? '').toString().trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (savedPhysicalArea.isNotEmpty && !values.contains(savedPhysicalArea)) {
      values.insert(0, savedPhysicalArea);
    }
    return values;
  }

  Future<void> _rememberEventCity(String value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => savedEventCity = value);
    try {
      await firestore.collection('profiles').doc(user.uid).set({
        'preferredEventCity': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _loadListings({bool reset = false}) async {
    if (_loadingListings || _loadingMore) {
      if (reset) _pendingListingReset = true;
      return;
    }
    if (!reset && !_hasMoreListings) return;
    setState(() {
      if (reset) {
        _loadingListings = true;
        _listingDocs.clear();
        _lastListing = null;
        _lastLegacyListing = null;
        _hasMoreListings = true;
      } else {
        _loadingMore = true;
      }
      _listingError = null;
    });
    try {
      // Events are queried by their own type so they are not buried under
      // the first page of unrelated classes.
      Query<Map<String, dynamic>> activeQuery =
          selectedFormats.length == 1 && selectedFormats.contains('event')
          ? firestore
                .collection('listings')
                .where('listing_type', isEqualTo: 'event')
                .limit(_pageSize)
          : firestore
                .collection('listings')
                .where('expires_at', isGreaterThan: Timestamp.now())
                .orderBy('expires_at')
                .limit(_pageSize);
      if (_lastListing != null) {
        activeQuery = activeQuery.startAfterDocument(_lastListing!);
      }
      Query<Map<String, dynamic>> legacyQuery = firestore
          .collection('listings')
          .orderBy('updatedAt', descending: true)
          .limit(_pageSize);
      if (_lastLegacyListing != null) {
        legacyQuery = legacyQuery.startAfterDocument(_lastLegacyListing!);
      }
      final pages = await Future.wait([activeQuery.get(), legacyQuery.get()]);
      final activePage = pages[0];
      final legacyPage = pages[1];
      if (!mounted) return;
      setState(() {
        _listingDocs.addAll(activePage.docs);
        _listingDocs.addAll(
          legacyPage.docs.where((doc) => doc.data()['expires_at'] == null),
        );
        if (activePage.docs.isNotEmpty) _lastListing = activePage.docs.last;
        if (legacyPage.docs.isNotEmpty) {
          _lastLegacyListing = legacyPage.docs.last;
        }
        _hasMoreListings =
            activePage.docs.length == _pageSize ||
            legacyPage.docs.length == _pageSize;
      });
    } on FirebaseException catch (e) {
      if (mounted) setState(() => _listingError = e.message ?? e.code);
    } finally {
      if (mounted) {
        setState(() {
          _loadingListings = false;
          _loadingMore = false;
        });
        if (_pendingListingReset) {
          _pendingListingReset = false;
          _loadListings(reset: true);
        }
      }
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  bool isExpired(Map<String, dynamic> data) {
    final expiresAt = data['expires_at'];
    if (expiresAt is Timestamp)
      return !expiresAt.toDate().isAfter(DateTime.now());
    final dateText = (data['expiry_date'] ?? data['start_date'] ?? '')
        .toString();
    final date = DateTime.tryParse(dateText);
    if (date == null) return false;
    return !DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    ).isAfter(DateTime.now());
  }

  bool matches(Map<String, dynamic> d) {
    final listedCategory = (d['category'] ?? '').toString();
    final listedFocus = (d['subcategory'] ?? '').toString();
    final words =
        '${d['title'] ?? ''} ${d['description'] ?? ''} ${d['topic'] ?? ''} ${d['about_master'] ?? ''} ${d['spoken_languages'] ?? ''} ${d['age_group'] ?? ''} $listedCategory $listedFocus ${formats[listingFormat(d)] ?? ''}'
            .toLowerCase();
    if (category != null) {
      final categoryId = (categoryIds[category] ?? category!).toLowerCase();
      final categoryLabel = category!.toLowerCase();
      final categoryMatches =
          listedCategory.toLowerCase() == categoryId ||
          listedCategory.toLowerCase() == categoryLabel ||
          listedCategory.toLowerCase().contains(categoryLabel) ||
          (listedCategory.isNotEmpty &&
              categoryLabel.contains(listedCategory.toLowerCase())) ||
          (categories[category]?.any(
                (value) => words.contains(value.toLowerCase()),
              ) ??
              false);
      if (!categoryMatches) return false;
    }
    if (focus != null &&
        listedFocus.toLowerCase() != focus!.toLowerCase() &&
        !words.contains(focus!.toLowerCase()))
      return false;
    final format = listingFormat(d);
    if (format == 'class_request') return false;
    if (!selectedFormats.contains(format)) return false;
    if (freeOnly &&
        d['is_free'] != true &&
        d['priceType'] != 'free' &&
        d['price'] != null &&
        d['price'] != 0) {
      return false;
    }
    final place = (d['city'] ?? '').toString();
    final listingArea = (d['area'] ?? '').toString();
    if (city.isNotEmpty &&
        format != 'online' &&
        place.isNotEmpty &&
        place.toLowerCase() != city.toLowerCase())
      return false;
    if (area.isNotEmpty &&
        (format == 'physical' || format == 'competition') &&
        listingArea.toLowerCase() != area.toLowerCase()) {
      return false;
    }
    final query = search.text.trim().toLowerCase();
    return query.isEmpty || words.contains(query);
  }

  Widget _buildListingFeed() {
    final listings = _listingDocs
        .where((doc) => !isExpired(doc.data()) && matches(doc.data()))
        .toList();
    return RefreshIndicator(
      onRefresh: () => _loadListings(reset: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 25),
        children: [
          Text(
            category == null
                ? selectedFormats.contains('competition')
                      ? 'Competitions'
                      : selectedFormats.contains('event')
                      ? 'Events'
                      : selectedFormats.contains('physical')
                      ? 'Physical classes'
                      : 'Online classes'
                : category!,
            style: const TextStyle(
              fontSize: 20,
              height: 1.08,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _loadingListings
                ? 'Loading the board…'
                : '${listings.length} results loaded',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed:
                    selectedFormats.length == 1 &&
                        selectedFormats.contains('online')
                    ? null
                    : openCityPicker,
                icon: const Icon(Icons.location_on_outlined, size: 16),
                label: Text(city.isEmpty ? 'All cities' : city),
                style: _filterStyle,
              ),
              if (selectedFormats.contains('physical') ||
                  selectedFormats.contains('competition'))
                OutlinedButton.icon(
                  onPressed: openAreaPicker,
                  icon: const Icon(Icons.place_outlined, size: 16),
                  label: Text(area.isEmpty ? 'All areas' : area),
                  style: _filterStyle,
                ),
              FilterChip(
                label: const Text('Free only'),
                selected: freeOnly,
                selectedColor: const Color(0xFFFFE2C1),
                checkmarkColor: const Color(0xFF9C3F00),
                onSelected: (value) => setState(() => freeOnly = value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_listingError != null)
            _Notice(
              'Could not load classes',
              _listingError!,
              onPost: () => _loadListings(reset: true),
            )
          else if (_loadingListings)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (listings.isEmpty)
            _Notice(
              'Nothing here yet',
              'Try a different filter, refresh the board, or be the first to post for this focus.',
              onPost: () => openPost(context),
            )
          else
            for (var index = 0; index < listings.length; index++) ...[
              _CompactClassCard({
                ...listings[index].data(),
                'id': listings[index].id,
              }, onDeleted: () => _loadListings(reset: true)),
              if (index < listings.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Divider(
                    height: 12,
                    thickness: 1.5,
                    color: Color(0xFFD7DDD7),
                  ),
                ),
            ],
          if (!_loadingListings && _hasMoreListings) ...[
            const SizedBox(height: 4),
            OutlinedButton(
              onPressed: _loadingMore ? null : _loadListings,
              child: _loadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Load more classes'),
            ),
          ],
        ],
      ),
    );
  }

  void _selectFormats(Set<String> values) {
    _loadPreferredCity();
    setState(() {
      selectedFormats
        ..clear()
        ..addAll(values);
      if (values.length == 1 && values.contains('online')) {
        city = '';
        area = '';
      } else if (values.contains('physical') ||
          values.contains('competition')) {
        city = savedPhysicalCity;
        area = savedPhysicalArea;
      } else if (values.contains('event')) {
        city = savedEventCity;
        area = '';
      } else {
        city = '';
      }
      focus = null;
    });
  }

  void openCityPicker() => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          runSpacing: 8,
          children: [
            const _Label('CITY'),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: ['All cities', ...cities]
                  .map(
                    (name) => ChoiceChip(
                      label: Text(name),
                      selected: name == 'All cities'
                          ? city.isEmpty
                          : city == name,
                      onSelected: (_) async {
                        final value = name == 'All cities' ? '' : name;
                        setState(() {
                          city = value;
                          area = '';
                        });
                        if (selectedFormats.contains('physical') ||
                            selectedFormats.contains('competition')) {
                          await _rememberPhysicalCity(value);
                          await _rememberPhysicalArea('');
                        } else if (selectedFormats.contains('event')) {
                          await _rememberEventCity(value);
                        }
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> openAreaPicker() async {
    final availableAreas = _availableAreas();
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            runSpacing: 8,
            children: [
              const _Label('AREA / LOCALITY'),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  ChoiceChip(
                    label: const Text('All areas'),
                    selected: area.isEmpty,
                    onSelected: (_) => Navigator.pop(sheetContext, ''),
                  ),
                  ...availableAreas.map(
                    (value) => ChoiceChip(
                      label: Text(value),
                      selected: area == value,
                      onSelected: (_) => Navigator.pop(sheetContext, value),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 17),
                    label: const Text('Add area'),
                    onPressed: () => Navigator.pop(sheetContext, '_custom'),
                  ),
                ],
              ),
              if (availableAreas.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No saved areas for this city yet. Add the first one.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == '_custom') {
      final controller = TextEditingController();
      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add area / locality'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            decoration: const InputDecoration(hintText: 'e.g. Indiranagar'),
            onSubmitted: (text) => Navigator.pop(dialogContext, text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Use area'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (!mounted || value == null || value.isEmpty) return;
      setState(() => area = value);
      await _rememberPhysicalArea(value);
      return;
    }
    setState(() => area = selected);
    await _rememberPhysicalArea(selected);
  }

  @override
  Widget build(BuildContext context) =>
      _browseFormat == null ? _buildHome(context) : _buildBrowse(context);

  Widget _buildHome(BuildContext context) {
    final name = FirebaseAuth.instance.currentUser?.displayName
        ?.split(' ')
        .first;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'logo.png',
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LEARNING NEAR',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8B8B8B),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: Color(0xFFED792B),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              savedPhysicalCity,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => openProfile(context),
                  borderRadius: BorderRadius.circular(22),
                  child: CircleAvatar(
                    radius: 21,
                    backgroundColor: const Color(0xFFFFE7D3),
                    child: Text(
                      (name ?? 'M').characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFBC591D),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              readOnly: true,
              onTap: () => _openBrowse('online'),
              decoration: InputDecoration(
                hintText: 'Search music, yoga, languages…',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF897362)),
                suffixIcon: const Icon(
                  Icons.arrow_forward_ios,
                  size: 15,
                  color: Color(0xFF897362),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE9DED1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE9DED1)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            InkWell(
              onTap: () => _openBrowse('online'),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 172,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFA648),
                      Color(0xFFFF772F),
                      Color(0xFFD85818),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DISCOVER SOMETHING NEW',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 9),
                          Text(
                            'Find your next\nmaster class',
                            style: TextStyle(
                              fontSize: 23,
                              height: 1.05,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 14),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Explore classes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 7),
                              Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Color(0x33FFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_stories_outlined,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            _HomeFeaturedClasses(onExplore: () => _openBrowse('online')),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'What do you want to learn?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF194B42),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _openBrowse('online'),
                  child: const Text('Explore'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth - 10) / 2;
                return Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: _HomeTypeTile(
                            icon: Icons.laptop_mac_outlined,
                            title: 'Online',
                            subtitle: 'Learn anywhere',
                            color: const Color(0xFFE2F3DE),
                            onTap: () => _openBrowse('online'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: tileWidth,
                          child: _HomeTypeTile(
                            icon: Icons.location_on_outlined,
                            title: 'Physical',
                            subtitle: 'Meet nearby',
                            color: const Color(0xFFFFE8DF),
                            onTap: () => _openBrowse('physical'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: _HomeTypeTile(
                            icon: Icons.emoji_events_outlined,
                            title: 'Competition',
                            subtitle: 'Show your skills',
                            color: const Color(0xFFFFF2C8),
                            onTap: () => _openBrowse('competition'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: tileWidth,
                          child: _HomeTypeTile(
                            icon: Icons.event_outlined,
                            title: 'Events',
                            subtitle: 'Explore events',
                            color: const Color(0xFFE9E5FF),
                            onTap: () => _openBrowse('event'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _ActiveListingCount(
              kind: 'demo_poll',
              builder: (activeCount) => InkWell(
                onTap: () => openDemoClasses(context),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9EEF3),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.how_to_vote_outlined,
                        color: Color(0xFF245866),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Demo Class',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF245866),
                              ),
                            ),
                            Text(
                              'Vote for the next class to try.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF46727B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _CountBadge(count: activeCount),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_outward, color: Color(0xFF245866)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ActiveListingCount(
              kind: 'class_request',
              builder: (activeCount) => InkWell(
                onTap: () => openRequests(context),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECA58E),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.forum_outlined,
                        color: Color(0xFF42352B),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request a Class',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF42352B),
                              ),
                            ),
                            Text(
                              'Can’t find it? Ask the community.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF684D43),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _CountBadge(count: activeCount),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_outward, color: Color(0xFF42352B)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _homeFooter(context),
    );
  }

  void _openBrowse(String format) {
    final changingFormat = _browseFormat != format;
    _selectFormats({format});
    setState(() {
      _browseFormat = format;
      if (changingFormat) {
        category = null;
        focus = null;
        freeOnly = false;
        search.clear();
      }
    });
    _loadListings(reset: true);
  }

  Widget _buildBrowse(BuildContext context) {
    final format = _browseFormat!;
    final title = format == 'online'
        ? 'Learn from anywhere.'
        : format == 'physical'
        ? 'Learn near you.'
        : format == 'event'
        ? 'Explore events near you.'
        : 'Compete and grow.';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFECECEC))),
              ),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _browseFormat = null),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F5),
                      foregroundColor: const Color(0xFF1A1A1A),
                    ),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    format == 'physical'
                        ? Icons.location_on_outlined
                        : format == 'competition'
                        ? Icons.emoji_events_outlined
                        : format == 'event'
                        ? Icons.event_outlined
                        : Icons.laptop_mac_outlined,
                    color: const Color(0xFFFF8C00),
                    size: 22,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EXPLORE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8B8B8B),
                          ),
                        ),
                        Text(
                          formats[format] ?? 'Classes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RoundIcon(
                    icon: Icons.person_outline,
                    onTap: () => openProfile(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search piano, French, yoga...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF8B8B8B),
                      ),
                      suffixIcon: search.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(search.clear),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 5,
                ),
                children: [
                  _Chip(
                    'All',
                    category == null,
                    () => setState(() {
                      category = null;
                      focus = null;
                    }),
                  ),
                  ...categories.keys.map(
                    (name) => _Chip(
                      name,
                      category == name,
                      () => setState(() {
                        category = name;
                        focus = null;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            if (category != null && categories[category] != null)
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: categories[category]!
                      .map(
                        (value) => _Chip(
                          value,
                          focus == value,
                          () => setState(
                            () => focus = focus == value ? null : value,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            Expanded(child: _buildListingFeed()),
          ],
        ),
      ),
      bottomNavigationBar: _homeFooter(context),
    );
  }

  Widget _homeFooter(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      height: 64,
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Tab(
            Icons.home_outlined,
            'Home',
            _browseFormat == null,
            () => setState(() => _browseFormat = null),
          ),
          IconButton.filled(
            onPressed: () => openPost(context),
            icon: const Icon(Icons.add),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C00),
              foregroundColor: Colors.white,
            ),
          ),
          _Tab(
            Icons.person_outline,
            'Profile',
            false,
            () => openProfile(context),
          ),
        ],
      ),
    ),
  );
}

Future<void> openRequests(BuildContext context) async {
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const _RequestsPage()));
}

class _RequestsPage extends StatelessWidget {
  const _RequestsPage();
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        title: const Text(
          'Class requests',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Online'),
            Tab(text: 'Physical'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          _RequestFeed(mode: 'online'),
          _RequestFeed(mode: 'physical'),
        ],
      ),
    ),
  );
}

class _RequestFeed extends StatelessWidget {
  const _RequestFeed({required this.mode});
  final String mode;
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('listings')
            .where('listing_kind', isEqualTo: 'class_request')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text('Could not load requests.'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final requests = snapshot.data!.docs
              .where(
                (doc) =>
                    (doc.data()['request_mode'] ?? 'online') == mode &&
                    isActiveCommunityListing(doc.data()),
              )
              .toList();
          if (requests.isEmpty)
            return Center(
              child: Text(
                'No $mode class requests yet.',
                style: const TextStyle(color: muted),
              ),
            );
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final doc = requests[index];
              return _Card({...doc.data(), 'id': doc.id});
            },
          );
        },
      );
}

Future<void> openDemoClasses(BuildContext context) async {
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const _DemoClassesPage()));
}

class _DemoClassesPage extends StatelessWidget {
  const _DemoClassesPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      title: const Text(
        'Demo classes',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => openCommunityPost(context, 'demo_poll'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Post'),
          style: TextButton.styleFrom(foregroundColor: clay),
        ),
      ],
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('listings')
          .where('listing_kind', isEqualTo: 'demo_poll')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load demo classes.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final demos = snapshot.data!.docs
            .where((doc) => isActiveCommunityListing(doc.data()))
            .toList();
        if (demos.isEmpty) {
          return const Center(
            child: Text('No demo classes yet.', style: TextStyle(color: muted)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: demos.length,
          itemBuilder: (context, index) {
            final doc = demos[index];
            return _Card({...doc.data(), 'id': doc.id});
          },
        );
      },
    ),
  );
}

Future<void> openPost(BuildContext context) async {
  if (!await requireLogin(context) || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('Post a class or event'),
              onTap: () {
                Navigator.pop(sheetContext);
                showPostSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.volunteer_activism_outlined),
              title: const Text('Request a class'),
              subtitle: const Text('Other learners can show interest'),
              onTap: () {
                Navigator.pop(sheetContext);
                openCommunityPost(context, 'class_request');
              },
            ),
            ListTile(
              leading: const Icon(Icons.how_to_vote_outlined),
              title: const Text('Demo class vote'),
              subtitle: const Text('Let learners choose a demo'),
              onTap: () {
                Navigator.pop(sheetContext);
                openCommunityPost(context, 'demo_poll');
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> openClass(BuildContext context, Map<String, dynamic> data) async {
  if (!await requireLogin(context) || !context.mounted) return false;
  if (data['listing_kind'] == 'class_request' ||
      data['listing_kind'] == 'demo_poll') {
    return await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => CommunityDetailPage(
              listingId: data['id'].toString(),
              data: data,
            ),
          ),
        ) ??
        false;
  }
  return await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => MasterClassDetailPage(data: data)),
      ) ??
      false;
}

final _filterStyle = OutlinedButton.styleFrom(
  backgroundColor: const Color(0xFFFFF4E6),
  foregroundColor: const Color(0xFF9C3F00),
  side: const BorderSide(color: Color(0xFFFFD6AE)),
  shape: const StadiumBorder(),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      color: muted,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.active, this.onTap);
  final String text;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFF8C00) : const Color(0xFFF5F5F5),
          border: Border.all(
            color: active ? const Color(0xFFFF8C00) : const Color(0xFFECECEC),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: active ? Colors.white : const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: const Color(0xFF194B42)),
    ),
  );
}

class _HomeFeaturedClasses extends StatelessWidget {
  const _HomeFeaturedClasses({required this.onExplore});

  final VoidCallback onExplore;

  Widget _cover(Map<String, dynamic> data) {
    final encoded = (data['image_base64'] ?? '').toString();
    if (encoded.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(encoded),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, _, _) => _fallbackCover(),
        );
      } catch (_) {
        return _fallbackCover();
      }
    }
    final url = (data['image_url'] ?? '').toString();
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, _, _) => _fallbackCover(),
      );
    }
    return _fallbackCover();
  }

  Widget _fallbackCover() => const ColoredBox(
    color: Color(0xFFFFE8D6),
    child: Center(
      child: Icon(
        Icons.auto_stories_outlined,
        size: 36,
        color: Color(0xFFD66D27),
      ),
    ),
  );

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: firestore
        .collection('listings')
        .orderBy('updatedAt', descending: true)
        .limit(30)
        .snapshots(),
    builder: (context, snapshot) {
      final listings =
          snapshot.data?.docs
              .where((doc) {
                final data = doc.data();
                final format = listingFormat(data);
                if (!const {
                  'online',
                  'physical',
                  'competition',
                  'event',
                }.contains(format))
                  return false;
                final expires = data['expires_at'];
                return expires is! Timestamp ||
                    expires.toDate().isAfter(DateTime.now());
              })
              .take(6)
              .toList() ??
          [];
      if (listings.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Featured classes',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              TextButton(onPressed: onExplore, child: const Text('Explore')),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 194,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: listings.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final doc = listings[index];
                final data = doc.data();
                final format = listingFormat(data);
                return SizedBox(
                  width: 208,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: () => showMasterClassDetails(context, {
                        ...data,
                        'id': doc.id,
                      }),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE9DED1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(17),
                              ),
                              child: SizedBox(
                                height: 104,
                                width: double.infinity,
                                child: _cover(data),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (data['title'] ?? 'Class').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${formats[format] ?? 'Class'} · ${data['city'] ?? 'Anywhere'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF897362),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
        ],
      );
    },
  );
}

class _HomeTypeTile extends StatelessWidget {
  const _HomeTypeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 2,
    shadowColor: const Color(0x1A5A3320),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(17),
      side: const BorderSide(color: Color(0xFFE9DED1)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF276559)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF194B42),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF829184),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF829184)),
          ],
        ),
      ),
    ),
  );
}

class _CompactClassCard extends StatelessWidget {
  const _CompactClassCard(this.data, {required this.onDeleted});
  final Map<String, dynamic> data;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final format = listingFormat(data);
    final title = (data['title'] ?? 'Untitled class').toString();
    final categoryName =
        categories.keys
            .where((key) => categoryIds[key] == data['category'])
            .firstOrNull ??
        (data['category'] ?? 'Class').toString();
    final price = listingPrice(data);
    final imageUrl =
        (data['image_url'] ?? data['imageUrl'] ?? data['photoUrl'] ?? '')
            .toString();
    final imageBase64 = (data['image_base64'] ?? '').toString();

    Widget imageHeader() {
      if (imageBase64.isNotEmpty) {
        return Image.memory(
          base64Decode(imageBase64),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const ColoredBox(
            color: Color(0xFFEEDFCB),
            child: Icon(Icons.broken_image_outlined, color: clay),
          ),
        );
      }
      if (imageUrl.isNotEmpty) {
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const ColoredBox(
            color: Color(0xFFEEDFCB),
            child: Icon(Icons.broken_image_outlined, color: clay),
          ),
        );
      }
      return const ColoredBox(
        color: Color(0xFFEEDFCB),
        child: Icon(Icons.auto_awesome, color: clay),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 18),
      child: Material(
        color: Colors.white,
        elevation: 2,
        shadowColor: const Color(0x1A241912),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x66000000), width: 1),
        ),
        child: InkWell(
          onTap: () async {
            if (await openClass(context, data)) onDeleted();
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 150,
                    child: imageHeader(),
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Icon(
                      format == 'competition'
                          ? Icons.emoji_events_outlined
                          : format == 'event'
                          ? Icons.event_outlined
                          : format == 'physical'
                          ? Icons.location_on_outlined
                          : Icons.laptop_mac_outlined,
                      size: 16,
                      color: const Color(0xFF1A1A1A),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '$categoryName · ${data['subcategory'] ?? ''}'
                            .replaceAll(RegExp(r' · $'), ''),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        price,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if ((data['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    data['description'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
                const SizedBox(height: 11),
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        format == 'online'
                            ? 'Online'
                            : [
                                (data['area'] ?? '').toString(),
                                (data['city'] ?? 'Nearby').toString(),
                              ].where((value) => value.isNotEmpty).join(', '),
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
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (data['start_date'] ?? 'Dates to be announced')
                            .toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        if (await openClass(context, data)) onDeleted();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8C00),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 15),
                      label: const Text('Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card(this.data);
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final format = listingFormat(data);
    final image = (data['image_url'] ?? '').toString();
    final imageBase64 = (data['image_base64'] ?? '').toString();
    final title = (data['title'] ?? 'Untitled class').toString();
    final categoryName =
        categories.keys
            .where((key) => categoryIds[key] == data['category'])
            .firstOrNull ??
        (format == 'class_request'
            ? 'Class request'
            : format == 'demo_poll'
            ? 'Demo vote'
            : 'Class');
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Material(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x66000000), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openClass(context, data),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 165,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageBase64.isNotEmpty
                        ? Image.memory(
                            base64Decode(imageBase64),
                            fit: BoxFit.cover,
                          )
                        : image.isEmpty
                        ? Container(
                            color: const Color(0xFFFFE8D6),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: const Color(0xFFD66D27),
                              size: 52,
                            ),
                          )
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              color: const Color(0xFFFFE8D6),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: const Color(0xFFD66D27),
                                size: 52,
                              ),
                            ),
                          ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _Badge(
                        formats[format] ?? 'Class',
                        Colors.white,
                        ink,
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: _Badge(listingPrice(data), ink, gold),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${categoryName.toUpperCase()}${data['subcategory'] == null ? '' : ' · ${data['subcategory']}'}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (format == 'class_request' || format == 'demo_poll')
                      CommunityActivity(
                        listingId: (data['id'] ?? '').toString(),
                        isPoll: format == 'demo_poll',
                        creatorId: (data['creatorId'] ?? '').toString(),
                        creatorName: (data['creatorName'] ?? 'Member')
                            .toString(),
                      ),
                    const SizedBox(height: 11),
                    const Divider(color: border, height: 1),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (data['start_date'] ?? 'Dates to be announced')
                                .toString(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.location_on_outlined,
                          color: const Color(0xFFD66D27),
                          size: 15,
                        ),
                        Text(
                          format == 'online'
                              ? 'Online'
                              : (data['city'] ?? 'Any city').toString(),
                          style: const TextStyle(fontSize: 11, color: ink),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.background, this.foreground);
  final String text;
  final Color background, foreground;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.title, this.detail, {this.onPost});
  final String title, detail;
  final VoidCallback? onPost;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: paper,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        const Icon(Icons.auto_awesome, color: gold, size: 30),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(fontFamily: 'serif', fontSize: 21, color: ink),
        ),
        const SizedBox(height: 7),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: muted),
        ),
        if (onPost != null) ...[
          const SizedBox(height: 15),
          FilledButton(
            onPressed: onPost,
            style: FilledButton.styleFrom(backgroundColor: clay),
            child: const Text('Post a class'),
          ),
        ],
      ],
    ),
  );
}

class _ActiveListingCount extends StatelessWidget {
  const _ActiveListingCount({required this.kind, required this.builder});
  final String kind;
  final Widget Function(int activeCount) builder;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('listings')
            .where('listing_kind', isEqualTo: kind)
            .snapshots(),
        builder: (context, snapshot) {
          final count = (snapshot.data?.docs ?? [])
              .where((doc) => isActiveCommunityListing(doc.data()))
              .length;
          return builder(count);
        },
      );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 4),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF195548),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab(this.icon, this.label, this.active, [this.onTap]);
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: active ? const Color(0xFFFF8C00) : muted),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? const Color(0xFF1A1A1A) : muted,
          ),
        ),
      ],
    ),
  );
}

void showProfile(BuildContext context) => showModalBottomSheet(
  context: context,
  backgroundColor: Colors.white,
  builder: (context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to Master Class',
          style: TextStyle(fontFamily: 'serif', fontSize: 26, color: ink),
        ),
        SizedBox(height: 8),
        Text(
          'Browse classes and share your knowledge.',
          style: TextStyle(color: muted),
        ),
        SizedBox(height: 15),
      ],
    ),
  ),
);
