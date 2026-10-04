import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_database.dart';

import 'package:flutter/material.dart';

import 'master_class_app.dart' show showPostSheet;
import 'madhura_detail.dart' show showMasterClassDetails;
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
  String city = '';
  String savedPhysicalCity = 'Bangalore';
  final selectedFormats = <String>{'online'};
  final _formatScrollController = ScrollController();
  final _categoryScrollController = ScrollController();
  Timer? _filterScrollTimer;
  bool _formatScrollForward = true;
  bool _categoryScrollForward = true;
  static const _pageSize = 30;
  final _listingDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastListing;
  DocumentSnapshot<Map<String, dynamic>>? _lastLegacyListing;
  bool _loadingListings = false;
  bool _loadingMore = false;
  bool _hasMoreListings = true;
  String? _listingError;
  @override
  void initState() {
    super.initState();
    _loadPreferredCity();
    _loadListings(reset: true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _startFilterAutoScroll(),
    );
  }

  void _startFilterAutoScroll() {
    _filterScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _bounceScroll(_formatScrollController, isFormat: true);
      _bounceScroll(_categoryScrollController, isFormat: false);
    });
  }

  void _bounceScroll(ScrollController controller, {required bool isFormat}) {
    if (!mounted || !controller.hasClients) return;
    final position = controller.position;
    if (position.maxScrollExtent <= 0) return;
    final forward = isFormat ? _formatScrollForward : _categoryScrollForward;
    final target = forward
        ? position.maxScrollExtent
        : position.minScrollExtent;
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeInOut,
    );
    if (isFormat) {
      _formatScrollForward = !forward;
    } else {
      _categoryScrollForward = !forward;
    }
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
      if (value.isNotEmpty && mounted) {
        setState(() {
          savedPhysicalCity = value;
          if (selectedFormats.contains('physical') ||
              selectedFormats.contains('competition'))
            city = value;
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

  Future<void> _loadListings({bool reset = false}) async {
    if (_loadingListings || _loadingMore || (!reset && !_hasMoreListings))
      return;
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
      Query<Map<String, dynamic>> activeQuery = firestore
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
      if (mounted)
        setState(() {
          _loadingListings = false;
          _loadingMore = false;
        });
    }
  }

  @override
  void dispose() {
    _filterScrollTimer?.cancel();
    _formatScrollController.dispose();
    _categoryScrollController.dispose();
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
    if (category != null &&
        listedCategory.toLowerCase() !=
            (categoryIds[category] ?? category!).toLowerCase() &&
        listedCategory.toLowerCase() != category!.toLowerCase()) {
      if (listedCategory.isNotEmpty ||
          !(categories[category]?.any((s) => words.contains(s.toLowerCase())) ??
              false))
        return false;
    }
    if (focus != null &&
        listedFocus.toLowerCase() != focus!.toLowerCase() &&
        !words.contains(focus!.toLowerCase()))
      return false;
    final format = listingFormat(d);
    if (format == 'class_request') return false;
    if (!selectedFormats.contains(format)) return false;
    final place = (d['city'] ?? '').toString();
    if (city.isNotEmpty &&
        format != 'online' &&
        place.isNotEmpty &&
        place.toLowerCase() != city.toLowerCase())
      return false;
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
            category == null ? 'Learn from master near you' : category!,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 19,
              height: 1.08,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _loadingListings
                ? 'Loading the board…'
                : '${listings.length} matching class${listings.length == 1 ? '' : 'es'} loaded',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed:
                  selectedFormats.length == 1 &&
                      selectedFormats.contains('online')
                  ? null
                  : openCityPicker,
              icon: const Icon(
                Icons.location_on_outlined,
                color: clay,
                size: 16,
              ),
              label: Text(city.isEmpty ? 'All cities' : city),
              style: _filterStyle,
            ),
          ),
          const SizedBox(height: 16),
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
            ...listings.map((doc) => _Card({...doc.data(), 'id': doc.id})),
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
      } else if (values.contains('physical') ||
          values.contains('competition')) {
        city = savedPhysicalCity;
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
                        setState(() => city = value);
                        if (selectedFormats.contains('physical') ||
                            selectedFormats.contains('competition')) {
                          await _rememberPhysicalCity(value);
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
  void openFilters() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, refreshSheet) {
        void update(VoidCallback action) {
          setState(action);
          refreshSheet(() {});
        }

        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .83,
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 26,
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    children: [
                      const _Label('FORMAT'),
                      ...formats.entries.map(
                        (entry) => CheckboxListTile(
                          value: selectedFormats.contains(entry.key),
                          title: Text(entry.value),
                          activeColor: clay,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (_) => update(() {
                            if (selectedFormats.contains(entry.key)) {
                              if (selectedFormats.length > 1) {
                                selectedFormats.remove(entry.key);
                              }
                            } else {
                              selectedFormats.add(entry.key);
                            }
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _Label('CITY'),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final options = <String, String>{
                            for (final name in cities) name.toLowerCase(): name,
                          };
                          for (final doc in _listingDocs) {
                            final name = (doc.data()['city'] ?? '')
                                .toString()
                                .trim();
                            if (name.isNotEmpty) {
                              options.putIfAbsent(
                                name.toLowerCase(),
                                () => name,
                              );
                            }
                          }
                          final cityNames = options.values.toList()
                            ..sort(
                              (a, b) =>
                                  a.toLowerCase().compareTo(b.toLowerCase()),
                            );
                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: ['All cities', ...cityNames].map((value) {
                              final selected = value == 'All cities'
                                  ? city.isEmpty
                                  : city.toLowerCase() == value.toLowerCase();
                              return ChoiceChip(
                                label: Text(value),
                                selected: selected,
                                selectedColor: ink,
                                backgroundColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: selected ? paper : ink,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => update(
                                  () =>
                                      city = value == 'All cities' ? '' : value,
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      if (category != null) ...[
                        const SizedBox(height: 18),
                        _Label('${category!.toUpperCase()} — FOCUS'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: categories[category]!
                              .map(
                                (value) => ChoiceChip(
                                  label: Text(value),
                                  selected: focus == value,
                                  selectedColor: gold,
                                  backgroundColor: Colors.white,
                                  onSelected: (_) => update(
                                    () => focus = focus == value ? null : value,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => update(() {
                          selectedFormats
                            ..clear()
                            ..add('online');
                          focus = null;
                          city = '';
                        }),
                        child: const Text('Reset filters'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: FilledButton.styleFrom(backgroundColor: clay),
                        child: const Text('Show results'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          Container(
            color: paper,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: gold,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'म',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 22,
                          color: ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Master Class',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          Text(
                            'MASTER CLASS',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.1,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'WELCOME',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.1,
                            color: muted,
                          ),
                        ),
                        Text(
                          FirebaseAuth.instance.currentUser?.displayName ??
                              'Guest',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search classes, masters, competitions',
                    hintStyle: const TextStyle(fontSize: 13, color: muted),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: muted,
                      size: 19,
                    ),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close, size: 18),
                          ),
                    filled: true,
                    fillColor: cream,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: border),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 48,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF5C9), Color(0xFFFFFBEB)],
              ),
            ),
            child: SizedBox(
              height: 48,
              child: ListView(
                controller: _formatScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                children: [
                  _Chip(
                    'Online',
                    selectedFormats.length == 1 &&
                        selectedFormats.contains('online'),
                    () => _selectFormats({'online'}),
                    activeColor: const Color(0xFFF4B183),
                    activeTextColor: const Color(0xFF5D341A),
                  ),
                  _Chip(
                    'Physical',
                    selectedFormats.length == 1 &&
                        selectedFormats.contains('physical'),
                    () => _selectFormats({'physical'}),
                    activeColor: const Color(0xFFF4B183),
                    activeTextColor: const Color(0xFF5D341A),
                  ),
                  _Chip(
                    'Demo',
                    selectedFormats.length == 1 &&
                        selectedFormats.contains('demo_poll'),
                    () => _selectFormats({'demo_poll'}),
                    activeColor: const Color(0xFFF4B183),
                    activeTextColor: const Color(0xFF5D341A),
                  ),
                  _Chip(
                    'Competition',
                    selectedFormats.length == 1 &&
                        selectedFormats.contains('competition'),
                    () => _selectFormats({'competition'}),
                    activeColor: const Color(0xFFF4B183),
                    activeTextColor: const Color(0xFF5D341A),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 140,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF1B8), Color(0xFFFFF9E4)],
              ),
              border: Border.symmetric(horizontal: BorderSide(color: border)),
            ),
            child: ListView.builder(
              controller: _categoryScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              itemCount: ((categories.length + 1) / 2).ceil(),
              itemBuilder: (context, column) {
                final items = [
                  'All',
                  ...categories.keys,
                ].skip(column * 2).take(2).toList();
                return Column(
                  children: items
                      .map(
                        (name) => _CategoryIcon(
                          name: name,
                          active: name == 'All'
                              ? category == null
                              : category == name,
                          onTap: () => setState(() {
                            category = name == 'All' ? null : name;
                            focus = null;
                          }),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
          if (category != null)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
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
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        height: 65,
        decoration: const BoxDecoration(
          color: paper,
          border: Border(top: BorderSide(color: border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _Tab(Icons.home_outlined, 'Board', true),
            _ListingCountTab(
              icon: Icons.volunteer_activism_outlined,
              label: 'Requests',
              kind: 'class_request',
              onTap: () => openRequests(context),
            ),
            IconButton.filled(
              onPressed: () => openPost(context),
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: clay,
                foregroundColor: paper,
              ),
            ),
            _ListingCountTab(
              icon: Icons.how_to_vote_outlined,
              label: 'Demos',
              kind: 'demo_poll',
              onTap: () => openDemoClasses(context),
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
          style: TextStyle(fontFamily: 'serif'),
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
      title: const Text('Demo classes', style: TextStyle(fontFamily: 'serif')),
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
        if (snapshot.hasError)
          return const Center(child: Text('Could not load demo classes.'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final demos = snapshot.data!.docs
            .where((doc) => isActiveCommunityListing(doc.data()))
            .toList();
        if (demos.isEmpty)
          return const Center(
            child: Text('No demo classes yet.', style: TextStyle(color: muted)),
          );
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
              title: const Text('Post a class'),
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

Future<void> openClass(BuildContext context, Map<String, dynamic> data) async {
  if (await requireLogin(context) && context.mounted) {
    if (data['listing_kind'] == 'class_request' ||
        data['listing_kind'] == 'demo_poll') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CommunityDetailPage(listingId: data['id'].toString(), data: data),
        ),
      );
    } else {
      showMasterClassDetails(context, data);
    }
  }
}

final _filterStyle = OutlinedButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: ink,
  side: const BorderSide(color: border),
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

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({
    required this.name,
    required this.active,
    required this.onTap,
  });
  final String name;
  final bool active;
  final VoidCallback onTap;

  IconData get icon => switch (name) {
    'All' => Icons.apps_outlined,
    'Music' => Icons.music_note_outlined,
    'Language' => Icons.translate_outlined,
    'Foreign Languages' => Icons.public_outlined,
    'Yoga' => Icons.self_improvement_outlined,
    'Meditation' => Icons.spa_outlined,
    'Bhagavat Geeta' => Icons.menu_book_outlined,
    'Workshop' => Icons.handyman_outlined,
    'Arts' => Icons.palette_outlined,
    'Curriculum' => Icons.menu_book_outlined,
    'Trading / Stock' => Icons.trending_up_outlined,
    'AI Tools' => Icons.auto_awesome_outlined,
    _ => Icons.category_outlined,
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8, bottom: 5),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 136,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF008ECC) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? const Color(0xFF0076AA) : border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: active ? Colors.white : clay),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(
    this.text,
    this.active,
    this.onTap, {
    this.activeColor = const Color(0xFF008ECC),
    this.activeTextColor = Colors.white,
  });
  final String text;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;
  final Color activeTextColor;
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
          color: active ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: active ? activeTextColor : ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
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
        color: paper,
        elevation: 2,
        borderRadius: BorderRadius.circular(18),
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
                            color: const Color(0xFFEEDFCB),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: clay,
                              size: 52,
                            ),
                          )
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              color: const Color(0xFFEEDFCB),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: clay,
                                size: 52,
                              ),
                            ),
                          ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _Badge(formats[format] ?? 'Class', paper, clay),
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
                    _Label(
                      '${categoryName.toUpperCase()}${data['subcategory'] == null ? '' : ' · ${data['subcategory']}'}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    if ((data['about_master'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        data['about_master'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: muted),
                      ),
                    ],
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
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                        ),
                        const Icon(
                          Icons.location_on_outlined,
                          color: clay,
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

class _ListingCountTab extends StatelessWidget {
  const _ListingCountTab({
    required this.icon,
    required this.label,
    required this.kind,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String kind;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('listings')
            .where('listing_kind', isEqualTo: kind)
            .snapshots(),
        builder: (context, snapshot) {
          final active = (snapshot.data?.docs ?? [])
              .where((doc) => isActiveCommunityListing(doc.data()))
              .length;
          return _Tab(icon, '$label($active)', false, onTap);
        },
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
        Icon(icon, color: active ? clay : muted),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: active ? ink : muted),
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
