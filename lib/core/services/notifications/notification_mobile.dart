import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:timezone/timezone.dart' as tz;

Future<void> scheduleAlarmImpl(
  fln.FlutterLocalNotificationsPlugin plugin,
  int id,
  String title,
  String body,
  DateTime scheduledTime, {
  fln.DateTimeComponents? matchDateTimeComponents,
}) async {
    // Convert to TZDateTime
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(scheduledTime, tz.local);

      if (scheduledTZDate.isBefore(now)) {
        scheduledTZDate = scheduledTZDate.add(const Duration(days: 1));
      }

    const fln.AndroidNotificationDetails androidPlatformChannelSpecifics =
        fln.AndroidNotificationDetails(
      'medicine_alarm_channel', 
      'Medicine Alarms',
      channelDescription: 'Channel for medicine reminders',
      importance: fln.Importance.max,
      priority: fln.Priority.high,
      fullScreenIntent: true, 
      playSound: true,
      actions: <fln.AndroidNotificationAction>[
        fln.AndroidNotificationAction(
          'snooze_action',
          'Snooze 5 Min',
          showsUserInterface: true, 
          cancelNotification: true,
        ),
      ],
    );

    const fln.NotificationDetails platformChannelSpecifics =
        fln.NotificationDetails(android: androidPlatformChannelSpecifics);

    await plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTZDate,
      platformChannelSpecifics,
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
      /* uiLocalNotificationDateInterpretation:
          fln.UILocalNotificationDateInterpretation.absoluteTime, */
      matchDateTimeComponents: matchDateTimeComponents,
    );
     // debugPrint("Scheduled notification $id at $scheduledTZDate");
}
