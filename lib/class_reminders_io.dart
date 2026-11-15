import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'firestore_database.dart';
import 'notification_inbox.dart';
import 'reminder_times.dart';

final _plugin = FlutterLocalNotificationsPlugin();
var _ready = false;

Future<void> initClassReminders() async {
  if (kIsWeb || _ready) return;
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (_) {
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  }
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const apple = DarwinInitializationSettings();
  await _plugin.initialize(
    settings: const InitializationSettings(android: android, iOS: apple),
  );
  await _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  await _plugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);
  _ready = true;
  await _saveFcmToken();
}

Future<void> _saveFcmToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.isAnonymous) return;
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    if (token == null) return;
    await firestore.collection('profiles').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
    messaging.onTokenRefresh.listen((next) {
      firestore.collection('profiles').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([next]),
      }, SetOptions(merge: true));
    });
  } catch (error) {
    debugPrint('FCM token was not saved: $error');
  }
}

DateTime? _classStart(Map<String, dynamic> listing) {
  final date = DateTime.tryParse((listing['start_date'] ?? '').toString());
  if (date == null) return null;
  final clock = (listing['class_time'] ?? '18:00').toString();
  final parts = clock.split(':');
  final hour = parts.isEmpty ? 18 : int.tryParse(parts.first) ?? 18;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return DateTime(date.year, date.month, date.day, hour, minute);
}

int _idFor(String listingId, String kind) =>
    (listingId.hashCode ^ kind.hashCode) & 0x7fffffff;

Future<void> scheduleClassReminders(Map<String, dynamic> listing) async {
  if (!_ready) await initClassReminders();
  if (!_ready) return;
  final start = _classStart(listing);
  final title = (listing['title'] ?? 'Your class').toString();
  final listingId = (listing['id'] ?? '').toString();
  if (start == null || listingId.isEmpty) return;
  final plan = {
    'day': start.subtract(classReminderLeadTime),
    'soon': start.subtract(classReminderSoonBefore),
  };
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'class_reminders',
      'Class reminders',
      channelDescription: 'A day before class, and again shortly before it starts.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );
  for (final entry in plan.entries) {
    final when = entry.value;
    if (!when.isAfter(DateTime.now())) continue;
    final body = entry.key == 'day'
        ? '$title starts tomorrow.'
        : '$title starts in about an hour.';
    await _plugin.zonedSchedule(
      id: _idFor(listingId, entry.key),
      title: 'Class reminder',
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: listingId,
    );
    await postInboxNote(title: 'Class reminder', body: body, kind: 'class_reminder');
  }
}

Future<void> cancelClassReminders(String listingId) async {
  if (!_ready) return;
  await _plugin.cancel(id: _idFor(listingId, 'day'));
  await _plugin.cancel(id: _idFor(listingId, 'soon'));
}
