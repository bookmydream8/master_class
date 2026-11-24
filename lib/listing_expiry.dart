/// Online listings stay visible for at most 31 days from post or renew.
const onlineExpiryCap = Duration(days: 31);

/// End of the online listing window. A missing date becomes the full month.
/// A later date is pulled back so it never passes [anchor] + 31 days.
DateTime capOnlineExpiry({required DateTime anchor, DateTime? requested}) {
  final cap = anchor.add(onlineExpiryCap).subtract(const Duration(minutes: 1));
  if (requested == null) return cap;
  final end = DateTime(requested.year, requested.month, requested.day, 23, 59);
  if (!end.isAfter(anchor) || end.isAfter(cap)) return cap;
  return end;
}

String formatExpiryDate(DateTime value) =>
    '${value.day}/${value.month}/${value.year}';

DateTime? readTimestampDate(Object? value) {
  if (value == null) return null;
  try {
    final dynamic stamp = value;
    final date = stamp.toDate();
    if (date is DateTime) return date;
  } catch (_) {}
  return null;
}
