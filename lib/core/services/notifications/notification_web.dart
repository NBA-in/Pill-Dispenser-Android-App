import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> scheduleAlarmImpl(
  FlutterLocalNotificationsPlugin plugin,
  int id,
  String title,
  String body,
  DateTime scheduledTime, {
  dynamic matchDateTimeComponents, // Use dynamic or import types to avoid dep issues if strict
}) async {
  print("Alarm scheduling is not supported on Web.");
}
