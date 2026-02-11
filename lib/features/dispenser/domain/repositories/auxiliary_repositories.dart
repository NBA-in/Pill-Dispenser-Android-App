
// EVENTS
abstract class EventsRepository {
  Future<void> logEvent(String dispenserId, String type, String details, {String? component});
  Future<List<Map<String, dynamic>>> getEvents(String dispenserId, {int limit = 50});
}

// NOTIFICATIONS
abstract class NotificationRepository {
  Stream<List<Map<String, dynamic>>> streamNotifications(String userId, {int limit = 20});
  Future<void> markAsRead(String notificationId);
}

// ALERTS
abstract class AlertRepository {
  Stream<List<Map<String, dynamic>>> streamActiveAlerts(String dispenserId);
  Future<void> resolveAlert(String alertId, String resolvedByUserId);
}
