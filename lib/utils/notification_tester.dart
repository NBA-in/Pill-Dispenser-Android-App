import 'package:flutter/material.dart';
import '../core/services/notifications/notification_service.dart';

class NotificationTester {
  static final NotificationService _notificationService = NotificationService();

  static Future<void> showTestNotification() async {
    try {
      debugPrint("NotificationTester: Triggering immediate test notification.");
      await _notificationService.showNotification(
        id: 9991,
        title: 'Immediate Test',
        body: 'This is an immediate local notification test.',
      );
    } catch (e, stackTrace) {
      debugPrint("NotificationTester Error: showTestNotification failed - $e\n$stackTrace");
    }
  }

  static Future<void> scheduleTestNotification() async {
    try {
      final scheduledTime = DateTime.now().add(const Duration(seconds: 10));
      debugPrint("NotificationTester: Scheduling test notification for $scheduledTime (in 10 seconds).");
      
      await _notificationService.scheduleAlarm(
        id: 9992,
        title: 'Scheduled Test',
        body: 'This notification was scheduled 10 seconds ago.',
        scheduledTime: scheduledTime,
      );
    } catch (e, stackTrace) {
      debugPrint("NotificationTester Error: scheduleTestNotification failed - $e\n$stackTrace");
    }
  }

  static Future<void> showPendingNotifications() async {
    try {
      debugPrint("NotificationTester: Querying pending notifications...");
      final pendingList = await _notificationService.getPendingNotifications();
      
      if (pendingList.isEmpty) {
        debugPrint("NotificationTester: No pending notifications found.");
        return;
      }

      debugPrint("NotificationTester: Found ${pendingList.length} pending notifications:");
      for (var request in pendingList) {
        debugPrint(" - ID: ${request.id}, Title: ${request.title}, Body: ${request.body}");
      }
    } catch (e, stackTrace) {
      debugPrint("NotificationTester Error: showPendingNotifications failed - $e\n$stackTrace");
    }
  }

  static Future<void> cancelAllNotifications() async {
    try {
      debugPrint("NotificationTester: Canceling all notifications.");
      await _notificationService.cancelAll();
      debugPrint("NotificationTester: All notifications canceled successfully.");
    } catch (e, stackTrace) {
      debugPrint("NotificationTester Error: cancelAllNotifications failed - $e\n$stackTrace");
    }
  }

  static Widget buildTestButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Notification Tester",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => showTestNotification(),
            icon: const Icon(Icons.notifications_active),
            label: const Text("Immediate Notification"),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              scheduleTestNotification();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scheduled for 10 seconds from now')),
              );
            },
            icon: const Icon(Icons.schedule),
            label: const Text("Schedule in 10s"),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              showPendingNotifications();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pending alarms printed to console')),
              );
            },
            icon: const Icon(Icons.list_alt),
            label: const Text("Print Pending to Console"),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              cancelAllNotifications();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications canceled')),
              );
            },
            icon: const Icon(Icons.cancel_presentation),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            label: const Text("Cancel All Alarms"),
          ),
        ],
      ),
    );
  }
}
