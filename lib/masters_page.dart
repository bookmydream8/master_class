import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'category_style.dart';
import 'firestore_database.dart';
import 'home_illustrations.dart';
import 'profile_photo.dart';
import 'spark_logic.dart';
import 'spark_pages.dart';

const masterCategoryNames = <String, String>{
  'music': 'Music',
  'language': 'Language',
  'foreign_languages': 'Foreign Languages',
  'yoga': 'Yoga',
  'meditation': 'Meditation',
  'bhagavat_geeta': 'Bhagavat Geeta',
  'workshop': 'Workshop',
  'arts': 'Arts',
  'adult': 'Adult',
  'sports': 'Sports',
  'curriculum': 'Curriculum',
  'trading': 'Trading / Stock',
  'ai_tools': 'AI Tools',
};

void Function(BuildContext context, Map<String, dynamic> data)? openMasterListing;

class PublicMaster {
  const PublicMaster({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.skills,
    required this.city,
    this.area = '',
    this.pictureUrl = '',
    this.experience = '',
    this.rating = 0,
    this.verified = false,
    this.classCount = 0,
    this.classes = const [],
  });

  final String id;
  final String name;
  final String categoryId;
  final List<String> skills;
  final String city;
  final String area;
  final String pictureUrl;
  final String experience;
  final double rating;
  final bool verified;
  final int classCount;
  final List<Map<String, dynamic>> classes;

  String get categoryName => masterCategoryNames[categoryId] ?? categoryId;
}

PublicMaster publicMasterFromMap(String id, Map<String, dynamic> data) {
  final skills = data['skills'];
  final classes = data['classes'];
  return PublicMaster(
    id: id,
    name: (data['name'] ?? 'Master').toString(),
    categoryId: (data['categoryId'] ?? '').toString(),
    skills: skills is List ? skills.map((item) => item.toString()).toList() : const [],
    city: (data['city'] ?? '').toString(),
    area: (data['area'] ?? '').toString(),
    pictureUrl: (data['pictureUrl'] ?? '').toString(),
    experience: (data['experience'] ?? '').toString(),
    rating: (data['rating'] as num?)?.toDouble() ?? 0,
    verified: data['verified'] == true,
    classCount: (data['classCount'] as num?)?.toInt() ?? 0,
    classes: classes is List
        ? classes.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : const [],
  );
}

int compareMasters(PublicMaster a, PublicMaster b) {
  if (a.verified != b.verified) return a.verified ? -1 : 1;
  return b.rating.compareTo(a.rating);
}

/// One or two masters from each category, verified and higher rated first.
List<PublicMaster> pickDefaultMasters(List<PublicMaster> all, {int limit = 10}) {
  final groups = <String, List<PublicMaster>>{};
  for (final master in all) {
    groups.putIfAbsent(master.categoryId, () => []).add(master);
  }
  for (final group in groups.values) {
    group.sort(compareMasters);
  }
  final categories = groups.keys.toList()..sort();
  final picked = <PublicMaster>[];
  for (final category in categories) {
    if (picked.length >= limit) break;
    picked.add(groups[category]!.first);
  }
  for (final category in categories) {
    if (picked.length >= limit) break;
    final group = groups[category]!;
    if (group.length > 1) picked.add(group[1]);
  }
  return picked.take(limit).toList();
}

List<PublicMaster> filterMasters(
  List<PublicMaster> all, {
  String query = '',
  String? categoryId,
  String city = '',
}) {
  final words = query.trim().toLowerCase();
  final place = city.trim().toLowerCase();
  return all.where((master) {
    if (categoryId != null && categoryId.isNotEmpty && master.categoryId != categoryId) {
      return false;
    }
    if (place.isNotEmpty &&
        !master.city.toLowerCase().contains(place) &&
        !master.area.toLowerCase().contains(place)) {
      return false;
    }
    if (words.isEmpty) return true;
    final haystack = [
      master.name,
      master.categoryName,
      master.categoryId,
      master.city,
      ...master.skills,
    ].join(' ').toLowerCase();
    return haystack.contains(words);
  }).toList()
    ..sort(compareMasters);
}

const seedMasters = <PublicMaster>[
  PublicMaster(id: 'demo_master_music', name: 'Meera Rao', categoryId: 'music', skills: ['Hindustani', 'Vocal'], city: 'Bangalore', area: 'Indiranagar', experience: '12 years', rating: 4.9, verified: true, classCount: 3),
  PublicMaster(id: 'demo_master_language', name: 'Divya Rao', categoryId: 'language', skills: ['Kannada', 'Hindi'], city: 'Bangalore', area: 'Malleswaram', experience: '8 years', rating: 4.8, verified: true, classCount: 2),
  PublicMaster(id: 'demo_master_yoga', name: 'Ananya Shetty', categoryId: 'yoga', skills: ['Hatha', 'Beginners'], city: 'Bangalore', area: 'Jayanagar', experience: '10 years', rating: 4.9, verified: false, classCount: 2),
  PublicMaster(id: 'demo_master_arts', name: 'Ritu Malhotra', categoryId: 'arts', skills: ['Watercolour', 'Sketching'], city: 'Bangalore', area: 'Indiranagar', experience: '9 years', rating: 4.7, verified: false, classCount: 2),
  PublicMaster(id: 'demo_master_sports', name: 'Sanjay Gowda', categoryId: 'sports', skills: ['Badminton'], city: 'Bangalore', area: 'HSR Layout', experience: '6 years', rating: 4.6, verified: false, classCount: 1),
  PublicMaster(id: 'demo_master_curriculum', name: 'Sneha Iyengar', categoryId: 'curriculum', skills: ['Maths', 'CBSE'], city: 'Bangalore', area: 'Whitefield', experience: '11 years', rating: 4.8, verified: true, classCount: 2),
  PublicMaster(id: 'demo_master_meditation', name: 'Suresh Pai', categoryId: 'meditation', skills: ['Breath', 'Sound'], city: 'Bangalore', area: 'Jayanagar', experience: '15 years', rating: 4.9, verified: false, classCount: 1),
  PublicMaster(id: 'demo_master_workshop', name: 'Ayesha Siddiqui', categoryId: 'workshop', skills: ['Speaking'], city: 'Bangalore', area: 'Whitefield', experience: '7 years', rating: 4.5, verified: false, classCount: 1),
  PublicMaster(id: 'demo_master_french', name: 'Julien Pereira', categoryId: 'foreign_languages', skills: ['French'], city: 'Bangalore', area: 'Koramangala', experience: '9 years', rating: 4.7, verified: false, classCount: 2),
  PublicMaster(id: 'demo_master_trading', name: 'Nikhil Thomas', categoryId: 'trading', skills: ['Markets'], city: 'Bangalore', area: 'Bellandur', experience: '5 years', rating: 4.4, verified: false, classCount: 1),
  PublicMaster(id: 'demo_master_ai', name: 'Rohan Deshpande', categoryId: 'ai_tools', skills: ['Prompting'], city: 'Bangalore', area: 'Koramangala', experience: '4 years', rating: 4.6, verified: false, classCount: 1),
  PublicMaster(id: 'demo_master_geeta', name: 'Lakshmi Bhat', categoryId: 'bhagavat_geeta', skills: ['Bhagavat Geeta'], city: 'Bangalore', area: 'Basavanagudi', experience: '20 years', rating: 4.8, verified: false, classCount: 1),
];

Future<void> publishMasterProfile() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final profile = (await firestore.collection('profiles').doc(user.uid).get()).data() ?? {};
  if ((profile['role'] ?? '') != 'Master') return;
  final interests = profile['topicInterests'];
  final skills = interests is List ? interests.map((item) => item.toString()).take(12).toList() : <String>[];
  var categoryId = 'music';
  for (final entry in masterCategoryNames.entries) {
    if (skills.contains(entry.value)) {
      categoryId = entry.key;
      break;
    }
  }
  final listings = await firestore.collection('listings').where('creatorId', isEqualTo: user.uid).limit(40).get();
  final classes = listings.docs.where((doc) => doc.data()['listing_kind'] == null).length;
  final card = firestore.collection('master_profiles').doc(user.uid);
  final existing = await card.get();
  await card.set({
    'name': (profile['name'] ?? user.displayName ?? 'Master').toString(),
    'pictureUrl': (profile['pictureUrl'] ?? user.photoURL ?? '').toString(),
    'city': (profile['city'] ?? '').toString(),
    'area': (profile['preferredPhysicalArea'] ?? '').toString(),
    'categoryId': categoryId,
    'skills': skills,
    'experience': (profile['expertDetails'] ?? '').toString().length > 200
        ? (profile['expertDetails'] ?? '').toString().substring(0, 200)
        : (profile['expertDetails'] ?? '').toString(),
    'rating': (profile['rating'] as num?)?.toDouble() ?? 0,
    'verified': existing.data()?['verified'] == true,
    'classCount': classes,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

class MastersPage extends StatefulWidget {
  const MastersPage({super.key});

  @override
  State<MastersPage> createState() => _MastersPageState();
}

class _MastersPageState extends State<MastersPage> {
  final search = TextEditingController();
  final city = TextEditingController();
  String? categoryId;
  int shown = 10;
  List<PublicMaster> live = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await firestore.collection('master_profiles').limit(80).get();
      if (!mounted) return;
      setState(() {
        live = snap.docs.map((doc) => publicMasterFromMap(doc.id, doc.data())).toList();
      });
    } catch (_) {}
  }

  List<PublicMaster> get directory {
    final ids = live.map((master) => master.id).toSet();
    return [...live, for (final master in seedMasters) if (!ids.contains(master.id)) master];
  }

  @override
  Widget build(BuildContext context) {
    final searching = search.text.trim().isNotEmpty || city.text.trim().isNotEmpty || categoryId != null;
    final filtered = searching
        ? filterMasters(directory, query: search.text, categoryId: categoryId, city: city.text)
        : pickDefaultMasters(directory);
    final visible = filtered.take(shown).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Masters')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          TextField(
            controller: search,
            onChanged: (_) => setState(() => shown = 10),
            decoration: const InputDecoration(
              hintText: 'Name, skill, or category',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: city,
            onChanged: (_) => setState(() => shown = 10),
            decoration: const InputDecoration(
              hintText: 'City',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: categoryId == null,
                    onSelected: (_) => setState(() {
                      categoryId = null;
                      shown = 10;
                    }),
                  ),
                ),
                for (final entry in masterCategoryNames.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(entry.value),
                        selected: categoryId == entry.key,
                        onSelected: (_) => setState(() {
                          categoryId = categoryId == entry.key ? null : entry.key;
                          shown = 10;
                        }),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!searching)
            Text('A mix across subjects', style: Theme.of(context).textTheme.bodySmall),
          for (final master in visible) _MasterCard(master: master),
          if (visible.length < filtered.length)
            TextButton(
              onPressed: () => setState(() => shown += 10),
              child: const Text('More masters'),
            ),
        ],
      ),
    );
  }
}

class _MasterCard extends StatelessWidget {
  const _MasterCard({required this.master});
  final PublicMaster master;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: ProfileAvatar(url: master.pictureUrl, name: master.name, radius: 24),
        title: Row(
          children: [
            Flexible(child: Text(master.name, overflow: TextOverflow.ellipsis)),
            if (master.verified) const Icon(Icons.verified, color: Color(0xFF1A6B73), size: 18),
          ],
        ),
        subtitle: Text(
          '${master.categoryName} · ${master.skills.join(', ')}\n${master.experience.isEmpty ? '' : '${master.experience} · '}${master.area.isEmpty ? master.city : '${master.area}, ${master.city}'} · ${master.rating.toStringAsFixed(1)} · ${master.classCount} classes',
        ),
        trailing: HomeIllustration(master.categoryId, size: 36),
        isThreeLine: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MasterPublicPage(master: master)),
        ),
      ),
    );
  }
}

class MasterPublicPage extends StatelessWidget {
  const MasterPublicPage({super.key, required this.master});
  final PublicMaster master;

  @override
  Widget build(BuildContext context) {
    final live = firestore.collection('listings').where('creatorId', isEqualTo: master.id).limit(20);
    return Scaffold(
      appBar: AppBar(title: Text(master.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              ProfileAvatar(url: master.pictureUrl, name: master.name, radius: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(master.name, style: Theme.of(context).textTheme.titleLarge)),
                        if (master.verified) const Icon(Icons.verified, color: Color(0xFF1A6B73)),
                      ],
                    ),
                    Text('${master.categoryName} · ${master.city}'),
                    if (master.experience.isNotEmpty) Text(master.experience),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FollowButton(masterId: master.id, masterName: master.name),
              SharePosterButton(
                title: master.name,
                subtitle: master.categoryName,
                detail: master.city,
                link: masterShareLink(master.id),
                color: categoryStyleForId(master.categoryId).tint,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Classes', style: Theme.of(context).textTheme.titleMedium),
          if (master.id.startsWith('demo_'))
            Text('${master.classCount} classes in ${master.skills.join(', ')}.')
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: live.snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) return const Text('No classes posted yet.');
                return Column(
                  children: [
                    for (final doc in docs)
                      ListTile(
                        title: Text((doc.data()['title'] ?? 'Class').toString()),
                        subtitle: Text((doc.data()['city'] ?? 'Online').toString()),
                        onTap: () => openMasterListing?.call(context, {...doc.data(), 'id': doc.id}),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
