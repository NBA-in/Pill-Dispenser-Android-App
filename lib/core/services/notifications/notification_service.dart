import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'notification_web.dart' if (dart.library.io) 'notification_mobile.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Define action ID for Snooze
  static const String snoozeActionId = 'snooze_action';

  Future<void> initialize({
    void Function(NotificationResponse)? onDidReceiveNotificationResponse,
  }) async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      debugPrint('NotificationService: Timezones initialized to Asia/Kolkata.');
    } catch (e) {
      debugPrint('NotificationService Error: Failed to initialize timezones: $e');
    }

    try {
      // Android Initialization
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS Initialization (optional, basic)
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      await _createNotificationChannel();

      final bool? result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      debugPrint('NotificationService: Notification permission result: $result');

      final bool? alarm = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();

      debugPrint('NotificationService: Exact alarm permission result: $alarm');

      _isInitialized = true;
      debugPrint('NotificationService: Successfully initialized.');
    } catch (e) {
      debugPrint('NotificationService Error: Failed during initialization: $e');
    }
  }

  Future<void> _createNotificationChannel() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'medicine_alarm_channel', // id
        'Medicine Alarms', // name
        description: 'Channel for scheduled medicine alarms',
        importance: Importance.max,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('NotificationService: Notification channel created successfully.');
    } catch (e) {
      debugPrint('NotificationService Error: Failed to create notification channel: $e');
    }
  }

  // Static function for background handling if needed
  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse notificationResponse) {
    try {
      // handle background actions if necessary, e.g. Snooze directly from background
      if (notificationResponse.actionId == snoozeActionId) {
        debugPrint("NotificationService: Snooze clicked in background");
      }
    } catch (e) {
      debugPrint("NotificationService Error: Failed in background tap: $e");
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'medicine_alarm_channel',
        'Medicine Alarms',
        channelDescription: 'Channel for scheduled medicine alarms',
        importance: Importance.max,
        priority: Priority.max,
      );
      
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
      );
      debugPrint("NotificationService: Shown immediate notification (id: $id, title: $title).");
    } catch (e) {
      debugPrint("NotificationService Error: Failed to show notification: $e");
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      final pendingList = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      debugPrint("NotificationService: Retrieved ${pendingList.length} pending notifications.");
      return pendingList;
    } catch (e) {
      debugPrint("NotificationService Error: Failed to retrieve pending notifications: $e");
      return [];
    }
  }

  Future<List<ActiveNotification>> getActiveNotifications() async {
    try {
      final activeList = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.getActiveNotifications() ?? [];
      debugPrint("NotificationService: Retrieved ${activeList.length} active notifications.");
      return activeList;
    } catch (e) {
      debugPrint("NotificationService Error: Failed to retrieve active notifications: $e");
      return [];
    }
  }

  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      await scheduleAlarmImpl(
        flutterLocalNotificationsPlugin,
        id,
        title,
        body,
        scheduledTime,
      );
      debugPrint("NotificationService: Scheduled alarm (id: $id, time: $scheduledTime).");
    } catch (e) {
      debugPrint("NotificationService Error: Failed to schedule alarm: $e");
    }
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      final now = DateTime.now();
      final scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

      await scheduleAlarmImpl(
        flutterLocalNotificationsPlugin,
        id,
        title,
        body,
        scheduledTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint("NotificationService: Scheduled daily alarm (id: $id, time: $scheduledTime).");
    } catch (e) {
      debugPrint("NotificationService Error: Failed to schedule daily alarm: $e");
    }
  }

  Future<void> cancelAll() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      debugPrint("NotificationService: Canceled all notifications.");
    } catch (e) {
      debugPrint("NotificationService Error: Failed to cancel all notifications: $e");
    }
  }

  Future<void> cancel(int id) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
      debugPrint("NotificationService: Canceled notification (id: $id).");
    } catch (e) {
      debugPrint("NotificationService Error: Failed to cancel notification (id: $id): $e");
    }
  }
}
