/// Share links, discounts, calendar export, and schedule ordering.
/// These stay on the device. Push is optional later in Cloud Functions.
const masterClassLinkHost = 'https://masterclass.app';

String classShareLink(String listingId) =>
    '$masterClassLinkHost/class/$listingId';

String masterShareLink(String uid) => '$masterClassLinkHost/master/$uid';

int discountAmount({
  required int amount,
  required String kind,
  required int value,
}) {
  if (amount <= 0 || value <= 0) return 0;
  if (kind == 'percent') {
    final cut = (amount * value / 100).round();
    return cut > amount ? amount : cut;
  }
  return value > amount ? amount : value;
}

int priceAfterDiscount({
  required int amount,
  required String kind,
  required int value,
}) => amount - discountAmount(amount: amount, kind: kind, value: value);

bool couponUsable({
  required int used,
  required int limit,
  required DateTime? starts,
  required DateTime? ends,
  required DateTime now,
}) {
  if (limit > 0 && used >= limit) return false;
  if (starts != null && now.isBefore(starts)) return false;
  if (ends != null && now.isAfter(ends)) return false;
  return true;
}

String icsEscape(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('\n', '\\n')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;');

String _icsStamp(DateTime value) {
  final utc = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

String buildIcs({
  required String title,
  required DateTime start,
  required DateTime end,
  String description = '',
  String location = '',
}) {
  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Master Class//EN',
    'BEGIN:VEVENT',
    'UID:${start.millisecondsSinceEpoch}@masterclass.app',
    'DTSTAMP:${_icsStamp(DateTime.now())}',
    'DTSTART:${_icsStamp(start)}',
    'DTEND:${_icsStamp(end)}',
    'SUMMARY:${icsEscape(title)}',
    if (description.isNotEmpty) 'DESCRIPTION:${icsEscape(description)}',
    if (location.isNotEmpty) 'LOCATION:${icsEscape(location)}',
    'END:VEVENT',
    'END:VCALENDAR',
    '',
  ].join('\r\n');
}

class ScheduleItem {
  const ScheduleItem({
    required this.title,
    required this.start,
    required this.kind,
    this.place = '',
    this.listingId = '',
  });

  final String title;
  final DateTime start;
  final String kind;
  final String place;
  final String listingId;
}

List<ScheduleItem> sortSchedule(List<ScheduleItem> items) {
  final copy = [...items]..sort((a, b) => a.start.compareTo(b.start));
  return copy;
}

ScheduleItem? nextUp(List<ScheduleItem> items, DateTime now) {
  final upcoming = sortSchedule(
    items.where((item) => !item.start.isBefore(now)).toList(),
  );
  if (upcoming.isEmpty) return null;
  return upcoming.first;
}

List<ScheduleItem> itemsOnDay(List<ScheduleItem> items, DateTime day) {
  final start = DateTime(day.year, day.month, day.day);
  final end = start.add(const Duration(days: 1));
  return sortSchedule(
    items
        .where((item) => !item.start.isBefore(start) && item.start.isBefore(end))
        .toList(),
  );
}

DateTime? listingStart(Map<String, dynamic> data) {
  final raw = (data['start_date'] ?? '').toString();
  final date = DateTime.tryParse(raw);
  if (date == null) return null;
  final clock = (data['start_time'] ?? data['class_time'] ?? '18:00').toString();
  final parts = clock.split(':');
  final hour = parts.isEmpty ? 18 : int.tryParse(parts.first) ?? 18;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return DateTime(date.year, date.month, date.day, hour, minute);
}
