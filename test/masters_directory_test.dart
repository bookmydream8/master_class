import 'package:flutter_test/flutter_test.dart';
import 'package:master_class_mc/masters_page.dart';

void main() {
  test('default masters cover different categories and prefer verified', () {
    final extra = PublicMaster(
      id: 'music_2',
      name: 'Lower',
      categoryId: 'music',
      skills: const ['Flute'],
      city: 'Bangalore',
      rating: 3,
    );
    final higher = PublicMaster(
      id: 'music_top',
      name: 'Higher',
      categoryId: 'music',
      skills: const ['Vocal'],
      city: 'Bangalore',
      rating: 4.2,
      verified: true,
    );
    final picked = pickDefaultMasters([higher, extra, ...seedMasters]);
    expect(picked.length, 10);
    expect(picked.map((master) => master.categoryId).toSet().length, greaterThan(6));
    expect(picked.firstWhere((master) => master.categoryId == 'music').verified, isTrue);
  });

  test('search matches name, skill, and city', () {
    final found = filterMasters(seedMasters, query: 'french', city: 'Bangalore');
    expect(found.single.name, 'Julien Pereira');
    expect(filterMasters(seedMasters, categoryId: 'yoga').single.categoryId, 'yoga');
  });
}
