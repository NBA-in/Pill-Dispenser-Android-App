import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notifications/notification_service.dart';
import '../../data/models/dispenser_model.dart';
import '../providers/dispenser_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/user_entity.dart';

final notificationSyncLogicProvider = Provider<void>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null || user.linkedDispensers.isEmpty) return;

  final dispenserId = user.linkedDispensers.first; // Assume first for now
  final dispenserAsync = ref.watch(dispenserProvider(dispenserId));

  dispenserAsync.whenData((dispenser) {
    if (dispenser != null) {
      final currentDay = dispenser.currentState.operational.currentDay;
      final totalDosesRemaining = dispenser.currentState.totalDosesRemaining;
      final notificationsEnabled = dispenser.configuration.notificationsEnabled;

      // Check if sync is actually needed to avoid redundant cancels and reschedules
      final needsSync = _lastSynced == null ||
          _lastSynced!.currentDay != currentDay ||
          _lastSynced!.totalDosesRemaining != totalDosesRemaining ||
          _lastSynced!.notificationsEnabled != notificationsEnabled ||
          !_areSchedulesEqual(_lastSynced!.schedule, dispenser.schedule);

      if (needsSync) {
        _lastSynced = LastSyncedData(
          schedule: dispenser.schedule,
          currentDay: currentDay,
          totalDosesRemaining: totalDosesRemaining,
          notificationsEnabled: notificationsEnabled,
        );
        
        if (notificationsEnabled) {
          _syncSchedule(dispenser);
        } else {
          _notificationService.cancelAll();
        }
      }
    }
  });
});

final _notificationService = NotificationService();

Future<void> _syncSchedule(DispenserModel dispenser) async {
  // 1. Cancel all existing alarms to avoid stale or duplicate schedules
  await _notificationService.cancelAll();

  // Patients and Caregivers get dose reminders AND the Day 4 & Day 5 Refill alerts!
  final schedule = dispenser.schedule;
  final currentDay = dispenser.currentState.operational.currentDay; // 1-indexed
  final now = DateTime.now();

  for (int i = currentDay - 1; i < schedule.days.length; i++) {
     final int dayNum = i + 1; // 1-based day number
     final daySchedule = schedule.days[i];
     final int daysFromNow = i - (currentDay - 1);
     final dateBase = now.add(Duration(days: daysFromNow));

     // Schedule Day 4 & 5 Refill Alerts
     if (dayNum == 4 || dayNum == 5) {
       final refillTime = DateTime(
         dateBase.year, 
         dateBase.month, 
         dateBase.day, 
         9, // 9:00 AM
         0
       );
       final alarmId = 100 * dayNum; // 400 or 500
       
       if (refillTime.isAfter(now)) {
         await _notificationService.scheduleAlarm(
           id: alarmId,
           title: "Refill Reminder ⚠️",
           body: "Dispenser is on Day $dayNum. Please refill the dispenser soon.",
           scheduledTime: refillTime,
         );
       } else if (currentDay == dayNum) {
         // If it is already that day and past 9:00 AM, trigger immediate alert
         await _notificationService.showNotification(
           id: alarmId,
           title: "Refill Reminder ⚠️",
           body: "Dispenser is on Day $dayNum. Please refill the dispenser soon.",
         );
       }
     }

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

        if (scheduledTime.isBefore(now)) return;

        await _notificationService.scheduleAlarm(
          id: idBase + dayNum, 
          title: title,
          body: body,
          scheduledTime: scheduledTime,
        );
     }
     
     await scheduleDose(100, "Morning Medicine", "It's time for your Day $dayNum morning dose.", daySchedule.morning);
     await scheduleDose(200, "Lunch Medicine", "It's time for your Day $dayNum lunch dose.", daySchedule.lunch);
     await scheduleDose(300, "Night Medicine", "It's time for your Day $dayNum night dose.", daySchedule.night);
  }
}

// --- Caching and Comparison Helpers for stable local notification scheduling ---

class LastSyncedData {
  final ScheduleModel schedule;
  final int currentDay;
  final int totalDosesRemaining;
  final bool notificationsEnabled;

  LastSyncedData({
    required this.schedule,
    required this.currentDay,
    required this.totalDosesRemaining,
    required this.notificationsEnabled,
  });
}

LastSyncedData? _lastSynced;

bool _areSchedulesEqual(ScheduleModel a, ScheduleModel b) {
  if (a.days.length != b.days.length) return false;
  for (int i = 0; i < a.days.length; i++) {
    final dayA = a.days[i];
    final dayB = b.days[i];
    if (!_isDoseEqual(dayA.morning, dayB.morning) ||
        !_isDoseEqual(dayA.lunch, dayB.lunch) ||
        !_isDoseEqual(dayA.night, dayB.night)) {
      return false;
    }
  }
  return true;
}

bool _isDoseEqual(DoseTimeModel a, DoseTimeModel b) {
  return a.hour == b.hour && a.minute == b.minute && a.enabled == b.enabled;
}
