import 'package:flutter_test/flutter_test.dart';
import 'package:master_class_mc/category_style.dart';
import 'package:master_class_mc/city_topics.dart';

void main() {
  test('city topics are stable slugs', () {
    expect(cityTopicName('Bangalore'), 'city_bangalore');
    expect(cityTopicName('  New Delhi '), 'city_new_delhi');
    expect(cityTopicName(''), isNull);
    expect(cityTopicName(null), isNull);
  });

  test('learning card tints stay light enough to read', () {
    for (final style in [categoryStyleForId(null), ...categoryStyles.values]) {
      expect(style.tint.computeLuminance(), greaterThan(0.70));
      expect(style.ink.computeLuminance(), lessThan(0.25));
    }
  });
}
