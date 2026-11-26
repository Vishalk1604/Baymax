import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
// latest_all, not latest: Android still reports legacy names such as
// "Asia/Calcutta", which only the full database knows.
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'medication_utils.dart';
import 'settings_service.dart';

/// Medication and appointment reminders.
///
/// Reminders are never edited one by one: [sync] cancels everything and
/// rebuilds the schedule from Firestore, so any change (new medicine, edited
/// times, a stopped course, a booked or cancelled visit, the Settings toggle)
/// always leaves exactly the right reminders behind.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Course reminders are scheduled this many days ahead; each sync (app
  /// start, any change) tops them up.
  static const int _daysAhead = 30;

  /// How long before a visit its reminder fires.
  static const Duration appointmentLead = Duration(hours: 2);

  static const _medicationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'medication_channel',
      'Medication reminders',
      channelDescription: 'Reminders to take your medicines',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
  );

  static const _appointmentDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'appointment_channel',
      'Appointment reminders',
      channelDescription: 'Reminders before a booked clinic visit',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  Future<void> _chain = Future.value();
  bool _ready = false;

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      // Unknown zone name: use the phone's current offset so reminders still
      // fire at the right local time (only daylight-saving changes are missed).
      final offset = DateTime.now().timeZoneOffset;
      tz.setLocalLocation(tz.Location('Local', [tz.minTime], [0], [
        tz.TimeZone(offset.inMilliseconds, isDst: false, abbreviation: 'LOCAL'),
      ]));
      debugPrint('Unknown time zone ($e); reminders use a fixed offset of ${offset.inMinutes} min');
    }
    const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _plugin.initialize(settings);
    _ready = true;
  }

  /// Asks for notification (Android 13+) and exact-alarm (Android 12+)
  /// permission. Call it where reminders are explained, not at launch.
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission() ?? true;
    await android.requestExactAlarmsPermission();
    return granted;
  }

  Future<bool> notificationsAllowed() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Rebuilds every reminder for the signed-in user.
  Future<void> sync() {
    _chain = _chain.then((_) => _sync()).catchError((Object e) {
      debugPrint('Reminder sync failed: $e');
    });
    return _chain;
  }

  Future<void> _sync() async {
    if (!_ready) return;
    await _plugin.cancelAll();
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    if (user == null || !(prefs.getBool(SettingsService.notificationsKey) ?? true)) return;

    final root = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final now = DateTime.now();
    var nextId = 1;

    // Medicines
    final meds = await root.collection('Medication').get();
    for (final med in meds.docs) {
      final data = med.data();
      if (!isMedicationActive(data, now: now)) continue;
      final name = '${data['Name'] ?? 'your medicine'}';
      final compartment = (data['Compartment'] as num?)?.toInt() ?? 0;
      final body = compartment >= 1 && compartment <= 6
          ? 'Time to take $name — compartment $compartment of your Baymax.'
          : 'Time to take $name.';
      final duration = (data['Duration'] as num?)?.toInt() ?? 0;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? now;
      final DateTime? endsAt = duration > 0 ? createdAt.add(Duration(days: duration)) : null;

      final reminders = await med.reference.collection('Reminder').get();
      for (final r in reminders.docs) {
        final t = (r.data()['time'] as Timestamp?)?.toDate();
        if (t == null) continue;
        var when = _nextOccurrence(t.hour, t.minute, now);
        if (endsAt == null) {
          await _schedule(nextId++, 'Medicine reminder', body, when, _medicationDetails, repeatDaily: true);
        } else {
          // One per remaining day, so reminders stop when the course does.
          for (var day = 0; day < _daysAhead && when.isBefore(endsAt); day++) {
            await _schedule(nextId++, 'Medicine reminder', body, when, _medicationDetails);
            when = DateTime(when.year, when.month, when.day + 1, when.hour, when.minute);
          }
        }
      }
    }

    // Appointments
    final visits = await root.collection('Appointments').where('Time', isGreaterThan: Timestamp.fromDate(now)).get();
    for (final v in visits.docs) {
      final time = (v.data()['Time'] as Timestamp?)?.toDate();
      if (time == null) continue;
      final at = time.subtract(appointmentLead);
      if (!at.isAfter(now)) continue;
      final clinic = '${v.data()['clinicName'] ?? 'your clinic'}';
      final hh = time.hour % 12 == 0 ? 12 : time.hour % 12;
      final mm = time.minute.toString().padLeft(2, '0');
      final ampm = time.hour < 12 ? 'AM' : 'PM';
      await _schedule(nextId++, 'Visit at $hh:$mm $ampm', 'Your appointment at $clinic is in 2 hours.', at, _appointmentDetails);
    }
  }

  static DateTime _nextOccurrence(int hour, int minute, DateTime now) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isAfter(now) ? today : DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  Future<void> _schedule(
    int id,
    String title,
    String body,
    DateTime when,
    NotificationDetails details, {
    bool repeatDaily = false,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);
    final repeat = repeatDaily ? DateTimeComponents.time : null;
    try {
      await _plugin.zonedSchedule(id, title, body, scheduled, details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: repeat);
    } catch (_) {
      // Exact alarms not permitted on this device: fall back to inexact.
      await _plugin.zonedSchedule(id, title, body, scheduled, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: repeat);
    }
  }
}
