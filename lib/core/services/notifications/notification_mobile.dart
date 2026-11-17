import 'package:flutter/foundation.dart';
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
  try {
    // Get current time in UTC
    final tz.TZDateTime now = tz.TZDateTime.now(tz.getLocation('UTC'));
    
    // Convert scheduled time to UTC TZDateTime
    final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(
      scheduledTime.toUtc(),
      tz.getLocation('UTC'),
    );

    // If the scheduled time is in the past, don't schedule it
    if (scheduledTZDate.isBefore(now)) {
      debugPrint('⚠️ Skipping past notification: id=$id, scheduledTime=$scheduledTZDate, now=$now');
      return;
    }

    debugPrint('📅 Scheduling notification: id=$id, time=$scheduledTZDate (in ${scheduledTZDate.difference(now).inMinutes} minutes)');

    // Android notification configuration
    const fln.AndroidNotificationDetails androidPlatformChannelSpecifics =
        fln.AndroidNotificationDetails(
      'medicine_alarm_channel', // Must match channel created in notification_service.dart
      'Medicine Alarms',
      channelDescription: 'Notifications for medicine reminder alarms',
      importance: fln.Importance.max,
      priority: fln.Priority.high,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      autoCancel: false, // Don't auto-dismiss when tapped
      ongoing: false, // Not a persistent notification
      showWhen: true,
      actions: <fln.AndroidNotificationAction>[
        fln.AndroidNotificationAction(
          'snooze_action',
          'Snooze 5 Min',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        fln.AndroidNotificationAction(
          'taken_action',
          'Taken',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const fln.NotificationDetails platformChannelSpecifics =
        fln.NotificationDetails(android: androidPlatformChannelSpecifics);

    // Schedule the notification - REMOVED the uiLocalNotificationDateInterpretation parameter
    await plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTZDate,
      platformChannelSpecifics,
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: matchDateTimeComponents,
    );

    debugPrint('✅ Notification scheduled successfully: id=$id at $scheduledTZDate');
  } catch (e, stackTrace) {
    debugPrint('❌ Error scheduling notification: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
}