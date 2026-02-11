import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notifications/notification_service.dart';
import '../../data/models/dispenser_model.dart';
import '../providers/dispenser_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

// This provider should be watched in main.dart or a top-level widget
final notificationSyncLogicProvider = Provider<void>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null || user.linkedDispensers.isEmpty) return;

  final dispenserId = user.linkedDispensers.first; // Assume first for now
  final dispenserAsync = ref.watch(dispenserProvider(dispenserId));

  dispenserAsync.whenData((dispenser) {
    if (dispenser != null) {
      _syncSchedule(dispenser);
    }
  });
});

final _notificationService = NotificationService();

Future<void> _syncSchedule(DispenserModel dispenser) async {
  // 1. Cancel all existing alarms to avoid stale or duplicate schedules
  await _notificationService.cancelAll();

  final schedule = dispenser.schedule;
  final currentDay = dispenser.currentState.operational.currentDay; // 1-indexed

  // Iterate from current day to end of cycle (Day 5)
  // We align 'currentDay' with 'Today' (now).
  final now = DateTime.now();

  for (int i = currentDay - 1; i < schedule.days.length; i++) {
     final int dayNum = i + 1; // 1-based day number
     final daySchedule = schedule.days[i];
     final int daysFromNow = i - (currentDay - 1);
     final dateBase = now.add(Duration(days: daysFromNow));

     // Helper to schedule a specific dose
     Future<void> scheduleDose(int idBase, String title, String body, DoseTimeModel dose) async {
        if (!dose.enabled) return;

        final scheduledTime = DateTime(
          dateBase.year, 
          dateBase.month, 
          dateBase.day, 
          dose.hour, 
          dose.minute
        );

        // If it's today and time passed, don't schedule or it triggers immediately depending on plugin logic
        if (scheduledTime.isBefore(now)) return;

        await _notificationService.scheduleAlarm(
          id: idBase + dayNum, // e.g., 100 + 1 => 101 for Morning Day 1
          title: title,
          body: body,
          scheduledTime: scheduledTime,
        );
     }

     // IDs: 
     // Morning: 100 + Day (101..105)
     // Lunch:   200 + Day (201..205)
     // Night:   300 + Day (301..305)
     
     await scheduleDose(100, "Morning Medicine", "It's time for your Day $dayNum morning dose.", daySchedule.morning);
     await scheduleDose(200, "Lunch Medicine", "It's time for your Day $dayNum lunch dose.", daySchedule.lunch);
     await scheduleDose(300, "Night Medicine", "It's time for your Day $dayNum night dose.", daySchedule.night);
  }
}
