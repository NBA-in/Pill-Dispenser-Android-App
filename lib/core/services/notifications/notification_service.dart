import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
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

    tz.initializeTimeZones();

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
     
    final bool? result = await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

    final bool? alarm = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    _isInitialized = true;
  }
  
  // Static function for background handling if needed
  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse notificationResponse) {
    // handle background actions if necessary, e.g. Snooze directly from background
    if (notificationResponse.actionId == snoozeActionId) {
        // We can't easily access instance here, but we could schedule a new one?
        // Ideally we handle this in the main isolate if the app opens, or we might need a separate background handler.
        // For simplicity, we just print here, and let the UI handle logic if the app opens.
        // If we want valid background snooze without opening UI, we need more complex setup (WorkManager etc).
        print("Snooze clicked in background");
    }
  }

// ... (in class)

  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
     await scheduleAlarmImpl(
       flutterLocalNotificationsPlugin, 
       id, 
       title, 
       body, 
       scheduledTime
     );
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
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
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> cancel(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
