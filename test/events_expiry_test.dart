import 'package:flutter_test/flutter_test.dart';
import 'package:master_class_mc/events_page.dart';
import 'package:master_class_mc/listing_expiry.dart';
import 'package:master_class_mc/seed/bangalore_demo.dart';

void main() {
  test('online expiry defaults to a month and never passes 31 days', () {
    final anchor = DateTime(2026, 11, 1, 9);
    final open = capOnlineExpiry(anchor: anchor);
    expect(open.isAfter(anchor), isTrue);
    expect(open.isBefore(anchor.add(onlineExpiryCap)), isTrue);

    final tooFar = capOnlineExpiry(
      anchor: anchor,
      requested: DateTime(2027, 2, 1),
    );
    expect(tooFar.isBefore(anchor.add(onlineExpiryCap)), isTrue);

    final sooner = capOnlineExpiry(
      anchor: anchor,
      requested: DateTime(2026, 11, 10),
    );
    expect(sooner.day, 10);
    expect(sooner.month, 11);
  });

  test('seed events fill upcoming and recently completed', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final events = eventCatalogue(bangaloreDemoListings());
    final upcoming = upcomingEvents(events, now: now);
    final completed = recentlyCompletedEvents(events, now: now);
    expect(upcoming, isNotEmpty);
    expect(completed, isNotEmpty);
    expect(completed.length, lessThanOrEqualTo(5));
    for (final item in upcoming) {
      final start = eventStart(item)!;
      expect(start.isBefore(today), isFalse);
      expect(start.isAfter(today.add(const Duration(days: 10))), isFalse);
    }
    for (final item in completed) {
      expect(eventStart(item)!.isBefore(today), isTrue);
    }
    if (completed.length > 1) {
      expect(
        eventStart(completed.first)!.isAfter(eventStart(completed.last)!),
        isTrue,
      );
    }
  });
}
