// Demo catalogue for Bangalore. Shown only when Firestore has no listings,
// so the board is not blank before real posts exist. Not written to Firestore.

int enrolledCount(Map<String, dynamic> data) {
  final value = data['enrolled_count'];
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value') ?? 0;
}

double? ratingOf(Map<String, dynamic> data) {
  final value = data['rating'];
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

DateTime? postedAt(Map<String, dynamic> data) {
  final raw = data['createdAt'] ?? data['updatedAt'];
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool postedToday(Map<String, dynamic> data, [DateTime? now]) {
  final posted = postedAt(data);
  if (posted == null) return false;
  final clock = now ?? DateTime.now();
  return _sameDay(posted.toLocal(), clock);
}

bool postedYesterday(Map<String, dynamic> data, [DateTime? now]) {
  final posted = postedAt(data);
  if (posted == null) return false;
  final clock = now ?? DateTime.now();
  final yesterday = DateTime(clock.year, clock.month, clock.day)
      .subtract(const Duration(days: 1));
  return _sameDay(posted.toLocal(), yesterday);
}

bool postedThisMonth(Map<String, dynamic> data, [DateTime? now]) {
  final posted = postedAt(data);
  if (posted == null) return false;
  final clock = now ?? DateTime.now();
  final local = posted.toLocal();
  return local.year == clock.year && local.month == clock.month;
}

bool isLiveClass(Map<String, dynamic> data, [DateTime? now]) {
  if (data['is_live'] == true) return true;
  final raw = (data['start_date'] ?? '').toString();
  final start = DateTime.tryParse(raw);
  if (start == null) return false;
  final clock = now ?? DateTime.now();
  return _sameDay(start, clock) &&
      (data['listing_type'] == 'online_class' || data['type'] == 'online_class');
}

int masterCount(Iterable<Map<String, dynamic>> items) => items
    .map((item) => (item['creatorId'] ?? item['creatorName'] ?? '').toString())
    .where((id) => id.isNotEmpty)
    .toSet()
    .length;

int learnerCount(Iterable<Map<String, dynamic>> items) =>
    items.fold<int>(0, (sum, item) => sum + enrolledCount(item));

/// Live documents win. An empty backend falls back to the Bangalore demo set.
List<Map<String, dynamic>> catalogueOrDemo(List<Map<String, dynamic>> live) {
  if (live.isNotEmpty) return live;
  return bangaloreDemoListings();
}

List<Map<String, dynamic>> bangaloreDemoListings() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final listings = <Map<String, dynamic>>[];
  for (var index = 0; index < _specs.length; index++) {
    final spec = _specs[index];
    final posted = today.subtract(Duration(days: spec.postedDaysAgo));
    final starts = today.add(Duration(days: spec.startsInDays));
    final slug = spec.educator.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), '_');
    final format = switch (spec.format) {
      'physical' => 'offline_class',
      'online' => 'online_class',
      'event' => 'event',
      _ => 'competition',
    };
    final photo = _photos[spec.categoryId]![index % _photos[spec.categoryId]!.length];
    listings.add({
      'id': 'demo_${spec.format}_$index',
      'type': format,
      'listing_type': format,
      'category': spec.categoryId,
      'subcategory': spec.subcategory,
      'title': spec.title,
      'description': spec.blurb,
      'about_master': '${spec.educator} teaches small groups in Bangalore.',
      'creatorName': spec.educator,
      'creatorId': 'demo_$slug',
      'city': 'Bangalore',
      if (spec.area.isNotEmpty) 'area': spec.area,
      'price': spec.price,
      if (spec.price == 0 || spec.demo) 'is_free': true,
      if (spec.price == 0 || spec.demo) 'priceType': 'free',
      'start_date': _date(starts),
      'expiry_date': _date(today.add(const Duration(days: 60))),
      'createdAt': posted.add(const Duration(hours: 9)).toIso8601String(),
      'updatedAt': posted.add(const Duration(hours: 9)).toIso8601String(),
      'enrolled_count': spec.enrolled,
      'rating': spec.rating,
      'fee_period': spec.price >= 1400 ? 'course' : 'month',
      if (spec.demo) 'is_demo': true,
      if (spec.live) 'is_live': true,
      'image_url':
          'https://images.unsplash.com/$photo?auto=format&fit=crop&w=900&q=70',
    });
  }
  return listings;
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class _Spec {
  const _Spec({
    required this.format,
    required this.categoryId,
    required this.subcategory,
    required this.title,
    required this.educator,
    required this.price,
    required this.area,
    required this.rating,
    required this.enrolled,
    required this.postedDaysAgo,
    required this.startsInDays,
    required this.blurb,
    this.live = false,
    this.demo = false,
  });

  final String format;
  final String categoryId;
  final String subcategory;
  final String title;
  final String educator;
  final int price;
  final String area;
  final double rating;
  final int enrolled;
  final int postedDaysAgo;
  final int startsInDays;
  final String blurb;
  final bool live;
  final bool demo;
}

bool isDemoListing(Map<String, dynamic> data) => data['is_demo'] == true;

DateTime? classStartDate(Map<String, dynamic> data) =>
    DateTime.tryParse((data['start_date'] ?? '').toString());

/// Whole days from today until the class starts. Negative means it already started.
int daysUntilStart(Map<String, dynamic> data, [DateTime? now]) {
  final start = classStartDate(data);
  if (start == null) return 9999;
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final day = DateTime(start.year, start.month, start.day);
  return day.difference(today).inDays;
}

String startCountdown(Map<String, dynamic> data, [DateTime? now]) {
  final days = daysUntilStart(data, now);
  if (days <= 0) return 'Starts today';
  if (days == 1) return 'Starts in 1 day';
  return 'Starts in $days days';
}

/// Free demo or trial classes whose start date is today through the next 10 days.
List<Map<String, dynamic>> demosStartingSoon(
  Iterable<Map<String, dynamic>> items, [
  DateTime? now,
]) {
  final soon = items.where((item) {
    if (!isDemoListing(item)) return false;
    final days = daysUntilStart(item, now);
    return days >= 0 && days <= 10;
  }).toList();
  soon.sort((a, b) => daysUntilStart(a, now).compareTo(daysUntilStart(b, now)));
  return soon;
}

const _photos = <String, List<String>>{
  'music': [
    'photo-1511379938547-c1f69419868d',
    'photo-1510915361894-db8b60106cb1',
    'photo-1514320291840-2e0a9bf2a9ae',
    'photo-1493225457124-a3eb161ffa5f',
    'photo-1508700115892-45ecd05ae2ad',
  ],
  'language': [
    'photo-1456513080880-7d93d27a8a77',
    'photo-1481627834876-b7833e8f5570',
    'photo-1524995997946-a1c2e315a42f',
  ],
  'foreign_languages': [
    'photo-1434030216411-0b793f4b4173',
    'photo-1457369804613-52c61a468e7d',
    'photo-1503676260728-1c00da094a0b',
    'photo-1522202176988-66273c2fd55f',
  ],
  'yoga': [
    'photo-1544367567-0f2fcb009e0b',
    'photo-1545389336-cf090694435e',
    'photo-1599901860904-17e6ed7083a0',
    'photo-1552196563-55cd4e45efb3',
  ],
  'meditation': [
    'photo-1506126613408-eca07ce68773',
    'photo-1474418397713-7ede21d49118',
  ],
  'arts': [
    'photo-1460661419201-fd4cecdf8a8b',
    'photo-1513364776144-60967b0f800f',
    'photo-1579783902614-a3fb3927b6a5',
  ],
  'sports': [
    'photo-1531415074968-036ba1b575da',
    'photo-1461896836934-ffeaf3157c77',
    'photo-1574629810360-7efbbe195018',
    'photo-1517649763962-0c623066027b',
  ],
  'curriculum': [
    'photo-1434030216411-0b793f4b4173',
    'photo-1509062522246-3755977927d7',
    'photo-1427504494785-3a9ca7044f45',
  ],
  'ai_tools': [
    'photo-1515879218367-8466d910aaa4',
    'photo-1498050108023-c5249f4df085',
    'photo-1517694712202-14dd9538aa97',
  ],
  'trading': [
    'photo-1611974789855-9c2a0a7236a3',
    'photo-1590283603385-17ffb3a7f29f',
  ],
  'bhagavat_geeta': [
    'photo-1544947950-fa07a98d237f',
    'photo-1519682337058-a94d519337bc',
  ],
  'workshop': [
    'photo-1551836022-d5d88e9218df',
    'photo-1475721027785-f74eccf877e2',
  ],
  'adult': [
    'photo-1554224155-6726b3ff858f',
    'photo-1517248135467-4c7edcad34c4',
    'photo-1476703993599-0035a21b17a9',
  ],
};

const _specs = <_Spec>[
  // 25 online classes. First rows are today and yesterday.
  _Spec(format: 'online', categoryId: 'music', subcategory: 'Vocal — Hindustani', title: 'Hindustani vocals for beginners', educator: 'Meera Rao', price: 800, area: '', rating: 4.8, enrolled: 420, postedDaysAgo: 0, startsInDays: 0, blurb: 'Swaras, a simple raag, and voice care. Built for adult beginners joining from home.', live: true),
  _Spec(format: 'online', categoryId: 'yoga', subcategory: 'Vinyasa Yoga', title: 'Morning vinyasa flow', educator: 'Ananya Shetty', price: 650, area: '', rating: 4.9, enrolled: 388, postedDaysAgo: 0, startsInDays: 0, blurb: 'A 45-minute flow you can do on a mat before work. All levels welcome.', live: true),
  _Spec(format: 'online', categoryId: 'language', subcategory: 'Kannada', title: 'Spoken Kannada in eight weeks', educator: 'Divya Rao', price: 1200, area: '', rating: 4.7, enrolled: 254, postedDaysAgo: 0, startsInDays: 2, blurb: 'Everyday Kannada for people who just moved to Bangalore.'),
  _Spec(format: 'online', categoryId: 'ai_tools', subcategory: 'ChatGPT', title: 'ChatGPT for everyday work', educator: 'Aditi Jain', price: 999, area: '', rating: 4.6, enrolled: 310, postedDaysAgo: 0, startsInDays: 1, blurb: 'Write clearer prompts for mail, research, and small automations.'),
  _Spec(format: 'online', categoryId: 'music', subcategory: 'Vocal — Carnatic', title: 'Carnatic voice lab', educator: 'Lakshmi Iyer', price: 900, area: '', rating: 4.8, enrolled: 198, postedDaysAgo: 1, startsInDays: 3, blurb: 'Sarali, jantai, and one geetham. Small online batch.'),
  _Spec(format: 'online', categoryId: 'music', subcategory: 'Flute', title: 'Flute for adults', educator: 'Raghav Bhat', price: 750, area: '', rating: 4.5, enrolled: 142, postedDaysAgo: 1, startsInDays: 4, blurb: 'Breath, fingering, and two film tunes. No prior flute needed.'),
  _Spec(format: 'online', categoryId: 'foreign_languages', subcategory: 'French', title: 'French café A1', educator: 'Julien Pereira', price: 1500, area: '', rating: 4.7, enrolled: 276, postedDaysAgo: 1, startsInDays: 2, blurb: 'Order, introduce yourself, and survive a short conversation.'),
  _Spec(format: 'online', categoryId: 'meditation', subcategory: 'Breath meditation', title: 'Breath meditation at dusk', educator: 'Suresh Pai', price: 0, area: '', rating: 4.9, enrolled: 360, postedDaysAgo: 1, startsInDays: 1, blurb: 'Twenty quiet minutes. A free seat, camera optional.'),
  _Spec(format: 'online', categoryId: 'music', subcategory: 'Guitar', title: 'Guitar chords after work', educator: 'Arjun Menon', price: 700, area: '', rating: 4.6, enrolled: 231, postedDaysAgo: 3, startsInDays: 5, blurb: 'Open chords, a strum, and one song by the third class.'),
  _Spec(format: 'online', categoryId: 'music', subcategory: 'Keyboard', title: 'Keyboard harmony hour', educator: 'Neha Kapoor', price: 850, area: '', rating: 4.4, enrolled: 118, postedDaysAgo: 4, startsInDays: 6, blurb: 'Right-hand melody and simple left-hand patterns.'),
  _Spec(format: 'online', categoryId: 'language', subcategory: 'Hindi', title: 'Hindi conversation circle', educator: 'Amit Sharma', price: 600, area: '', rating: 4.5, enrolled: 167, postedDaysAgo: 5, startsInDays: 3, blurb: 'Speak, not just worksheets. Useful for work and family.'),
  _Spec(format: 'online', categoryId: 'language', subcategory: 'Tamil', title: 'Tamil for Bangaloreans', educator: 'Kavitha Nair', price: 700, area: '', rating: 4.6, enrolled: 96, postedDaysAgo: 6, startsInDays: 7, blurb: 'Greetings, food, and the phrases you actually hear.'),
  _Spec(format: 'online', categoryId: 'foreign_languages', subcategory: 'Spanish', title: 'Spanish for a short trip', educator: 'Sofia D\'Souza', price: 1100, area: '', rating: 4.7, enrolled: 154, postedDaysAgo: 2, startsInDays: 8, blurb: 'Airport, café, and directions. Light homework.'),
  _Spec(format: 'online', categoryId: 'foreign_languages', subcategory: 'Japanese', title: 'Japanese hiragana studio', educator: 'Aiko Fernandes', price: 1600, area: '', rating: 4.8, enrolled: 188, postedDaysAgo: 7, startsInDays: 4, blurb: 'Read hiragana with confidence and a few useful phrases.'),
  _Spec(format: 'online', categoryId: 'foreign_languages', subcategory: 'German', title: 'German A1 evenings', educator: 'Anika Schultz', price: 1400, area: '', rating: 4.5, enrolled: 121, postedDaysAgo: 8, startsInDays: 9, blurb: 'Cases without the panic. Built around everyday scenes.'),
  _Spec(format: 'online', categoryId: 'yoga', subcategory: 'Yoga therapy', title: 'Yoga for desk backs', educator: 'Priya Kulkarni', price: 550, area: '', rating: 4.8, enrolled: 298, postedDaysAgo: 9, startsInDays: 2, blurb: 'Hips, neck, and a short wind-down for laptop days.'),
  _Spec(format: 'online', categoryId: 'meditation', subcategory: 'Stress relief', title: 'Stress relief Sundays', educator: 'Meera Joshi', price: 400, area: '', rating: 4.7, enrolled: 205, postedDaysAgo: 10, startsInDays: 6, blurb: 'A guided sit plus one practice you can reuse at work.'),
  _Spec(format: 'online', categoryId: 'arts', subcategory: 'Painting', title: 'Watercolour Bangalore skies', educator: 'Ritu Malhotra', price: 900, area: '', rating: 4.6, enrolled: 133, postedDaysAgo: 3, startsInDays: 5, blurb: 'Washes, clouds, and one finished postcard-sized painting.'),
  _Spec(format: 'online', categoryId: 'arts', subcategory: 'Drawing', title: 'Sketching faces', educator: 'Omar Qureshi', price: 800, area: '', rating: 4.4, enrolled: 88, postedDaysAgo: 11, startsInDays: 7, blurb: 'Proportion, eyes, and a three-quarter portrait.'),
  _Spec(format: 'online', categoryId: 'sports', subcategory: 'Badminton', title: 'Badminton footwork, from home', educator: 'Karthik Reddy', price: 500, area: '', rating: 4.5, enrolled: 176, postedDaysAgo: 4, startsInDays: 3, blurb: 'Shadow drills and split-step timing. A little floor space is enough.'),
  _Spec(format: 'online', categoryId: 'curriculum', subcategory: 'Maths', title: 'CBSE maths, class 10', educator: 'Sneha Iyengar', price: 1500, area: '', rating: 4.9, enrolled: 341, postedDaysAgo: 1, startsInDays: 1, blurb: 'Triangles and circles, with worked examples and a weekly quiz.'),
  _Spec(format: 'online', categoryId: 'curriculum', subcategory: 'Olympiad', title: 'Science olympiad drills', educator: 'Vikram Rao', price: 1300, area: '', rating: 4.6, enrolled: 112, postedDaysAgo: 12, startsInDays: 8, blurb: 'Short timed sets and how to read a tricky question.'),
  _Spec(format: 'online', categoryId: 'ai_tools', subcategory: 'Prompting', title: 'Prompting studio', educator: 'Rohan Deshpande', price: 1100, area: '', rating: 4.7, enrolled: 241, postedDaysAgo: 2, startsInDays: 4, blurb: 'Turn a vague brief into a prompt you can reuse with a team.'),
  _Spec(format: 'online', categoryId: 'trading', subcategory: 'Options', title: 'Options basics, calmly', educator: 'Nikhil Shah', price: 1800, area: '', rating: 4.3, enrolled: 97, postedDaysAgo: 6, startsInDays: 10, blurb: 'Calls, puts, and risk in plain language. Not a tip service.'),
  _Spec(format: 'online', categoryId: 'bhagavat_geeta', subcategory: 'Chapter-wise study', title: 'Bhagavad Gita, chapter 2', educator: 'Anand Sharma', price: 0, area: '', rating: 4.9, enrolled: 228, postedDaysAgo: 13, startsInDays: 2, blurb: 'A slow reading of the chapter, with time for questions.'),

  // 25 physical classes across Bangalore localities.
  _Spec(format: 'physical', categoryId: 'music', subcategory: 'Tabla', title: 'Tabla hands-on', educator: 'Imran Khan', price: 1000, area: 'Indiranagar', rating: 4.8, enrolled: 86, postedDaysAgo: 0, startsInDays: 1, blurb: 'Basic bols on a shared tabla. A studio off 100 Feet Road.'),
  _Spec(format: 'physical', categoryId: 'language', subcategory: 'Kannada', title: 'Kannada script circle', educator: 'Shalini Gowda', price: 0, area: 'HSR Layout', rating: 4.7, enrolled: 74, postedDaysAgo: 0, startsInDays: 2, blurb: 'Read shop signs and write your name. Free Saturday hour.'),
  _Spec(format: 'physical', categoryId: 'yoga', subcategory: 'Hatha Yoga', title: 'Hatha yoga, Jayanagar', educator: 'Lakshmi Bhat', price: 700, area: 'Jayanagar', rating: 4.9, enrolled: 156, postedDaysAgo: 0, startsInDays: 0, blurb: 'A quiet shala near 4th Block. Mats provided.'),
  _Spec(format: 'physical', categoryId: 'music', subcategory: 'Dance', title: 'Evening dance fitness', educator: 'Niharika Rao', price: 800, area: 'Koramangala', rating: 4.6, enrolled: 132, postedDaysAgo: 1, startsInDays: 1, blurb: 'Bollywood and a little contemporary. No partner needed.'),
  _Spec(format: 'physical', categoryId: 'foreign_languages', subcategory: 'French', title: 'French conversation meetup', educator: 'Claire D\'Souza', price: 900, area: 'Indiranagar', rating: 4.5, enrolled: 61, postedDaysAgo: 1, startsInDays: 3, blurb: 'Speak for an hour over coffee. A1 and A2 learners.'),
  _Spec(format: 'physical', categoryId: 'yoga', subcategory: 'Yoga for beginners', title: 'Yoga for beginners', educator: 'Pooja Hegde', price: 600, area: 'HSR Layout', rating: 4.8, enrolled: 143, postedDaysAgo: 1, startsInDays: 2, blurb: 'Sun salutations explained slowly. First-timers welcome.'),
  _Spec(format: 'physical', categoryId: 'music', subcategory: 'Sitar', title: 'Sitar circle', educator: 'Devendra Joshi', price: 1500, area: 'Jayanagar', rating: 4.7, enrolled: 42, postedDaysAgo: 4, startsInDays: 5, blurb: 'Sitting, right-hand stroke, and a short alaap.'),
  _Spec(format: 'physical', categoryId: 'music', subcategory: 'Mridangam', title: 'Mridangam lab', educator: 'Hari Krishnan', price: 1200, area: 'Malleswaram', rating: 4.6, enrolled: 38, postedDaysAgo: 5, startsInDays: 6, blurb: 'Lessons for students who already know basic solkattu.'),
  _Spec(format: 'physical', categoryId: 'language', subcategory: 'Hindi', title: 'Hindi reading room', educator: 'Pankaj Mishra', price: 500, area: 'Whitefield', rating: 4.4, enrolled: 57, postedDaysAgo: 6, startsInDays: 4, blurb: 'Short stories read aloud. Helpful if you understand but freeze when speaking.'),
  _Spec(format: 'physical', categoryId: 'foreign_languages', subcategory: 'Korean', title: 'Korean hangul workshop', educator: 'Minseo Park', price: 1100, area: 'Bellandur', rating: 4.8, enrolled: 69, postedDaysAgo: 3, startsInDays: 6, blurb: 'Read hangul by the end of the session. One Sunday.'),
  _Spec(format: 'physical', categoryId: 'yoga', subcategory: 'Pranayama', title: 'Dawn pranayama', educator: 'Sridhar Rao', price: 450, area: 'Hebbal', rating: 4.7, enrolled: 81, postedDaysAgo: 8, startsInDays: 1, blurb: 'Breath work in a small park-side studio. 6.30am.'),
  _Spec(format: 'physical', categoryId: 'meditation', subcategory: 'Mindfulness meditation', title: 'Mindfulness, lunch hour', educator: 'Tara Krishnan', price: 300, area: 'Koramangala', rating: 4.6, enrolled: 64, postedDaysAgo: 7, startsInDays: 2, blurb: 'A 40-minute sit for people who work nearby.'),
  _Spec(format: 'physical', categoryId: 'meditation', subcategory: 'Guided meditation', title: 'Guided sit, JP Nagar', educator: 'Anil Kumar', price: 350, area: 'JP Nagar', rating: 4.5, enrolled: 48, postedDaysAgo: 9, startsInDays: 5, blurb: 'Cushions, a short talk, and silence.'),
  _Spec(format: 'physical', categoryId: 'arts', subcategory: 'Painting', title: 'Acrylic studio night', educator: 'Farah Khan', price: 1300, area: 'Indiranagar', rating: 4.7, enrolled: 77, postedDaysAgo: 2, startsInDays: 3, blurb: 'Paint one canvas. Materials included.'),
  _Spec(format: 'physical', categoryId: 'arts', subcategory: 'Photography', title: 'Street photography walk', educator: 'Nikhil Thomas', price: 900, area: 'Jayanagar', rating: 4.6, enrolled: 55, postedDaysAgo: 10, startsInDays: 6, blurb: 'A two-hour walk with feedback on five frames.'),
  _Spec(format: 'physical', categoryId: 'sports', subcategory: 'Badminton', title: 'Badminton club hour', educator: 'Sanjay Gowda', price: 400, area: 'HSR Layout', rating: 4.5, enrolled: 102, postedDaysAgo: 4, startsInDays: 1, blurb: 'Drills then games. Bring indoor shoes.'),
  _Spec(format: 'physical', categoryId: 'sports', subcategory: 'Cricket', title: 'Cricket nets, Whitefield', educator: 'Rahul Patil', price: 500, area: 'Whitefield', rating: 4.4, enrolled: 90, postedDaysAgo: 11, startsInDays: 2, blurb: 'Batting throwdowns for weekend players.'),
  _Spec(format: 'physical', categoryId: 'sports', subcategory: 'Football', title: 'Football first touch', educator: 'Joseph D\'Costa', price: 450, area: 'Koramangala', rating: 4.5, enrolled: 73, postedDaysAgo: 8, startsInDays: 4, blurb: 'Passing and a small-sided game. Turf shoes help.'),
  _Spec(format: 'physical', categoryId: 'curriculum', subcategory: 'Science', title: 'CBSE science doubt room', educator: 'Radhika Menon', price: 800, area: 'Jayanagar', rating: 4.8, enrolled: 66, postedDaysAgo: 5, startsInDays: 3, blurb: 'Class 9 and 10. Bring the question you are stuck on.'),
  _Spec(format: 'physical', categoryId: 'curriculum', subcategory: 'Maths', title: 'ICSE maths clinic', educator: 'George Varghese', price: 850, area: 'Malleswaram', rating: 4.7, enrolled: 59, postedDaysAgo: 12, startsInDays: 5, blurb: 'Algebra and graphs, eight students max.'),
  _Spec(format: 'physical', categoryId: 'workshop', subcategory: 'Skill-building workshop', title: 'Public speaking, one evening', educator: 'Ayesha Siddiqui', price: 700, area: 'Indiranagar', rating: 4.6, enrolled: 84, postedDaysAgo: 3, startsInDays: 4, blurb: 'A three-minute talk, filmed, then kind notes.'),
  _Spec(format: 'physical', categoryId: 'adult', subcategory: 'Financial literacy', title: 'Personal finance, plainly', educator: 'Varun Shetty', price: 999, area: 'Whitefield', rating: 4.5, enrolled: 71, postedDaysAgo: 6, startsInDays: 7, blurb: 'SIPs, emergency funds, and what to ignore.'),
  _Spec(format: 'physical', categoryId: 'adult', subcategory: 'Parenting', title: 'Parenting circle', educator: 'Leela Krishnan', price: 400, area: 'Banashankari', rating: 4.8, enrolled: 46, postedDaysAgo: 9, startsInDays: 6, blurb: 'A facilitated conversation, not a lecture.'),
  _Spec(format: 'physical', categoryId: 'bhagavat_geeta', subcategory: 'Bhakti Yoga', title: 'Gita study circle', educator: 'Ramesh Jois', price: 0, area: 'Malleswaram', rating: 4.9, enrolled: 63, postedDaysAgo: 14, startsInDays: 2, blurb: 'Read a few verses and sit with them. Free.'),
  _Spec(format: 'physical', categoryId: 'workshop', subcategory: 'Career workshop', title: 'Career stories workshop', educator: 'Megha Reddy', price: 750, area: 'Bellandur', rating: 4.4, enrolled: 52, postedDaysAgo: 7, startsInDays: 8, blurb: 'Rewrite how you talk about your work. Small room.'),

  // 10 competitions.
  _Spec(format: 'competition', categoryId: 'music', subcategory: 'Vocal — Hindustani', title: 'Open mic, Indiranagar', educator: 'Meera Rao', price: 200, area: 'Indiranagar', rating: 4.7, enrolled: 110, postedDaysAgo: 0, startsInDays: 6, blurb: 'Three minutes, any style. A friendly room and a small jury.'),
  _Spec(format: 'competition', categoryId: 'ai_tools', subcategory: 'Prompting', title: 'Prompt battle', educator: 'Rohan Deshpande', price: 300, area: '', rating: 4.6, enrolled: 148, postedDaysAgo: 0, startsInDays: 5, blurb: 'Same brief, twenty minutes, best prompt wins. Online.'),
  _Spec(format: 'competition', categoryId: 'sports', subcategory: 'Badminton', title: 'Sunday doubles cup', educator: 'Sanjay Gowda', price: 400, area: 'HSR Layout', rating: 4.5, enrolled: 64, postedDaysAgo: 1, startsInDays: 6, blurb: 'Recreational doubles. Bring a partner or we will pair you.'),
  _Spec(format: 'competition', categoryId: 'music', subcategory: 'Guitar', title: 'Guitar showdown', educator: 'Arjun Menon', price: 250, area: 'Koramangala', rating: 4.6, enrolled: 72, postedDaysAgo: 1, startsInDays: 9, blurb: 'One unplugged piece. Beginners and regulars in separate slots.'),
  _Spec(format: 'competition', categoryId: 'music', subcategory: 'Tabla', title: 'Tabla solo cup', educator: 'Imran Khan', price: 300, area: 'Jayanagar', rating: 4.8, enrolled: 41, postedDaysAgo: 4, startsInDays: 12, blurb: 'A short solo in teentaal. Under-18 and open categories.'),
  _Spec(format: 'competition', categoryId: 'foreign_languages', subcategory: 'French', title: 'French spelling bee', educator: 'Julien Pereira', price: 150, area: 'Koramangala', rating: 4.4, enrolled: 58, postedDaysAgo: 5, startsInDays: 10, blurb: 'A1 and A2 words, spoken then written.'),
  _Spec(format: 'competition', categoryId: 'arts', subcategory: 'Painting', title: 'Watercolour hour contest', educator: 'Ritu Malhotra', price: 350, area: 'Indiranagar', rating: 4.7, enrolled: 49, postedDaysAgo: 3, startsInDays: 8, blurb: 'One hour, one theme, paper provided.'),
  _Spec(format: 'competition', categoryId: 'curriculum', subcategory: 'Maths', title: 'CBSE maths sprint', educator: 'Sneha Iyengar', price: 200, area: 'Whitefield', rating: 4.6, enrolled: 93, postedDaysAgo: 6, startsInDays: 7, blurb: 'Twenty questions, class 10. Working shown, not just answers.'),
  _Spec(format: 'competition', categoryId: 'yoga', subcategory: 'Hatha Yoga', title: 'Asana challenge', educator: 'Ananya Shetty', price: 250, area: 'Jayanagar', rating: 4.8, enrolled: 67, postedDaysAgo: 8, startsInDays: 11, blurb: 'Hold, align, and a short routine. Judged kindly.'),
  _Spec(format: 'competition', categoryId: 'language', subcategory: 'Kannada', title: 'Kannada elocution', educator: 'Divya Rao', price: 100, area: 'Malleswaram', rating: 4.7, enrolled: 54, postedDaysAgo: 9, startsInDays: 13, blurb: 'Two minutes on a neighbourhood you love. School and open groups.'),

  // Free demo / trial classes starting within the next 10 days.
  _Spec(format: 'online', categoryId: 'music', subcategory: 'Vocal — Hindustani', title: 'Hindustani demo, one raag', educator: 'Meera Rao', price: 0, area: '', rating: 4.8, enrolled: 18, postedDaysAgo: 1, startsInDays: 0, blurb: 'A free 30-minute trial. Hear a raag and try the first swaras.', demo: true),
  _Spec(format: 'physical', categoryId: 'yoga', subcategory: 'Yoga for beginners', title: 'Yoga trial, Koramangala', educator: 'Ananya Shetty', price: 0, area: 'Koramangala', rating: 4.9, enrolled: 12, postedDaysAgo: 0, startsInDays: 1, blurb: 'One free class on the mat. Wear clothes you can move in.', demo: true),
  _Spec(format: 'online', categoryId: 'language', subcategory: 'Kannada', title: 'Kannada taster', educator: 'Divya Rao', price: 0, area: '', rating: 4.7, enrolled: 22, postedDaysAgo: 2, startsInDays: 2, blurb: 'Greet a neighbour. A free half hour for new Bangaloreans.', demo: true),
  _Spec(format: 'physical', categoryId: 'arts', subcategory: 'Painting', title: 'Watercolour trial hour', educator: 'Ritu Malhotra', price: 0, area: 'Indiranagar', rating: 4.6, enrolled: 9, postedDaysAgo: 1, startsInDays: 3, blurb: 'Paper and paint are on the table. Leave with one wash.', demo: true),
  _Spec(format: 'online', categoryId: 'foreign_languages', subcategory: 'French', title: 'French demo conversation', educator: 'Julien Pereira', price: 0, area: '', rating: 4.7, enrolled: 15, postedDaysAgo: 3, startsInDays: 4, blurb: 'Order a coffee in French. No homework, cameras welcome.', demo: true),
  _Spec(format: 'physical', categoryId: 'sports', subcategory: 'Badminton', title: 'Badminton trial, HSR', educator: 'Sanjay Gowda', price: 0, area: 'HSR Layout', rating: 4.5, enrolled: 11, postedDaysAgo: 2, startsInDays: 5, blurb: 'A free court hour. Rackets are here if you do not have one.', demo: true),
  _Spec(format: 'online', categoryId: 'meditation', subcategory: 'Breath meditation', title: 'Breath demo at dusk', educator: 'Suresh Pai', price: 0, area: '', rating: 4.9, enrolled: 27, postedDaysAgo: 4, startsInDays: 6, blurb: 'Twenty quiet minutes. Stay for the sit, leave when it ends.', demo: true),
  _Spec(format: 'physical', categoryId: 'music', subcategory: 'Dance', title: 'Dance trial, Jayanagar', educator: 'Niharika Rao', price: 0, area: 'Jayanagar', rating: 4.6, enrolled: 14, postedDaysAgo: 1, startsInDays: 7, blurb: 'One song, no partner. A free evening to see if the class fits.', demo: true),
  _Spec(format: 'online', categoryId: 'curriculum', subcategory: 'Maths', title: 'Maths doubt demo', educator: 'Sneha Iyengar', price: 0, area: '', rating: 4.8, enrolled: 19, postedDaysAgo: 5, startsInDays: 8, blurb: 'Bring one class 10 question. A free session to see the method.', demo: true),
  _Spec(format: 'physical', categoryId: 'workshop', subcategory: 'Skill-building workshop', title: 'Speaking trial, Whitefield', educator: 'Ayesha Siddiqui', price: 0, area: 'Whitefield', rating: 4.6, enrolled: 8, postedDaysAgo: 2, startsInDays: 9, blurb: 'A two-minute talk and kind notes. Free for first-timers.', demo: true),

  // Events, so the Events tile has a real count.
  _Spec(format: 'event', categoryId: 'music', subcategory: 'Vocal — Hindustani', title: 'Raag evening, Indiranagar', educator: 'Meera Rao', price: 300, area: 'Indiranagar', rating: 4.8, enrolled: 64, postedDaysAgo: 1, startsInDays: 4, blurb: 'An evening of short pieces. Seats are limited.'),
  _Spec(format: 'event', categoryId: 'yoga', subcategory: 'Hatha Yoga', title: 'Sunrise yoga, Cubbon', educator: 'Lakshmi Bhat', price: 0, area: 'Cubbon Park', rating: 4.9, enrolled: 88, postedDaysAgo: 0, startsInDays: 2, blurb: 'A free outdoor hour. Bring a mat if you have one.'),
  _Spec(format: 'event', categoryId: 'arts', subcategory: 'Photography', title: 'Photo walk, Jayanagar', educator: 'Nikhil Thomas', price: 200, area: 'Jayanagar', rating: 4.6, enrolled: 31, postedDaysAgo: 3, startsInDays: 6, blurb: 'Meet at the circle, walk, and look at five frames.'),
  _Spec(format: 'event', categoryId: 'workshop', subcategory: 'Career workshop', title: 'Open house for new learners', educator: 'Megha Reddy', price: 0, area: 'Koramangala', rating: 4.5, enrolled: 40, postedDaysAgo: 2, startsInDays: 8, blurb: 'Meet masters, see rooms, and ask what a first month looks like.'),
];
