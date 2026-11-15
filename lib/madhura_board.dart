import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_database.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'home_catalogue.dart';
import 'member_id.dart';
import 'master_class_app.dart' show showPostSheet;
import 'seed/bangalore_demo.dart';
import 'madhura_detail.dart' show MasterClassDetailPage, showMasterClassDetails;
import 'auth_profile.dart' show ProfilePage, requireLogin;
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
  const MasterClassBoard({
    super.key,
    this.initialTab = 0,
    this.initialFormat,
    this.showFreshOnStart = true,
    this.previewMcId,
  });

  /// Opens Home, Classes, Community, or Profile. Defaults to Home.
  final int initialTab;

  /// When set, opens Classes on this format (online, physical, competition, event).
  final String? initialFormat;

  /// The "just posted" sheet auto-opens on Home unless this is false.
  final bool showFreshOnStart;

  /// Shown in the header when there is no signed-in profile yet.
  final String? previewMcId;

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
  late int _tab;
  late final StreamSubscription<User?> _authSub;
  String memberId = '';

  @override
  void initState() {
    super.initState();
    final requestedTab = widget.initialTab;
    _tab = requestedTab < 0 ? 0 : (requestedTab > 3 ? 3 : requestedTab);
    final format = widget.initialFormat;
    if (format != null) {
      _tab = 1;
      _browseFormat = format;
      selectedFormats
        ..clear()
        ..add(format);
      if (format != 'online') city = savedPhysicalCity;
      _loadListings(reset: true);
    } else if (_tab == 1) {
      _browseFormat = 'online';
      _loadListings(reset: true);
    } else if (_tab == 0 && widget.showFreshOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showFreshPosts());
    }
    _loadPreferredCity();
    _refreshMemberId();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user != null && !user.isAnonymous) _loadPreferredCity();
      _refreshMemberId();
      setState(() {});
    }, onError: (_) {});
  }

  Future<void> _refreshMemberId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      final preview = widget.previewMcId ?? '';
      if (mounted && preview.isNotEmpty) setState(() => memberId = preview);
      return;
    }
    try {
      final id = await ensureMemberId(user);
      if (mounted) setState(() => memberId = id);
    } catch (_) {
      final preview = widget.previewMcId ?? '';
      if (mounted && preview.isNotEmpty) setState(() => memberId = preview);
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
    _authSub.cancel();
    search.dispose();
    super.dispose();
  }

  bool isExpired(Map<String, dynamic> data) {
    final expiresAt = data['expires_at'];
    if (expiresAt is Timestamp) {
      return !expiresAt.toDate().isAfter(DateTime.now());
    }
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
        !words.contains(focus!.toLowerCase())) {
      return false;
    }
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
        place.toLowerCase() != city.toLowerCase()) {
      return false;
    }
    if (area.isNotEmpty &&
        (format == 'physical' || format == 'competition') &&
        listingArea.toLowerCase() != area.toLowerCase()) {
      return false;
    }
    final query = search.text.trim().toLowerCase();
    return query.isEmpty || words.contains(query);
  }

  /// Unfiltered catalogue for Home counts and the demo rail.
  /// Live documents replace the Bangalore seed, same as the class list.
  List<Map<String, dynamic>> _homeCatalogue() {
    if (_listingDocs.isEmpty) {
      return bangaloreDemoListings().where((data) => !isExpired(data)).toList();
    }
    return _listingDocs
        .where((doc) => !isExpired(doc.data()))
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();
  }

  List<Map<String, dynamic>> _visibleListings() {
    final live = _listingDocs
        .where((doc) => !isExpired(doc.data()) && matches(doc.data()))
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();
    if (_listingDocs.isNotEmpty) return live;
    return bangaloreDemoListings()
        .where((data) => !isExpired(data) && matches(data))
        .toList();
  }

  Widget _buildListingFeed() {
    final listings = _visibleListings();
    final usingDemo = _listingDocs.isEmpty;
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final heading = category == null
        ? selectedFormats.contains('competition')
              ? 'Competitions'
              : selectedFormats.contains('event')
              ? 'Events'
              : selectedFormats.contains('physical')
              ? 'Physical classes'
              : 'Online classes'
        : category!;
    return RefreshIndicator(
      onRefresh: () => _loadListings(reset: true),
      child: ListView(
        physics: AlwaysScrollableScrollPhysics(
          parent: ScrollConfiguration.of(context).getScrollPhysics(context),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(
            heading,
            style: text.titleLarge?.copyWith(color: colors.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            !usingDemo && _loadingListings
                ? 'Loading classes…'
                : '${listings.length} ${listings.length == 1 ? 'class' : 'classes'}',
            style: text.bodySmall?.copyWith(color: colors.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed:
                    selectedFormats.length == 1 &&
                        selectedFormats.contains('online')
                    ? null
                    : openCityPicker,
                icon: const Icon(Icons.location_on_outlined, size: 18),
                label: Text(city.isEmpty ? 'All cities' : city),
                style: _filterStyle(context),
              ),
              if (selectedFormats.contains('physical') ||
                  selectedFormats.contains('competition'))
                OutlinedButton.icon(
                  onPressed: openAreaPicker,
                  icon: const Icon(Icons.place_outlined, size: 18),
                  label: Text(area.isEmpty ? 'All areas' : area),
                  style: _filterStyle(context),
                ),
              FilterChip(
                label: const Text('Free only'),
                selected: freeOnly,
                onSelected: (value) => setState(() => freeOnly = value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!usingDemo && _listingError != null && listings.isEmpty)
            _Notice(
              'Could not load classes',
              _listingError!,
              actionLabel: 'Try again',
              onPost: () => _loadListings(reset: true),
            )
          else if (!usingDemo && _loadingListings && listings.isEmpty)
            const AppLoading(message: 'Loading classes')
          else if (listings.isEmpty)
            _Notice(
              'Nothing here yet',
              'Try another filter, or be the first to post a class for this focus.',
              onPost: () => openPost(context),
            )
          else
            for (final data in listings) ...[
              CourseCard(
                data: data,
                onTap: () async {
                  if (await openClass(context, data)) _loadListings(reset: true);
                },
              ),
              const SizedBox(height: 14),
            ],
          if (!usingDemo && !_loadingListings && _hasMoreListings) ...[
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
    showDragHandle: true,
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
      showDragHandle: true,
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_tab) {
        0 => SafeArea(bottom: false, child: _buildHome(context)),
        1 => SafeArea(bottom: false, child: _buildBrowse(context)),
        2 => SafeArea(bottom: false, child: _buildCommunity(context)),
        _ => _buildProfileTab(context),
      },
      floatingActionButton: _tab == 3
          ? null
          : FloatingActionButton(
              onPressed: () => openPost(context),
              tooltip: 'Create a post',
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: _homeFooter(context),
    );
  }

  Widget _buildHome(BuildContext context) {
    final name = FirebaseAuth.instance.currentUser?.displayName
        ?.split(' ')
        .first;
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final initial = (name ?? 'M').characters.first.toUpperCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'logo.png',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MASTER CLASS',
                    style: text.labelSmall?.copyWith(
                      color: colors.muted,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 18, color: colors.accent),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          savedPhysicalCity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge?.copyWith(color: colors.ink),
                        ),
                      ),
                    ],
                  ),
                  if (memberId.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    McIdBanner(mcId: memberId, compact: true),
                  ],
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'Open profile',
              child: InkWell(
                onTap: () => _selectTab(3),
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: colors.accentSoft,
                  child: Text(
                    initial,
                    style: text.titleMedium?.copyWith(
                      color: colors.onAccentSoft,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Semantics(
          button: true,
          label: 'Search classes',
          child: TextField(
            readOnly: true,
            onTap: () => _openBrowse('online'),
            decoration: InputDecoration(
              hintText: 'Search music, yoga, languages…',
              prefixIcon: Icon(Icons.search, color: colors.muted),
            ),
          ),
        ),
        const SizedBox(height: 16),
        PromoCarousel(onOpen: _openBrowse),
        const SizedBox(height: 22),
        LearnYourWay(listings: _homeCatalogue(), onOpen: _openBrowse),
        const SizedBox(height: 22),
        DemoClassesSoon(
          listings: _homeCatalogue(),
          onOpen: (data) => showMasterClassDetails(context, data),
        ),
        const SizedBox(height: 18),
        AppSectionHeader(title: 'Browse by subject'),
        const SizedBox(height: 12),
        HomeCategoryRail(onOpen: (name) => _openBrowse('online', focusCategory: name)),
        const SizedBox(height: 22),
        _communityEntry(
          context,
          icon: Icons.how_to_vote_outlined,
          title: 'Demo class votes',
          subtitle: 'Help choose the next class to try.',
          kind: 'demo_poll',
          onTap: () => openDemoClasses(context),
        ),
        const SizedBox(height: 12),
        _communityEntry(
          context,
          icon: Icons.forum_outlined,
          title: 'Request a class',
          subtitle: 'Ask the community for a class you want.',
          kind: 'class_request',
          onTap: () => openRequests(context),
        ),
        const SizedBox(height: 22),
        HomeCatalogue(
          onOpen: (data) => showMasterClassDetails(context, data),
          onSeeAll: () => _openBrowse('online'),
        ),
      ],
    );
  }

  Widget _communityEntry(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String kind,
    required VoidCallback onTap,
  }) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    return _ActiveListingCount(
      kind: kind,
      builder: (activeCount) => Material(
        color: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.line),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: colors.onAccentSoft),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(color: colors.muted),
                      ),
                    ],
                  ),
                ),
                _CountBadge(count: activeCount),
                Icon(Icons.chevron_right, color: colors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    if (index == 1 && _browseFormat == null) {
      _openBrowse('online');
      return;
    }
    setState(() => _tab = index);
  }

  void _openBrowse(String format, {String? focusCategory}) {
    final changingFormat = _browseFormat != format;
    _selectFormats({format});
    setState(() {
      _browseFormat = format;
      _tab = 1;
      if (changingFormat) {
        category = focusCategory;
        focus = null;
        freeOnly = false;
        search.clear();
      } else if (focusCategory != null) {
        category = focusCategory;
        focus = null;
      }
    });
    _loadListings(reset: true);
  }

  Future<void> _showFreshPosts() async {
    if (!mounted || _tab != 0) return;
    final show = await _claimFreshPostsPrompt();
    if (!mounted || !show || _tab != 0) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.52,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (context, controller) => FreshPostsSheet(
          controller: controller,
          onOpen: (data) {
            Navigator.pop(sheetContext);
            showMasterClassDetails(sheetContext, data);
          },
        ),
      ),
    );
  }

  /// Shows the sheet on at most three Home opens per calendar day.
  Future<bool> _claimFreshPostsPrompt() async {
    const dayKey = 'fresh_posts_sheet_day';
    const countKey = 'fresh_posts_sheet_count';
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final storedDay = prefs.getString(dayKey);
    final count = storedDay == today ? (prefs.getInt(countKey) ?? 0) : 0;
    if (count >= 3) return false;
    await prefs.setString(dayKey, today);
    await prefs.setInt(countKey, count + 1);
    return true;
  }

  Widget _buildBrowse(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Classes', style: text.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Browse lessons, nearby sessions, competitions, and events.',
                style: text.bodySmall?.copyWith(color: colors.muted),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Chip(
                      'Online',
                      _browseFormat == 'online',
                      () => _openBrowse('online'),
                    ),
                    _Chip(
                      'Physical',
                      _browseFormat == 'physical',
                      () => _openBrowse('physical'),
                    ),
                    _Chip(
                      'Competitions',
                      _browseFormat == 'competition',
                      () => _openBrowse('competition'),
                    ),
                    _Chip(
                      'Events',
                      _browseFormat == 'event',
                      () => _openBrowse('event'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: 'Search classes',
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search piano, French, yoga…',
                    prefixIcon: Icon(Icons.search, color: colors.muted),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () => setState(search.clear),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
            height: 44,
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
    );
  }

  Widget _buildCommunity(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = AppPalette.of(context);
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Community', style: text.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Ask for a class, or vote on the next demo.',
                  style: text.bodySmall?.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Online requests'),
              Tab(text: 'Nearby requests'),
              Tab(text: 'Demo votes'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _RequestFeed(mode: 'online'),
                _RequestFeed(mode: 'physical'),
                _DemoFeed(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return SafeArea(
        child: AppEmpty(
          icon: Icons.person_outline,
          title: 'Your profile',
          message:
              'Sign in to publish classes, save your city, and see learners who are interested.',
          actionLabel: 'Sign in',
          onAction: () async {
            final ok = await requireLogin(context);
            if (ok && mounted) setState(() => _tab = 3);
          },
        ),
      );
    }
    return const ProfilePage();
  }

  Widget _homeFooter(BuildContext context) {
    return NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: _selectTab,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.school_outlined),
          selectedIcon: Icon(Icons.school),
          label: 'Classes',
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: 'Community',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
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
      appBar: AppBar(
        title: const Text('Class requests'),
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
          if (snapshot.hasError) {
            return const AppEmpty(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load requests',
              message: 'Check your connection and try again in a moment.',
            );
          }
          if (!snapshot.hasData) {
            return const AppLoading(message: 'Loading requests');
          }
          final requests = snapshot.data!.docs
              .where(
                (doc) =>
                    (doc.data()['request_mode'] ?? 'online') == mode &&
                    isActiveCommunityListing(doc.data()),
              )
              .toList();
          if (requests.isEmpty) {
            return AppEmpty(
              icon: Icons.forum_outlined,
              title: 'No requests yet',
              message: mode == 'physical'
                  ? 'No nearby class requests yet. Ask for one the community can teach in person.'
                  : 'No online class requests yet. Tell masters what you want to learn.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
    appBar: AppBar(
      title: const Text('Demo classes'),
      actions: [
        TextButton.icon(
          onPressed: () => openCommunityPost(context, 'demo_poll'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Post'),
        ),
      ],
    ),
    body: const _DemoFeed(),
  );
}

class _DemoFeed extends StatelessWidget {
  const _DemoFeed();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('listings')
            .where('listing_kind', isEqualTo: 'demo_poll')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const AppEmpty(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load demo classes',
              message: 'Check your connection and try again in a moment.',
            );
          }
          if (!snapshot.hasData) {
            return const AppLoading(message: 'Loading demo votes');
          }
          final demos = snapshot.data!.docs
              .where((doc) => isActiveCommunityListing(doc.data()))
              .toList();
          if (demos.isEmpty) {
            return AppEmpty(
              icon: Icons.how_to_vote_outlined,
              title: 'No demo votes yet',
              message: 'Propose a demo class and let learners choose what to try.',
              actionLabel: 'Post a demo',
              onAction: () => openCommunityPost(context, 'demo_poll'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: demos.length,
            itemBuilder: (context, index) {
              final doc = demos[index];
              return _Card({...doc.data(), 'id': doc.id});
            },
          );
        },
      );
}

Future<void> openPost(BuildContext context) async {
  if (!await requireLogin(context) || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final colors = AppPalette.of(sheetContext);
      Widget leading(IconData icon) => CircleAvatar(
        backgroundColor: colors.accentSoft,
        child: Icon(icon, color: colors.onAccentSoft),
      );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  'Create',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: leading(Icons.school_outlined),
                title: const Text('Post a class or event'),
                subtitle: const Text('Share a lesson, competition, or event'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showPostSheet(context);
                },
              ),
              ListTile(
                leading: leading(Icons.volunteer_activism_outlined),
                title: const Text('Request a class'),
                subtitle: const Text('Other learners can show interest'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  openCommunityPost(context, 'class_request');
                },
              ),
              ListTile(
                leading: leading(Icons.how_to_vote_outlined),
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
      );
    },
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

ButtonStyle _filterStyle(BuildContext context) {
  final colors = AppPalette.of(context);
  return OutlinedButton.styleFrom(
    backgroundColor: colors.accentSoft,
    foregroundColor: colors.onAccentSoft,
    side: BorderSide(color: colors.line),
    shape: const StadiumBorder(),
    minimumSize: const Size(0, 40),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppPalette.of(context).muted,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.active, this.onTap);
  final String text;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: active,
        label: text,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? colors.accent : colors.card,
              border: Border.all(color: active ? colors.accent : colors.line),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: active ? colors.onAccent : colors.ink,
                fontWeight: FontWeight.w600,
              ),
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
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.line),
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
                        ? ColoredBox(
                            color: colors.imageFallback,
                            child: Icon(
                              Icons.auto_stories_outlined,
                              color: colors.accent,
                              size: 48,
                            ),
                          )
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => ColoredBox(
                              color: colors.imageFallback,
                              child: Icon(
                                Icons.auto_stories_outlined,
                                color: colors.accent,
                                size: 48,
                              ),
                            ),
                          ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _Badge(
                        formats[format] ?? 'Class',
                        colors.card,
                        colors.ink,
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: _Badge(
                        listingPrice(data),
                        colors.accent,
                        colors.onAccent,
                      ),
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
                      '$categoryName${data['subcategory'] == null ? '' : ' · ${data['subcategory']}'}',
                      style: text.bodySmall?.copyWith(color: colors.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                    if (format == 'class_request' || format == 'demo_poll')
                      CommunityActivity(
                        listingId: (data['id'] ?? '').toString(),
                        isPoll: format == 'demo_poll',
                        creatorId: (data['creatorId'] ?? '').toString(),
                        creatorName: (data['creatorName'] ?? 'Member')
                            .toString(),
                      ),
                    const SizedBox(height: 12),
                    Divider(color: colors.line, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (data['start_date'] ?? 'Dates to be announced')
                                .toString(),
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(color: colors.muted),
                          ),
                        ),
                        Icon(
                          Icons.location_on_outlined,
                          color: colors.accent,
                          size: 16,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          format == 'online'
                              ? 'Online'
                              : (data['city'] ?? 'Any city').toString(),
                          style: text.bodySmall?.copyWith(color: colors.ink),
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
  const _Notice(
    this.title,
    this.detail, {
    this.actionLabel = 'Post a class',
    this.onPost,
  });
  final String title, detail, actionLabel;
  final VoidCallback? onPost;
  @override
  Widget build(BuildContext context) => AppEmpty(
    title: title,
    message: detail,
    actionLabel: onPost == null ? null : actionLabel,
    onAction: onPost,
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
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.accent,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          color: colors.onAccent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

void showProfile(BuildContext context) => showModalBottomSheet(
  context: context,
  showDragHandle: true,
  builder: (context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to Master Class',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Browse classes and share your knowledge.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppPalette.of(context).muted,
          ),
        ),
      ],
    ),
  ),
);
