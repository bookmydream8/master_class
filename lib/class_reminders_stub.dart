/// Web and tests that do not schedule native notifications.
Future<void> initClassReminders() async {}

Future<void> scheduleClassReminders(Map<String, dynamic> listing) async {}

Future<void> cancelClassReminders(String listingId) async {}

Future<void> syncCityTopics({String? city, String? eventCity}) async {}

Future<void> scheduleListingExpiryReminder({
  required String listingId,
  required String title,
  required DateTime expiresAt,
}) async {}
