import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'madhura_board.dart';
import 'madhura_post.dart';

const pista = Color(0xFFF1E5D3),
    yellow = Color(0xFFF6D886),
    cream = Color(0xFFF7F1E6),
    forest = Color(0xFF42352B),
    paper = Color(0xFFFFFCF6),
    marigold = Color(0xFFE8AD42),
    clay = Color(0xFFB9654A);

class MasterClassApp extends StatelessWidget {
  const MasterClassApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Master Class',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: clay, surface: paper),
      appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
      cardTheme: const CardThemeData(
        color: paper,
        surfaceTintColor: Colors.transparent,
      ),
    ),
    home: const MadhuraBoard(),
  );
}

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});
  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
    Future.delayed(const Duration(milliseconds: 1550), () {
      if (mounted)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: pista,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: controller,
            child: Container(
              width: 112,
              height: 112,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: yellow,
                shape: BoxShape.circle,
                border: Border.all(color: forest, width: 4),
                boxShadow: const [
                  BoxShadow(color: Color(0x33243D2A), offset: Offset(7, 7)),
                ],
              ),
              child: const Text(
                'म',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: forest,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Master Class',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: forest,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'SHARE · LEARN · GROW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: Color(0xFF3F5C45),
            ),
          ),
        ],
      ),
    ),
  );
}

enum ClassFilter { all, physical, online, competition }

class CategoryData {
  const CategoryData(
    this.filter,
    this.title,
    this.subtitle,
    this.icon,
    this.color,
  );
  final ClassFilter filter;
  final String title, subtitle;
  final IconData icon;
  final Color color;
}

const categories = [
  CategoryData(
    ClassFilter.physical,
    'Physical',
    'Learn together, nearby',
    Icons.location_on_outlined,
    pista,
  ),
  CategoryData(
    ClassFilter.online,
    'Online',
    'Join from anywhere',
    Icons.play_circle_outline,
    yellow,
  ),
  CategoryData(
    ClassFilter.competition,
    'Competitions',
    'Challenge yourself',
    Icons.emoji_events_outlined,
    Color(0xFFE6EFE1),
  ),
];
String listingType(ClassFilter value) => value == ClassFilter.physical
    ? 'offline_class'
    : value == ClassFilter.online
    ? 'online_class'
    : 'competition';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ClassFilter filter = ClassFilter.all;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> picks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> all,
  ) {
    final random = Random();
    return categories
        .map((c) {
          final pool = all
              .where((d) => d.data()['type'] == listingType(c.filter))
              .toList();
          return pool.isEmpty ? null : pool[random.nextInt(pool.length)];
        })
        .whereType<QueryDocumentSnapshot<Map<String, dynamic>>>()
        .toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore.collection('listings').snapshots(),
        builder: (context, snapshot) {
          final all = snapshot.data?.docs ?? [];
          final shown = filter == ClassFilter.all
              ? picks(all)
              : all
                    .where((d) => d.data()['type'] == listingType(filter))
                    .toList();
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandHeader(),
                      const SizedBox(height: 18),
                      HeroPanel(onPost: () => showPostSheet(context)),
                      const SizedBox(height: 28),
                      const SectionLabel('WHAT ARE YOU LOOKING FOR?'),
                      const SizedBox(height: 12),
                      ...categories.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CategoryButton(
                            data: c,
                            onTap: () => setState(() => filter = c.filter),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionLabel(
                                filter == ClassFilter.all
                                    ? 'RANDOM PICKS — ONE FROM EACH'
                                    : 'EXPLORE',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                filter == ClassFilter.all
                                    ? 'A little inspiration'
                                    : categories
                                          .firstWhere((c) => c.filter == filter)
                                          .title,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          if (filter != ClassFilter.all)
                            TextButton(
                              onPressed: () =>
                                  setState(() => filter = ClassFilter.all),
                              child: const Text('Clear selection'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (shown.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('No listings available yet.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: SliverList.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, index) =>
                        ListingCard(doc: shown[index]),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 43,
        height: 43,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: pista, shape: BoxShape.circle),
        child: const Text(
          'MC',
          style: TextStyle(fontWeight: FontWeight.w900, color: forest),
        ),
      ),
      const SizedBox(width: 10),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Master Class',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          Text(
            'MASTERCLASS BOARD',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFF806F61),
            ),
          ),
        ],
      ),
    ],
  );
}

class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.onPost});
  final VoidCallback onPost;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: pista,
      borderRadius: BorderRadius.circular(20),
    ),
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('TEACH WHAT YOU LOVE'),
        const SizedBox(height: 8),
        const Text(
          'Share your knowledge.',
          style: TextStyle(
            fontSize: 32,
            height: 1.08,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Turn your skills into a class, bring people together, or host a competition.',
          style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF806F61)),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: forest,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          ),
          onPressed: onPost,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text(
            'POST A CLASS',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
      color: Color(0xFF806F61),
    ),
  );
}

class CategoryButton extends StatelessWidget {
  const CategoryButton({super.key, required this.data, required this.onTap});
  final CategoryData data;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: data.color,
    shape: Border.all(color: const Color(0xFFE6D8C8)),
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: 96,
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF806F61),
                  ),
                ),
              ],
            ),
            CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: .65),
              child: Icon(data.icon, color: forest),
            ),
          ],
        ),
      ),
    ),
  );
}

class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.doc});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  @override
  Widget build(BuildContext context) {
    final d = doc.data(), type = doc.data()['type'];
    final label = type == 'competition'
        ? 'Competition'
        : type == 'online_class'
        ? 'Online class'
        : 'Physical class';
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: const Color(0xFFFFFCF6),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE6D8C8)),
        ),
        child: InkWell(
          onTap: () => showDetails(context, d),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 112,
                  color: const Color(0xFFF2E7D8),
                  alignment: Alignment.center,
                  child: Icon(
                    type == 'competition'
                        ? Icons.emoji_events_outlined
                        : type == 'online_class'
                        ? Icons.play_circle_outline
                        : Icons.school_outlined,
                    size: 42,
                    color: const Color(0xFFB9654A),
                  ),
                ),
                const SizedBox(height: 14),
                SectionLabel(label.toUpperCase()),
                const SizedBox(height: 4),
                Text(
                  d['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  d['description'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF806F61),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      color: pista,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        d['priceType'] == 'free' ? 'Free' : '₹${d['price']}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward),
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

void showDetails(
  BuildContext context,
  Map<String, dynamic> d,
) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: cream,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .72,
    maxChildSize: .94,
    builder: (context, controller) => Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        controller: controller,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
          SectionLabel(
            (d['type'] ?? 'class')
                .toString()
                .replaceAll('_', ' ')
                .toUpperCase(),
          ),
          const SizedBox(height: 8),
          Text(
            d['title'] ?? '',
            style: const TextStyle(
              fontSize: 30,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: Color(0xFFE6D8C8)),
              ),
            ),
            child: Text(
              '${d['city'] ?? d['topic'] ?? 'Community learning'}  ·  ${d['priceType'] == 'free' ? 'Free' : '₹${d['price']}'}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF806F61),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            d['description'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              height: 1.55,
              color: Color(0xFF42352B),
            ),
          ),
        ],
      ),
    ),
  ),
);
Future<bool?> showPostSheet(BuildContext context) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  backgroundColor: cream,
  builder: (context) =>
      const FractionallySizedBox(heightFactor: .94, child: MadhuraPostForm()),
);

class PostForm extends StatefulWidget {
  const PostForm({super.key});
  @override
  State<PostForm> createState() => _PostFormState();
}

class _PostFormState extends State<PostForm> {
  ClassFilter? type;
  final title = TextEditingController(),
      description = TextEditingController(),
      location = TextEditingController();
  String? error;
  bool saving = false;
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    location.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (type == null) {
      setState(() => error = 'Choose Physical, Online, or Competition.');
      return;
    }
    if (title.text.trim().length < 3 || description.text.trim().isEmpty) {
      setState(() => error = 'Add a title and description.');
      return;
    }
    if (type != ClassFilter.online && location.text.trim().isEmpty) {
      setState(() => error = 'Add the city.');
      return;
    }
    setState(() => saving = true);
    try {
      final auth = FirebaseAuth.instance,
          user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
      final now = DateTime.now().toIso8601String(), t = listingType(type!);
      final ref = firestore
          .collection('listings')
          .doc('${t}_${DateTime.now().millisecondsSinceEpoch}');
      await ref.set({
        'id': ref.id,
        'type': t,
        'title': title.text.trim(),
        'description': description.text.trim(),
        'priceType': 'free',
        if (type == ClassFilter.online)
          'topic': location.text.trim().isEmpty
              ? 'General'
              : location.text.trim(),
        if (type != ClassFilter.online) 'city': location.text.trim(),
        'creatorId': user.uid,
        'creatorEmail': user.email ?? 'flutter-user@masterclass.local',
        'createdAt': now,
        'updatedAt': now,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel('SHARE YOUR KNOWLEDGE'),
                SizedBox(height: 6),
                Text(
                  'Post a class',
                  style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
        const FormLabel('CLASS TYPE'),
        Row(
          children: categories
              .map(
                (c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: Text(
                        c.title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: type == c.filter ? Colors.white : null,
                        ),
                      ),
                      selected: type == c.filter,
                      selectedColor: forest,
                      backgroundColor: yellow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (_) => setState(() => type = c.filter),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const FormLabel('TITLE'),
        TextField(
          controller: title,
          decoration: fieldDecoration('What will you teach?'),
        ),
        const FormLabel('DESCRIPTION'),
        TextField(
          controller: description,
          minLines: 4,
          maxLines: 5,
          decoration: fieldDecoration('Tell learners what to expect'),
        ),
        FormLabel(type == ClassFilter.online ? 'TOPIC' : 'CITY'),
        TextField(
          controller: location,
          decoration: fieldDecoration(
            type == ClassFilter.online ? 'e.g. Music' : 'e.g. Mumbai',
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              error!,
              style: const TextStyle(
                color: Color(0xFFA43D37),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: forest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
          ),
          onPressed: saving ? null : submit,
          child: Text(
            saving ? 'PUBLISHING…' : 'PUBLISH CLASS',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

class FormLabel extends StatelessWidget {
  const FormLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 7),
    child: SectionLabel(text),
  );
}

InputDecoration fieldDecoration(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: const Color(0xFFFFFCF6),
  border: const OutlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(color: Color(0xFFE6D8C8)),
  ),
);
