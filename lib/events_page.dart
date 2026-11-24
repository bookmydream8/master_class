import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'home_illustrations.dart';
import 'madhura_board.dart' as board;
import 'madhura_detail.dart';
import 'seed/bangalore_demo.dart';

DateTime? eventStart(Map<String, dynamic> data) {
  final raw = (data['start_date'] ?? '').toString();
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

bool isEventListing(Map<String, dynamic> data) =>
    board.listingFormat(data) == 'event';

/// Events from the live catalogue plus Bangalore seed events, one row per id.
List<Map<String, dynamic>> eventCatalogue(List<Map<String, dynamic>> live) {
  final seen = <String>{};
  final events = <Map<String, dynamic>>[];
  for (final item in [...live, ...bangaloreDemoListings()]) {
    if (!isEventListing(item)) continue;
    final id = (item['id'] ?? item['title'] ?? '').toString();
    if (id.isEmpty || !seen.add(id)) continue;
    events.add(item);
  }
  return events;
}

List<Map<String, dynamic>> upcomingEvents(
  List<Map<String, dynamic>> events, {
  DateTime? now,
}) {
  final today = _day(now ?? DateTime.now());
  final last = today.add(const Duration(days: 10));
  final upcoming = events.where((item) {
    final start = eventStart(item);
    if (start == null) return false;
    return !start.isBefore(today) && !start.isAfter(last);
  }).toList();
  upcoming.sort((a, b) => eventStart(a)!.compareTo(eventStart(b)!));
  return upcoming;
}

List<Map<String, dynamic>> recentlyCompletedEvents(
  List<Map<String, dynamic>> events, {
  DateTime? now,
  int limit = 5,
}) {
  final today = _day(now ?? DateTime.now());
  final past = events.where((item) {
    final start = eventStart(item);
    return start != null && start.isBefore(today);
  }).toList();
  past.sort((a, b) => eventStart(b)!.compareTo(eventStart(a)!));
  if (past.length <= limit) return past;
  return past.sublist(0, limit);
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

class EventsPage extends StatelessWidget {
  const EventsPage({super.key, required this.listings});

  final List<Map<String, dynamic>> listings;

  @override
  Widget build(BuildContext context) {
    final events = eventCatalogue(listings);
    final upcoming = upcomingEvents(events);
    final completed = recentlyCompletedEvents(events);
    final text = Theme.of(context).textTheme;
    final colors = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            children: [
              const HomeIllustration('upcoming_events', size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'What is on in the next 10 days, and what just finished.',
                  style: text.bodyMedium?.copyWith(color: colors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Upcoming', style: text.titleLarge),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            Text(
              'No events in the next 10 days.',
              style: text.bodyMedium?.copyWith(color: colors.muted),
            )
          else
            for (final item in upcoming)
              _EventRow(data: item, whenLabel: _whenLabel(item)),
          const SizedBox(height: 18),
          Text('Recently completed', style: text.titleLarge),
          const SizedBox(height: 8),
          if (completed.isEmpty)
            Text(
              'No completed events yet.',
              style: text.bodyMedium?.copyWith(color: colors.muted),
            )
          else
            for (final item in completed)
              _EventRow(data: item, whenLabel: 'Completed'),
        ],
      ),
    );
  }

  String _whenLabel(Map<String, dynamic> data) {
    final start = eventStart(data);
    if (start == null) return '';
    return '${start.day}/${start.month}/${start.year}';
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.data, required this.whenLabel});

  final Map<String, dynamic> data;
  final String whenLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final title = (data['title'] ?? 'Event').toString();
    final place = [
      (data['area'] ?? '').toString(),
      (data['city'] ?? 'Bangalore').toString(),
    ].where((value) => value.trim().isNotEmpty).join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showMasterClassDetails(context, data),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const HomeIllustration('event', size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        '$whenLabel · $place',
                        style: text.bodySmall?.copyWith(color: colors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
