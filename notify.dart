import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'calc.dart';

class Notifier {
  static final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();
  static bool ready = false;

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _p.initialize(const InitializationSettings(android: android));
    ready = true;
  }

  static Future<void> askPermission() async {
    if (!ready) return;
    try {
      final a = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await a?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    if (!ready) return;
    try {
      await _p.cancelAll();
    } catch (_) {}
  }

  // Agle 7 din ki har namaz ke waqt ka reminder lagata hai.
  // App jab bhi khulti hai to dobara lag jata hai.
  static Future<void> schedule(double lat, double lng) async {
    if (!ready) return;
    await cancelAll();
    final now = DateTime.now();
    int id = 1;
    for (int day = 0; day < 7; day++) {
      final date = now.add(Duration(days: day));
      final list = prayerTimesFor(lat, lng, date);
      for (final e in list) {
        if (!e.isPrayer) continue;
        final when = e.time.toLocal();
        if (when.isAfter(now)) {
          await _zs(
            id,
            '${e.name} ka waqt ho gaya',
            '${e.name} parhne ke saath ek qaza namaz bhi parh lein.',
            when,
          );
        }
        id++;
      }
    }
  }

  static Future<void> _zs(int id, String title, String body, DateTime when) async {
    final t = tz.TZDateTime.from(when, tz.UTC);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'qaza_reminder',
        'Qaza yaad dehani',
        channelDescription: 'Namaz ke waqt qaza ki yaad dehani',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    try {
      await _p.zonedSchedule(
        id,
        title,
        body,
        t,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      try {
        await _p.zonedSchedule(
          id,
          title,
          body,
          t,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    }
  }
}
