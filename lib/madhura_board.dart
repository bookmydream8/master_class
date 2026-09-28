import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_database.dart';
import 'package:flutter/material.dart';

import 'master_class_app.dart' show showPostSheet;
import 'madhura_detail.dart' show showMadhuraDetails;
import 'auth_profile.dart' show requireLogin, openProfile;

const cream = Color(0xFFF7F1E6),
    paper = Color(0xFFFFFCF6),
    ink = Color(0xFF42352B),
    muted = Color(0xFF806F61),
    border = Color(0xFFE6D8C8),
    clay = Color(0xFFB9654A),
    gold = Color(0xFFE8AD42);
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
  ],  'Curriculum': [
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
  'Foreign Languages': 'foreign_languages',  'Curriculum': 'curriculum',
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
};

String listingFormat(Map<String, dynamic> data) =>
    switch ((data['listing_type'] ?? data['type'] ?? '').toString()) {
      'offline_class' => 'physical',
      'online_class' => 'online',
      final value => value,
    };
String listingPrice(Map<String, dynamic> data) =>
    data['is_free'] == true ||
        data['priceType'] == 'free' ||
        data['price'] == null
    ? 'Free'
    : '₹${data['price']}';

class MadhuraBoard extends StatefulWidget {
  const MadhuraBoard({super.key});
  @override
  State<MadhuraBoard> createState() => _MadhuraBoardState();
}

class _MadhuraBoardState extends State<MadhuraBoard> {
  final search = TextEditingController();
  String? category, focus;
  String city = 'Bangalore';
  final selectedFormats = <String>{};
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  bool matches(Map<String, dynamic> d) {
    final listedCategory = (d['category'] ?? '').toString();
    final listedFocus = (d['subcategory'] ?? '').toString();
    final words =
        '${d['title'] ?? ''} ${d['description'] ?? ''} ${d['topic'] ?? ''} ${d['about_master'] ?? ''} $listedCategory $listedFocus'
            .toLowerCase();
    if (category != null && listedCategory.toLowerCase() != (categoryIds[category] ?? category!).toLowerCase() && listedCategory.toLowerCase() != category!.toLowerCase()) {
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
    if (selectedFormats.isNotEmpty && !selectedFormats.contains(format))
      return false;
    final place = (d['city'] ?? '').toString();
    if (format != 'online' &&
        place.isNotEmpty &&
        place.toLowerCase() != city.toLowerCase())
      return false;
    final query = search.text.trim().toLowerCase();
    return query.isEmpty || words.contains(query);
  }

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
                            if (!selectedFormats.add(entry.key))
                              selectedFormats.remove(entry.key);
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _Label('CITY'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: cities
                            .map(
                              (value) => ChoiceChip(
                                label: Text(value),
                                selected: city == value,
                                selectedColor: ink,
                                backgroundColor: cream,
                                labelStyle: TextStyle(
                                  color: city == value ? paper : ink,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => update(() => city = value),
                              ),
                            )
                            .toList(),
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
                                  backgroundColor: cream,
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
                          selectedFormats.clear();
                          focus = null;
                          city = 'Bangalore';
                        }),
                        child: const Text('Show everything'),
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
    backgroundColor: cream,
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
                    const Column(
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
                          'MASTERCLASS BOARD',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.1,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => openProfile(context),
                      style: TextButton.styleFrom(
                        backgroundColor: ink,
                        foregroundColor: paper,
                      ),
                      child: const Text('Profile'),
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
            height: 54,
            decoration: const BoxDecoration(
              border: Border.symmetric(horizontal: BorderSide(color: border)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
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
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('listings')
                  .snapshots(),
              builder: (context, snapshot) {
                final listings = (snapshot.data?.docs ?? [])
                    .where((doc) => matches(doc.data()))
                    .toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 25),
                  children: [
                    Text(
                      category == null
                          ? 'Learn from a master near you'
                          : category!,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 27,
                        height: 1.08,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      snapshot.connectionState == ConnectionState.waiting
                          ? 'Loading the board…'
                          : '${listings.length} class${listings.length == 1 ? '' : 'es'} in $city and online',
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: openFilters,
                          icon: const Icon(Icons.tune, size: 16),
                          label: Text(
                            selectedFormats.isEmpty && focus == null
                                ? 'Filters'
                                : 'Filters ${selectedFormats.length + (focus == null ? 0 : 1)}',
                          ),
                          style: _filterStyle,
                        ),
                        OutlinedButton.icon(
                          onPressed: openFilters,
                          icon: const Icon(
                            Icons.location_on_outlined,
                            color: clay,
                            size: 16,
                          ),
                          label: Text(city),
                          style: _filterStyle,
                        ),
                      ],
                    ),
                    if (category != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
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
                    ],
                    const SizedBox(height: 16),
                    if (snapshot.hasError)
                      const _Notice(
                        'Could not load classes',
                        'Check your connection and try again.',
                      )
                    else if (snapshot.connectionState ==
                        ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (listings.isEmpty)
                      _Notice(
                        'Nothing here yet',
                        'Try a different filter, or be the first to post for this focus.',
                        onPost: () => openPost(context),
                      )
                    else
                      ...listings.map((doc) => _Card(doc.data())),
                  ],
                );
              },
            ),
          ),
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
            IconButton.filled(
              onPressed: () => openPost(context),
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: clay,
                foregroundColor: paper,
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
    ),
  );
}

Future<void> openPost(BuildContext context) async {
  if (await requireLogin(context) && context.mounted) {
    await showPostSheet(context);
  }
}

Future<void> openClass(BuildContext context, Map<String, dynamic> data) async {
  if (await requireLogin(context) && context.mounted) {
    showMadhuraDetails(context, data);
  }
}

final _filterStyle = OutlinedButton.styleFrom(
  backgroundColor: paper,
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
          color: active ? ink : const Color(0xFFF1E8DA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: active ? paper : ink,
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
        'Class';
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
                        ? Image.memory(base64Decode(imageBase64), fit: BoxFit.cover)
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
                        fontSize: 20,
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
                              : (data['city'] ?? 'Bangalore').toString(),
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
  backgroundColor: paper,
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
