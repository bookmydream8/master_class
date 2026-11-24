import 'package:flutter_test/flutter_test.dart';
import 'package:master_class_mc/spark_logic.dart';

void main() {
  test('discounts never exceed the fee', () {
    expect(discountAmount(amount: 800, kind: 'percent', value: 10), 80);
    expect(discountAmount(amount: 800, kind: 'flat', value: 1000), 800);
    expect(priceAfterDiscount(amount: 800, kind: 'percent', value: 25), 600);
  });

  test('share links and calendar text stay plain', () {
    expect(classShareLink('class1'), 'https://masterclass.app/class/class1');
    expect(masterShareLink('uid'), 'https://masterclass.app/master/uid');
    final ics = buildIcs(
      title: 'Tabla, evening',
      start: DateTime.utc(2026, 11, 24, 12),
      end: DateTime.utc(2026, 11, 24, 13),
      location: 'Jayanagar',
    );
    expect(ics, contains('BEGIN:VCALENDAR'));
    expect(ics, contains('SUMMARY:Tabla\\, evening'));
  });

  test('next up skips sessions that already started', () {
    final now = DateTime(2026, 11, 24, 10);
    final next = nextUp([
      ScheduleItem(title: 'Past', start: DateTime(2026, 11, 23, 18), kind: 'class'),
      ScheduleItem(title: 'Soon', start: DateTime(2026, 11, 24, 18), kind: 'event'),
      ScheduleItem(title: 'Later', start: DateTime(2026, 11, 25, 9), kind: 'demo'),
    ], now);
    expect(next?.title, 'Soon');
    expect(itemsOnDay([
      ScheduleItem(title: 'Soon', start: DateTime(2026, 11, 24, 18), kind: 'event'),
      ScheduleItem(title: 'Later', start: DateTime(2026, 11, 25, 9), kind: 'demo'),
    ], DateTime(2026, 11, 24)).length, 1);
  });

  test('a coupon past its limit or date is closed', () {
    final now = DateTime(2026, 11, 24);
    expect(
      couponUsable(used: 5, limit: 5, starts: null, ends: null, now: now),
      isFalse,
    );
    expect(
      couponUsable(
        used: 0,
        limit: 5,
        starts: DateTime(2026, 11, 1),
        ends: DateTime(2026, 11, 30),
        now: now,
      ),
      isTrue,
    );
  });
}
